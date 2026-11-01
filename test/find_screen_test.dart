import 'package:lurk_app/features/player/models/player.dart';
import 'package:lurk_app/providers/discovery_limits.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/features/parties/models/party.dart';
import 'package:lurk_app/providers/player_provider.dart';
import 'fixtures/players.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lurk_app/providers/party_provider.dart';
import 'fixtures/parties.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/core/theme/app_theme.dart';
import 'package:lurk_app/features/find/screens/find_screen.dart';

void main() {
  for (final total in [0, 99, 100, 101]) {
    testWidgets(
      'Player footer appears only with more than 100 players: $total',
      (tester) async {
        final players = List.generate(
          total,
          (i) => Player(id: 'u$i', name: 'Player $i', isActive: false),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(null)),
              availablePartiesProvider.overrideWith((ref) => Stream.value([])),
              playerDiscoveryPageProvider.overrideWith((ref) {
                final limit = ref.watch(playerDiscoveryLimitProvider);
                return Stream.value(players.take(limit + 1).toList());
              }),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const Scaffold(body: FindSreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Player'));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(FindSreen)),
        );
        expect(container.read(hasMorePlayersProvider), total > 100);
        expect(
          container.read(discoverablePlayersProvider).asData!.value.length,
          total > 100 ? 100 : total,
        );
        expect(find.text('Load more players'), findsNothing);
        if (total > 100) {
          await tester.scrollUntilVisible(
            find.text('Load more players'),
            1500,
            maxScrolls: 100,
            scrollable: find.byType(Scrollable).last,
          );
          expect(
            find.descendant(
              of: find.byType(ListView),
              matching: find.text('Load more players'),
            ),
            findsOneWidget,
          );
          await tester.tap(find.text('Load more players'));
          await tester.pumpAndSettle();
          expect(
            container.read(discoverablePlayersProvider).asData!.value.length,
            101,
          );
          expect(container.read(hasMorePlayersProvider), isFalse);
          expect(find.text('Load more players'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final total in [0, 99, 100, 101]) {
    testWidgets(
      'Party footer appears only with more than 100 parties: $total',
      (tester) async {
        final parties = List.generate(
          total,
          (i) => Party(
            id: 'p$i',
            title: 'Party $i',
            gameName: 'Valorant',
            playStyle: 'Casual',
            currentPlayers: 1,
            maxPlayers: 5,
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(null)),
              discoverablePlayersProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              partyDiscoveryPageProvider.overrideWith((ref) {
                final limit = ref.watch(partyDiscoveryLimitProvider);
                return Stream.value(parties.take(limit + 1).toList());
              }),
            ],
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const Scaffold(body: FindSreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(FindSreen));
        final container = ProviderScope.containerOf(context);
        expect(container.read(hasMorePartiesProvider), total > 100);
        expect(
          container.read(availablePartiesProvider).asData!.value.length,
          total > 100 ? 100 : total,
        );
        if (total <= 100) {
          expect(find.text('Load more parties'), findsNothing);
        } else {
          // The button is a scrollable footer, rather than above the results.
          expect(find.text('Load more parties'), findsNothing);
          await tester.scrollUntilVisible(
            find.text('Load more parties'),
            1500,
            maxScrolls: 100,
            scrollable: find.byType(Scrollable).last,
          );
          expect(
            find.descendant(
              of: find.byType(ListView),
              matching: find.text('Load more parties'),
            ),
            findsOneWidget,
          );
          await tester.tap(find.text('Load more parties'));
          await tester.pumpAndSettle();
          expect(
            container.read(availablePartiesProvider).asData!.value.length,
            101,
          );
          expect(container.read(hasMorePartiesProvider), isFalse);
          expect(find.text('Load more parties'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Find switches lists, searches and filters players', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoverablePlayersProvider.overrideWith(
            (ref) => Stream.value(testPlayers),
          ),
          availablePartiesProvider.overrideWith(
            (ref) => Stream.value(testParties),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: FindSreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Late Night Ranked'), findsOneWidget);
    expect(find.text('Jay'), findsNothing);
    await tester.enterText(find.byType(TextField), 'no-match');
    await tester.pump();
    expect(find.text('0 parties found'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    await tester.tap(find.text('Player'));
    await tester.pumpAndSettle();
    expect(find.text('Jay'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Late Night Ranked'), findsNothing);
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Evening'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Evening'));
    await tester.tap(find.text('Show Results'));
    await tester.pumpAndSettle();
    expect(find.text('Jay'), findsOneWidget);
    expect(find.text('Alex'), findsNothing);
    expect(find.text('1 players found'), findsOneWidget);
    await tester.tap(find.text('Party'));
    await tester.pumpAndSettle();
    expect(find.text('3 parties found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
