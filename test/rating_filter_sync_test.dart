import 'package:lurk_app/features/find/screens/filter_preferences_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/find/screens/find_screen.dart';
import 'package:lurk_app/features/find/models/filter_preferences.dart';
import 'package:lurk_app/features/player/models/player.dart';
import 'package:lurk_app/features/ratings/models/teammate_rating.dart';
import 'package:lurk_app/providers/party_provider.dart';
import 'package:lurk_app/providers/player_provider.dart';
import 'package:lurk_app/providers/rating_provider.dart';

void main() {
  testWidgets('Filter restores game IDs using catalogue labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FilterPreferencesScreen(
          initial: FilterPreferences(game: 'valorant'),
          games: ['Valorant'],
          forPlayers: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Valorant'), findsWidgets);
    expect(find.text('valorant'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test(
    'Player game and rank filters use the saved rank for each selected game',
    () {
      final player = Player.fromFirestoreData('bob', {
        'username': 'Bob',
        'currentGame': 'valorant',
        'games': ['valorant', 'mobile_legends'],
        'rank': 5,
        'gameRanks': {'valorant': 'diamond', 'mobile_legends': 'epic'},
      });
      const filters = FilterPreferences(
        game: 'Mobile Legends',
        minRank: 4,
        maxRank: 4,
      );
      expect(player.rankForGame('mobile_legends'), 4);
      expect(player.rankForGame('valorant'), 5);
      expect(player.rankForGame('fortnite'), isNull);
      expect(
        filters.matches(
          gameName: player.currentGame,
          games: player.games,
          regionName: null,
          gameMode: null,
          rank: player.rankForGame(filters.game),
          style: null,
          comms: null,
          rating: null,
          hasAvailability: false,
        ),
        true,
      );
    },
  );
  testWidgets(
    'Player rating filter uses live reviews rather than a stale profile rating',
    (tester) async {
      final ratings = StreamController<RatingSummary>();
      addTearDown(ratings.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoverablePlayersProvider.overrideWith(
              (ref) => Stream.value([
                Player.fromFirestoreData('bob', {
                  'username': 'Bob',
                  'rating': 1.0,
                }),
              ]),
            ),
            availablePartiesProvider.overrideWith((ref) => Stream.value([])),
            ratingSummaryProvider('bob').overrideWith((ref) => ratings.stream),
          ],
          child: const MaterialApp(home: Scaffold(body: FindSreen())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Player'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<double>),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byType(DropdownButtonFormField<double>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4.0 and above').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show Results'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      ratings.add(const RatingSummary(total: 9, count: 2));
      await tester.pumpAndSettle();
      expect(find.text('Bob'), findsOneWidget);
      ratings.add(const RatingSummary(total: 6, count: 2));
      await tester.pumpAndSettle();
      expect(find.text('Bob'), findsNothing);
      ratings.add(const RatingSummary());
      await tester.pumpAndSettle();
      expect(find.text('Bob'), findsNothing);
      ratings.addError(StateError('Reviews unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to load players. Please try again.'),
        findsOneWidget,
      );
      ratings.add(const RatingSummary(total: 10, count: 2));
      await tester.pumpAndSettle();
      expect(find.text('Bob'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
