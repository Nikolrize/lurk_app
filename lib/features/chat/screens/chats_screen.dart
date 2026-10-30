import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/profile_provider.dart';
import '../models/chat.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/chat_error.dart';
import 'chat_screen.dart';
import 'new_message_screen.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});
  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(chatsProvider);
    final uid = ref.watch(authStateProvider).asData?.value?.uid;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Messages',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'New message',
                  color: AppColors.primary,
                  onPressed: uid == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const NewMessageScreen(),
                          ),
                        ),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search conversations',
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: chats.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => ChatNotice(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load chats',
                  description: chatErrorDescription(error),
                  onRetry: () => ref.invalidate(chatsProvider),
                ),
                data: (items) {
                  if (items.isEmpty || uid == null) {
                    return const ChatNotice(
                      icon: Icons.forum_outlined,
                      title: 'Your next party starts with a hello',
                      description:
                          'Tap the compose button to message a player.',
                    );
                  }
                  // Profile streams provide current names; no stale names stored in chats.
                  final profiles = {
                    for (final item in items)
                      item.otherUid(uid): ref.watch(
                        playerProfileProvider(item.otherUid(uid)),
                      ),
                  };
                  final filtered = items.where((item) {
                    final name =
                        profiles[item.otherUid(uid)]?.asData?.value?.username ??
                        '';
                    return _search.isEmpty ||
                        name.toLowerCase().contains(_search);
                  }).toList();
                  if (filtered.isEmpty) {
                    return const ChatNotice(
                      icon: Icons.search_off,
                      title: 'No conversation found',
                      description: 'Try another player name.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 104),
                    itemCount: filtered.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final profile = profiles[item.otherUid(uid)]!;
                      final name = profile.asData?.value?.username;
                      return _ChatTile(
                        chat: item,
                        uid: uid,
                        name: name == null || name.isEmpty ? 'Player' : name,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  const _ChatTile({required this.chat, required this.uid, required this.name});
  final Chat chat;
  final String uid, name;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(chatSettingsProvider(chat.id));
    final clearedAt = settings.asData?.value.clearedAt;
    final cleared =
        clearedAt != null &&
        chat.updatedAt != null &&
        !chat.updatedAt!.isAfter(clearedAt);
    final preview = settings.isLoading
        ? 'Loading chat…'
        : settings.hasError
        ? 'Preview unavailable'
        : cleared
        ? 'Chat cleared'
        : chat.preview.isEmpty
        ? 'Say hello 👋'
        : '${chat.lastSenderId == uid ? 'You: ' : ''}${chat.preview}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: ChatAvatar(name: name),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      trailing: Text(
        chatTime(chat.updatedAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ChatScreen(chatId: chat.id, otherUid: chat.otherUid(uid)),
        ),
      ),
    );
  }
}
