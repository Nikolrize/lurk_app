import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/verification_provider.dart';

import '../screens/admin_verification_screen.dart';

class VerificationRoleGate extends ConsumerWidget {
  const VerificationRoleGate({
    super.key,
    required this.uid,
    required this.playerChild,
  });

  final String uid;
  final Widget playerChild;

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await ref.read(firebaseServiceProvider).signOut();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to sign out. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).asData?.value;

    if (user?.uid != uid) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ref.watch(verificationAdminProvider).when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Account access')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unable to check account access. '
                  'Check your connection and permissions.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(verificationAdminProvider);
                  },
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () => _signOut(context, ref),
                  child: const Text('Log out'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (isAdmin) {
        return isAdmin
            ? AdminVerificationScreen(uid: uid)
            : playerChild;
      },
    );
  }
}