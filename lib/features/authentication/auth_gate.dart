import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lurk_app/core/widgets/app_shell.dart';

import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to check your login status.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
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
class _SignedInScreen extends ConsumerWidget {
  const _SignedInScreen({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppShell();
  }
}
