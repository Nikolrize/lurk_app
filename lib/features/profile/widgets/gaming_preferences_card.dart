import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/models/gaming_preferences.dart';
import 'package:lurk_app/providers/profile_provider.dart';

class GamingPreferencesCard extends ConsumerWidget {
  const GamingPreferencesCard({
    super.key,
    required this.uid,
  });

  final String uid;

  @override 
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gamingPreferencesProvider(uid));

    return Card(
      child:Padding(
        padding: const EdgeInsets.all(20),
        child: state.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stackTrace) => TextButton(
            onPressed: () {
              ref.invalidate(gamingPreferencesProvider(uid));
            },
            child: const Text("Unable to laod preferences. Retry"),
          ),
          data: (preferences) {
            if (preferences.games.isEmpty) {
              return const Text('No games added yet.');
            }

            final mode = GamingPreferences.modeLabels[preferences.mode];
            final communication = GamingPreferences.communicationLabels[preferences.communication];
            final rank = preferences.rank;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final game in preferences.games) 
                      Chip(
                        avatar: game == preferences.currentGame ? const Icon(Icons.star_outline, size: 18) : null,
                        label: Text(GamingPreferences.gameLabels[game] ?? game,),
                      ),
                  ],
                ),
                const SizedBox(height:8),
                const Text('The starred game is the main matchmaking game.'),
                if (mode != null) ...[
                  const SizedBox(height: 12),
                  Text('Mode: $mode'),
                ],
                if (preferences.playstyles.isNotEmpty) ... [
                  const SizedBox(height: 12),
                  Text('Playstyles: ${preferences.playstyles.map(
                    (style) => GamingPreferences.styleLabels[style] ?? style,
                    ).join(', ')
                  }',)
                ],
                if (communication != null)... [
                  const SizedBox(height: 12),
                  Text('Communication: $communication'),
                ],
                if (preferences.currentGame == 'valorant' && rank != null && rank >=0 && rank < GamingPreferences.valorantRanks.length) ... [
                  const SizedBox(height: 12),
                  Text(
                    'Valorant rank: '
                    '${GamingPreferences.valorantRanks[rank]}'
                    '(self-reported)',
                  ),
                ],
              ],
            );
          }
        )
      )
    );
  }
}