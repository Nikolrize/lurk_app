import 'package:lurk_app/models/player_profile.dart';
import 'package:lurk_app/core/data/gaming_regions.dart';
import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/parties/models/party.dart';
import 'package:lurk_app/features/parties/models/quick_match.dart';
import 'package:lurk_app/features/parties/widgets/quick_match_card.dart';
import 'package:lurk_app/models/gaming_preferences.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/party_provider.dart';
import 'package:lurk_app/providers/profile_provider.dart';
import 'package:lurk_app/services/party_service.dart';

Party candidate(
  String id, {
  String game = 'valorant',
  String host = 'host',
  String region = 'Asia',
  String status = 'open',
  String visibility = 'public',
  int size = 1,
}) => Party(
  id: id,
  title: id,
  gameId: game,
  gameName: game,
  playStyle: 'Competitive',
  hostId: host,
  region: region,
  currentPlayers: size,
  maxPlayers: 5,
  status: status,
  visibility: visibility,
);

class QuickUser extends Fake implements User {
  @override
  String get uid => 'viewer';
}

class QuickService extends Fake implements PartyService {
  final response = Completer<List<Party>>();
  int calls = 0;
  String? game, matchedRegion;
  @override
  Future<List<Party>> findQuickMatchParties(
    String gameId, {
    required String regionId,
  }) {
    calls++;
    game = gameId;
    matchedRegion = regionId;
    return response.future;
  }
}

Widget app(
  QuickService service, {
  String? game = 'valorant',
  String region = 'Asia',
}) => ProviderScope(
  overrides: [
    authStateProvider.overrideWith((ref) => Stream.value(QuickUser())),
    gamingPreferencesProvider(
      'viewer',
    ).overrideWith((ref) => Stream.value(GamingPreferences(currentGame: game))),
    playerProfileProvider('viewer').overrideWith(
      (ref) => Stream.value(
        PlayerProfile(
          uid: 'viewer',
          username: 'Viewer',
          bio: '',
          region: region,
          createdAt: null,
          updatedAt: null,
        ),
      ),
    ),
    joinedPartyIdProvider.overrideWith((ref) => Stream.value('current')),
    partyServiceProvider.overrideWithValue(service),
    partyByIdProvider.overrideWith((ref, id) => Stream.value(candidate(id))),
    partyMemberIdsProvider.overrideWith((ref, id) => Stream.value([])),
  ],
  child: const MaterialApp(home: Scaffold(body: QuickMatchCard())),
);

void main() {
  test('Profile labels and database region IDs normalize consistently', () {
    expect(GamingRegions.idFor(' North America '), 'north_america');
    expect(GamingRegions.idFor('north_america'), 'north_america');
    expect(GamingRegions.idFor('Malaysia'), isNull);
  });
  testWidgets('Missing region prevents an unfiltered match', (tester) async {
    final service = QuickService();
    await tester.pumpWidget(app(service, region: ''));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick Match'));
    await tester.pumpAndSettle();
    expect(
      find.text('Set your region in your profile before using Quick Match.'),
      findsOneWidget,
    );
    expect(service.calls, 0);
  });
  test(
    'Random pool excludes current, hosted, full, closed, private and other games',
    () {
      final parties = [
        candidate('one'),
        candidate('two'),
        candidate('current'),
        candidate('mine', host: 'viewer'),
        candidate('full', size: 5),
        candidate('closed', status: 'closed'),
        candidate('private', visibility: 'private'),
        candidate('other', game: 'fortnite'),
        candidate('other-region', region: 'Europe'),
      ];
      final picks = <String>{};
      for (var seed = 0; seed < 30; seed++) {
        picks.add(
          pickQuickMatchParty(
            parties,
            mainGameId: 'valorant',
            regionId: 'asia',
            viewerUid: 'viewer',
            currentPartyId: 'current',
            random: Random(seed),
          )!.id,
        );
      }
      expect(picks, {'one', 'two'});
      expect(
        pickQuickMatchParty(
          parties.skip(2),
          mainGameId: 'valorant',
          regionId: 'asia',
          viewerUid: 'viewer',
          currentPartyId: 'current',
        ),
        isNull,
      );
    },
  );
  testWidgets(
    'Quick Match queries saved main game once and previews before joining',
    (tester) async {
      final service = QuickService();
      await tester.pumpWidget(app(service));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quick Match'));
      await tester.pump();
      await tester.tap(find.text('Finding party…'));
      expect(service.calls, 1);
      expect(service.game, 'valorant');
      expect(service.matchedRegion, 'asia');
      service.response.complete([candidate('Selected squad')]);
      await tester.pumpAndSettle();
      expect(find.text('Selected squad'), findsOneWidget);
      expect(find.text('Join Party'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Quick Match'), findsOneWidget);
    },
  );
  testWidgets('Missing main game prompts setup without querying parties', (
    tester,
  ) async {
    final service = QuickService();
    await tester.pumpWidget(app(service, game: null));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick Match'));
    await tester.pumpAndSettle();
    expect(
      find.text('Choose your main game for matchmaking first.'),
      findsOneWidget,
    );
    expect(find.text('Set main game'), findsOneWidget);
    expect(service.calls, 0);
  });
  testWidgets('Empty matching pool explains that no parties are available', (
    tester,
  ) async {
    final service = QuickService();
    service.response.complete([]);
    await tester.pumpWidget(app(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick Match'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No open Valorant parties with space'),
      findsOneWidget,
    );
    expect(find.text('Join Party'), findsNothing);
  });
}
