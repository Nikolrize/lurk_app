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
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(party);
      final membership = await transaction.get(member);
      final pointer = await transaction.get(current);
      final data = snapshot.data();
      if (data == null || data['status'] != 'open') {
        throw StateError('This party session has ended.');
      }
      if (data['hostId'] == expectedUid ||
          (membership.exists && membership.data()?['leftAt'] == null)) {
        return;
      }
      if ((data['memberCount'] as num) >= (data['maxPlayers'] as num)) {
        throw StateError('This party is full.');
      }
      if (membership.data()?['removedBy'] != null) {
        final invitation = await transaction.get(
          party.collection('invitations').doc(expectedUid),
        );
        final sent = invitation.data()?['createdAt'] as Timestamp?;
        final removed = membership.data()?['leftAt'] as Timestamp?;
        if (sent == null || removed == null || sent.compareTo(removed) <= 0) {
          throw StateError(
            'You were removed from this party. Ask the host for a new invitation to rejoin.',
          );
        }
      }
      final hosted = await transaction.get(
        _firestore.collection('party_host_slots').doc(expectedUid),
      );
      if ((hosted.data()?['activeCount'] as num? ?? 0) > 0) {
        throw StateError(
          'End your hosted party session before joining another party.',
        );
      }
      final previousId = pointer.data()?['partyId'] as String?;
      if (previousId != null && previousId != id) {
        final previousParty = _firestore.collection('parties').doc(previousId);
        final previousMember = await transaction.get(
          previousParty.collection('members').doc(expectedUid),
        );
        final previous =
            previousMember.exists && previousMember.data()?['leftAt'] == null
            ? await transaction.get(previousParty)
            : null;
        if (previous?.data()?['status'] == 'open') {
          if (switchFromPartyId != previousId) {
            throw StateError(
              'Your current party changed. Reopen the preview and confirm switching parties.',
            );
          }
          if (previousMember.data()?['role'] != 'member') {
            throw StateError(
              'End your hosted party session before joining another party.',
            );
          }
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
      transaction.set(member, {
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
        'leftAt': null,
      });
      transaction.update(party, {
        'memberCount': (data['memberCount'] as num).toInt() + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(_history(expectedUid, id), {
        'title': data['title'],
        'gameId': data['gameId'],
        'mode': data['mode'],
        'joinedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(current, {
        'partyId': id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
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

  Future<void> leaveParty(String id, {required String expectedUid}) async {
    _checkAccount(expectedUid);
    final party = _firestore.collection('parties').doc(id);
    final member = party.collection('members').doc(expectedUid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(party);
      final membership = await transaction.get(member);
      final data = snapshot.data();
      if (data == null || data['status'] != 'open') {
        throw StateError('This party is already closed.');
      }
      if (!membership.exists || membership.data()?['leftAt'] != null) {
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
    });
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

  Stream<List<Party>> watchDiscoverableParties() {
    // Match security rules; private/completed parties never enter the client list.
    // Bounded initial discovery feed. Add pagination before expanding this limit.
    return _firestore
        .collection('parties')
        .where('visibility', isEqualTo: 'public')
        .where('status', isEqualTo: 'open')
        .limit(100)
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

  Stream<List<PartyHistoryRecord>> watchHistory(String uid) => _firestore
      .collection('players')
      .doc(uid)
      .collection('party_history')
      .orderBy('joinedAt', descending: true)
      .limit(50)
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
}
