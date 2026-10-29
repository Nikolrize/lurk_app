import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PlayerLoadError extends StatelessWidget {
  const PlayerLoadError({
    super.key,
    required this.error,
    required this.onRetry,
  });
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final message = switch (error) {
      FirebaseException(code: 'permission-denied') =>
        'Unable to access player profiles. Check your sign-in and Firestore permissions.',
      FirebaseException(code: 'unavailable') =>
        'Cannot reach players. Check your connection and try again.',
      _ => 'Unable to load players. Please try again.',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
