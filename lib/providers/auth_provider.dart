import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firebase_service.dart';

//makes firebase service available
final firebaseServiceProvider = Provider<FirebaseService>((ref){
  return FirebaseService();
});

// lets screens observe user's authentication state
final authStateProvider = StreamProvider<User?>((ref){
  final firebaseService = ref.watch(firebaseServiceProvider);

  return firebaseService.authStateChanges;
});