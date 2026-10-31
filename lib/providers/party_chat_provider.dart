import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/chat/models/chat_message.dart';
import '../services/party_chat_service.dart';
import 'auth_provider.dart';

final partyChatServiceProvider = Provider((ref) => PartyChatService());
final partyMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, ({String partyId, int limit})>((ref, key) {
      if (ref.watch(authStateProvider).asData?.value == null) {
        return Stream.value(const []);
      }
      return ref
          .watch(partyChatServiceProvider)
          .watchMessages(key.partyId, key.limit);
    }, retry: (count, error) => null);
