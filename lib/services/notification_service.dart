import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Push is enabled on Android first; other clients continue without push.
// Token APIs support Console test sends and the laptop sender's Admin SDK.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  StreamSubscription<String>? _refresh;
  Future<void> _writes = Future.value();
  String? _uid;
  String? token;
  bool _initialConsumed = false;

  Future<void> register(String uid) async {
    if (!supported) return;
    _uid = uid;
    // ignore: deprecated_member_use
    _refresh ??= FirebaseMessaging.instance.onTokenRefresh.listen((value) {
      unawaited(
        _save(value).catchError((Object e) {
          debugPrint('Notification registration failed: $e');
        }),
      );
    });
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    // ignore: deprecated_member_use
    final value = await FirebaseMessaging.instance.getToken();
    if (_uid == uid && value != null) await _save(value);
  }

  Future<void> _save(String value) {
    final uid = _uid;
    if (uid == null) return Future.value();
    final previous = token;
    token = value;
    final next = _writes.catchError((Object _) {}).then((_) async {
      if (_uid != uid || FirebaseAuth.instance.currentUser?.uid != uid) return;
      final devices = FirebaseFirestore.instance
          .collection('notification_users')
          .doc(uid)
          .collection('devices');
      await devices.doc(value).set({
        'token': value,
        'platform': 'android',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (previous != null && previous != value) {
        await devices.doc(previous).delete();
      }
    });
    _writes = next;
    return next;
  }

  Future<RemoteMessage?> initialMessage() async {
    if (!supported || _initialConsumed) return null;
    _initialConsumed = true;
    return FirebaseMessaging.instance.getInitialMessage();
  }

  /// Revoke delivery before ending the authenticated session.
  Future<void> unregister() async {
    if (!supported) return;
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    _uid = null;
    await _refresh?.cancel();
    _refresh = null;
    // Do not block logout forever on an offline Firestore write.
    await _writes
        .catchError((Object _) {})
        .timeout(const Duration(seconds: 5), onTimeout: () {});
    // ignore: deprecated_member_use
    final value = token ?? await FirebaseMessaging.instance.getToken();
    // ignore: deprecated_member_use
    await FirebaseMessaging.instance.deleteToken();
    token = null;
    if (uid != null && value != null) {
      try {
        await FirebaseFirestore.instance
            .collection('notification_users')
            .doc(uid)
            .collection('devices')
            .doc(value)
            .delete()
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Device cleanup deferred: $e');
      }
    }
  }
}
