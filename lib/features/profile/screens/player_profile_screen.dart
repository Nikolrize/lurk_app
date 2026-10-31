import '../widgets/gaming_preferences_card.dart';
import '../../availability/widgets/availability_summary_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../services/player_safety_service.dart';

import 'report_player_screen.dart';
import '../../ratings/widgets/player_rating_summary.dart';

class PlayerProfileScreen extends ConsumerStatefulWidget {
  const PlayerProfileScreen({super.key, required this.uid});
  final String uid;
  @override
  ConsumerState<PlayerProfileScreen> createState() =>
      _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends ConsumerState<PlayerProfileScreen> {
  bool _busy = false;
  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _block(bool blocked) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(blocked ? 'Unblock player?' : 'Block player?'),
        content: Text(
          blocked
              ? 'You will be able to message each other again.'
              : 'Messages and party invitations between you will be stopped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(blocked ? 'Unblock' : 'Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(playerSafetyServiceProvider)
          .setBlocked(widget.uid, !blocked);
      _notice(blocked ? 'Player unblocked.' : 'Player blocked.');
    } catch (_) {
      _notice('Unable to update block. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      final result = await FirebaseFirestore.instance
          .collection('parties')
          .where('visibility', isEqualTo: 'public')
          .where('status', isEqualTo: 'open')
          .get();
      final parties = result.docs
          .where((doc) => doc.data()['hostId'] == uid)
          .toList();
      if (!mounted) return;
      if (parties.isEmpty) {
        _notice('Host an open public party before inviting a player.');
        return;
      }
      final party = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Invite to party'),
          children: [
            for (final party in parties)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, party.id),
                child: Text(party.data()['title'] as String? ?? 'Your party'),
              ),
          ],
        ),
      );
      if (party == null) return;
      final service = ref.read(chatServiceProvider);
      final chat = await service.openDirect(uid, widget.uid);
      await service.sendPartyInvite(chat, uid, party);
      _notice('Party invitation sent.');
    } catch (_) {
      _notice(
        'Unable to invite this player. Check your connection or block settings.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProfileProvider(widget.uid));
    final blocks = ref.watch(blockedPlayersProvider);
    final blocked = blocks.asData?.value.contains(widget.uid) ?? false;
    final own = ref.watch(authStateProvider).asData?.value?.uid == widget.uid;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Player Profile')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(playerProfileProvider(widget.uid)),
            child: const Text('Unable to load player. Retry'),
          ),
        ),
        data: (player) {
          if (player == null) {
            return const Center(child: Text('Player not found.'));
          }
          final pronoun = {
            'male': 'He/Him',
            'female': 'She/Her',
            'other': 'They/Them',
          }[player.sharedGender];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                        ],
                      ),
                    ),
                    child: const Icon(Icons.sports_esports_outlined, size: 64),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 36,
                        child: Icon(Icons.person_outline, size: 36),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player.username.isEmpty
                                  ? 'Player'
                                  : player.username,
                              style: text.headlineSmall,
                            ),
                            Text(
                              [
                                if (player.sharedAge != null)
                                  'Age ${player.sharedAge}',
                                ?pronoun,
                                if (player.region.isNotEmpty) player.region,
                              ].join(' • '),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PlayerRatingSummary(uid: widget.uid),
                  const SizedBox(height: 24),
                  Text(
                    'About Me',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(player.bio.isEmpty ? 'No bio added yet.' : player.bio),
                  const SizedBox(height: 24),
                  Text(
                    'Gaming Preferences',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GamingPreferencesCard(uid: widget.uid),
                  const SizedBox(height: 24),
                  Text(
                    'Availability',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AvailabilitySummaryCard(uid: widget.uid),
                  if (!own) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy || blocked || !blocks.hasValue
                          ? null
                          : _invite,
                      child: const Text('Invite to Party'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ReportPlayerScreen(uid: widget.uid),
                                    ),
                                  ),
                            child: const Text('Report'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy || !blocks.hasValue
                                ? null
                                : () => _block(blocked),
                            child: Text(blocked ? 'Unblock' : 'Block'),
                          ),
                        ),
                      ],
                    ),
                    if (blocked)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('You have blocked this player.'),
                      ),
                    if (blocks.hasError)
                      TextButton(
                        onPressed: () => ref.invalidate(blockedPlayersProvider),
                        child: const Text(
                          'Unable to load block settings. Retry',
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
