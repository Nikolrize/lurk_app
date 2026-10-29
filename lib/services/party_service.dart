import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/parties/models/party.dart';

class PartyService {
  PartyService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

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
