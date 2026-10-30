import 'package:flutter/material.dart';
import '../models/lobby_member.dart';

class LobbyMemberCard extends StatelessWidget {
  const LobbyMemberCard({
    super.key,
    required this.member,
    this.isHost = false,
    required this.onViewProfile,
    this.onRemove,
  });
  final LobbyMember member;
  final bool isHost;
  final VoidCallback onViewProfile;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rank = member.rank?.trim();
    final mic = switch (member.micEnabled) {
      true => 'Mic on',
      false => 'Mic off',
      null => 'Mic status unavailable',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 4, 18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: colors.surfaceContainerHighest,
              child: Icon(Icons.person_outline, color: colors.onSurfaceVariant),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${member.name}${rank == null || rank.isEmpty ? '' : ' · $rank'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (isHost) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Party host',
                          child: Icon(
                            Icons.workspace_premium_outlined,
                            size: 21,
                            color: colors.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                      Text(
                        member.rating?.toStringAsFixed(1) ?? 'Not rated',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text('· $mic', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Options for ${member.name}',
              icon: Icon(Icons.more_vert, color: colors.onSurfaceVariant),
              onSelected: (value) {
                if (value == 'profile') {
                  onViewProfile();
                } else {
                  onRemove?.call();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Text('View profile'),
                ),
                if (onRemove != null)
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove player'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
