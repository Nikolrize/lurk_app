import '../../../core/widgets/action_card.dart';
import '../../player/data/sample_players.dart';
import '../../player/widgets/player_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lurk_app/features/parties/widgets/party_card.dart';
import '../../../providers/party_provider.dart';
import '../../parties/widgets/party_load_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onFindParties});
  final VoidCallback? onFindParties;

  void _preview(BuildContext context, String title, String description) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(description),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = ref
        .watch(authStateProvider)
        .asData
        ?.value
        ?.displayName
        ?.trim();
    final name = displayName != null && displayName.isNotEmpty
        ? displayName
        : 'Player';
    final text = Theme.of(context).textTheme;
    final partyState = ref.watch(availablePartiesProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          Text(
            'LURK',
            style: text.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Hey, $name',
            style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Ready to find a squad?',
            style: text.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ActionCard(
            icon: Icons.bolt_rounded,
            title: 'Quick Match',
            subtitle: 'Join a party or find players now',
            onTap:
                onFindParties ??
                () => _preview(
                  context,
                  'Quick Match',
                  'Matching is not connected yet.',
                ),
          ),
          const SizedBox(height: 28),
          Text(
            'Games you play',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final game in const [
                  ('Valorant', Icons.gps_fixed_rounded),
                  ('MLBB', Icons.shield_outlined),
                  ('Fortnite', Icons.sports_esports_outlined),
                ]) ...[
                  SizedBox(
                    width: 76,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 76,
                          height: 76,
                          child: IconButton.filledTonal(
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.secondary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            tooltip: 'Find ${game.$1} parties',
                            onPressed:
                                onFindParties ??
                                () => _preview(
                                  context,
                                  game.$1,
                                  'Game filtering is not connected yet.',
                                ),
                            icon: Icon(game.$2, size: 30),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(game.$1, style: text.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                SizedBox(
                  width: 76,
                  height: 76,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => _preview(
                      context,
                      'Your games',
                      'These are sample games. Game preferences will be managed through your player profile.',
                    ),
                    child: const Icon(Icons.add, semanticLabel: 'Add game'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Recommended parties',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          partyState.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, _) => PartyLoadError(
              error: error,
              onRetry: () => ref.invalidate(availablePartiesProvider),
            ),
            data: (parties) => parties.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No open parties yet. Check back soon.'),
                  )
                : Column(
                    children: [
                      for (final party in parties.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PartyCard(
                            party: party,
                            onJoin: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Party joining is not connected yet.',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 30),
          Text(
            'PLAYERS LOOKING TO PLAY',
            style: text.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          PlayerCard(
            player: samplePlayers.first,
            onTap: () => _preview(
              context,
              samplePlayers.first.name,
              'Sample player preview. Live availability and profiles are not connected yet.',
            ),
          ),
        ],
      ),
    );
  }
}
