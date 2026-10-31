import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'notification_service.dart';
import 'party_service.dart';

class FirebaseService {
  FirebaseService({
    FirebaseAuth? auth,
    Future<void> Function(String uid)? leaveParties,
    Future<void> Function()? unregisterNotifications,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _leaveParties =
           leaveParties ??
           ((uid) => PartyService().leaveCurrentParties(expectedUid: uid)),
       _unregisterNotifications =
           unregisterNotifications ?? NotificationService.instance.unregister;

  final FirebaseAuth _auth;
  final Future<void> Function(String uid) _leaveParties;
  final Future<void> Function() _unregisterNotifications;

  Future<void> Function()? beforeSignOut;

  // returns currently signed-in user, or null of signed out
  User? get currentUser => _auth.currentUser;

  //notifies app
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // creates email password account and signs in
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  //sign in
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // google sign in for web and android
  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      return _auth.signInWithPopup(GoogleAuthProvider());
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final googleUser = await GoogleSignIn.instance.authenticate();

      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw StateError('Google sign-in did not return an ID token.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);

      return _auth.signInWithCredential(credential);
    }

    throw UnsupportedError(
      'Google sign-in is currently configured for web and Android.',
    );
  }

  //sends email containing password reset
  Future<void> sendPasswordReset({required String email}) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  // Party, notification and presence cleanup all need authentication.
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) await _leaveParties(uid);
    await _unregisterNotifications();
    await beforeSignOut?.call();
    await _auth.signOut();
  }
}
