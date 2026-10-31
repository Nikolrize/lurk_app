import 'package:lurk_app/features/chat/widgets/chat_message_bubble.dart';
import 'package:lurk_app/features/chat/models/chat_message.dart';
import 'package:lurk_app/features/parties/models/party.dart';
import 'package:lurk_app/providers/party_provider.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/core/theme/app_theme.dart';
import 'package:lurk_app/features/chat/screens/new_message_screen.dart';
import 'package:lurk_app/features/chat/screens/chat_screen.dart';
import 'package:lurk_app/features/player/models/player.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/chat_provider.dart';
import 'package:lurk_app/providers/player_provider.dart';
import 'package:lurk_app/providers/profile_provider.dart';
import 'package:lurk_app/services/chat_service.dart';

class InviteUser extends Fake implements User {
  InviteUser([this.id = 'alice']);
  final String id;
  @override
  String get uid => id;
}

class InviteService extends Fake implements ChatService {
  final result = Completer<void>();
  int calls = 0;
  String? recipient, invitedParty;
  @override
  Future<String> openDirect(String uid, String otherUid) async {
    recipient = otherUid;
    return 'direct';
  }

  @override
  Future<void> sendPartyInvite(String chatId, String uid, String partyId) {
    calls++;
    invitedParty = partyId;
    return result.future;
  }
}

Widget app(InviteService service) => ProviderScope(
  overrides: [
    authStateProvider.overrideWith((ref) => Stream.value(InviteUser())),
    chatServiceProvider.overrideWithValue(service),
    discoverablePlayersProvider.overrideWith(
      (ref) => Stream.value(const [
        Player(id: 'alice', name: 'Alice', isActive: true),
        Player(id: 'bob', name: 'Bob', isActive: true),
        Player(id: 'member', name: 'Already joined', isActive: true),
      ]),
    ),
    playerProfileProvider.overrideWith((ref, uid) => Stream.value(null)),
    chatPlayerProvider.overrideWith((ref, uid) => Stream.value(null)),
    messagesProvider.overrideWith((ref, key) => Stream.value([])),
  ],
  child: MaterialApp(
    theme: AppTheme.dark,
    home: const NewMessageScreen(
      invitePartyId: 'private-party',
      excludedPlayerIds: {'member'},
    ),
  ),
);
void main() {
  testWidgets(
    'Invite picker searches, excludes squad, sends once and opens chat',
    (tester) async {
      final service = InviteService();
      await tester.pumpWidget(app(service));
      await tester.pumpAndSettle();
      expect(find.text('Invite player'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
      expect(find.text('Already joined'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Nobody');
      await tester.pumpAndSettle();
      expect(find.text('No players found'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'bob');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bob'));
      await tester.pump();
      await tester.tap(find.text('Bob'));
      await tester.pump();
      expect(service.calls, 1);
      expect(service.recipient, 'bob');
      expect(service.invitedParty, 'private-party');
      service.result.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('Party invitation sent.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Failed invitation retains picker and explains the failure', (
    tester,
  ) async {
    final service = InviteService();
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bob'));
    await tester.pump();
    service.result.completeError(StateError('This party is full.'));
    await tester.pumpAndSettle();
    expect(find.byType(NewMessageScreen), findsOneWidget);
    expect(find.text('This party is full.'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byType(ListTile)).enabled, isTrue);
  });

  testWidgets('Invitation shows Join only and disables it for the sender', (
    tester,
  ) async {
    const party = Party(
      id: 'private-party',
      hostId: 'alice',
      title: 'Squad',
      gameName: 'Valorant',
      playStyle: 'Competitive',
      currentPlayers: 1,
      maxPlayers: 5,
    );
    const message = ChatMessage(
      id: 'invite',
      senderId: 'alice',
      text: 'Party invitation',
      type: 'party_invite',
      partyId: 'private-party',
    );
    for (final mine in [true, false]) {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(mine),
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(InviteUser(mine ? 'alice' : 'bob')),
            ),
            joinedPartyIdProvider.overrideWith((ref) => Stream.value(null)),
            chatPartyProvider.overrideWith((ref, id) => Stream.value(party)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChatMessageBubble(message: message, mine: mine),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Join'), findsOneWidget);
      expect(find.text('View party'), findsNothing);
      expect(find.text('Open Lobby'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        mine ? isNull : isNotNull,
      );
    }
  });
}
