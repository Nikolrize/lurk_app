import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/core/data/game_catalog.dart';
import 'package:lurk_app/models/gaming_preferences.dart';
import 'package:lurk_app/providers/profile_provider.dart';

import 'profile_game_tile.dart';

class GamingPreferencesCard extends ConsumerWidget {
  const GamingPreferencesCard({
    super.key,
    required this.uid,
    this.onEdit,
  });

  final String uid;
  final VoidCallback? onEdit;

  Future<void> _openGameDetails(
    BuildContext context,
    GamingPreferences preferences,
    String gameId,
  ) async {
    final game = GameCatalog.games[gameId];

    if (game == null) return;

    final rankLabel = preferences.rankLabelFor(gameId);
    final isMainGame = preferences.currentGame == gameId;

    final editRequested = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.sports_esports_outlined,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  game.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  isMainGame
                      ? 'Main matchmaking game'
                      : 'Additional game',
                  textAlign: TextAlign.center,
                ),
                if (game.supportsRanks) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Rank: ${rankLabel ?? 'Unranked / not specified'}',
                    textAlign: TextAlign.center,
                  ),
                ],
                if (onEdit != null) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop(true);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit gaming preferences'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || editRequested != true) return;

    onEdit?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gamingPreferencesProvider(uid));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: state.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stackTrace) => TextButton(
            onPressed: () {
              ref.invalidate(gamingPreferencesProvider(uid));
            },
            child: const Text('Unable to load preferences. Retry'),
          ),
          data: (preferences) {
            final mode =
                GamingPreferences.modeLabels[preferences.mode];

            final communication =
                GamingPreferences.communicationLabels[
                  preferences.communication
                ];

            final gameIds = preferences.games
                .where(GameCatalog.games.containsKey)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (onEdit != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(
                        gameIds.isEmpty ? 'Add games' : 'Edit games',
                      ),
                    ),
                  ),
                if (gameIds.isEmpty)
                  const Text('No games added yet.')
                else
                  ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        ...ScrollConfiguration.of(context).dragDevices,
                        PointerDeviceKind.mouse,
                      },
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal, //scroll left and right
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final gameId in gameIds)
                            ProfileGameTile(
                              name: GameCatalog.games[gameId]!.name,
                              isMainGame:
                                  preferences.currentGame == gameId,
                              onTap: () {
                                _openGameDetails(
                                  context,
                                  preferences,
                                  gameId,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                if (mode != null) ...[
                  const SizedBox(height: 16),
                  Text('Mode: $mode'),
                ],
                if (preferences.playstyles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Playstyles: ${preferences.playstyles.map(
                      (style) =>
                          GamingPreferences.styleLabels[style] ?? style,
                    ).join(', ')}',
                  ),
                ],
                if (communication != null) ...[
                  const SizedBox(height: 12),
                  Text('Communication: $communication'),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}