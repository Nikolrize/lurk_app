import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/rating_provider.dart';
import '../../chat/widgets/chat_widgets.dart';
import '../models/teammate_rating.dart';
import 'rate_teammate_screen.dart';

class RatePartyTeammatesScreen extends ConsumerWidget {
  const RatePartyTeammatesScreen({
    super.key,
    required this.partyId,
    required this.partyTitle,
  });
  final String partyId, partyTitle;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Rate teammates',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    body: SafeArea(
      top: false,
      child: ref
          .watch(ratingCandidatesProvider(partyId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, stack) => Center(
              child: TextButton(
                onPressed: () =>
                    ref.invalidate(ratingCandidatesProvider(partyId)),
                child: const Text('Unable to load teammates. Tap to retry.'),
              ),
            ),
            data: (players) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(ratingCandidatesProvider(partyId));
                try {
                  await ref.read(ratingCandidatesProvider(partyId).future);
                } catch (_) {
                  /* The provider displays the retry state. */
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    partyTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Rate the teammates you played with. Feedback is optional for each player.',
                  ),
                  const SizedBox(height: 20),
                  if (players.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No eligible teammates for this session. Ratings become available after your participation ends.',
                      ),
                    ),
                  for (final player in players)
                    _CandidateTile(partyId: partyId, player: player),
                ],
              ),
            ),
          ),
    ),
  );
}

class _CandidateTile extends ConsumerWidget {
  const _CandidateTile({required this.partyId, required this.player});
  final String partyId;
  final RatingCandidate player;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProfileProvider(player.uid));
    final name = profile.asData?.value?.username ?? 'Teammate';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        minTileHeight: 88,
        minVerticalPadding: 16,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ChatAvatar(name: name, uid: player.uid),
        title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: player.rated
            ? const Chip(
                label: Text('Rated'),
                avatar: Icon(Icons.check, size: 16),
              )
            : TextButton(
                onPressed: () async {
                  final submitted = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => RateTeammateScreen(
                        partyId: partyId,
                        targetUid: player.uid,
                      ),
                    ),
                  );
                  if (submitted == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Thanks! Your review has been submitted.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Rate'),
              ),
      ),
    );
  }
}
