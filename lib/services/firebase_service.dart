import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // returns currently signed-in user, or null of signed out
  User? get currentUser => _auth.currentUser;

  //notifies app 
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // creates email password account and signs in
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(email: email.trim(), password: password,);
  }

  //sign in
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
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

      final credential = GoogleAuthProvider.credential(idToken : idToken,);

      return _auth.signInWithCredential(credential);
    }

    throw UnsupportedError('Google sign-in is currently configured for web and Android.',);
  }

  //sends email containing password reset 
  Future<void> sendPasswordReset({
    required String email,
  }) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  //sign out
  Future<void> signOut() {
    return _auth.signOut();
  }
}