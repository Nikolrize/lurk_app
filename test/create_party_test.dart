import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/parties/models/party_draft.dart';
import 'package:lurk_app/features/parties/screens/create_party_screen.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/party_provider.dart';
import 'package:lurk_app/services/party_service.dart';

class TestUser extends Fake implements User {
  @override
  String get uid => 'host-uid';
}

class TestPartyService extends Fake implements PartyService {
  final result = Completer<String>();
  PartyDraft? captured;
  int calls = 0;
  String? uid;
  @override
  Future<String> createParty(PartyDraft draft, {required String expectedUid}) {
    calls++;
    captured = draft;
    uid = expectedUid;
    return result.future;
  }
}

PartyDraft draft({
  String title = ' Late Night Ranked ',
  int size = 5,
  Set<String> styles = const {'chill', 'fun'},
  int? min = 2,
  int? max = 5,
}) => PartyDraft(
  title: title,
  gameId: 'valorant',
  maxPlayers: size,
  region: 'asia',
  mode: 'competitive',
  visibility: 'public',
  minimumRating: 4,
  playstyles: styles,
  communication: 'mic_required',
  minRank: min,
  maxRank: max,
);

void main() {
  test(
    'Draft validates and serializes canonical fields without trusted host metadata',
    () {
      final data = draft().toFirestoreFields();
      expect(data['title'], 'Late Night Ranked');
      expect(data['region'], 'asia');
      expect(data['playstyles'], ['chill', 'fun']);
      expect(data.containsKey('hostId'), isFalse);
      expect(data.containsKey('memberCount'), isFalse);
      for (final invalid in [
        draft(title: ' '),
        draft(size: 1),
        draft(size: 11),
        draft(styles: {}),
        draft(styles: {'invalid'}),
        draft(min: 5, max: 2),
      ]) {
        expect(invalid.validate, throwsArgumentError);
      }
    },
  );
  testWidgets(
    'Create form fits phone, validates and submits once before returning',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = TestPartyService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(TestUser())),
            partyServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => openCreateParty(context),
                  child: const Text('Open form'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open form'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create Party'));
      await tester.pump();
      expect(find.text('Enter a party name.'), findsOneWidget);
      expect(service.calls, 0);
      await tester.enterText(find.byType(TextFormField).first, 'Friday squad');
      await tester.scrollUntilVisible(
        find.text('Fun'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Fun'));
      await tester.tap(find.widgetWithText(FilledButton, 'Create Party'));
      await tester.pump();
      expect(service.calls, 1);
      expect(service.uid, 'host-uid');
      expect(service.captured?.playstyles, {'chill', 'fun'});
      expect(service.captured?.title, 'Friday squad');
      expect(find.text('Creating…'), findsOneWidget);
      service.result.complete('new-party');
      await tester.pumpAndSettle();
      expect(find.text('Open form'), findsOneWidget);
      expect(find.text('Party created. You are the host.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Creation errors retain entered name and enable retry', (
    tester,
  ) async {
    final service = TestPartyService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(TestUser())),
          partyServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: CreatePartyScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Keep this name');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Party'));
    await tester.pump();
    service.result.completeError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await tester.pump();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.textContaining('Unable to create the party'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('Unable to create the party'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 1500));
    await tester.pumpAndSettle();
    expect(find.text('Keep this name'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create Party'),
          )
          .onPressed,
      isNotNull,
    );
  });
}
