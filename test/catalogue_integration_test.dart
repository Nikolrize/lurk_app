import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/core/data/game_catalog.dart';
import 'package:lurk_app/core/data/gaming_regions.dart';
import 'package:lurk_app/features/home/widgets/home_games.dart';
import 'package:lurk_app/features/parties/models/party_draft.dart';
import 'package:lurk_app/features/parties/screens/create_party_screen.dart';
import 'package:lurk_app/models/gaming_preferences.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/profile_provider.dart';

PartyDraft draft(String game, int? min, int? max) => PartyDraft(
  title: 'Squad',
  gameId: game,
  maxPlayers: 5,
  region: 'asia',
  mode: 'competitive',
  visibility: 'public',
  minimumRating: 0,
  playstyles: {'chill'},
  communication: 'mic_required',
  minRank: min,
  maxRank: max,
);
void main() {
  test(
    'Party and player validation follow catalogue ranks and shared regions',
    () {
      expect(PartyDraft.games.keys, GameCatalog.games.keys);
      expect(PartyDraft.regions.values, GamingRegions.values);
      expect(() => draft('valorant', 8, 8).validate(), returnsNormally);
      expect(() => draft('mobile_legends', 0, 9).validate(), returnsNormally);
      expect(() => draft('fortnite', null, null).validate(), returnsNormally);
      expect(() => draft('valorant', 0, 9).validate(), throwsArgumentError);
      expect(
        () => draft('mobile_legends', 0, 10).validate(),
        throwsArgumentError,
      );
      expect(() => draft('fortnite', 0, 1).validate(), throwsArgumentError);
      expect(
        () => const GamingPreferences(
          games: ['mobile_legends'],
          currentGame: 'mobile_legends',
          rank: 9,
        ).validate(),
        returnsNormally,
      );
      expect(
        () => const GamingPreferences(
          games: ['valorant'],
          currentGame: 'valorant',
          rank: 8,
        ).validate(),
        returnsNormally,
      );
    },
  );
  testWidgets('Home shows only saved games and opens preference editing', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gamingPreferencesProvider('viewer').overrideWith(
            (ref) => Stream.value(
              const GamingPreferences(
                games: ['mobile_legends'],
                currentGame: 'mobile_legends',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HomeGames(
              uid: 'viewer',
              onFindGame: (game) => selected = game,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mobile Legends'), findsOneWidget);
    expect(find.text('Valorant'), findsNothing);
    expect(find.text('Fortnite'), findsNothing);
    await tester.tap(find.byTooltip('Find Mobile Legends parties'));
    expect(selected, 'mobile_legends');
    await tester.tap(find.bySemanticsLabel('Edit gaming preferences'));
    await tester.pumpAndSettle();
    expect(find.text('Gaming Preferences'), findsOneWidget);
  });
  testWidgets(
    'Changing game resets rank range and hides it for unranked games',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(home: CreatePartyScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Valorant'));
      await tester.tap(find.text('Valorant'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobile Legends').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Warrior — Mythical Immortal'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Warrior — Mythical Immortal'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, 1200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mobile Legends'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fortnite').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('This game has no rank requirements.'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.byType(RangeSlider), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
