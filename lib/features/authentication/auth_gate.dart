import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
        ),
        error: (error,stackTrace) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to check your login status.'),
                const SizedBox(height: 12),
                FilledButton(onPressed: () {
                  ref.invalidate(authStateProvider);
                },
                child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (user) {
          if (user == null) {
            return const LoginScreen();
          }

          return _SignedInScreen(user: user);
        },
    );
  }
}

//temp screen for testing
class _SignedInScreen extends ConsumerWidget {
  const _SignedInScreen({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lurk')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 64),
              const SizedBox(height: 16),
              const Text('You are signed in.'),
              const SizedBox(height: 8),
              Text(user.email ?? 'Lurk player'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  final service = ref.read(firebaseServiceProvider);

                  try {
                    await service.signOut();
                  } catch (_) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unable to sign out. Try again.'),
                      ),
                    );
                  }
                },
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}