import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/providers/profile_provider.dart';

import '../widgets/gaming_preferences_card.dart';


class PlayerProfileScreen extends ConsumerWidget {
  const PlayerProfileScreen({super.key, required this.uid});

  final String uid;

  static const _pronounLabels = {
    'male': 'He/him',
    'female': 'She/her',
    'other': 'They/them',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(playerProfileProvider(uid));
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Player Profile')),
      body: SafeArea(
        child: profileState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: FilledButton(
              onPressed: () {
                ref.invalidate(playerProfileProvider(uid));
              },
              child: const Text('Unable to load player. Retry'),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Player not found.'));
            }

            final sharedAge = profile.sharedAge;
            final sharedDate = profile.ageSharedAt;
            final pronouns = _pronounLabels[profile.sharedGender];

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: colors.outline),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: colors.primary.withValues(
                                  alpha: 0.18,
                                ),
                                child: Icon(
                                  Icons.person_outline,
                                  size: 44,
                                  color: colors.secondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              profile.username.isEmpty
                                  ? 'New player'
                                  : profile.username,
                              textAlign: TextAlign.center,
                              style: text.headlineSmall,
                            ),
                            if (profile.region.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                profile.region,
                                textAlign: TextAlign.center,
                                style: text.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (sharedAge != null || pronouns != null) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (sharedAge != null)
                                    Chip(label: Text('Shared age: $sharedAge')),
                                  if (pronouns != null)
                                    Chip(label: Text(pronouns)),
                                ],
                              ),
                            ],
                            if (sharedAge != null && sharedDate != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Age shared on '
                                '${MaterialLocalizations.of(context).formatMediumDate(sharedDate)}',
                                textAlign: TextAlign.center,
                                style: text.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'About Me',
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Gaming Preferences',
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GamingPreferencesCard(uid: uid),
                    
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          profile.bio.isEmpty
                              ? 'No bio added yet.'
                              : profile.bio,
                        ),
                      ),
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
}
