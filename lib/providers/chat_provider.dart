import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/chat/models/chat.dart';
import '../features/chat/models/chat_message.dart';
import '../services/chat_service.dart';
import 'auth_provider.dart';
import '../features/chat/models/chat_receipt.dart';
import '../features/player/models/player.dart';
import '../features/parties/models/party.dart';
import '../features/chat/models/chat_settings.dart';

final chatReceiptProvider = StreamProvider.autoDispose
    .family<ChatReceipt, ({String chatId, String uid})>((ref, key) {
      if (ref.watch(authStateProvider).asData?.value == null) {
        return Stream.value(const ChatReceipt());
      }
      return ref.watch(chatServiceProvider).watchReceipt(key.chatId, key.uid);
    }, retry: (count, error) => null);

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());
final unreadCountProvider = StreamProvider.autoDispose.family<int, String>((
  ref,
  chatId,
) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(0);
  final receipt = ref.watch(chatReceiptProvider((chatId: chatId, uid: uid)));
  final settings = ref.watch(chatSettingsProvider(chatId));
  if (receipt.hasError) return Stream.error(receipt.error!);
  if (settings.hasError) return Stream.error(settings.error!);
  if (!receipt.hasValue || !settings.hasValue) return const Stream<int>.empty();
  final readAt = receipt.asData?.value.readThrough;
  final clearedAt = settings.asData?.value.clearedAt;
  final after = readAt == null
      ? clearedAt
      : clearedAt != null && clearedAt.isAfter(readAt)
      ? clearedAt
      : readAt;
  return ref.watch(chatServiceProvider).watchUnreadCount(chatId, uid, after);
}, retry: (count, error) => null);
final chatSettingsProvider = StreamProvider.autoDispose
    .family<ChatSettings, String>((ref, chatId) {
      final uid = ref.watch(authStateProvider).asData?.value?.uid;
      if (uid == null) return Stream.value(const ChatSettings());
      return ref.watch(chatServiceProvider).watchSettings(chatId, uid);
    }, retry: (count, error) => null);

final chatPlayerProvider = StreamProvider.autoDispose.family<Player?, String>((
  ref,
  uid,
) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(null);
  return ref.watch(chatServiceProvider).watchPlayer(uid);
}, retry: (count, error) => null);

final chatPartyProvider = StreamProvider.autoDispose.family<Party?, String>((
  ref,
  id,
) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(null);
  return ref.watch(chatServiceProvider).watchInviteParty(id);
}, retry: (count, error) => null);

final chatsProvider = StreamProvider.autoDispose<List<Chat>>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.hasError) return Stream.error(auth.error!);
  final uid = auth.asData?.value?.uid;
  if (uid == null) return Stream.value(const <Chat>[]);
  return ref.watch(chatServiceProvider).watchChats(uid);
}, retry: (count, error) => null);

final messagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, ({String id, int limit})>((ref, key) {
      final uid = ref.watch(authStateProvider).asData?.value?.uid;
      if (uid == null) return Stream.value(const <ChatMessage>[]);
      final settings = ref.watch(chatSettingsProvider(key.id));
      if (settings.hasError) return Stream.error(settings.error!);
      if (settings.isLoading) return const Stream<List<ChatMessage>>.empty();
      return ref
          .watch(chatServiceProvider)
          .watchMessages(
            key.id,
            limit: key.limit,
            after: settings.asData?.value.clearedAt,
          );
    }, retry: (count, error) => null);
