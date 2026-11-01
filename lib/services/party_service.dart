import '../features/parties/models/party_join_eligibility.dart';
import 'party_membership_events.dart';
import '../features/parties/models/party_history_entry.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/parties/models/party_draft.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/parties/models/party.dart';

class PartyService {
  PartyService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Future<String> createParty(
    PartyDraft draft, {
    required String expectedUid,
  }) async {
    draft.validate();
    if (FirebaseAuth.instance.currentUser?.uid != expectedUid) {
      throw StateError(
        'Your account changed. Sign in again before creating a party.',
      );
    }
    // Include existing parties created before host slots were introduced.
    final existing = await _firestore
        .collection('parties')
        .where('hostId', isEqualTo: expectedUid)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (existing.docs.isNotEmpty) {
      throw StateError(
        'You already host an active party. End your current party session before creating another.',
      );
    }
    final party = _firestore.collection('parties').doc();
    final slot = _firestore.collection('party_host_slots').doc(expectedUid);
    await _firestore.runTransaction((transaction) async {
      final current = await transaction.get(slot);
      final pointer = await transaction.get(
        _firestore.collection('party_memberships').doc(expectedUid),
      );
      final joinedId = pointer.data()?['partyId'] as String?;
      if (joinedId != null) {
        final joinedRef = _firestore.collection('parties').doc(joinedId);
        final member = await transaction.get(
          joinedRef.collection('members').doc(expectedUid),
        );
        final joined = member.exists && member.data()?['leftAt'] == null
            ? await transaction.get(joinedRef)
            : null;
        if (joined?.data()?['status'] == 'open') {
          throw StateError(
            'Leave your current party before creating a new one.',
          );
        }
      }
      if ((current.data()?['activeCount'] ?? 0) != 0) {
        throw StateError(
          'You already host an active party. End your current party session before creating another.',
        );
      }
      transaction.set(party, {
        ...draft.toFirestoreFields(),
        'hostId': expectedUid,
        'status': 'open',
        'memberCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'startedAt': null,
        'completedAt': null,
      });
      transaction.set(party.collection('members').doc(expectedUid), {
        'role': 'host',
        'joinedAt': FieldValue.serverTimestamp(),
        'leftAt': null,
      });
      transaction.set(_history(expectedUid, party.id), {
        'title': draft.title.trim(),
        'gameId': draft.gameId,
        'mode': draft.mode,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(slot, {
        'activeCount': 1,
        'lastPartyId': party.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    PartyMembershipEvents.emit(expectedUid, party.id, PartySound.join);
    return party.id;
  }

  Future<void> joinParty(
    String id, {
    required String expectedUid,
    String? switchFromPartyId,
  }) async {
    _checkAccount(expectedUid);
    final party = _firestore.collection('parties').doc(id);
    final member = party.collection('members').doc(expectedUid);
    final current = _firestore.collection('party_memberships').doc(expectedUid);
    final rejection = PartyJoinRejection();
    final switchedFrom = await rejection.run(
      () => _firestore.runTransaction<String?>((transaction) async {
        rejection.reset();
        String? previousActiveParty;
        final snapshot = await transaction.get(party);
        final membership = await transaction.get(member);
        final pointer = await transaction.get(current);
        final historySnapshot = await transaction.get(
          _history(expectedUid, id),
        );
        final data = snapshot.data();
        if (data == null || data['status'] != 'open') {
          rejection.reject('This party session has ended.');
        }
        if (data['hostId'] == expectedUid ||
            (membership.exists && membership.data()?['leftAt'] == null)) {
          return null;
        }
        if ((data['memberCount'] as num) >= (data['maxPlayers'] as num)) {
          rejection.reject('This party is full.');
        }
        final profile = await transaction.get(
          _firestore.collection('players').doc(expectedUid),
        );
        final minimum = (data['minimumRating'] as num?)?.toDouble() ?? 0;
        final summary = minimum > 0
            ? (await transaction.get(
                _firestore
                    .collection('player_rating_summaries')
                    .doc(expectedUid),
              )).data()
            : null;
        final reason = partyRequirementMessage(
          party: data,
          profile: profile.data(),
          ratingSummary: summary,
        );
        if (reason != null) rejection.reject(reason);
        final needsInvite = data['visibility'] == 'private';
        final removed = membership.data()?['removedBy'] != null;
        if (needsInvite || removed) {
          final invitation = await transaction.get(
            party.collection('invitations').doc(expectedUid),
          );
          if (removed) {
            final sent = invitation.data()?['createdAt'] as Timestamp?;
            final left = membership.data()?['leftAt'] as Timestamp?;
            if (sent == null || left == null || sent.compareTo(left) <= 0) {
              rejection.reject(
                'You were removed from this party. Ask the host for a new invitation to rejoin.',
              );
            }
          } else if (!invitation.exists) {
            rejection.reject(
              'This is a private party. Ask the host to send you an invitation before joining.',
            );
          }
        }
        final hostId = data['hostId'] as String;
        for (final pair in [(expectedUid, hostId), (hostId, expectedUid)]) {
          for (final path in ['blocked', 'users']) {
            final block = await transaction.get(
              _firestore
                  .collection('player_blocks')
                  .doc(pair.$1)
                  .collection(path)
                  .doc(pair.$2),
            );
            if (block.exists) {
              rejection.reject(
                pair.$1 == expectedUid
                    ? 'You blocked this party’s host. Unblock them before joining.'
                    : 'You cannot join this party because the host has blocked your account.',
              );
            }
          }
        }
        final hosted = await transaction.get(
          _firestore.collection('party_host_slots').doc(expectedUid),
        );
        if ((hosted.data()?['activeCount'] as num? ?? 0) > 0) {
          rejection.reject(
            'End your hosted party session before joining another party.',
          );
        }
        final previousId = pointer.data()?['partyId'] as String?;
        if (previousId != null && previousId != id) {
          final previousParty = _firestore
              .collection('parties')
              .doc(previousId);
          final previousMember = await transaction.get(
            previousParty.collection('members').doc(expectedUid),
          );
          final previous =
              previousMember.exists && previousMember.data()?['leftAt'] == null
              ? await transaction.get(previousParty)
              : null;
          if (previous?.data()?['status'] == 'open') {
            if (switchFromPartyId != previousId) {
              rejection.reject(
                'Your current party changed. Reopen the preview and confirm switching parties.',
              );
            }
            if (previousMember.data()?['role'] != 'member') {
              rejection.reject(
                'End your hosted party session before joining another party.',
              );
            }
            previousActiveParty = previousId;
            transaction.update(previousParty, {
              'memberCount':
                  (previous!.data()!['memberCount'] as num).toInt() - 1,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            transaction.update(
              previousParty.collection('members').doc(expectedUid),
              {'leftAt': FieldValue.serverTimestamp()},
            );
          }
        }
        // Preserve the completed visit before replacing the live membership.
        final previousVisit = membership.data();
        if (previousVisit?['joinedAt'] is Timestamp &&
            previousVisit?['leftAt'] is Timestamp) {
          final joinedAt = previousVisit!['joinedAt'] as Timestamp;
          transaction.set(
            party
                .collection('visits')
                .doc('${expectedUid}_${joinedAt.millisecondsSinceEpoch}'),
            {
              'uid': expectedUid,
              'joinedAt': joinedAt,
              'leftAt': previousVisit['leftAt'],
            },
          );
        }
        transaction.set(member, {
          'role': 'member',
          'joinedAt': FieldValue.serverTimestamp(),
          'leftAt': null,
        });
        transaction.update(party, {
          'memberCount': (data['memberCount'] as num).toInt() + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (!historySnapshot.exists) {
          transaction.set(_history(expectedUid, id), {
            'title': data['title'],
            'gameId': data['gameId'],
            'mode': data['mode'],
            'joinedAt': FieldValue.serverTimestamp(),
          });
        }
        transaction.set(current, {
          'partyId': id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return previousActiveParty ?? '';
      }),
    );
    if (switchedFrom != null) {
      if (switchedFrom.isNotEmpty) {
        PartyMembershipEvents.emit(expectedUid, switchedFrom, PartySound.leave);
      }
      PartyMembershipEvents.emit(expectedUid, id, PartySound.join);
    }
  }

  Stream<String?> watchJoinedPartyId(String uid) => _firestore
      .collection('party_memberships')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data()?['partyId'] as String?);

  Stream<List<String>> watchMemberIds(String id) => _firestore
      .collection('parties')
      .doc(id)
      .collection('members')
      .where('leftAt', isNull: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());

  void _checkAccount(String uid) {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Your account changed. Sign in again.');
    }
  }

  Stream<Party?> watchParty(String id) => _firestore
      .collection('parties')
      .doc(id)
      .snapshots()
      .map(
        (doc) =>
            doc.exists ? Party.fromFirestoreData(doc.id, doc.data()!) : null,
      );

  Future<void> updateParty(
    String id,
    PartyDraft draft, {
    required String expectedUid,
  }) async {
    _checkAccount(expectedUid);
    draft.validate();
    final party = _firestore.collection('parties').doc(id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(party);
      final data = snapshot.data();
      if (data == null ||
          data['hostId'] != expectedUid ||
          data['status'] != 'open') {
        throw StateError('Only the host can edit an open party.');
      }
      if (draft.maxPlayers < (data['memberCount'] as num).toInt()) {
        throw StateError('Max size cannot be smaller than the current squad.');
      }
      transaction.update(party, {
        ...draft.toFirestoreFields(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> transferHost(
    String id,
    String newHostUid, {
    required String expectedUid,
  }) async {
    _checkAccount(expectedUid);
    if (newHostUid == expectedUid) {
      throw StateError('You are already the host.');
    }
    final party = _firestore.collection('parties').doc(id);
    final oldMember = party.collection('members').doc(expectedUid);
    final newMember = party.collection('members').doc(newHostUid);
    final oldSlot = _firestore.collection('party_host_slots').doc(expectedUid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(party);
      final oldMembership = await transaction.get(oldMember);
      final newMembership = await transaction.get(newMember);
      final slot = await transaction.get(oldSlot);
      if (snapshot.data()?['hostId'] != expectedUid ||
          snapshot.data()?['status'] != 'open') {
        throw StateError('Only the current host can transfer this party.');
      }
      if (oldMembership.data()?['role'] != 'host' ||
          oldMembership.data()?['leftAt'] != null ||
          !newMembership.exists ||
          newMembership.data()?['role'] != 'member' ||
          newMembership.data()?['leftAt'] != null) {
        throw StateError('Choose a player who is still in this party.');
      }
      if (slot.data()?['activeCount'] != 1) {
        throw StateError(
          'End any other hosted sessions before transferring this party.',
        );
      }
      transaction.update(party, {
        'hostId': newHostUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(oldMember, {'role': 'member'});
      transaction.update(newMember, {'role': 'host'});
      transaction.set(oldSlot, {
        'activeCount': 0,
        'lastPartyId': id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        _firestore.collection('party_host_slots').doc(newHostUid),
        {
          'activeCount': 1,
          'lastPartyId': id,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      transaction.set(
        _firestore.collection('party_memberships').doc(expectedUid),
        {'partyId': id, 'updatedAt': FieldValue.serverTimestamp()},
      );
      transaction.delete(
        _firestore.collection('party_memberships').doc(newHostUid),
      );
    });
  }

  Future<void> removeMember(
    String id,
    String memberUid, {
    required String expectedUid,
  }) async {
    _checkAccount(expectedUid);
    if (memberUid == expectedUid) {
      throw StateError('Use Leave Party to end your session.');
    }
    final party = _firestore.collection('parties').doc(id);
    final member = party.collection('members').doc(memberUid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(party);
      final membership = await transaction.get(member);
      final data = snapshot.data();
      if (data == null ||
          data['hostId'] != expectedUid ||
          data['status'] != 'open') {
        throw StateError(
          'Only the host can remove players from an open party.',
        );
      }
      if (!membership.exists ||
          membership.data()?['role'] != 'member' ||
          membership.data()?['leftAt'] != null) {
        throw StateError('This player is no longer in the party.');
      }
      transaction.update(member, {
        'leftAt': FieldValue.serverTimestamp(),
        'removedBy': expectedUid,
      });
      transaction.update(party, {
        'memberCount': (data['memberCount'] as num).toInt() - 1,
        'lastRemovedMemberId': memberUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<Map<String, dynamic>?> watchMembership(String id, String uid) =>
      _firestore
          .collection('parties')
          .doc(id)
          .collection('members')
          .doc(uid)
          .snapshots()
          .map((doc) => doc.data());

  /// Finish participation while authentication is still available, including
  /// sessions hosted before the one-party restriction was introduced.
  Future<void> leaveCurrentParties({required String expectedUid}) async {
    _checkAccount(expectedUid);
    final hosted = await _firestore
        .collection('parties')
        .where('hostId', isEqualTo: expectedUid)
        .where('status', isEqualTo: 'open')
        .get(const GetOptions(source: Source.server));
    final pointer = await _firestore
        .collection('party_memberships')
        .doc(expectedUid)
        .get(const GetOptions(source: Source.server));
    final ids = hosted.docs.map((doc) => doc.id).toSet();
    final joinedId = pointer.data()?['partyId'] as String?;
    if (joinedId != null) {
      // A kicked member may retain a stale pointer; their own membership is
      // always readable, even when private party details are no longer visible.
      final member = await _firestore
          .collection('parties')
          .doc(joinedId)
          .collection('members')
          .doc(expectedUid)
          .get(const GetOptions(source: Source.server));
      if (member.exists && member.data()?['leftAt'] == null) ids.add(joinedId);
    }
    for (final id in ids) {
      await _leaveParty(id, expectedUid: expectedUid, onlyIfActive: true);
    }
  }

  Future<void> leaveParty(String id, {required String expectedUid}) =>
      _leaveParty(id, expectedUid: expectedUid);

  Future<void> _leaveParty(
    String id, {
    required String expectedUid,
    bool onlyIfActive = false,
  }) async {
    _checkAccount(expectedUid);
    final party = _firestore.collection('parties').doc(id);
    final member = party.collection('members').doc(expectedUid);
    final left = await _firestore.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(party);
      final membership = await transaction.get(member);
      final data = snapshot.data();
      if (data == null || data['status'] != 'open') {
        if (onlyIfActive) return false;
        throw StateError('This party is already closed.');
      }
      if (!membership.exists || membership.data()?['leftAt'] != null) {
        if (onlyIfActive) return false;
        throw StateError('You are no longer in this party.');
      }
      final current = _firestore
          .collection('party_memberships')
          .doc(expectedUid);
      final pointer = await transaction.get(current);
      final isHost = data['hostId'] == expectedUid;
      final slot = _firestore.collection('party_host_slots').doc(expectedUid);
      final slotSnapshot = isHost ? await transaction.get(slot) : null;
      if (isHost) {
        final count = (slotSnapshot?.data()?['activeCount'] as num?)?.toInt();
        if (count == null || count < 1) {
          throw StateError('Unable to end this session. Please try again.');
        }
        transaction.set(slot, {
          'activeCount': count - 1,
          'lastPartyId': id,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.update(party, {
        'memberCount': isHost ? 0 : (data['memberCount'] as num).toInt() - 1,
        if (isHost) 'status': 'closed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(member, {'leftAt': FieldValue.serverTimestamp()});
      if (pointer.data()?['partyId'] == id) transaction.delete(current);
      return true;
    });
    if (left) PartyMembershipEvents.emit(expectedUid, id, PartySound.leave);
  }

  Stream<Party?> watchLatestHostedParty(String uid) {
    return _firestore
        .collection('parties')
        .where('hostId', isEqualTo: uid)
        .where('status', isEqualTo: 'open')
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final parties = snapshot.docs
              .map((doc) => Party.fromFirestoreData(doc.id, doc.data()))
              .toList();
          parties.sort(
            (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
              a.createdAt ?? DateTime(1970),
            ),
          );
          return parties.isEmpty ? null : parties.first;
        });
  }

  Stream<List<Party>> watchDiscoverableParties({int limit = 100}) {
    // Match security rules; private/completed parties never enter the client list.
    // Find increases this live query limit when another page is requested.
    return _firestore
        .collection('parties')
        .where('visibility', isEqualTo: 'public')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final parties = snapshot.docs
              .map((doc) => Party.fromFirestoreData(doc.id, doc.data()))
              .toList();
          parties.sort((a, b) {
            final time = (b.createdAt ?? DateTime(1970)).compareTo(
              a.createdAt ?? DateTime(1970),
            );
            return time != 0 ? time : a.id.compareTo(b.id);
          });
          return List.unmodifiable(parties);
        });
  }

  DocumentReference<Map<String, dynamic>> _history(
    String uid,
    String partyId,
  ) => _firestore
      .collection('players')
      .doc(uid)
      .collection('party_history')
      .doc(partyId);

  Stream<List<PartyHistoryRecord>> watchHistory(String uid, {int limit = 50}) =>
      _firestore
          .collection('players')
          .doc(uid)
          .collection('party_history')
          .orderBy('joinedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => PartyHistoryRecord.fromMap(doc.id, doc.data()))
                .toList(),
          );

  Stream<List<String>> watchHistoryMemberIds(String id) => _firestore
      .collection('parties')
      .doc(id)
      .collection('members')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());

  Future<List<Party>> findQuickMatchParties(
    String gameId, {
    required String regionId,
  }) async {
    // Read the game-specific pool in pages; joining is validated transactionally.
    final query = _firestore
        .collection('parties')
        .where('gameId', isEqualTo: gameId)
        .where('region', isEqualTo: regionId)
        .where('visibility', isEqualTo: 'public')
        .where('status', isEqualTo: 'open')
        .orderBy(FieldPath.documentId)
        .limit(100);
    final parties = <Party>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      final page =
          await (cursor == null ? query : query.startAfterDocument(cursor)).get(
            const GetOptions(source: Source.server),
          );
      parties.addAll(
        page.docs.map((doc) => Party.fromFirestoreData(doc.id, doc.data())),
      );
      if (page.docs.length < 100) return parties;
      cursor = page.docs.last;
    }
  }
}
