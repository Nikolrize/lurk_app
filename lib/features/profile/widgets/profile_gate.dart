import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/models/player_profile.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/profile_provider.dart';
import 'package:lurk_app/features/profile/screens/edit_profile_screen.dart';

import 'profile_page_layout.dart';

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
          body: ProfilePageLayout(
            introduction: const ProfileIntroduction(
              title: 'Your next lobby starts here.',
              description:
                  'Meet players, discover parties, and find teammates '
                  'who suit the way you play.',
            ),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Complete your player profile',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Add your player name, region and introduction. '
                      'Your full birth date stays private, and you choose '
                      'whether to display your age and pronouns.',
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
        );
      },
    );
  }
}
