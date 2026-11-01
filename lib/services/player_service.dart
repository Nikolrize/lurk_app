import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/player/models/player.dart';

class PlayerService {
  PlayerService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Stream<List<Player>> watchDiscoverablePlayers(
    String viewerId, {
    int limit = 100,
    Set<String> excludedIds = const {},
  }) {
    // Public profiles only. No reads from player_private.
    // Find increases the live directory limit when another page is requested.
    return _firestore
        .collection('players')
        .limit(limit + excludedIds.length + 1)
        .snapshots()
        .map((snapshot) {
          final players = snapshot.docs
              .where(
                (doc) => doc.id != viewerId && !excludedIds.contains(doc.id),
              )
              .map((doc) => Player.fromFirestoreData(doc.id, doc.data()))
              .where((player) => player.name.isNotEmpty)
              .toList();
          players.sort((a, b) {
            final comparison = a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            );
            return comparison != 0 ? comparison : a.id.compareTo(b.id);
          });
          return List.unmodifiable(players.take(limit));
        });
  }
}
