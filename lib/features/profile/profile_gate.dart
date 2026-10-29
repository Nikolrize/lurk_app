import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/player_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import 'edit_profile_screen.dart';

class ProfileGate extends ConsumerWidget {
  const ProfileGate({super.key, required this.uid, required this.child});

  final String uid;
  final Widget child;

  Future<void> _openSetup(
    BuildContext context,
    WidgetRef ref,
    ProfileSetupData data,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EditProfileScreen(initialData: data, initialSetup: true),
      ),
    );

    if (!context.mounted || saved != true) return;

    // Recheck only after the editor confirms a committed save.
    ref.invalidate(profileSetupProvider(uid));
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(firebaseServiceProvider).signOut();
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to sign out. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupState = ref.watch(profileSetupProvider(uid));

    return setupState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Profile setup')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Unable to load your profile. '
                'Please check your connection.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  ref.invalidate(profileSetupProvider(uid));
                },
                child: const Text('Try again'),
              ),
              TextButton(
                onPressed: () => _signOut(context, ref),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        if (data.isComplete) {
          return child;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Welcome to Lurk'),
            actions: [
              TextButton(
                onPressed: () => _signOut(context, ref),
                child: const Text('Log out'),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/lurk_logo.jpg',
                            width: 140,
                            height: 140,
                            semanticLabel: 'Lurk logo',
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Your next lobby starts here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Introduce yourself before finding teammates. '
                        'Create your player profile and choose '
                        'which personal details you want to share.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => _openSetup(context, ref, data),
                        child: const Text('Complete my profile'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
