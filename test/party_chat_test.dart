import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/chat/models/chat_message.dart';
import 'package:lurk_app/features/chat/screens/party_chat_screen.dart';
import 'package:lurk_app/features/parties/models/party.dart';
import 'package:lurk_app/features/parties/models/lobby_member.dart';
import 'package:lurk_app/features/parties/widgets/lobby_member_card.dart';
import 'package:lurk_app/features/profile/screens/player_profile_screen.dart';
import 'package:lurk_app/models/player_profile.dart';
import 'package:lurk_app/models/gaming_preferences.dart';
import 'package:lurk_app/features/player/models/player_availability.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/rating_provider.dart';
import 'package:lurk_app/features/ratings/models/teammate_rating.dart';
import 'package:lurk_app/providers/party_chat_provider.dart';
import 'package:lurk_app/providers/party_provider.dart';
import 'package:lurk_app/providers/profile_provider.dart';
import 'package:lurk_app/services/party_chat_service.dart';
import 'package:lurk_app/services/player_safety_service.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'alice';
}

class _Service extends Fake implements PartyChatService {
  bool fail = false;
  final sent = <String>[];
  @override
  Future<void> send(String id, String uid, String text) async {
    if (fail) throw StateError('offline');
    sent.add(text);
  }
}

Widget _app(_Service service, {Stream<Map<String, dynamic>?>? membership}) =>
    ProviderScope(
      overrides: [
        ratingSummaryProvider.overrideWith(
          (ref, uid) => Stream.value(const RatingSummary()),
        ),
        authStateProvider.overrideWith((ref) => Stream.value(_User())),
        partyChatServiceProvider.overrideWithValue(service),
        partyByIdProvider.overrideWith(
          (ref, id) => Stream.value(
            const Party(
              id: 'squad',
              title: 'Our squad',
              hostId: 'alice',
              gameName: 'Valorant',
              playStyle: '',
              currentPlayers: 3,
              maxPlayers: 5,
            ),
          ),
        ),
        myPartyMembershipProvider.overrideWith(
          (ref, id) => membership ?? Stream.value({'leftAt': null}),
        ),
        blockedPlayersProvider.overrideWith((ref) => Stream.value({'blocked'})),
        partyMessagesProvider.overrideWith(
          (ref, key) => Stream.value(const [
            ChatMessage(id: 'one', senderId: 'bob', text: 'Hello squad'),
            ChatMessage(id: 'two', senderId: 'blocked', text: 'Hidden message'),
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
        gamingPreferencesProvider.overrideWith(
          (ref, uid) => Stream.value(const GamingPreferences()),
        ),
        playerAvailabilityProvider.overrideWith(
          (ref, uid) => Stream.value(const PlayerAvailability()),
        ),
      ],
      child: const MaterialApp(home: PartyChatScreen(partyId: 'squad')),
    );

void main() {
  testWidgets('wireframe composer fits a narrow phone with the keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(_app(_Service()));
    await tester.pumpAndSettle();
    expect(find.text('Type a message...'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ready to play');
    await tester.pump();
    expect(
      tester.getBottomRight(find.byTooltip('Send party message')).dy,
      lessThanOrEqualTo(380),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'party chat hides blocked messages and avatar opens report/block profile',
    (tester) async {
      await tester.pumpWidget(_app(_Service()));
      await tester.pumpAndSettle();
      expect(find.text('Hello squad'), findsOneWidget);
      expect(find.text('Our squad’s Chat'), findsOneWidget);
      expect(
        find.text('This chat is only available to this party session.'),
        findsOneWidget,
      );
      expect(tester.getTopLeft(find.text('Hello squad')).dy, lessThan(300));
      expect(find.text('Hidden message'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('party-chat-avatar-bob')));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerProfileScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Report'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Block'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed party send keeps draft; retry sends; removal disables composer',
    (tester) async {
      final membership = StreamController<Map<String, dynamic>?>();
      addTearDown(membership.close);
      final service = _Service()..fail = true;
      await tester.pumpWidget(_app(service, membership: membership.stream));
      membership.add({'leftAt': null});
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Ready?');
      await tester.tap(find.byTooltip('Send party message'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Ready?',
      );
      service.fail = false;
      await tester.tap(find.byTooltip('Send party message'));
      await tester.pumpAndSettle();
      expect(service.sent, ['Ready?']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      membership.add({'leftAt': DateTime.now()});
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
      expect(find.text('Hello squad'), findsNothing);
    },
  );
  testWidgets('lobby avatar invokes existing profile action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LobbyMemberCard(
            member: const LobbyMember(uid: 'bob', name: 'Bob'),
            onViewProfile: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CircleAvatar));
    expect(tapped, true);
  });
}
