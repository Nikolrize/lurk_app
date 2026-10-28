import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class ProfileGate extends ConsumerWidget {
  const ProfileGate({
    super.key,
    required this.uid,
    required this.child,
  });

  final String uid;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialization =
        ref.watch(profileInitializationProvider(uid));

    return initialization.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Profile setup')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load your profile.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  ref.invalidate(profileInitializationProvider(uid));
                },
                child: const Text('Try again'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await ref.read(firebaseServiceProvider).signOut();
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
      data: (_) => child,
    );
  }
}