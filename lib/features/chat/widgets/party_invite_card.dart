import '../../parties/actions/join_party.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/chat_provider.dart';

class PartyInviteCard extends ConsumerWidget {
  const PartyInviteCard({
    super.key,
    required this.partyId,
    this.sentByMe = false,
  });
  final bool sentByMe;
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
            data: (party) => party == null || party.status != 'open'
                ? const Text('This party is no longer available.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${party.gameName} · ${party.playStyle} · ${party.currentPlayers} players',
                      ),
                      const SizedBox(height: 12),
                      PartyJoinButton(party: party, disabled: sentByMe),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
