import 'package:flutter/material.dart';

import '../models/player.dart';

import 'package:lurk_app/core/widgets/player_status_badge.dart';

class PlayerCard extends StatelessWidget {
  const PlayerCard({super.key, required this.player, this.onTap});

  final Player player;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final game = player.currentGame?.trim();
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colors.surfaceContainerHighest,
            child: Icon(Icons.person_outline, color: colors.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name, style: text.titleMedium),
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
