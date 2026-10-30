import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/parties/models/party.dart';
import '../../../providers/chat_provider.dart';

class PartyInviteCard extends ConsumerWidget {
  const PartyInviteCard({super.key, required this.partyId});
  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatPartyProvider(partyId));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.groups_outlined, size: 18, color: AppColors.secondary),
              SizedBox(width: 8),
              Text(
                'PARTY INVITE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          state.when(
            loading: () => const Text('Loading party…'),
            error: (error, stack) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This party is unavailable or no longer open.'),
                TextButton(
                  onPressed: () => ref.invalidate(chatPartyProvider(partyId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
            data: (party) => party == null
                ? const Text('This party is no longer available.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${party.gameName} · ${party.playStyle} · ${party.currentPlayers} players',
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => showPartyDetails(context, party),
                        child: const Text('View party'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

void showPartyDetails(BuildContext context, Party party) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(party.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text('${party.gameName} · ${party.playStyle}'),
            const SizedBox(height: 8),
            Text('${party.currentPlayers} / ${party.maxPlayers} players'),
            if (party.region != null) ...[
              const SizedBox(height: 8),
              Text(party.region!),
            ],
            if (party.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(party.description),
            ],
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ),
  );
}
