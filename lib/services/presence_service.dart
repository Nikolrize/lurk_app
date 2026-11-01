import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/player_presence.dart';
import '../models/player_status.dart';

import '../core/data/game_catalog.dart';

class PresenceService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
    //url gotten from real-time database
        'https://lurk-mae-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  Stream<PlayerPresence?> watchPresence(String uid) {
    return _db.ref('presence/$uid').onValue.map((event) { //points to one player's presence data
      final value = event.snapshot.value;

      if (value == null) return null;

      return PlayerPresence.fromMap(
        Map<Object?, Object?>.from(value as Map),
      );
    });
  }

  Future<void> setPreference({
    required String expectedUid,
    required PlayerStatus status,
  }) {
    final user = _auth.currentUser;

    if (user == null || user.uid != expectedUid) {
      throw StateError('The account changed. Reopen your profile.');
    }

    return _db
        .ref('presence/${user.uid}/preference')
        .set(status.id); //writes chosen status ID
  }

  void _checkAccount(String expectedUid) {
    if (_auth.currentUser?.uid != expectedUid) {
      throw StateError('The signed-in account changed.');
    }
  }

  DatabaseReference _sessionReference(
    String uid,
    String sessionId,
  ) {
    if (sessionId.isEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(sessionId)) {
      throw ArgumentError('Invalid session ID.');
    }

    return _db.ref('presence/$uid/sessions/$sessionId');
  }

  Stream<bool> get connectionChanges {
    return _db.ref('.info/connected').onValue.map((event) { //detects whether the app is connected
      return event.snapshot.value == true;
    }).distinct();
  }

  String createSessionId() {
    return _db.ref().push().key!; //generates session ID 
  }

  Future<void> openSession({
    required String expectedUid,
    required String sessionId,
    String? gameId,
    required bool idle,
    bool Function()? shouldContinue,
  }) async {
    bool canContinue() => shouldContinue?.call() ?? true;

    if (!canContinue()) return;
    _checkAccount(expectedUid);

    await _db.ref('presence/$expectedUid/preference').runTransaction(
      (current) => Transaction.success(
        current ?? PlayerStatus.online.id,
      ),
      applyLocally: false,
    );

    if (!canContinue()) return;
    _checkAccount(expectedUid);

    final session = _sessionReference(expectedUid, sessionId);

    final activity = _db.ref(
      'presence/$expectedUid/activities/$sessionId',
    );

    await session.onDisconnect().remove();
    await activity.onDisconnect().remove();

    if (!canContinue()) return;
    _checkAccount(expectedUid);

    await _writeSession(
      expectedUid: expectedUid,
      sessionId: sessionId,
      idle: idle,
      gameId: gameId,
    );
  }

  Future<void> updateSession({
    required String expectedUid,
    required String sessionId,
    required bool idle,
    String? gameId,
  }) {
    return _writeSession(
      expectedUid: expectedUid,
      sessionId: sessionId,
      idle: idle,
      gameId: gameId,
    );
  } 

  Future<void> closeSession({
    required String expectedUid,
    required String sessionId,
  }) async {
    _checkAccount(expectedUid);

    final session = _sessionReference(expectedUid, sessionId);

    final activity = _db.ref(
      'presence/$expectedUid/activities/$sessionId',
    );

    await session.parent!.parent!.update({
      'sessions/$sessionId': null,
      'activities/$sessionId': null,
    });

    //disconnects session when closed
    await session.onDisconnect().cancel();
    await activity.onDisconnect().cancel();
  }

  Future<void> connect() => _db.goOnline();

  Future<void> disconnect() => _db.goOffline();

  //include game in current session
  Future<void> _writeSession({
    required String expectedUid,
    required String sessionId,
    required bool idle,
    String? gameId,
  }) {
    _checkAccount(expectedUid);

    final session = _sessionReference(expectedUid, sessionId);

    if (gameId != null && !GameCatalog.games.containsKey(gameId)) {
      throw ArgumentError('Unsupported party game.');
    }

    return session.parent!.parent!.update({
      'sessions/$sessionId':
          idle ? PlayerStatus.idle.id : PlayerStatus.online.id,
      'activities/$sessionId': gameId,
  });
}
}