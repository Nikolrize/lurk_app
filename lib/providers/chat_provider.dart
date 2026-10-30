import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/chat/models/chat.dart';
import '../features/chat/models/chat_message.dart';
import '../services/chat_service.dart';
import 'auth_provider.dart';
import '../features/player/models/player.dart';
import '../features/parties/models/party.dart';
import '../features/chat/models/chat_settings.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());
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
