import '../../../providers/party_provider.dart';
import '../../../providers/rating_provider.dart';
import '../../../services/player_safety_service.dart';
import '../../../providers/party_matching_provider.dart';
import '../../parties/widgets/quick_match_card.dart';
import '../widgets/home_games.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/player_provider.dart';
import '../../player/widgets/player_load_error.dart';
import '../../profile/screens/player_profile_screen.dart';
import '../../player/widgets/player_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lurk_app/features/parties/widgets/party_card.dart';
import '../../parties/widgets/party_load_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onFindGame});
  final ValueChanged<String>? onFindGame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).asData?.value?.uid;
    final displayName = uid == null
        ? null
        : ref.watch(playerProfileProvider(uid)).asData?.value?.username.trim();
    final name = displayName != null && displayName.isNotEmpty
        ? displayName
        : 'Player';
    final text = Theme.of(context).textTheme;
    final partyState = ref.watch(recommendedPartiesProvider);
    final playerState = ref.watch(discoverablePlayersProvider);

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
          const QuickMatchCard(),
          const SizedBox(height: 28),
          Text(
            'Games you play',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          HomeGames(uid: uid, onFindGame: onFindGame),
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
              onRetry: () {
                ref.invalidate(partyDiscoveryPageProvider);
                ref.invalidate(availablePartiesProvider);
                ref.invalidate(hostBlocksViewerProvider);
                ref.invalidate(blockedPlayersProvider);
                if (uid != null) {
                  ref.invalidate(playerProfileProvider(uid));
                  ref.invalidate(gamingPreferencesProvider(uid));
                  ref.invalidate(ratingSummaryProvider(uid));
                }
              },
            ),
            data: (parties) => parties.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No matching parties yet. Set your games and region, or explore Find.',
                    ),
                  )
                : Column(
                    children: [
                      for (final party in parties.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PartyCard(party: party),
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
          playerState.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, _) => PlayerLoadError(
              error: error,
              onRetry: () {
                ref.invalidate(playerDiscoveryPageProvider);
                ref.invalidate(discoverablePlayersProvider);
              },
            ),
            data: (players) {
              final available = players
                  .where((p) => p.availability.availableNow)
                  .take(3)
                  .toList();
              if (available.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No players have marked themselves available yet. Explore the Player tab in Find.',
                  ),
                );
              }
              return Column(
                children: [
                  for (final player in available)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PlayerCard(
                        player: player,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PlayerProfileScreen(uid: player.id),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
