import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PartyLoadError extends StatelessWidget {
  const PartyLoadError({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final message = switch (error) {
      FirebaseException(code: 'permission-denied') =>
        'Party access is not enabled yet. Check the Firestore rules and sign in again.',
      FirebaseException(code: 'unavailable') =>
        'Cannot reach parties. Check your connection and try again.',
      _ => 'Unable to load parties. Please try again.',
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
