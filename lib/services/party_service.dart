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
    final party = _firestore.collection('parties').doc();
    final batch = _firestore.batch();
    batch.set(party, {
      ...draft.toFirestoreFields(),
      'hostId': expectedUid,
      'status': 'open',
      'memberCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'startedAt': null,
      'completedAt': null,
    });
    batch.set(party.collection('members').doc(expectedUid), {
      'role': 'host',
      'joinedAt': FieldValue.serverTimestamp(),
      'leftAt': null,
    });
    await batch.commit();
    return party.id;
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
