import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/profile_provider.dart';
import 'package:lurk_app/features/profile/screens/edit_profile_screen.dart';
import 'package:lurk_app/features/profile/screens/player_profile_screen.dart';

import 'gaming_preferences_screen.dart';
import '../widgets/gaming_preferences_card.dart';

import 'package:lurk_app/features/availability/screens/availability_screen.dart';
import 'package:lurk_app/features/availability/widgets/availability_summary_card.dart';

import 'package:lurk_app/core/widgets/player_status_badge.dart';

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

  void _openAvailability() {
    if (_isBusy) return;

    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AvailabilityScreen(uid: widget.uid),
      ),
    );
  }
  Future<void> _openGamingPreferences() async {
    if (_isBusy) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GamingPreferencesScreen(uid: widget.uid),
      ),     
    );

    if (!mounted || saved != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gaming preferences updated')),
    );
  }
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
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (currentUser?.uid != widget.uid) {
      return const SafeArea(
        child: Center(child: Text('Please sign in to view your profile.')),
      );
    }

    final profileState = ref.watch(playerProfileProvider(widget.uid));

    // AppShell already provides the Scaffold and bottom navigation.
    return SafeArea(
      bottom: false,
      child: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton(
            onPressed: () {
              ref.invalidate(playerProfileProvider(widget.uid));
            },
            child: const Text('Unable to load profile. Retry'),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Text('Your profile could not be found.'),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;

              final twoColumns =
                  constraints.maxWidth >= 760 &&
                  MediaQuery.textScalerOf(context).scale(16) <= 24;

              final horizontalPadding = compact ? 16.0 : 24.0;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  20,
                  horizontalPadding,
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'My Profile',
                          style: text.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your player identity and preferences.',
                          style: text.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),

                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: colors.outline),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(compact ? 16 : 24),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: compact ? 28 : 36,
                                  backgroundColor: colors.primary.withValues(
                                    alpha: 0.18,
                                  ),
                                  child: Icon(
                                    Icons.person_outline,
                                    size: compact ? 32 : 40,
                                    color: colors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile.username.isEmpty
                                            ? 'New player'
                                            : profile.username,
                                        style: text.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      PlayerStatusBadge(
                                        uid: widget.uid,
                                        editable: true,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        profile.region.isEmpty
                                            ? 'Region not set'
                                            : profile.region,
                                        style: text.bodyMedium?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        OutlinedButton.icon(
                          onPressed: _isBusy
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          PlayerProfileScreen(uid: widget.uid),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('View public profile'),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Games you play',
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        GamingPreferencesCard(
                          uid: widget.uid,
                          onEdit: _isBusy
                              ? null
                              : widget.onGamingPreferences ?? _openGamingPreferences,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Availability',
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AvailabilitySummaryCard(
                          uid: widget.uid,
                          onEdit: _isBusy
                              ? null
                              : widget.onAvailability ?? _openAvailability,
                        ),
                        const SizedBox(height: 28),

                        Text(
                          'Manage your profile',
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),

                        LayoutBuilder(
                          builder: (context, menuConstraints) {
                            final itemWidth = twoColumns
                                ? (menuConstraints.maxWidth - 16) / 2
                                : menuConstraints.maxWidth;

                            final entries =
                                <
                                  ({
                                    IconData icon,
                                    String title,
                                    VoidCallback? onTap,
                                  })
                                >[
                                  (
                                    icon: Icons.edit_outlined,
                                    title: 'Edit Profile',
                                    onTap: _editProfile,
                                  ),
                                  (
                                    icon: Icons.sports_esports_outlined,
                                    title: 'Gaming Preferences',
                                    onTap: widget.onGamingPreferences ?? _openGamingPreferences,
                                  ),
                                  (
                                    icon: Icons.schedule_outlined,
                                    title: 'Availability',
                                    onTap: widget.onAvailability ?? _openAvailability,
                                  ),
                                  (
                                    icon: Icons.history,
                                    title: 'Party History',
                                    onTap: widget.onPartyHistory,
                                  ),
                                  (
                                    icon: Icons.verified_user_outlined,
                                    title: 'Verification',
                                    onTap: widget.onVerification,
                                  ),
                                  (
                                    icon: Icons.shield_outlined,
                                    title: 'Privacy & Safety',
                                    onTap: widget.onPrivacyAndSafety,
                                  ),
                                  (
                                    icon: Icons.block_outlined,
                                    title: 'Blocked Players',
                                    onTap: widget.onBlockedPlayers,
                                  ),
                                  (
                                    icon: Icons.settings_outlined,
                                    title: 'Settings',
                                    onTap: widget.onSettings,
                                  ),
                                ];

                            return Wrap(
                              spacing: 16,
                              children: [
                                for (final entry in entries)
                                  SizedBox(
                                    width: itemWidth,
                                    child: _menuItem(
                                      icon: entry.icon,
                                      title: entry.title,
                                      onTap: entry.onTap,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        if (_isBusy) ...[
                          const Center(child: CircularProgressIndicator()),
                          const SizedBox(height: 16),
                        ],

                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _isBusy ? null : _signOut,
                            icon: const Icon(Icons.logout),
                            label: const Text('Log out'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    final available = onTap != null;
    final enabled = available && !_isBusy;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outline),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          enabled: enabled,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: enabled ? colors.secondary : colors.onSurfaceVariant,
            ),
          ),
          title: Text(title),
          trailing: Icon(
            Icons.chevron_right,
            color: enabled
                ? colors.onSurfaceVariant
                : colors.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          onTap: enabled ? onTap : null,
        ),
      ),
    );
  }
}
