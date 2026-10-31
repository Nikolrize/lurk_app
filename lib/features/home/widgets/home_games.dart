import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/game_catalog.dart';
import '../../../models/game_definition.dart';
import '../../../providers/profile_provider.dart';
import '../../profile/screens/gaming_preferences_screen.dart';

class HomeGames extends ConsumerWidget {
  const HomeGames({super.key, required this.uid, this.onFindGame});
  final String? uid;
  final ValueChanged<String>? onFindGame;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (uid == null) return const Text('Sign in to choose your games.');
    final preferences = ref.watch(gamingPreferencesProvider(uid!));
    final colors = Theme.of(context).colorScheme;
    return preferences.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, stack) => TextButton(
        onPressed: () => ref.invalidate(gamingPreferencesProvider(uid!)),
        child: const Text('Unable to load your games. Retry'),
      ),
      data: (preferences) {
        final games = preferences.games
            .map(GameCatalog.find)
            .whereType<GameDefinition>()
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (games.isEmpty) ...[
              const Text('Choose your games to find your next squad.'),
              const SizedBox(height: 12),
            ],
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final game in games) ...[
                    SizedBox(
                      width: 84,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 76,
                            height: 76,
                            child: IconButton.filledTonal(
                              tooltip: 'Find ${game.name} parties',
                              style: IconButton.styleFrom(
                                backgroundColor: colors.surface,
                                foregroundColor: colors.secondary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: onFindGame == null
                                  ? null
                                  : () => onFindGame!(game.id),
                              icon: const Icon(
                                Icons.sports_esports_outlined,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            game.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => GamingPreferencesScreen(uid: uid!),
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        semanticLabel: 'Edit gaming preferences',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
