import '../../../core/widgets/player_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/player_provider.dart';
import '../widgets/chat_widgets.dart';
import 'chat_screen.dart';

class NewMessageScreen extends ConsumerStatefulWidget {
  const NewMessageScreen({
    super.key,
    this.invitePartyId,
    this.excludedPlayerIds = const {},
  });
  final String? invitePartyId;
  final Set<String> excludedPlayerIds;
  @override
  ConsumerState<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends ConsumerState<NewMessageScreen> {
  String _search = '';
  String? _opening;

  Future<void> _open(String otherUid) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null || _opening != null) return;
    setState(() => _opening = otherUid);
    try {
      final id = await ref.read(chatServiceProvider).openDirect(uid, otherUid);
      final partyId = widget.invitePartyId;
      if (partyId != null) {
        await ref.read(chatServiceProvider).sendPartyInvite(id, uid, partyId);
      }
      if (!mounted) return;
      if (partyId != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Party invitation sent.')));
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(chatId: id, otherUid: otherUid),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.invitePartyId == null
                  ? 'Could not open this chat. Please try again.'
                  : error is StateError
                  ? error.message.toString()
                  : 'Could not send the invitation. Check your connection and party access, then try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = ref.watch(discoverablePlayersProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.invitePartyId == null ? 'New message' : 'Invite player',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                onChanged: (value) =>
                    setState(() => _search = value.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search players',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: players.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => ChatNotice(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load players',
                    description: 'Check your connection and try again.',
                    onRetry: () => ref.invalidate(discoverablePlayersProvider),
                  ),
                  data: (items) {
                    final uid = ref.watch(authStateProvider).asData?.value?.uid;
                    final filtered = items
                        .where(
                          (player) =>
                              player.id != uid &&
                              !widget.excludedPlayerIds.contains(player.id) &&
                              player.name.toLowerCase().contains(_search),
                        )
                        .toList();
                    if (filtered.isEmpty) {
                      return const ChatNotice(
                        icon: Icons.person_search_outlined,
                        title: 'No players found',
                        description: 'Try another name or check back later.',
                      );
                    }
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final player = filtered[index];
                        final name = player.name.isEmpty
                            ? 'Player'
                            : player.name;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          leading: PlayerAvatar(
                            photoPath: player.photoPath,
                            radius: 24,
                          ),
                          title: Text(name),
                          subtitle: Text(
                            widget.invitePartyId == null
                                ? 'Start a chat'
                                : 'Send party invitation',
                          ),
                          trailing: _opening == player.id
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  widget.invitePartyId == null
                                      ? Icons.chevron_right
                                      : Icons.person_add_alt_1,
                                ),
                          enabled: _opening == null,
                          onTap: () => _open(player.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
