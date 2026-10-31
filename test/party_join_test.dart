import 'package:lurk_app/features/parties/widgets/party_card.dart';
import 'package:lurk_app/models/gaming_preferences.dart';
import 'package:lurk_app/features/profile/screens/player_profile_screen.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/parties/actions/join_party.dart';
import 'package:lurk_app/features/parties/models/party.dart';
import 'package:lurk_app/features/parties/screens/party_lobby_screen.dart';
import 'package:lurk_app/models/player_profile.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/party_provider.dart';
import 'package:lurk_app/providers/profile_provider.dart';
import 'package:lurk_app/services/party_service.dart';

class JoinUser extends Fake implements User {
  @override
  String get uid => 'bob';
}

class JoinService extends Fake implements PartyService {
  final result = Completer<void>();
  int calls = 0;
  String? switchedFrom;
  @override
  Future<void> joinParty(
    String id, {
    required String expectedUid,
    String? switchFromPartyId,
  }) {
    switchedFrom = switchFromPartyId;
    calls++;
    return result.future;
  }
}

const squad = Party(
  id: 'squad',
  hostId: 'alice',
  gameId: 'valorant',
  title: 'Squad',
  gameName: 'Valorant',
  playStyle: 'Competitive',
  currentPlayers: 1,
  maxPlayers: 5,
);
Widget app(JoinService service, {String? currentPartyId}) => ProviderScope(
  overrides: [
    authStateProvider.overrideWith((ref) => Stream.value(JoinUser())),
    joinedPartyIdProvider.overrideWith((ref) => Stream.value(currentPartyId)),
    myPartyMembershipProvider.overrideWith(
      (ref, id) => Stream.value({'role': 'member', 'leftAt': null}),
    ),
    partyByIdProvider('old').overrideWith(
      (ref) => Stream.value(
        const Party(
          id: 'old',
          hostId: 'other',
          title: 'Old squad',
          gameName: 'Valorant',
          playStyle: 'Chill',
          currentPlayers: 2,
          maxPlayers: 5,
        ),
      ),
    ),
    gamingPreferencesProvider.overrideWith(
      (ref, uid) => Stream.value(const GamingPreferences()),
    ),
    partyServiceProvider.overrideWithValue(service),
    partyByIdProvider('squad').overrideWith((ref) => Stream.value(squad)),
    partyMemberIdsProvider(
      'squad',
    ).overrideWith((ref) => Stream.value(['alice'])),
    playerProfileProvider.overrideWith(
      (ref, uid) => Stream.value(
        PlayerProfile(
          uid: uid,
          username: 'Nicole',
          bio: '',
          region: 'Asia',
          createdAt: null,
          updatedAt: null,
        ),
      ),
    ),
  ],
  child: MaterialApp(
    home: Scaffold(
      body: Consumer(
        builder: (context, ref, child) {
          final opened = ref.watch(lobbyNavigationProvider);
          return Column(
            children: [
              const PartyJoinButton(party: squad),
              if (opened != null) Text('Opened ${opened.party.id}'),
            ],
          );
        },
      ),
    ),
  ),
);
void main() {
  testWidgets('Current squad Join is disabled for members', (tester) async {
    final service = JoinService();
    await tester.pumpWidget(app(service, currentPartyId: 'squad'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(service.calls, 0);
  });
  testWidgets(
    'Switch requires confirmation and cancel keeps the current squad',
    (tester) async {
      final service = JoinService();
      await tester.pumpWidget(app(service, currentPartyId: 'old'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join Party'));
      await tester.pumpAndSettle();
      expect(find.text('Switch parties?'), findsOneWidget);
      expect(service.calls, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.calls, 0);
      await tester.tap(find.text('Join Party'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch Party'));
      await tester.pump();
      expect(service.calls, 1);
      expect(service.switchedFrom, 'old');
      service.result.complete();
      await tester.pumpAndSettle();
      expect(find.text('Opened squad'), findsOneWidget);
    },
  );
  testWidgets('Joining submits once and requests the party lobby', (
    tester,
  ) async {
    final service = JoinService();
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    expect(service.calls, 0);
    expect(find.text('Nicole'), findsOneWidget);
    await tester.ensureVisible(find.text('Nicole'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nicole'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerProfileScreen), findsOneWidget);
    expect(service.calls, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join Party'));
    await tester.pump();
    expect(find.text('Joining…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNull,
    );
    expect(service.calls, 1);
    service.result.complete();
    await tester.pumpAndSettle();
    expect(find.text('Opened squad'), findsOneWidget);
  });
  testWidgets('Failed join stays on screen with a useful error and retry', (
    tester,
  ) async {
    final service = JoinService();
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    expect(service.calls, 0);
    expect(find.text('Nicole'), findsOneWidget);
    await tester.tap(find.text('Join Party'));
    await tester.pump();
    service.result.completeError(StateError('This party is full.'));
    await tester.pumpAndSettle();
    expect(find.text('This party is full.'), findsOneWidget);
    expect(find.text('Opened squad'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNotNull,
    );
  });
  testWidgets('Lobby roster receives live membership and profile updates', (
    tester,
  ) async {
    final roster = StreamController<List<String>>();
    addTearDown(roster.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          partyByIdProvider('squad').overrideWith((ref) => Stream.value(squad)),
          partyMemberIdsProvider('squad').overrideWith((ref) => roster.stream),
          playerProfileProvider.overrideWith(
            (ref, uid) => Stream.value(
              PlayerProfile(
                uid: uid,
                username: uid == 'alice' ? 'Nicole' : 'Jay',
                bio: '',
                region: 'Asia',
                createdAt: null,
                updatedAt: null,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PartyLobbyScreen(
              party: squad,
              viewerUid: 'alice',
              onBack: () {},
            ),
          ),
        ),
      ),
    );
    roster.add(['alice', 'bob']);
    await tester.pumpAndSettle();
    expect(find.text('Nicole'), findsOneWidget);
    expect(find.text('Jay'), findsOneWidget);
    roster.add(['alice']);
    await tester.pumpAndSettle();
    expect(find.text('Jay'), findsNothing);
    expect(find.byTooltip('Party host'), findsOneWidget);
  });

  testWidgets('Host cannot press Join on their own party card', (tester) async {
    final service = JoinService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(JoinUser())),
          joinedPartyIdProvider.overrideWith((ref) => Stream.value(null)),
          partyServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PartyCard(
              party: Party(
                id: 'own',
                hostId: 'bob',
                title: 'My squad',
                gameName: 'Valorant',
                playStyle: 'Competitive',
                currentPlayers: 1,
                maxPlayers: 5,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Join'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(service.calls, 0);
  });
}
