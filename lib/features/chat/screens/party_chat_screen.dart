import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/party_chat_provider.dart';
import '../../../providers/party_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../services/player_safety_service.dart';
import '../../profile/screens/player_profile_screen.dart';
import '../models/chat_message.dart';
import '../widgets/chat_message_bubble.dart';

class PartyChatScreen extends ConsumerStatefulWidget {
  const PartyChatScreen({super.key, required this.partyId});
  final String partyId;
  @override
  ConsumerState<PartyChatScreen> createState() => _PartyChatScreenState();
}

class _PartyChatScreenState extends ConsumerState<PartyChatScreen> {
  final _composer = TextEditingController();
  int _limit = 50;
  bool _sending = false;
  String? _error;
  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _send(String uid) async {
    if (_sending || _composer.text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(partyChatServiceProvider)
          .send(widget.partyId, uid, _composer.text);
      if (mounted) _composer.clear();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not send. Check your connection and party membership, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).asData?.value?.uid;
    final party = ref.watch(partyByIdProvider(widget.partyId));
    final membership = ref.watch(myPartyMembershipProvider(widget.partyId));
    final blocks = ref.watch(blockedPlayersProvider);
    final ready =
        party.hasValue &&
        membership.hasValue &&
        blocks.hasValue &&
        !party.isLoading &&
        !membership.isLoading &&
        !blocks.isLoading &&
        !party.hasError &&
        !membership.hasError &&
        !blocks.hasError;
    final access =
        uid != null &&
        ready &&
        party.asData?.value?.status == 'open' &&
        membership.asData?.value != null &&
        membership.asData!.value!['leftAt'] == null;
    final key = (partyId: widget.partyId, limit: _limit);
    final messages = access ? ref.watch(partyMessagesProvider(key)) : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${party.asData?.value?.title ?? 'Party'}’s Chat",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: uid == null
                  ? const Center(child: Text('Sign in to use party chat.'))
                  : !ready
                  ? party.hasError || membership.hasError || blocks.hasError
                        ? Center(
                            child: TextButton(
                              onPressed: () {
                                ref.invalidate(
                                  partyByIdProvider(widget.partyId),
                                );
                                ref.invalidate(
                                  myPartyMembershipProvider(widget.partyId),
                                );
                                ref.invalidate(blockedPlayersProvider);
                              },
                              child: const Text(
                                'Could not load party chat. Tap to retry.',
                              ),
                            ),
                          )
                        : const Center(child: CircularProgressIndicator())
                  : !access
                  ? const Center(
                      child: Text(
                        'Chat is available to current members of an open party.',
                      ),
                    )
                  : messages!.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, stack) => Center(
                        child: TextButton(
                          onPressed: () =>
                              ref.invalidate(partyMessagesProvider(key)),
                          child: const Text(
                            'Chat unavailable. Check your membership or tap to retry.',
                          ),
                        ),
                      ),
                      data: (all) {
                        final visible = all
                            .where(
                              (m) => !blocks.asData!.value.contains(m.senderId),
                            )
                            .toList();
                        if (all.isEmpty) {
                          return const Center(
                            child: Text('Say hello to your squad!'),
                          );
                        }
                        return Align(
                          alignment: Alignment.topCenter,
                          child: ListView.builder(
                            shrinkWrap: true,
                            reverse: true,
                            padding: const EdgeInsets.all(16),
                            itemCount: visible.length + 1,
                            itemBuilder: (context, index) {
                              if (index == visible.length) {
                                return all.length >= _limit
                                    ? TextButton(
                                        onPressed: () =>
                                            setState(() => _limit += 50),
                                        child: const Text(
                                          'Load older messages',
                                        ),
                                      )
                                    : const SizedBox.shrink();
                              }
                              final message = visible[index];
                              final date = message.createdAt;
                              final previous = index + 1 < visible.length
                                  ? visible[index + 1].createdAt
                                  : null;
                              final showDate =
                                  date != null &&
                                  (previous == null ||
                                      DateUtils.dateOnly(date.toLocal()) !=
                                          DateUtils.dateOnly(
                                            previous.toLocal(),
                                          ) ||
                                      date.difference(previous).inMinutes >=
                                          30);
                              return Column(
                                children: [
                                  if (showDate)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        bottom: 16,
                                      ),
                                      child: Text(
                                        chatDateLabel(context, date),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  _PartyMessage(
                                    message: message,
                                    mine: message.senderId == uid,
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            if (blocks.asData?.value.isNotEmpty == true)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Messages from blocked players are hidden.'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      enabled: access && !_sending,
                      maxLength: 2000,
                      minLines: 1,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send party message',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    onPressed:
                        access && !_sending && _composer.text.trim().isNotEmpty
                        ? () => _send(uid)
                        : null,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Text(
                'This chat is only available to this party session.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartyMessage extends ConsumerWidget {
  const _PartyMessage({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name =
        ref
            .watch(playerProfileProvider(message.senderId))
            .asData
            ?.value
            ?.username ??
        'Player';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!mine) ...[
            Tooltip(
              message: 'View $name profile',
              child: InkWell(
                key: ValueKey('party-chat-avatar-${message.senderId}'),
                borderRadius: BorderRadius.circular(24),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlayerProfileScreen(uid: message.senderId),
                  ),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  child: Text(
                    name.trim().isEmpty
                        ? '?'
                        : name.trim().characters.first.toUpperCase(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!mine) ...[
                  Text(
                    name,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * .72,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: mine
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: mine
                          ? Colors.transparent
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: SelectableText(
                    message.text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: mine
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
