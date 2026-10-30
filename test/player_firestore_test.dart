import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/find/screens/find_screen.dart';
import 'package:lurk_app/features/player/models/player.dart';
import 'package:lurk_app/features/player/widgets/player_card.dart';
import 'package:lurk_app/providers/party_provider.dart';
import 'package:lurk_app/providers/player_provider.dart';

void main() {
  test(
    'Existing public schema reads username without inventing presence or game',
    () {
      final player = Player.fromFirestoreData('uid', {
        'username': 'Yessir',
        'bio': 'I love gaming',
        'region': 'Malaysia',
        'createdAt': Timestamp.now(),
        'sharedAge': null,
      });
      expect(player.id, 'uid');
      expect(player.name, 'Yessir');
      expect(player.region, 'Malaysia');
      expect(player.currentGame, isNull);
      expect(player.isActive, isNull);
      expect(player.rating, isNull);
      expect(player.availability.availableNow, isFalse);
      expect(player.availability.weeklySchedule, isEmpty);
      expect(Player.fromFirestoreData('new', {'username': '  '}).name, isEmpty);
    },
  );
  test(
    'Optional public game and availability map safely with disabled days excluded',
    () {
      final player = Player.fromFirestoreData('uid', {
        'username': 'Jay',
        'currentGame': 'valorant',
        'isActive': true,
        'playstyles': ['chill', 'fun'],
        'availability': {
          'availableNow': true,
          'preferredTimes': ['evening', 'night', 'invalid'],
          'weeklySchedule': [
            {'weekday': 1, 'startMinute': 1080, 'endMinute': 1380},
            {
              'weekday': 2,
              'startMinute': 1080,
              'endMinute': 1380,
              'enabled': false,
            },
            {'weekday': 8, 'startMinute': 0, 'endMinute': 60},
          ],
        },
      });
      expect(player.currentGame, 'Valorant');
      expect(player.playstyles, ['Chill', 'Fun']);
      expect(player.availability.preferredTimes, {'Evening', 'Night'});
      expect(player.availability.weeklySchedule.length, 1);
      expect(player.availability.weeklySchedule.single.weekday, 1);
      expect(player.availability.availableNow, isTrue);
    },
  );
  testWidgets('Missing status is displayed as unknown, not offline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerCard(
            player: Player.fromFirestoreData('uid', {'username': 'Yessir'}),
          ),
        ),
      ),
    );
    expect(find.text('Status unavailable'), findsNothing);
    expect(find.text('Offline'), findsNothing);
    expect(find.textContaining('Playing'), findsNothing);
  });
  testWidgets(
    'Player tab handles loading, empty, real updates, errors and region values',
    (tester) async {
      final stream = StreamController<List<Player>>();
      addTearDown(stream.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availablePartiesProvider.overrideWith((ref) => Stream.value([])),
            discoverablePlayersProvider.overrideWith((ref) => stream.stream),
          ],
          child: const MaterialApp(home: Scaffold(body: FindSreen())),
        ),
      );
      await tester.tap(find.text('Player'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      stream.add([]);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('0 players found'), findsOneWidget);
      stream.add([
        Player.fromFirestoreData('uid', {
          'username': 'Yessir',
          'region': 'Malaysia',
        }),
      ]);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Yessir'), findsOneWidget);
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Any region'));
      await tester.pumpAndSettle();
      expect(find.text('Malaysia').last, findsOneWidget);
      await tester.tap(find.text('Malaysia').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show Results'));
      await tester.pumpAndSettle();
      expect(find.text('Yessir'), findsOneWidget);
      stream.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Unable to access player profiles'),
        findsOneWidget,
      );
      expect(find.text('Yessir'), findsNothing);
    },
  );
}
