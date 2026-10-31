import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/chat/models/chat_receipt.dart';
import 'package:lurk_app/features/chat/models/chat_message.dart';
import 'package:lurk_app/features/chat/widgets/chat_message_bubble.dart';
import 'package:lurk_app/services/chat_service.dart';

void main() {
  test(
    'unread count excludes own, pending, read and cleared messages but includes invitations',
    () {
      final boundary = DateTime(2026, 10, 31);
      final later = boundary.add(const Duration(minutes: 1));
      final messages = [
        ChatMessage(
          id: 'read',
          senderId: 'bob',
          text: 'old',
          createdAt: boundary,
        ),
        ChatMessage(
          id: 'mine',
          senderId: 'alice',
          text: 'reply',
          createdAt: later,
        ),
        ChatMessage(id: 'new', senderId: 'bob', text: 'new', createdAt: later),
        ChatMessage(
          id: 'invite',
          senderId: 'bob',
          text: 'Party invitation',
          type: 'party_invite',
          createdAt: later,
        ),
        ChatMessage(
          id: 'pending',
          senderId: 'bob',
          text: 'pending',
          pending: true,
          createdAt: later,
        ),
      ];
      expect(ChatService.countUnread(messages, 'alice', null), 3);
      expect(ChatService.countUnread(messages, 'alice', boundary), 2);
      expect(ChatService.countUnread(messages, 'alice', later), 0);
    },
  );
  test(
    'read watermark covers earlier messages but not later or pending times',
    () {
      final date = DateTime(2026, 10, 31);
      final receipt = ChatReceipt(readThrough: date);
      expect(receipt.covers(date), true);
      expect(receipt.covers(date.subtract(const Duration(seconds: 1))), true);
      expect(receipt.covers(date.add(const Duration(seconds: 1))), false);
      expect(receipt.covers(null), false);
      expect(const ChatReceipt().covers(date), false);
    },
  );
  testWidgets('outgoing bubbles show message content without status labels', (
    tester,
  ) async {
    for (final pending in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              message: ChatMessage(
                id: 'one',
                senderId: 'alice',
                text: 'Hello',
                pending: pending,
              ),
              mine: true,
            ),
          ),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);
      for (final label in ['Read', 'Sent', 'Sending…']) {
        expect(find.text(label), findsNothing);
      }
    }
  });
}
