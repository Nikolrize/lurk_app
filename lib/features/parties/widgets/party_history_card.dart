import 'package:flutter/material.dart';
import '../../../core/data/game_catalog.dart';
import '../models/party.dart';
import '../models/party_history_entry.dart';
import 'party_preview_drawer.dart';

class PartyHistoryCard extends StatelessWidget {
  const PartyHistoryCard({super.key, required this.entry, this.onRate});
  final PartyHistoryEntry entry;
  final VoidCallback? onRate;

  String get _duration {
    final duration = entry.duration;
    if (duration == null) return 'Duration unavailable';
    if (duration.inMinutes < 1) return 'Less than 1 min';
    final hours = duration.inHours, minutes = duration.inMinutes.remainder(60);
    return hours == 0
        ? '${minutes}m'
        : minutes == 0
        ? '${hours}h'
        : '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final date = entry.endedAt?.toLocal();
    final local = MaterialLocalizations.of(context);
    final game = GameCatalog.find(entry.gameId)?.name ?? 'Unknown game';
    final mode = switch (entry.mode.toLowerCase()) {
      'competitive' => 'Competitive',
      'casual' => 'Casual',
      _ => entry.mode,
    };
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.primary.withValues(alpha: .22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.sports_esports_rounded,
                color: colors.secondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [game, if (mode.isNotEmpty) mode, _duration].join(' · '),
                    style: text.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    date == null
                        ? 'Date unavailable'
                        : '${local.formatMediumDate(date)} · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date))}',
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => showPartyPreview(
                          context,
                          entry.party ??
                              Party(
                                id: entry.record.partyId,
                                title: entry.title,
                                gameId: entry.gameId,
                                gameName: game,
                                mode: entry.mode,
                                playStyle: mode,
                                currentPlayers: 0,
                                maxPlayers: 0,
                                status: 'closed',
                              ),
                          showJoinButton: false,
                          history: true,
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('View details'),
                      ),
                      Tooltip(
                        message: onRate == null
                            ? 'Ratings will be available soon'
                            : 'Rate your teammates',
                        child: OutlinedButton(
                          onPressed: onRate,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(64, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: const Text('Rate'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
