import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lurk_app/providers/party_matching_provider.dart';
import 'package:lurk_app/providers/party_provider.dart';
import 'package:lurk_app/providers/profile_provider.dart';
import 'package:lurk_app/providers/rating_provider.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/discovery_limits.dart';
import 'package:lurk_app/providers/verification_provider.dart';
import 'package:lurk_app/services/player_safety_service.dart';
import 'package:lurk_app/models/player_profile.dart';
import 'package:lurk_app/features/ratings/models/teammate_rating.dart';
import 'package:lurk_app/features/parties/widgets/party_history_card.dart';
import 'package:lurk_app/features/parties/widgets/lobby_member_card.dart';
import 'package:lurk_app/features/parties/models/party_history_entry.dart';
import 'package:lurk_app/features/parties/models/lobby_member.dart';
import 'package:lurk_app/features/verification/models/verification_summary.dart';
import 'package:lurk_app/features/verification/models/verification_status.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/parties/models/party.dart';
import 'package:lurk_app/features/parties/models/party_matching.dart';
import 'package:lurk_app/features/parties/models/quick_match.dart';
import 'package:lurk_app/models/gaming_preferences.dart';
import 'package:lurk_app/providers/party_history_provider.dart';

Party party(String id, {double rating = 0, int? min, int? max}) => Party(
  id: id,
  hostId: 'host',
  title: id,
  gameId: 'valorant',
  gameName: 'Valorant',
  region: 'Asia',
  playStyle: 'Competitive',
  currentPlayers: 1,
  maxPlayers: 5,
  minimumRating: rating,
  minRank: min,
  maxRank: max,
);

class MatchUser extends Fake implements User {
  @override
  String get uid => 'viewer';
}

void main() {
  testWidgets(
    'recommendations prefer saved main game and hide blocked or ineligible parties',
    (tester) async {
      final sources = [
        party('eligible'),
        party('rated-too-high', rating: 5),
        const Party(
          id: 'wrong-region',
          hostId: 'host',
          title: 'Wrong region',
          gameId: 'valorant',
          gameName: 'Valorant',
          region: 'Europe',
          playStyle: 'Competitive',
          currentPlayers: 1,
          maxPlayers: 5,
        ),
        const Party(
          id: 'blocked',
          hostId: 'blocked-host',
          title: 'Blocked',
          gameId: 'valorant',
          gameName: 'Valorant',
          region: 'Asia',
          playStyle: 'Competitive',
          currentPlayers: 1,
          maxPlayers: 5,
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(MatchUser())),
            availablePartiesProvider.overrideWith(
              (ref) => Stream.value(sources),
            ),
            currentPartyProvider.overrideWith((ref) => const AsyncData(null)),
            playerProfileProvider.overrideWith(
              (ref, uid) => Stream.value(
                PlayerProfile(
                  uid: uid,
                  username: 'Viewer',
                  bio: '',
                  region: 'Asia',
                  createdAt: null,
                  updatedAt: null,
                ),
              ),
            ),
            gamingPreferencesProvider.overrideWith(
              (ref, uid) => Stream.value(
                const GamingPreferences(
                  games: ['valorant'],
                  currentGame: 'valorant',
                ),
              ),
            ),
            ratingSummaryProvider.overrideWith(
              (ref, uid) =>
                  Stream.value(const RatingSummary(total: 8, count: 2)),
            ),
            blockedPlayersProvider.overrideWith(
              (ref) => Stream.value(<String>{}),
            ),
            hostBlocksViewerProvider.overrideWith(
              (ref, host) => Stream.value(host == 'blocked-host'),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                final parties =
                    ref.watch(recommendedPartiesProvider).asData?.value ?? [];
                return Text(parties.map((p) => p.id).join(','));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('eligible'), findsOneWidget);
      expect(find.textContaining('rated-too-high'), findsNothing);
      expect(find.textContaining('blocked'), findsNothing);
    },
  );
  test(
    'discovery and history limits expand instead of silently stopping at the first page',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(partyDiscoveryLimitProvider.notifier).loadMore();
      container.read(playerDiscoveryLimitProvider.notifier).loadMore();
      container.read(historyLimitProvider.notifier).loadMore();
      expect(container.read(partyDiscoveryLimitProvider), 200);
      expect(container.read(playerDiscoveryLimitProvider), 200);
      expect(container.read(historyLimitProvider), 100);
    },
  );
  testWidgets(
    'history shows Rated and lobby uses the real verification summary',
    (tester) async {
      final start = DateTime.utc(2026);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ratingCandidatesProvider.overrideWith(
              (ref, id) async => [const RatingCandidate('bob', rated: true)],
            ),
            verificationSummaryProvider.overrideWith(
              (ref, uid) => Stream.value(
                VerificationSummary(
                  uid: uid,
                  status: VerificationStatus.verified,
                  updatedAt: null,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  PartyHistoryCard(
                    entry: PartyHistoryEntry(
                      record: PartyHistoryRecord(
                        partyId: 'p',
                        title: 'Party',
                        gameId: 'valorant',
                        mode: 'casual',
                        joinedAt: start,
                      ),
                      endedAt: start.add(const Duration(hours: 1)),
                    ),
                    onRate: () {},
                  ),
                  LobbyMemberCard(
                    member: const LobbyMember(uid: 'bob', name: 'Bob'),
                    onViewProfile: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rated'), findsOneWidget);
      expect(find.byTooltip('ID submission approved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  const prefs = GamingPreferences(
    games: ['valorant'],
    currentGame: 'valorant',
    gameRanks: {'valorant': 'gold'},
  );
  test(
    'match eligibility uses exact ratings, game ranks, region and blocks',
    () {
      final p = party('ranked', rating: 4, min: 2, max: 4);
      expect(
        meetsMatchRequirements(
          p,
          region: 'asia',
          preferences: prefs,
          rating: 4,
        ),
        isTrue,
      );
      expect(
        meetsMatchRequirements(
          p,
          region: 'Asia',
          preferences: prefs,
          rating: 3.99,
        ),
        isFalse,
      );
      expect(
        meetsMatchRequirements(
          p,
          region: 'Europe',
          preferences: prefs,
          rating: 5,
        ),
        isFalse,
      );
      expect(
        meetsMatchRequirements(
          p,
          region: 'Asia',
          preferences: prefs,
          rating: 5,
          blockedHosts: {'host'},
        ),
        isFalse,
      );
      expect(
        meetsMatchRequirements(
          p,
          region: 'Asia',
          preferences: const GamingPreferences(),
          rating: 5,
        ),
        isFalse,
      );
      expect(
        meetsMatchRequirements(
          party('any', min: 0, max: 8),
          region: 'Asia',
          preferences: const GamingPreferences(),
        ),
        isTrue,
      );
    },
  );
  test(
    'Quick Match skips parties below rating eligibility instead of suggesting a failed join',
    () {
      final match = pickQuickMatchParty(
        [party('too-high', rating: 5), party('eligible', rating: 4)],
        mainGameId: 'valorant',
        regionId: 'asia',
        viewerUid: 'viewer',
        preferences: prefs,
        rating: 4,
      );
      expect(match?.id, 'eligible');
    },
  );
  test('history adds visits and excludes time spent away', () {
    Timestamp t(int minutes) =>
        Timestamp.fromDate(DateTime.utc(2026).add(Duration(minutes: minutes)));
    expect(
      participationDuration(
        {'joinedAt': t(90)},
        [
          {'joinedAt': t(0), 'leftAt': t(30)},
          {'joinedAt': t(45), 'leftAt': t(60)},
        ],
        t(120).toDate(),
      ),
      const Duration(minutes: 75),
    );
  });
}
