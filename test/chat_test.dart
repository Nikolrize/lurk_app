import 'package:lurk_app/services/player_safety_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/core/theme/app_theme.dart';
import 'package:lurk_app/features/chat/models/chat_message.dart';
import 'package:lurk_app/features/chat/models/chat.dart';
import 'package:lurk_app/features/chat/screens/chat_screen.dart';
import 'package:lurk_app/features/chat/screens/chats_screen.dart';
import 'package:lurk_app/features/chat/widgets/chat_error.dart';
import 'package:lurk_app/models/player_profile.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/chat_provider.dart';
import 'package:lurk_app/providers/profile_provider.dart';
import 'package:lurk_app/services/chat_service.dart';
import 'package:lurk_app/features/parties/models/party.dart';
import 'package:lurk_app/features/player/models/player.dart';
import 'package:lurk_app/features/chat/models/chat_settings.dart';

Widget _optionsApp(_ChatService service) => ProviderScope(
  overrides: [
    authStateProvider.overrideWith((ref) => Stream.value(_User())),
    blockedPlayersProvider.overrideWith((ref) => Stream.value(<String>{})),

    chatServiceProvider.overrideWithValue(service),

    chatSettingsProvider.overrideWith(
      (ref, id) => Stream.value(const ChatSettings()),
    ),
    chatPlayerProvider.overrideWith((ref, uid) => Stream.value(null)),
    playerProfileProvider.overrideWith((ref, uid) => Stream.value(null)),
    messagesProvider.overrideWith(
      (ref, key) => Stream.value(const [
        ChatMessage(id: '1', senderId: 'alice', text: 'Hello teammate'),
        ChatMessage(id: '2', senderId: 'bob', text: 'Ranked tonight'),
      ]),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.dark,
    home: const ChatScreen(chatId: 'chat', otherUid: 'bob'),
  ),
);

class _User extends Fake implements User {
  @override
  String get uid => 'alice';
}

class _ChatService extends Fake implements ChatService {
  bool fail = true;
  final sent = <String>[];
  int clears = 0;
  @override
  Future<void> clearHistory(String chatId, String uid) async {
    clears++;
  }

  @override
  Future<void> sendMessage(String chatId, String uid, String text) async {
    if (fail) throw StateError('offline');
    sent.add(text);
  }
}

void main() {
  testWidgets('search fits a narrow phone with its keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(_optionsApp(_ChatService()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search messages'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('options search messages and confirm per-user clear', (
    tester,
  ) async {
    final service = _ChatService();
    await tester.pumpWidget(_optionsApp(service));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search messages'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'ranked');
    await tester.pumpAndSettle();
    expect(find.text('Hello teammate'), findsNothing);
    expect(find.text('Ranked tonight'), findsOneWidget);
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear chat history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear for me'));
    await tester.pumpAndSettle();
    expect(service.clears, 1);
    await tester.tap(find.byTooltip('Chat options'));
    await tester.pumpAndSettle();
    expect(find.text('Search messages'), findsOneWidget);
    expect(find.text('Clear chat history'), findsOneWidget);
    expect(find.text('Block player'), findsNothing);
    expect(find.text('Report player'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('setup and permission errors are not described as network errors', () {
    expect(
      chatSendErrorDescription(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      contains('permission'),
    );
    expect(
      chatErrorDescription(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
        ),
      ),
      contains('setup'),
    );
    expect(
      chatErrorDescription(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      contains('access'),
    );
    expect(
      chatErrorDescription(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ),
      contains('connection'),
    );
  });
  test('direct IDs are symmetric and do not confuse UID boundaries', () {
    expect(ChatService.directId('a', 'bc'), ChatService.directId('bc', 'a'));
    expect(
      ChatService.directId('a', 'bc'),
      isNot(ChatService.directId('ab', 'c')),
    );
  });

  testWidgets(
    'inbox searches names and fits a narrow screen with 24px padding',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(_User())),
            blockedPlayersProvider.overrideWith(
              (ref) => Stream.value(<String>{}),
            ),

            chatSettingsProvider.overrideWith(
              (ref, id) => Stream.value(const ChatSettings()),
            ),
            chatsProvider.overrideWith(
              (ref) => Stream.value([
                const Chat(
                  id: 'chat',
                  userIds: ['alice', 'bob'],
                  preview: 'Want to play?',
                  lastSenderId: 'bob',
                ),
              ]),
            ),
            playerProfileProvider.overrideWith(
              (ref, uid) => Stream.value(
                PlayerProfile(
                  uid: uid,
                  username: 'Bob',
                  bio: '',
                  region: '',
                  createdAt: null,
                  updatedAt: null,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: ChatsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bob'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byTooltip('New message'),
          matching: find.byIcon(Icons.add),
        ),
        findsOneWidget,
      );
      expect(tester.getTopLeft(find.byType(TextField)).dx, 24);
      await tester.enterText(find.byType(TextField), 'nobody');
      await tester.pump();
      expect(find.byIcon(Icons.search_off), findsOneWidget);
      expect(find.text('Bob'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed send preserves draft; successful retry clears it', (
    tester,
  ) async {
    final service = _ChatService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(_User())),
          blockedPlayersProvider.overrideWith(
            (ref) => Stream.value(<String>{}),
          ),

          chatSettingsProvider.overrideWith(
            (ref, id) => Stream.value(const ChatSettings()),
          ),
          chatServiceProvider.overrideWithValue(service),
          chatPlayerProvider.overrideWith((ref, uid) => Stream.value(null)),
          playerProfileProvider.overrideWith((ref, uid) => Stream.value(null)),
          messagesProvider.overrideWith(
            (ref, key) => Stream.value(<ChatMessage>[]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const ChatScreen(chatId: 'chat', otherUid: 'bob'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hello Bob 😀');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Hello Bob 😀',
    );
    service.fail = false;
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(service.sent, ['Hello Bob 😀']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'chat shows context and received invite details without an invite action',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _ChatService();
      const party = Party(
        id: 'party1',
        hostId: 'alice',
        title: 'Ranked tonight',
        gameName: 'Valorant',
        playStyle: 'Ranked',
        currentPlayers: 3,
        maxPlayers: 5,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(_User())),
            blockedPlayersProvider.overrideWith(
              (ref) => Stream.value(<String>{}),
            ),

            chatSettingsProvider.overrideWith(
              (ref, id) => Stream.value(const ChatSettings()),
            ),
            chatServiceProvider.overrideWithValue(service),
            chatPlayerProvider.overrideWith(
              (ref, uid) => Stream.value(
                const Player(
                  id: 'bob',
                  name: 'Bob',
                  isActive: true,
                  currentGame: 'Valorant',
                  rank: 3,
                  rating: 4.8,
                ),
              ),
            ),
            playerProfileProvider.overrideWith(
              (ref, uid) => Stream.value(
                const PlayerProfile(
                  uid: 'bob',
                  username: 'Bob',
                  bio: '',
                  region: '',
                  createdAt: null,
                  updatedAt: null,
                ),
              ),
            ),
            chatPartyProvider.overrideWith((ref, id) => Stream.value(party)),
            messagesProvider.overrideWith(
              (ref, key) => Stream.value([
                ChatMessage(
                  id: 'invite',
                  senderId: 'bob',
                  text: 'Party invitation',
                  type: 'party_invite',
                  partyId: 'party1',
                  createdAt: DateTime.now(),
                ),
                ChatMessage(
                  id: 'text',
                  senderId: 'alice',
                  text: 'Ready for ranked?',
                  createdAt: DateTime.now(),
                ),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const ChatScreen(chatId: 'chat', otherUid: 'bob'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Status unavailable'), findsNothing);
      expect(find.text('Valorant · Rank 3 · 4.8 rating'), findsOneWidget);
      expect(find.textContaining('TODAY ·'), findsOneWidget);
      expect(find.text('PARTY INVITE'), findsOneWidget);
      await tester.tap(find.text('View party'));
      await tester.pumpAndSettle();
      expect(find.text('Ranked tonight'), findsOneWidget);
      expect(find.text('3 / 5 players'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Invite to party'), findsNothing);
      expect(find.byIcon(Icons.group_add_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
