import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../services/notification_service.dart';

/// Mounted only after authentication and profile setup are complete.
class NotificationGate extends StatefulWidget {
  const NotificationGate({super.key, required this.uid, required this.child});
  final String uid;
  final Widget child;
  @override
  State<NotificationGate> createState() => _NotificationGateState();
}

class _NotificationGateState extends State<NotificationGate> {
  StreamSubscription<RemoteMessage>? _foreground, _opened;
  bool _opening = false;
  OverlayEntry? _banner;
  Timer? _bannerTimer;

  void _dismissBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    _banner?.remove();
    _banner?.dispose();
    _banner = null;
  }

  @override
  void initState() {
    super.initState();
    if (!NotificationService.supported) return;
    _foreground = FirebaseMessaging.onMessage.listen(_show);
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(_open);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final initial = await NotificationService.instance.initialMessage();
        if (initial != null && mounted) unawaited(_open(initial));
        if (mounted) await NotificationService.instance.register(widget.uid);
      } catch (e) {
        debugPrint('Notification setup failed: $e');
      }
    });
  }

  bool _forThisUser(RemoteMessage message) =>
      FirebaseAuth.instance.currentUser?.uid == widget.uid &&
      (message.data['recipientId'] == null ||
          message.data['recipientId'] == widget.uid);

  Future<void> _show(RemoteMessage message) async {
    if (!mounted || !_forThisUser(message)) return;
    if (message.data['chatId'] != null) {
      try {
        final preferences = await FirebaseFirestore.instance
            .collection('notification_preferences')
            .doc(widget.uid)
            .get();
        final key = message.data['type'] == 'party_invite'
            ? 'invitations'
            : 'messages';
        if (preferences.data()?[key] == false) return;
      } catch (_) {
        // A transient preference lookup failure must not break notification handling.
      }
    }
    if (!mounted || !_forThisUser(message)) return;
    final notification = message.notification;
    if (notification == null) return;
    _dismissBanner();
    final canOpen = message.data['chatId'] is String;
    final theme = Theme.of(context);
    _banner = OverlayEntry(
      builder: (_) => Positioned(
        top: 8,
        left: 16,
        right: 16,
        child: SafeArea(
          bottom: false,
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: theme.colorScheme.surfaceContainerHigh,
              elevation: 12,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: canOpen
                    ? () {
                        _dismissBanner();
                        unawaited(_open(message));
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (notification.title != null)
                              Text(
                                notification.title!,
                                style: theme.textTheme.titleSmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (notification.body != null)
                              Text(
                                notification.body!,
                                style: theme.textTheme.bodyMedium,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (canOpen)
                              Text(
                                'Tap to open',
                                style: theme.textTheme.labelSmall,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _dismissBanner,
                        tooltip: 'Dismiss notification',
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_banner!);
    _bannerTimer = Timer(const Duration(seconds: 5), _dismissBanner);
  }

  Future<void> _open(RemoteMessage message) async {
    if (!mounted || _opening || !_forThisUser(message)) return;
    final chatId = message.data['chatId'];
    if (chatId is! String || chatId.isEmpty || chatId.contains('/')) return;
    _opening = true;
    try {
      final chat = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();
      final ids =
          (chat.data()?['userIds'] as List?)?.whereType<String>().toList() ??
          [];
      if (!mounted ||
          !_forThisUser(message) ||
          ids.length != 2 ||
          !ids.contains(widget.uid)) {
        return;
      }
      final other = ids.firstWhere((id) => id != widget.uid);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(chatId: chatId, otherUid: other),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This conversation is no longer available.'),
          ),
        );
      }
    } finally {
      _opening = false;
    }
  }

  @override
  void dispose() {
    _dismissBanner();
    _foreground?.cancel();
    _opened?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
