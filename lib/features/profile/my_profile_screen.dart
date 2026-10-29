import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import 'edit_profile_screen.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({
    super.key,
    required this.uid,
    this.onGamingPreferences,
    this.onAvailability,
    this.onPartyHistory,
    this.onVerification,
    this.onPrivacyAndSafety,
    this.onBlockedPlayers,
    this.onSettings,
  });

  final String uid;

  //callbacks connect menu to other screens

  final VoidCallback? onGamingPreferences;
  final VoidCallback? onAvailability;
  final VoidCallback? onPartyHistory;
  final VoidCallback? onVerification;
  final VoidCallback? onPrivacyAndSafety;
  final VoidCallback? onBlockedPlayers;
  final VoidCallback? onSettings;

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  bool _isBusy = false;

  Future<void> _editProfile() async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
    });

    try {
      final service = ref.read(profileServiceProvider);

      //load fresh public and private information for the editor
      final data = await service.loadMyProfileSetup(widget.uid);

      if (!mounted) return;

      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => EditProfileScreen(initialData: data)),
      );

      if (!mounted || saved != true) return;

      //the profile stream updates the displayed information
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open your profile. '
            'Check your connection and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
    });

    try {
      await ref.read(firebaseServiceProvider).signOut();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to sign out. Try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).asData?.value;

    // MyProfile refer to signed-in account
    if (currentUser?.uid != widget.uid) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your profile.')),
      );
    }

    final profileState = ref.watch(playerProfileProvider(widget.uid));

    return Scaffold(
      body: SafeArea(
        child: profileState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: FilledButton(
              onPressed: () {
                ref.invalidate(playerProfileProvider(widget.uid));
              },
              child: const Text('Unload to load profile. Please retry'),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return const Center(
                child: Text('Your profile could not be found.'),
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'My Profile',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),

                    //profile header
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 38,
                          child: Icon(Icons.person_outline, size: 42),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.username.isEmpty
                                    ? 'New player'
                                    : profile.username,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                profile.region.isEmpty
                                    ? 'Region not set'
                                    : profile.region,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    //replaced by the games row in step 3
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(Icons.sports_esports_outlined),
                            SizedBox(width: 12),
                            Expanded(child: Text('No games added yet.')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _menuItem(
                      icon: Icons.edit_outlined,
                      title: 'Edit Profile',
                      onTap: _editProfile,
                    ),
                    _menuItem(
                      icon: Icons.sports_esports_outlined,
                      title: 'Gaming Preferences',
                      onTap: widget.onGamingPreferences,
                    ),
                    _menuItem(
                      icon: Icons.schedule_outlined,
                      title: 'Availability',
                      onTap: widget.onAvailability,
                    ),
                    _menuItem(
                      icon: Icons.history,
                      title: 'Party History',
                      onTap: widget.onPartyHistory,
                    ),
                    _menuItem(
                      icon: Icons.verified_user_outlined,
                      title: 'Verification',
                      onTap: widget.onVerification,
                    ),
                    _menuItem(
                      icon: Icons.shield_outlined,
                      title: 'Privacy & Safety',
                      onTap: widget.onPrivacyAndSafety,
                    ),
                    _menuItem(
                      icon: Icons.block_outlined,
                      title: 'Blocked Players',
                      onTap: widget.onBlockedPlayers,
                    ),
                    _menuItem(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      onTap: widget.onSettings,
                    ),
                    const SizedBox(height: 16),

                    if (_isBusy) ...[
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 16),
                    ],

                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Log out'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          enabled: !_isBusy && onTap != null,
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: _isBusy ? null : onTap,
        ),
      ),
    );
  }
}
