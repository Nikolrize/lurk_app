import 'package:lurk_app/providers/player_provider.dart';
import 'package:lurk_app/features/player/models/player.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/find/screens/find_screen.dart';
import 'package:lurk_app/features/parties/models/party.dart';
import 'package:lurk_app/providers/party_provider.dart';

void main() {
  test(
    'Reads the manually created Firestore party without optional fields',
    () {
      final party = Party.fromFirestoreData('real-doc', {
        'title': 'Late Night Ranked',
        'hostId': 'host',
        'gameId': 'valorant',
        'region': 'asia',
        'mode': 'competitive',
        'visibility': 'public',
        'maxPlayers': 5,
        'memberCount': 1,
        'status': 'open',
      });
      expect(party.id, 'real-doc');
      expect(party.gameName, 'Valorant');
      expect(party.mode, 'Competitive');
      expect(party.region, 'Asia');
      expect(party.currentPlayers, 1);
      expect(party.createdAt, isNull);
      expect(party.isFull, isFalse);
    },
  );
  test('Reads full rank ranges, multi-playstyles and timestamps', () {
    final party = Party.fromFirestoreData('full', {
      'playstyles': ['chill', 'fun'],
      'minRank': 2,
      'maxRank': 5,
      'communication': 'mic_required',
      'minimumRating': 4,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
    });
    expect(party.playstyles, ['Chill', 'Fun']);
    expect(party.communication, 'Mic required');
    expect(party.minRank, 2);
    expect(party.maxRank, 5);
    expect(party.minimumRating, 4);
    expect(
      party.rating,
      isNull,
    ); // An admission requirement is not an earned rating.
    expect(party.createdAt?.millisecondsSinceEpoch, 1000);
  });
  testWidgets('Discovery shows loading, empty, live updates and errors', (
    tester,
  ) async {
    final stream = StreamController<List<Party>>();
    addTearDown(stream.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoverablePlayersProvider.overrideWith(
            (ref) => Stream.value(const <Player>[]),
          ),
          availablePartiesProvider.overrideWith((ref) => stream.stream),
        ],
        child: const MaterialApp(home: Scaffold(body: FindSreen())),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    stream.add([]);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('0 parties found'), findsOneWidget);
    stream.add([
      Party.fromFirestoreData('new', {'title': 'Live party'}),
    ]);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Live party'), findsOneWidget);
    stream.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('Party access is not enabled'), findsOneWidget);
    expect(find.text('Live party'), findsNothing);
  });
}
