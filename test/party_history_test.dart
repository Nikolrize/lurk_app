import 'package:lurk_app/providers/profile_provider.dart';
import 'package:lurk_app/models/player_profile.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/core/theme/app_theme.dart';
import 'package:lurk_app/features/parties/models/party.dart';
import 'package:lurk_app/features/parties/models/party_history_entry.dart';
import 'package:lurk_app/features/parties/screens/party_history_screen.dart';
import 'package:lurk_app/providers/party_history_provider.dart';
import 'package:lurk_app/providers/party_provider.dart';

void main() {
  test('History duration handles missing and invalid timestamps honestly', () {
    final start = DateTime.utc(2026, 10, 31, 10);
    final record = PartyHistoryRecord(
      partyId: 'a',
      title: 'Session',
      gameId: 'valorant',
      mode: 'competitive',
      joinedAt: start,
    );
    expect(
      PartyHistoryEntry(
        record: record,
        endedAt: start.add(const Duration(hours: 2, minutes: 15)),
      ).duration,
      const Duration(hours: 2, minutes: 15),
    );
    expect(
      PartyHistoryEntry(
        record: record,
        endedAt: start.subtract(const Duration(seconds: 1)),
      ).duration,
      isNull,
    );
    expect(PartyHistoryEntry(record: record, endedAt: null).duration, isNull);
    final party = Party.fromFirestoreData('old', {
      'status': 'closed',
      'updatedAt': Timestamp.fromDate(start),
    });
    expect(party.completedAt?.toUtc(), start);
  });

  testWidgets(
    'History loads real participation, excludes active parties and filters on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final start = DateTime.utc(2026, 10, 31, 10);
      final records = [
        PartyHistoryRecord(
          partyId: 'v',
          title: 'Ranked squad',
          gameId: 'valorant',
          mode: 'competitive',
          joinedAt: start,
        ),
        PartyHistoryRecord(
          partyId: 'm',
          title: 'Evening MLBB',
          gameId: 'mobile_legends',
          mode: 'casual',
          joinedAt: start,
        ),
        PartyHistoryRecord(
          partyId: 'active',
          title: 'Still playing',
          gameId: 'valorant',
          mode: 'competitive',
          joinedAt: start,
        ),
      ];
      final stream = StreamController<List<PartyHistoryRecord>>();
      addTearDown(stream.close);
      var backs = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            partyHistoryMemberIdsProvider.overrideWith(
              (ref, id) => Stream.value(['host', 'former']),
            ),
            playerProfileProvider.overrideWith(
              (ref, uid) => Stream.value(
                PlayerProfile(
                  uid: uid,
                  username: uid == 'former' ? 'Former member' : 'Host',
                  bio: '',
                  region: 'Asia',
                  createdAt: null,
                  updatedAt: null,
                ),
              ),
            ),
            partyHistoryProvider.overrideWith((ref) => stream.stream),
            myPartyMembershipProvider.overrideWith(
              (ref, id) => Stream.value({
                'leftAt': id == 'v'
                    ? Timestamp.fromDate(
                        start.add(const Duration(hours: 2, minutes: 15)),
                      )
                    : null,
              }),
            ),
            partyByIdProvider.overrideWith(
              (ref, id) => Stream.value(
                Party(
                  id: id,
                  title: id == 'm'
                      ? 'Evening MLBB'
                      : id == 'v'
                      ? 'Ranked squad'
                      : 'Still playing',
                  gameName: 'Game',
                  gameId: id == 'm' ? 'mobile_legends' : 'valorant',
                  mode: 'casual',
                  playStyle: 'Casual',
                  currentPlayers: 0,
                  maxPlayers: 5,
                  status: id == 'active' ? 'open' : 'closed',
                  completedAt: start.add(const Duration(hours: 3)),
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(body: PartyHistoryScreen(onBack: () => backs++)),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      stream.add(records);
      await tester.pumpAndSettle();
      expect(find.text('Ranked squad'), findsOneWidget);
      expect(find.text('Evening MLBB'), findsOneWidget);
      expect(find.text('Still playing'), findsNothing);
      expect(find.textContaining('2h 15m'), findsOneWidget);
      for (final rate in tester.widgetList<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Rate'),
      )) {
        expect(rate.onPressed, isNull);
      }
      await tester.tap(find.widgetWithText(ChoiceChip, 'Valorant'));
      await tester.pumpAndSettle();
      expect(find.text('Evening MLBB'), findsNothing);
      expect(find.text('Ranked squad'), findsOneWidget);
      await tester.ensureVisible(find.text('View details'));
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('Join Party'), findsNothing);
      expect(find.text('2 players participated'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Former member'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Former member'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to Parties'));
      expect(backs, 1);
      stream.add([]);
      await tester.pumpAndSettle();
      expect(find.text('No sessions for this game'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
