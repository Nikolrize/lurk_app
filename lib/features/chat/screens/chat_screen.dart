import 'dart:async';
import '../../profile/screens/player_profile_screen.dart';
import '../../../services/player_safety_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/profile_provider.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/chat_error.dart';
import '../widgets/chat_message_bubble.dart';

import 'package:lurk_app/core/widgets/player_status_badge.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId, required this.otherUid});
  final String chatId, otherUid;
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  String? _lastReadId;
  bool _markingRead = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_tryMarkRead);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tryMarkRead();
  }

  void _tryMarkRead() {
    if (!mounted ||
        _markingRead ||
        _searching ||
        ModalRoute.of(context)?.isCurrent != true ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) ||
        (_scroll.hasClients && _scroll.offset > 80)) {
      return;
    }
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    final items = ref
        .read(messagesProvider((id: widget.chatId, limit: _limit)))
        .asData
        ?.value;
    if (uid == null || items == null) return;
    final committed = items
        .where((m) => !m.pending && m.createdAt != null)
        .toList();
    if (committed.isEmpty) return;
    final latest = committed.first;
    if (_lastReadId == latest.id) return;
    _markingRead = true;
    unawaited(
      ref
          .read(chatServiceProvider)
          .markRead(widget.chatId, uid, latest)
          .then((_) {
            _lastReadId = latest.id;
          })
          .catchError((Object error) {
            debugPrint('Could not update read status: $error');
          })
          .whenComplete(() {
            _markingRead = false;
            if (mounted && _lastReadId == latest.id) _tryMarkRead();
          }),
    );
  }

  bool _sending = false;
  String? _sendError;
  int _limit = 50;
  bool _searching = false;
  String _query = '';
  Future<void> _menuAction(String action) async {
    if (action == 'profile') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerProfileScreen(uid: widget.otherUid),
        ),
      );
      return;
    }
    if (action == 'search') {
      setState(() {
        _searching = true;
        _query = '';
      });
      return;
    }
    if (action != 'clear') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat history?'),
        content: const Text(
          'Earlier messages will be hidden for you. The other player keeps their history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear for me'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    try {
      await ref.read(chatServiceProvider).clearHistory(widget.chatId, uid);
      if (mounted) {
        setState(() {
          _limit = 50;
          _query = '';
          _searching = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _sendError = chatSendErrorDescription(error));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    final text = _composer.text;
    if (uid == null || _sending || text.trim().isEmpty) {
      return;
    }
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final service = ref.read(chatServiceProvider);
      await service.sendMessage(widget.chatId, uid, text);
      if (mounted) _composer.clear();
    } catch (error) {
      if (mounted) {
        setState(() => _sendError = chatSendErrorDescription(error));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.viewInsetsOf(context).bottom > 0;
    final uid = ref.watch(authStateProvider).asData?.value?.uid;
    final profile = ref.watch(playerProfileProvider(widget.otherUid));
    final peer = ref.watch(chatPlayerProvider(widget.otherUid));
    final player = peer.asData?.value;
    final username = profile.asData?.value?.username;
    final name = username == null || username.isEmpty ? 'Player' : username;
    final contextLabels = [
      if (player?.currentGame != null) player!.currentGame!,
      if (player?.rank != null) 'Rank ${player!.rank}',
      if (player?.rating != null)
        '${player!.rating!.toStringAsFixed(1)} rating',
    ];
    final key = (id: widget.chatId, limit: _limit);
    final messages = ref.watch(messagesProvider(key));
    final blocks = ref.watch(blockedPlayersProvider);
    final blocked = blocks.asData?.value.contains(widget.otherUid) ?? false;
    final canSend = uid != null && !_sending && blocks.hasValue && !blocked;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: const BorderSide(color: AppColors.outline),
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 48,
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'View player profile',
                    child: InkWell(
                      onTap: () => _menuAction('profile'),
                      borderRadius: BorderRadius.circular(24),
                      child: ChatAvatar(name: name, uid: widget.otherUid),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        PlayerStatusBadge(uid: widget.otherUid),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Chat options',
                    icon: const Icon(Icons.more_vert),
                    enabled: !_sending && uid != null,
                    onSelected: (action) => _menuAction(action),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'profile',
                        child: Text('View player profile'),
                      ),
                      const PopupMenuItem(
                        value: 'search',
                        child: Text('Search messages'),
                      ),
                      const PopupMenuItem(
                        value: 'clear',
                        child: Text('Clear chat history'),
                      ),
                    ],
                  ),
                ],
              ),
              if (contextLabels.isNotEmpty && !compact && !_searching) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Text(
                    contextLabels.join(' · '),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              SizedBox(height: compact ? 8 : 24),
              if (_searching) ...[
                TextField(
                  autofocus: true,
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search messages',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Close search',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _searching = false;
                        _query = '';
                      }),
                    ),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Searches loaded history. Load older messages to search further.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else
                  const SizedBox(height: 8),
              ],
              Expanded(
                child: messages.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => ChatNotice(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load messages',
                    description: chatErrorDescription(error),
                    onRetry: () => ref.invalidate(messagesProvider(key)),
                  ),
                  data: (allItems) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _tryMarkRead(),
                    );
                    final items = _query.isEmpty
                        ? allItems
                        : allItems
                              .where(
                                (message) =>
                                    message.text.toLowerCase().contains(_query),
                              )
                              .toList();
                    if (items.isEmpty) {
                      if (_query.isNotEmpty) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('No matching messages'),
                            if (allItems.length >= _limit)
                              TextButton(
                                onPressed: () => setState(() => _limit += 50),
                                child: const Text('Load older messages'),
                              ),
                          ],
                        );
                      }
                      return ChatNotice(
                        icon: Icons.waving_hand_outlined,
                        title: 'Say hello to $name',
                        description:
                            'Find your next teammate. Send the first message.',
                      );
                    }
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        shrinkWrap: true,
                        itemCount: items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == items.length) {
                            return allItems.length < _limit
                                ? const SizedBox.shrink()
                                : TextButton(
                                    onPressed: () =>
                                        setState(() => _limit += 50),
                                    child: const Text('Load older messages'),
                                  );
                          }
                          final message = items[index];
                          final previous = index + 1 < items.length
                              ? items[index + 1].createdAt?.toLocal()
                              : null;
                          final date = message.createdAt?.toLocal();
                          final showDate =
                              date != null &&
                              (previous == null ||
                                  date.year != previous.year ||
                                  date.month != previous.month ||
                                  date.day != previous.day ||
                                  date.difference(previous).inMinutes >= 30);
                          return Column(
                            children: [
                              if (showDate)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 20,
                                  ),
                                  child: Text(
                                    chatDateLabel(context, date),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      letterSpacing: .5,
                                    ),
                                  ),
                                ),
                              ChatMessageBubble(
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
              const SizedBox(height: 16),
              if (_sendError != null) ...[
                Text(
                  _sendError!,
                  style: const TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      readOnly: !canSend,
                      minLines: 1,
                      maxLines: compact ? 2 : 4,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: blocked
                            ? 'Unblock this player to message'
                            : 'Type a message…',
                        counterText: '',
                        border: border,
                        enabledBorder: border,
                        focusedBorder: border.copyWith(
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: !canSend || _composer.text.trim().isEmpty
                        ? null
                        : () => _send(),
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
            ],
          ),
        ),
      ),
    );
  }
}
