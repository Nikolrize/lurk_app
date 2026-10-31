import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/ratings/models/teammate_rating.dart';
import 'package:lurk_app/features/ratings/screens/rate_party_teammates_screen.dart';
import 'package:lurk_app/features/ratings/widgets/player_rating_summary.dart';
import 'package:lurk_app/models/player_profile.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/profile_provider.dart';
import 'package:lurk_app/providers/rating_provider.dart';
import 'package:lurk_app/services/rating_service.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'alice';
}

class _Ratings extends Fake implements RatingService {
  bool rated = false, fail = false;
  int submits = 0;
  RatingDraft? saved;
  @override
  Future<List<RatingCandidate>> loadCandidates(
    String party,
    String uid,
  ) async => [RatingCandidate('bob', rated: rated)];
  @override
  Future<void> submit(
    String party,
    String uid,
    String target,
    RatingDraft draft,
  ) async {
    draft.validate();
    submits++;
    if (fail) throw StateError('Please retry your review.');
    saved = draft;
    rated = true;
  }
}

Widget _app(_Ratings service) => ProviderScope(
  overrides: [
    authStateProvider.overrideWith((ref) => Stream.value(_User())),
    ratingServiceProvider.overrideWithValue(service),
    playerProfileProvider.overrideWith(
      (ref, uid) => Stream.value(
        PlayerProfile(
          uid: uid,
          username: 'Bob',
          bio: '',
          region: '',
          createdAt: null,
          updatedAt: null,
        ),
      ),
    ),
  ],
  child: const MaterialApp(
    home: RatePartyTeammatesScreen(
      partyId: 'squad',
      partyTitle: 'Ranked squad',
    ),
  ),
);

void main() {
  test('rating validation rejects malformed scores, tags and comments', () {
    for (final draft in [
      const RatingDraft(stars: 0),
      const RatingDraft(stars: 6),
      const RatingDraft(stars: 3, tags: ['fake']),
      const RatingDraft(stars: 3, tags: ['Friendly', 'Friendly']),
      RatingDraft(stars: 3, comment: 'x' * 501),
    ]) {
      expect(draft.validate, throwsArgumentError);
    }
    expect(
      () => const RatingDraft(stars: 5, tags: ['Friendly']).validate(),
      returnsNormally,
    );
  });
  test('membership must overlap and rater participation must have ended', () {
    final start = Timestamp.fromMillisecondsSinceEpoch(1000),
        end = Timestamp.fromMillisecondsSinceEpoch(3000);
    final own = {'joinedAt': start, 'leftAt': end};
    final peer = {
      'joinedAt': Timestamp.fromMillisecondsSinceEpoch(2000),
      'leftAt': null,
    };
    final party = {'status': 'open', 'updatedAt': end};
    final now = DateTime.fromMillisecondsSinceEpoch(5000);
    expect(RatingService.overlaps(own, peer, party, now), true);
    expect(
      RatingService.overlaps(
        {'joinedAt': start, 'leftAt': null},
        peer,
        party,
        now,
      ),
      false,
    );
    expect(
      RatingService.overlaps(
        own,
        {'joinedAt': end, 'leftAt': null},
        party,
        now,
      ),
      false,
    );
    expect(RatingService.overlaps(own, {}, party, now), false);
    expect(
      RatingService.overlaps(
        {'joinedAt': start, 'leftAt': null},
        peer,
        {'status': 'closed', 'completedAt': end},
        now,
      ),
      true,
    );
  });
  testWidgets(
    'teammate form submits stars, tags and optional comment then shows Rated',
    (tester) async {
      final service = _Ratings();
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rate'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('4 stars'));
      await tester.tap(find.text('Friendly'));
      await tester.enterText(find.byType(TextField), 'Great teammate');
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(service.saved!.stars, 4);
      expect(service.saved!.tags, ['Friendly']);
      expect(service.saved!.comment, 'Great teammate');
      expect(service.submits, 1);
      expect(find.text('Rated'), findsOneWidget);
      expect(find.text('Rate'), findsNothing);
    },
  );
  testWidgets(
    'rating form fits narrow phone with keyboard; failure retains input',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final service = _Ratings()..fail = true;
      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rate'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('5 stars'));
      await tester.tap(find.byTooltip('5 stars'));
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Keep my comment');
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Keep my comment',
      );
      expect(find.text('Please retry your review.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('profile rating average displays score and review count', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ratingSummaryProvider.overrideWith(
            (ref, uid) => Stream.value(const RatingSummary(total: 9, count: 2)),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PlayerRatingSummary(uid: 'bob')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('4.5 (2 reviews)'), findsOneWidget);
  });
}
