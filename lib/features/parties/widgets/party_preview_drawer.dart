import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/game_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/party_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../profile/screens/player_profile_screen.dart';
import '../actions/join_party.dart';
import '../models/party.dart';

Future<void> showPartyPreview(BuildContext context, Party party) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        minChildSize: .5,
        maxChildSize: .95,
        builder: (_, controller) =>
            _PartyPreview(party: party, controller: controller),
      ),
    );

class _PartyPreview extends ConsumerStatefulWidget {
  const _PartyPreview({required this.party, required this.controller});
  final Party party;
  final ScrollController controller;
  @override
  ConsumerState<_PartyPreview> createState() => _PartyPreviewState();
}

class _PartyPreviewState extends ConsumerState<_PartyPreview> {
  String? _error;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(partyByIdProvider(widget.party.id));
    final party = state.asData?.value ?? widget.party;
    final members = ref.watch(partyMemberIdsProvider(party.id));
    final ready = state.asData?.value != null && party.status == 'open';
    final ranks =
        GameCatalog.find(party.gameId)?.ranks.values.toList() ?? <String>[];
    final min = party.minRank, max = party.maxRank;
    final rankLabel =
        min != null && max != null && min >= 0 && max < ranks.length
        ? '${ranks[min]} — ${ranks[max]}'
        : null;
    final text = Theme.of(context).textTheme;
    final ids = [...?members.asData?.value];
    ids.sort(
      (a, b) => a == party.hostId
          ? -1
          : b == party.hostId
          ? 1
          : a.compareTo(b),
    );
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: .28),
                      AppColors.secondary.withValues(alpha: .09),
                      AppColors.surface,
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: .35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: .25),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.sports_esports_rounded,
                            color: AppColors.text,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            party.gameName,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          party.visibility == 'private'
                              ? Icons.lock_outline_rounded
                              : Icons.public_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      party.title,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      party.playStyle,
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${party.currentPlayers} / ${party.maxPlayers} players · ${party.visibility == 'private' ? 'Private' : 'Public'} party',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: party.maxPlayers > 0
                            ? (party.currentPlayers / party.maxPlayers).clamp(
                                0,
                                1,
                              )
                            : 0,
                        color: AppColors.secondary,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: .18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      party.isFull
                          ? 'Squad is full'
                          : '${party.maxPlayers - party.currentPlayers} spots available',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (party.region != null)
                    _DetailChip(
                      icon: Icons.public_rounded,
                      label: party.region!,
                    ),
                  if (rankLabel != null)
                    _DetailChip(
                      icon: Icons.military_tech_outlined,
                      label: rankLabel,
                    ),
                  if (party.communication != null)
                    _DetailChip(
                      icon: Icons.headset_mic_outlined,
                      label: party.communication!,
                    ),
                  for (final style in party.playstyles)
                    _DetailChip(
                      icon: Icons.auto_awesome_outlined,
                      label: style,
                    ),
                  if (party.minimumRating > 0)
                    _DetailChip(
                      icon: Icons.star_outline_rounded,
                      label:
                          '${party.minimumRating.toStringAsFixed(1)}+ rating',
                    ),
                ],
              ),
              if (party.description.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'About this party',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  party.description,
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
              if (state.hasError)
                TextButton(
                  onPressed: () => ref.invalidate(partyByIdProvider(party.id)),
                  child: const Text('Unable to load party. Try again'),
                ),
              if (state.asData != null && !ready)
                const Text('This party session has ended.'),
              const SizedBox(height: 24),
              Text(
                'Squad members',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Meet your teammates before you join.',
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              members.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
                error: (_, stack) => TextButton(
                  onPressed: () =>
                      ref.invalidate(partyMemberIdsProvider(party.id)),
                  child: const Text('Unable to load players. Try again'),
                ),
                data: (_) => ids.isEmpty
                    ? const Text('No players to show.')
                    : Column(
                        children: [
                          for (final uid in ids)
                            _PreviewMember(
                              uid: uid,
                              isHost: uid == party.hostId,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: AppColors.outline.withValues(alpha: .65)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null && _error!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  PartyJoinButton(
                    party: party,
                    preview: false,
                    disabled: !ready || members.asData == null,
                    onError: (message) {
                      if (mounted) setState(() => _error = message);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewMember extends ConsumerWidget {
  const _PreviewMember({required this.uid, required this.isHost});
  final String uid;
  final bool isHost;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProfileProvider(uid));
    final name = profile.asData?.value?.username;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isHost
                ? AppColors.primary.withValues(alpha: .4)
                : AppColors.outline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: (isHost ? AppColors.primary : AppColors.secondary)
                .withValues(alpha: .18),
            child: Icon(
              isHost ? Icons.workspace_premium_outlined : Icons.person_outline,
              color: isHost ? AppColors.primary : AppColors.secondary,
            ),
          ),
          title: Text(
            name != null && name.trim().isNotEmpty
                ? name
                : profile.isLoading
                ? 'Loading player…'
                : 'Player',
          ),
          subtitle: Text(
            isHost ? 'Party host' : 'Member',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PlayerProfileScreen(uid: uid),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.outline),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.secondary),
        const SizedBox(width: 7),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}
