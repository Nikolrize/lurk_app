import '../../../core/widgets/player_avatar.dart';
import 'package:flutter/material.dart';

import '../models/player.dart';

import 'package:lurk_app/core/widgets/player_status_badge.dart';

import 'package:lurk_app/core/widgets/player_verification_badge.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lurk_app/core/data/game_catalog.dart';
import 'package:lurk_app/providers/presence_provider.dart';

class PlayerCard extends ConsumerWidget {
  const PlayerCard({super.key, required this.player, this.onTap});

  final Player player;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final gameId = ref
        .watch(playerPresenceProvider(player.id))
        .asData
        ?.value
        ?.playingGameId;

    final game = GameCatalog.games[gameId]?.name;
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          PlayerAvatar(photoPath: player.photoPath, radius: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(player.name, style: text.titleMedium),
                    PlayerVerificationBadge(uid: player.id),
                  ],
                ),
                PlayerStatusBadge(uid: player.id),
                if (game != null && game.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Playing $game',
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Card(
      child: onTap == null
          ? content
          : InkWell(
              customBorder: Theme.of(context).cardTheme.shape,
              onTap: onTap,
              child: content,
            ),
    );
  }
}
