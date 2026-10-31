import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

const reportReasons = [
  'Toxic behaviour',
  'Harassment',
  'Inappropriate language',
  'Cheating',
  'Other',
];
final playerSafetyServiceProvider = Provider((ref) => PlayerSafetyService());
final blockedPlayersProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(<String>{});
  return FirebaseFirestore.instance
      .collection('player_blocks')
      .doc(uid)
      .collection('blocked')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
}, retry: (retryCount, error) => null);

class PlayerSafetyService {
  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      (throw StateError('Please sign in.'));
  void _validate(String target) {
    if (target.isEmpty || target.contains('/') || target == _uid) {
      throw ArgumentError('Choose another player.');
    }
  }

  Future<void> setBlocked(String target, bool blocked) async {
    _validate(target);
    final doc = FirebaseFirestore.instance
        .collection('player_blocks')
        .doc(_uid)
        .collection('blocked')
        .doc(target);
    if (blocked) {
      await doc.set({'createdAt': FieldValue.serverTimestamp()});
    } else {
      await doc.delete();
    }
  }

  Future<void> report(
    String target,
    List<String> reasons,
    String details,
  ) async {
    _validate(target);
    final reporterId = _uid;
    final selected = List<String>.of(reasons);
    final cleanDetails = details.trim();
    if (selected.isEmpty ||
        selected.length > reportReasons.length ||
        selected.toSet().length != selected.length ||
        selected.any((reason) => !reportReasons.contains(reason)) ||
        cleanDetails.length > 2000) {
      throw ArgumentError('Select valid report reasons.');
    }
    final db = FirebaseFirestore.instance;
    final report = db.collection('player_reports').doc();
    await db.runTransaction((transaction) async {
      final reporter = await transaction.get(
        db.collection('players').doc(reporterId),
      );
      final player = await transaction.get(
        db.collection('players').doc(target),
      );
      if (!reporter.exists || !player.exists) {
        throw StateError('Player profile not found.');
      }
      transaction.set(report, {
        'reporterId': reporterId,
        'reporterUsername': reporter.data()!['username'],
        'playerId': target,
        'playerUsername': player.data()!['username'],
        'reasons': selected,
        'details': cleanDetails,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
