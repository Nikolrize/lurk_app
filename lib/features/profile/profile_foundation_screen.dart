import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/profile_provider.dart';

class ProfileFoundationScreen extends ConsumerStatefulWidget {
  const ProfileFoundationScreen({
    super.key,
    required this.uid,
  });

  final String uid;

  @override
  ConsumerState<ProfileFoundationScreen> createState() =>
      _ProfileFoundationScreenState();
}

class _ProfileFoundationScreenState
    extends ConsumerState<ProfileFoundationScreen> {
  final _usernameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save({
    required String bio,
    required String region,
  }) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(profileServiceProvider).updateMyProfile(
        username: _usernameController.text,
        bio: bio,
        region: region,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved.')),
      );
    } catch (error) {
      if (!mounted) return;

      final message = error is ArgumentError
          ? error.message.toString()
          : 'Unable to save. Check your connection and permissions.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState =
        ref.watch(playerProfileProvider(widget.uid));
    final privateState = ref.watch(myPrivateInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile backend test')),
      body: profileState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => const Center(
          child: Text('Unable to read the profile.'),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Text('Profile document is missing.'),
            );
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('UID: ${profile.uid}'),
                    const SizedBox(height: 12),
                    Text(
                      'Saved username: '
                      '${profile.username.isEmpty ? "(not set)" : profile.username}',
                    ),
                    const SizedBox(height: 12),
                    privateState.when(
                      loading: () =>
                          const Text('Loading private details...'),
                      error: (error, stackTrace) =>
                          const Text('Unable to read private details.'),
                      data: (info) => Text(
                        info == null
                            ? 'Private document missing.'
                            : 'Your private document loaded successfully.',
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _usernameController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'New username',
                        helperText: 'Use 3–30 characters.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _isSaving
                          ? null
                          : () => _save(
                              bio: profile.bio,
                              region: profile.region,
                            ),
                      child: Text(
                        _isSaving ? 'Saving...' : 'Save username',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}