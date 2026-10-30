import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/profile_provider.dart';
import '../../profile/screens/player_profile_screen.dart';
import '../models/lobby_member.dart';
import '../models/party.dart';
import '../widgets/lobby_member_card.dart';

/// Tab content: AppShell owns the Scaffold and persistent bottom navigation.
/// Supply a roster and action callbacks when lobby services are ready.
class PartyLobbyScreen extends ConsumerWidget {
  const PartyLobbyScreen({
    super.key,
    required this.party,
    required this.onBack,
    this.members,
    this.viewerUid,
    this.onInvite,
    this.onChat,
    this.onLeave,
    this.onToggleMic,
    this.micEnabled = false,
  });
  final Party party;
  final VoidCallback onBack;
  final List<LobbyMember>? members;
  final String? viewerUid;
  final VoidCallback? onInvite, onChat, onLeave, onToggleMic;
  final bool micEnabled;

  void _notice(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _profile(BuildContext context, String uid) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlayerProfileScreen(uid: uid)),
    );
  }

  void _details(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                party.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text('${party.gameName} · ${party.playStyle}'),
              if (party.region != null) Text(party.region!),
              const SizedBox(height: 8),
              Text(
                '${party.currentPlayers} / ${party.maxPlayers} players · ${party.visibility == 'private' ? 'Private' : 'Public'} party',
              ),
              if (party.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(party.description),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _leave(BuildContext context) async {
    if (onLeave == null) {
      _notice(
        context,
        'Leaving parties is not available yet. You are still in this party.',
      );
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave party?'),
        content: const Text('You will leave this squad.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) onLeave!();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final roster = members;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(24, 12, 24, bottomInset + 24),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back to Parties',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${party.gameName} party',
                  maxLines: 2,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Party options',
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) {
                  if (value == 'details') {
                    _details(context);
                  } else {
                    _leave(context);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'details', child: Text('Party details')),
                  PopupMenuItem(value: 'leave', child: Text('Leave party')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            party.title,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${party.currentPlayers} / ${party.maxPlayers} players · ${party.visibility == 'private' ? 'Private' : 'Public'} party',
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 30),
          Text(
            'Squad members',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          if (roster != null) ...[
            if (roster.isEmpty) const Text('No member details available yet.'),
            for (final member in roster)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LobbyMemberCard(
                  member: member,
                  isHost: member.uid == party.hostId,
                  onViewProfile: () => _profile(context, member.uid),
                  onRemove:
                      viewerUid == party.hostId && member.uid != party.hostId
                      ? () => _notice(
                          context,
                          'Removing players is not available yet.',
                        )
                      : null,
                ),
              ),
          ] else ...[
            if (party.hostId.isNotEmpty)
              _HostCard(
                uid: party.hostId,
                onViewProfile: () => _profile(context, party.hostId),
              ),
            const SizedBox(height: 12),
            Text(
              'The full member list will appear when lobby sync is connected.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: party.isFull
                ? null
                : onInvite ??
                      () => _notice(
                        context,
                        'Player invitations are not available yet.',
                      ),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add),
            label: Text(party.isFull ? 'Party full' : 'Invite player'),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      onToggleMic ??
                      () => _notice(
                        context,
                        'Voice chat is not connected. Your microphone is off.',
                      ),
                  icon: Icon(micEnabled ? Icons.mic : Icons.mic_off_outlined),
                  label: Text(micEnabled ? 'Mic: ON' : 'Mic: OFF'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      onChat ??
                      () =>
                          _notice(context, 'Party chat is not available yet.'),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _leave(context),
            child: const Text('Leave Party'),
          ),
        ],
      ),
    );
  }
}

class _HostCard extends ConsumerWidget {
  const _HostCard({required this.uid, required this.onViewProfile});
  final String uid;
  final VoidCallback onViewProfile;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProfileProvider(uid));
    return profile.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, stack) => Card(
        child: TextButton(
          onPressed: () => ref.invalidate(playerProfileProvider(uid)),
          child: const Text('Unable to load host. Try again'),
        ),
      ),
      data: (profile) => LobbyMemberCard(
        member: LobbyMember(
          uid: uid,
          name: profile?.username.trim().isNotEmpty == true
              ? profile!.username
              : 'Host',
        ),
        isHost: true,
        onViewProfile: onViewProfile,
      ),
    );
  }
}
