import '../../../core/data/game_catalog.dart';
import '../widgets/party_preview_drawer.dart';
import '../../../providers/voice_provider.dart';
import '../../../services/party_voice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/profile_provider.dart';
import '../../profile/screens/player_profile_screen.dart';
import '../models/lobby_member.dart';
import '../../../providers/party_provider.dart';
import 'create_party_screen.dart';
import '../../chat/screens/new_message_screen.dart';
import '../../chat/screens/party_chat_screen.dart';
import '../models/party.dart';
import '../widgets/lobby_member_card.dart';

/// Tab content: AppShell owns the Scaffold and persistent bottom navigation.
/// Party details stay in sync with Firestore; social actions are supplied separately.
class PartyLobbyScreen extends ConsumerStatefulWidget {
  const PartyLobbyScreen({
    super.key,
    required this.party,
    required this.onBack,
    this.members,
    this.viewerUid,
    this.onInvite,
    this.onChat,
    this.onToggleMic,
    this.micEnabled = false,
  });
  final Party party;
  final VoidCallback onBack;
  final List<LobbyMember>? members;
  final String? viewerUid;
  final VoidCallback? onInvite, onChat, onToggleMic;
  final bool micEnabled;

  @override
  ConsumerState<PartyLobbyScreen> createState() => _PartyLobbyScreenState();
}

class _PartyLobbyScreenState extends ConsumerState<PartyLobbyScreen> {
  bool _leaving = false;
  String? _removing;
  @override
  void initState() {
    super.initState();
    _scheduleVoiceConnection();
  }

  @override
  void didUpdateWidget(covariant PartyLobbyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.party.id != widget.party.id ||
        oldWidget.viewerUid != widget.viewerUid) {
      _scheduleVoiceConnection();
    }
  }

  void _scheduleVoiceConnection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          viewerUid != null &&
          widget.onToggleMic == null &&
          ref.read(partyVoiceServiceProvider).configured) {
        _connectVoice();
      }
    });
  }

  Future<void> _connectVoice() async {
    try {
      await ref.read(partyVoiceServiceProvider).connect(party.id);
    } catch (_) {
      /* The voice panel shows the connection error and retry. */
    }
  }

  Party get party =>
      ref.read(partyByIdProvider(widget.party.id)).asData?.value ??
      widget.party;
  String? get viewerUid => widget.viewerUid;
  List<LobbyMember>? get members => widget.members;
  bool get micEnabled {
    if (widget.onToggleMic != null) return widget.micEnabled;
    final state = ref.read(partyVoiceServiceProvider).state;
    return state.partyId == party.id && state.connected && !state.muted;
  }

  VoidCallback get onBack => widget.onBack;
  VoidCallback? get onInvite => widget.onInvite;
  VoidCallback? get onChat => widget.onChat;
  VoidCallback? get onToggleMic => widget.onToggleMic;

  Future<void> _toggleVoice(BuildContext context) async {
    try {
      await ref.read(partyVoiceServiceProvider).toggle(party.id);
    } catch (error) {
      if (context.mounted &&
          ref.read(partyVoiceServiceProvider).state.error == null) {
        _notice(
          context,
          error is StateError
              ? error.message.toString()
              : 'Unable to connect voice chat.',
        );
      }
    }
  }

  Future<void> _remove(BuildContext context, String uid, String name) async {
    if (_removing != null ||
        _leaving ||
        viewerUid != party.hostId ||
        uid == party.hostId) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove player?'),
        content: Text(
          'Remove $name from this party? They will need a new invitation to rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _removing != null) return;
    setState(() => _removing = uid);
    try {
      await ref
          .read(partyServiceProvider)
          .removeMember(party.id, uid, expectedUid: viewerUid!);
      if (context.mounted) _notice(context, 'Player removed from the party.');
    } catch (error) {
      if (context.mounted) {
        _notice(
          context,
          error is StateError
              ? error.message.toString()
              : 'Unable to remove player. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _removing = null);
    }
  }

  Future<void> _invite(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NewMessageScreen(
          invitePartyId: party.id,
          excludedPlayerIds: {
            ...?ref.read(partyMemberIdsProvider(party.id)).asData?.value,
            party.hostId,
            ...?members?.map((member) => member.uid),
          },
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => CreatePartyScreen(party: party)),
    );
  }

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
    showPartyPreview(
      context,
      party,
      showJoinButton: false,
      onEdit: viewerUid == party.hostId ? () => _edit(context) : null,
    );
  }

  Future<void> _leave(BuildContext context) async {
    if (_leaving) return;
    if (viewerUid == null) {
      _notice(context, 'Sign in to leave this party.');
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          viewerUid == party.hostId ? 'End party session?' : 'Leave party?',
        ),
        content: Text(
          viewerUid == party.hostId
              ? 'You are the host. If you leave, the party session will end for everyone. This cannot be undone.'
              : 'You will leave this squad.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              viewerUid == party.hostId ? 'End Session & Leave' : 'Leave',
            ),
          ),
        ],
      ),
    );
    if (leave != true || !context.mounted || _leaving) return;
    setState(() => _leaving = true);
    try {
      await ref
          .read(partyServiceProvider)
          .leaveParty(party.id, expectedUid: viewerUid!);
      if (ref.read(partyVoiceServiceProvider).state.partyId == party.id) {
        await ref.read(partyVoiceServiceProvider).disconnect();
      }
      if (context.mounted) onBack();
    } catch (_) {
      if (context.mounted) {
        _notice(context, 'Unable to leave the party. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voice =
        ref.watch(voiceStateProvider).asData?.value ?? const VoiceState();
    final voiceBusy = voice.partyId == widget.party.id && voice.connecting;
    final liveParty = ref.watch(partyByIdProvider(widget.party.id));
    if (viewerUid != null && viewerUid != party.hostId) {
      final membership = ref.watch(myPartyMembershipProvider(party.id));
      if (membership.asData != null &&
          membership.asData!.value?['leftAt'] != null &&
          !_leaving) {
        return SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  membership.asData!.value?['removedBy'] != null
                      ? 'You were removed from this party.'
                      : 'You are no longer in this party.',
                ),
                TextButton(
                  onPressed: onBack,
                  child: const Text('Back to Parties'),
                ),
              ],
            ),
          ),
        );
      }
    }
    if (liveParty.hasError) {
      return SafeArea(
        child: Center(
          child: TextButton(
            onPressed: onBack,
            child: const Text('Unable to load party. Back to Parties'),
          ),
        ),
      );
    }
    if (liveParty.asData != null &&
        (liveParty.asData!.value == null ||
            liveParty.asData!.value!.status != 'open') &&
        !_leaving) {
      return SafeArea(
        child: Center(
          child: TextButton(
            onPressed: onBack,
            child: const Text('This party has closed. Back to Parties'),
          ),
        ),
      );
    }
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final roster = members;
    final liveMembers = roster == null
        ? ref.watch(partyMemberIdsProvider(party.id))
        : null;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
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
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Semantics(
                  button: true,
                  label: 'Party details',
                  child: Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: colors.primary.withValues(alpha: .45),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.primary.withValues(alpha: .28),
                            colors.secondary.withValues(alpha: .09),
                            colors.surface,
                          ],
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _details(context),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      party.title,
                                      style: text.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${party.currentPlayers} / ${party.maxPlayers} players · ${party.visibility == 'private' ? 'Private' : 'Public'} party',
                                      style: text.bodyMedium?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: .28),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.sports_esports_rounded,
                                  size: 28,
                                  color: colors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Squad members',
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                if (_removing != null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (roster != null) ...[
                  if (roster.isEmpty)
                    const Text('No member details available yet.'),
                  for (final member in roster)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LobbyMemberCard(
                        member: LobbyMember(
                          uid: member.uid,
                          name: member.name,
                          rank: member.rank,
                          rating: member.rating,
                          micEnabled:
                              voice.connected && voice.partyId == party.id
                              ? (member.uid == viewerUid
                                    ? micEnabled
                                    : voice.remoteMics[member.uid])
                              : member.micEnabled,
                          isSpeaking: voice.speakingPlayers.contains(
                            member.uid,
                          ),
                        ),
                        isHost: member.uid == party.hostId,
                        onViewProfile: () => _profile(context, member.uid),
                        onRemove:
                            viewerUid == party.hostId &&
                                member.uid != party.hostId
                            ? (_removing == null && !_leaving
                                  ? () => _remove(
                                      context,
                                      member.uid,
                                      member.name,
                                    )
                                  : null)
                            : null,
                      ),
                    ),
                ] else if (liveMembers?.asData != null) ...[
                  for (final uid in liveMembers!.asData!.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _HostCard(
                        partyGame: party.gameId.isEmpty
                            ? party.gameName
                            : party.gameId,
                        uid: uid,
                        isSpeaking: voice.speakingPlayers.contains(uid),
                        isHost: uid == party.hostId,
                        micEnabled: uid == viewerUid
                            ? micEnabled
                            : voice.remoteMics[uid],
                        onViewProfile: () => _profile(context, uid),
                        onRemove:
                            viewerUid == party.hostId &&
                                uid != party.hostId &&
                                _removing == null &&
                                !_leaving
                            ? (name) => _remove(context, uid, name)
                            : null,
                      ),
                    ),
                ] else ...[
                  if (party.hostId.isNotEmpty)
                    _HostCard(
                      partyGame: party.gameId.isEmpty
                          ? party.gameName
                          : party.gameId,
                      uid: party.hostId,
                      isSpeaking: voice.speakingPlayers.contains(party.hostId),
                      micEnabled: party.hostId == viewerUid
                          ? micEnabled
                          : voice.remoteMics[party.hostId],
                      onViewProfile: () => _profile(context, party.hostId),
                    ),
                  const SizedBox(height: 12),
                  if (liveMembers?.hasError == true)
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(partyMemberIdsProvider(party.id)),
                      child: const Text('Unable to load squad. Try again'),
                    ),
                  const SizedBox(height: 12),
                ],
                if (viewerUid != null && viewerUid == party.hostId)
                  OutlinedButton.icon(
                    onPressed: party.isFull || _leaving
                        ? null
                        : onInvite ?? () => _invite(context),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(party.isFull ? 'Party full' : 'Invite player'),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: colors.outline.withValues(alpha: .55)),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (voiceBusy)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            voice.serverWaking
                                ? 'Waiting for voice server… It may be waking up. This can take about a minute.'
                                : 'Connecting to voice…',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (voice.connected && voice.partyId == party.id)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Voice connected · ${voice.remoteCount} others in voice'
                      '${!voice.muted ? (voice.inputLevel > 5 ? ' · Mic picking up sound' : ' · No mic input detected') : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (!voiceBusy &&
                    !(voice.connected && voice.partyId == party.id))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _connectVoice,
                      icon: const Icon(Icons.headset_rounded, size: 18),
                      label: const Text('Join voice'),
                    ),
                  ),
                if (voice.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      voice.error!,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            voiceBusy ||
                                (onToggleMic == null &&
                                    !(voice.connected &&
                                        voice.partyId == party.id))
                            ? null
                            : onToggleMic ?? () => _toggleVoice(context),
                        icon: Icon(
                          micEnabled ? Icons.mic : Icons.mic_off_outlined,
                        ),
                        label: Text(
                          voiceBusy
                              ? 'Connecting…'
                              : micEnabled
                              ? 'Mic: ON'
                              : 'Mic: OFF',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            onChat ??
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    PartyChatScreen(partyId: party.id),
                              ),
                            ),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Chat'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _leaving ? null : () => _leave(context),
                  child: Text(_leaving ? 'Leaving…' : 'Leave Party'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HostCard extends ConsumerWidget {
  const _HostCard({
    required this.partyGame,
    required this.uid,
    required this.onViewProfile,
    this.isHost = true,
    this.micEnabled,
    this.isSpeaking = false,
    this.onRemove,
  });
  final bool isHost;
  final bool? micEnabled;
  final bool isSpeaking;
  final ValueChanged<String>? onRemove;
  final String uid, partyGame;
  final VoidCallback onViewProfile;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProfileProvider(uid));
    final game = GameCatalog.find(partyGame);
    final preferences = game?.supportsRanks == true
        ? ref.watch(gamingPreferencesProvider(uid))
        : null;
    final rank = preferences?.when(
      data: (value) => value.rankLabelFor(game!.id) ?? 'Unranked',
      loading: () => 'Loading rank…',
      error: (_, stack) => 'Rank unavailable',
    );
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
          child: const Text('Unable to load player. Try again'),
        ),
      ),
      data: (profile) => LobbyMemberCard(
        member: LobbyMember(
          uid: uid,
          rank: rank,
          micEnabled: micEnabled,
          isSpeaking: isSpeaking,
          name: profile?.username.trim().isNotEmpty == true
              ? profile!.username
              : isHost
              ? 'Host'
              : 'Player',
        ),
        isHost: isHost,
        onViewProfile: onViewProfile,
        onRemove: onRemove == null
            ? null
            : () => onRemove!(profile?.username ?? 'this player'),
      ),
    );
  }
}
