import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

String chatSendErrorDescription(Object error) {
  if (kDebugMode) debugPrint('Chat send failed: $error');
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'You do not have permission to send this message. Please sign in again or contact support.',
      'unauthenticated' => 'Please sign in again to send your message.',
      'unavailable' || 'deadline-exceeded' =>
        'Message was not confirmed. Check your connection before trying again.',
      _ =>
        'Message could not be sent. Your draft has been kept. Please try again.',
    };
  }
  if (error is ArgumentError) return 'Messages must contain 1-2000 characters.';
  return 'Message could not be sent. Your draft has been kept. Please try again.';
}

String chatErrorDescription(Object error) {
  if (kDebugMode) debugPrint('Chat load failed: $error');
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'Chat access is unavailable. Please contact support or try signing in again.',
      'unauthenticated' => 'Please sign in again to view your chats.',
      'failed-precondition' =>
        'Chat setup is still being completed. Please try again shortly.',
      'unavailable' ||
      'deadline-exceeded' => 'Check your connection and try again.',
      _ => 'Could not load your chats. Please try again.',
    };
  }
  return 'Could not load your chats. Please try again.';
}
