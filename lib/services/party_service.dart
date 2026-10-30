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
      transaction.set(slot, {
        'activeCount': 1,
        'lastPartyId': party.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return party.id;
  }

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
}
