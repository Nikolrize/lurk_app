import 'package:flutter/material.dart';
import '../../../core/widgets/notification_gate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/core/widgets/app_shell.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/features/profile/widgets/profile_gate.dart';
import 'package:lurk_app/features/authentication/screens/login_screen.dart';

import 'package:lurk_app/features/profile/widgets/presence_scope.dart';

import 'package:lurk_app/features/verification/widgets/verification_role_gate.dart';

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

        return VerificationRoleGate(
          key: ValueKey(user.uid),
          uid: user.uid,
          playerChild: PresenceScope(
            key: ValueKey(user.uid),
            uid: user.uid,
            child: ProfileGate(
              uid: user.uid,
              child: NotificationGate(
                uid: user.uid,
                child: AppShell(uid: user.uid),
              ),
            ),
          ),
        );
      },
    );
  }
}
