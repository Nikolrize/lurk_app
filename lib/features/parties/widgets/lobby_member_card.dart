import 'package:flutter/material.dart';
import '../models/lobby_member.dart';
import '../../../core/widgets/player_avatar.dart';

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
      true => 'Unmuted',
      false => 'Muted',
      null => 'Mic status unavailable',
    };
    final speaking = member.isSpeaking && member.micEnabled == true;
    return AnimatedContainer(
      key: ValueKey('voice-card-${member.uid}'),
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: speaking
              ? colors.secondary
              : colors.outline.withValues(alpha: .55),
          width: 1.5,
        ),
        boxShadow: speaking
            ? [
                BoxShadow(
                  color: colors.secondary.withValues(alpha: .25),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 4, 18),
          child: Row(
            children: [
              Tooltip(
                message: 'View ${member.name} profile',
                child: InkWell(
                  onTap: onViewProfile,
                  borderRadius: BorderRadius.circular(27),
                  child: PlayerAvatar(uid: member.uid, radius: 27),
                ),
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
                        Tooltip(
                          message: mic,
                          child: Icon(
                            member.micEnabled == true
                                ? Icons.mic_rounded
                                : Icons.mic_off_rounded,
                            semanticLabel: mic,
                            size: 18,
                            color: member.micEnabled == true
                                ? colors.onSurface
                                : colors.onSurfaceVariant,
                          ),
                        ),
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
      ),
    );
  }
}
