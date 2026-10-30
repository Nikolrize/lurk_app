import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/player_provider.dart';
import '../widgets/chat_widgets.dart';
import 'chat_screen.dart';

class NewMessageScreen extends ConsumerStatefulWidget {
  const NewMessageScreen({super.key});
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
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(chatId: id, otherUid: otherUid),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this chat. Please try again.'),
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
      appBar: AppBar(title: const Text('New message')),
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
                          leading: ChatAvatar(name: name),
                          title: Text(name),
                          subtitle: const Text('Start a chat'),
                          trailing: _opening == player.id
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.chevron_right),
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
