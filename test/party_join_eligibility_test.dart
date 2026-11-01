import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/parties/models/party_join_eligibility.dart';
import 'package:lurk_app/features/parties/actions/join_party.dart';

void main() {
  test(
    'Android transaction errors preserve the known rejection instead of showing a generic failure',
    () async {
      final rejection = PartyJoinRejection();
      await expectLater(
        rejection.run(() async {
          try {
            rejection.reject('This party is full.');
          } catch (_) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unknown',
              message: 'Native transaction failure',
            );
          }
        }),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'reason',
            'This party is full.',
          ),
        ),
      );
    },
  );
  test(
    'network failures are not misreported as eligibility failures',
    () async {
      final rejection = PartyJoinRejection();
      final network = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await expectLater(
        rejection.run(() async {
          throw network;
        }),
        throwsA(same(network)),
      );
      try {
        rejection.reject('Old retry reason');
      } catch (_) {}
      rejection.reset();
      await expectLater(
        rejection.run(() async {
          throw network;
        }),
        throwsA(same(network)),
      );
    },
  );
  const party = <String, dynamic>{
    'gameId': 'valorant',
    'region': 'asia',
    'minRank': 2,
    'maxRank': 5,
    'minimumRating': 4,
  };
  const profile = <String, dynamic>{
    'region': 'Asia',
    'gameRanks': {'valorant': 'gold'},
  };
  const summary = <String, dynamic>{'total': 8, 'count': 2};
  String? reason({
    Map<String, dynamic>? player = profile,
    Map<String, dynamic> requirements = party,
    Map<String, dynamic>? rating = summary,
  }) => partyRequirementMessage(
    party: requirements,
    profile: player,
    ratingSummary: rating,
  );
  test('region rejection explains the required and saved regions', () {
    expect(
      reason(player: {...profile, 'region': 'Europe'}),
      'This party requires region Asia. Your profile region is Europe.',
    );
    expect(
      reason(player: {...profile, 'region': ''}),
      contains('Set your region in Profile'),
    );
    expect(reason(player: null), contains('Complete your player profile'));
  });
  test('missing game rank explains where to set it and the required range', () {
    expect(
      reason(player: {...profile, 'gameRanks': {}}),
      'Set your Valorant rank in Gaming Preferences. This party requires Silver–Diamond.',
    );
  });
  test('out-of-range ranks include the saved rank and the party range', () {
    expect(
      reason(
        player: {
          ...profile,
          'gameRanks': {'valorant': 'bronze'},
        },
      ),
      'This party requires Valorant rank Silver–Diamond. Your rank is Bronze.',
    );
    expect(
      reason(
        player: {
          ...profile,
          'gameRanks': {'valorant': 'radiant'},
        },
      ),
      contains('Your rank is Radiant'),
    );
  });
  test('rating messages distinguish unrated from below-threshold players', () {
    expect(
      reason(rating: null),
      contains('You haven’t received any ratings yet'),
    );
    expect(
      reason(rating: {'total': 7, 'count': 2}),
      contains('4.0+ player rating. Your current rating is below'),
    );
    expect(reason(rating: {'total': 7.999, 'count': 2}), isNotNull);
    expect(reason(), isNull);
  });
  test(
    'full rank range accepts unranked players and unrestricted rating needs no reviews',
    () {
      expect(
        reason(
          player: {...profile, 'gameRanks': {}},
          requirements: {
            ...party,
            'minRank': 0,
            'maxRank': 8,
            'minimumRating': 0,
          },
          rating: null,
        ),
        isNull,
      );
    },
  );
  test('technical failures remain distinct from eligibility rejections', () {
    expect(
      partyJoinErrorMessage(StateError('This party is full.')),
      'This party is full.',
    );
    expect(
      partyJoinErrorMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ),
      contains('Check your connection'),
    );
    expect(
      partyJoinErrorMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'unauthenticated'),
      ),
      contains('Sign in again'),
    );
    expect(
      partyJoinErrorMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
      ),
      'This party no longer exists.',
    );
    expect(
      partyJoinErrorMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      contains('Refresh its details'),
    );
  });
}
