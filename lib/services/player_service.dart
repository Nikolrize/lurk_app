import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/player/models/player.dart';

class PlayerService {
  PlayerService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Stream<List<Player>> watchDiscoverablePlayers(String viewerId) {
    // Public profiles only. No reads from player_private.
    // Initial bounded directory; pagination can be added as the community grows.
    return _firestore.collection('players').limit(100).snapshots().map((
      snapshot,
    ) {
      final players = snapshot.docs
          .where((doc) => doc.id != viewerId)
          .map((doc) => Player.fromFirestoreData(doc.id, doc.data()))
          .where((player) => player.name.isNotEmpty)
          .toList();
      players.sort((a, b) {
        final comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return comparison != 0 ? comparison : a.id.compareTo(b.id);
      });
      return List.unmodifiable(players);
    });
  }
}
