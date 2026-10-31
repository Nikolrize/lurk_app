import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/chat/widgets/chat_widgets.dart';
import 'package:lurk_app/features/player/models/player.dart';
import 'package:lurk_app/models/player_profile.dart';
import 'package:lurk_app/providers/profile_provider.dart';
import 'package:lurk_app/services/profile_image_service.dart';

class _Images extends Fake implements ProfileImageService {
  @override
  String publicUrl(String path) =>
      'https://images.example.test/profile-images/$path';
}

PlayerProfile _profile(String? path) => PlayerProfile(
  uid: 'bob',
  username: 'Bob',
  bio: '',
  region: '',
  createdAt: null,
  updatedAt: null,
  photoPath: path,
);

void main() {
  test('discovered players retain their saved public photo path', () {
    expect(
      Player.fromFirestoreData('bob', {
        'photoPath': 'bob/avatar.jpg',
      }).photoPath,
      'bob/avatar.jpg',
    );
    for (final value in [null, '', '  ', 42]) {
      expect(
        Player.fromFirestoreData('bob', {'photoPath': value}).photoPath,
        isNull,
      );
    }
  });

  testWidgets(
    'chat avatar follows profile photo additions, replacements and removal',
    (tester) async {
      final profiles = StreamController<PlayerProfile?>();
      addTearDown(profiles.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProfileProvider('bob').overrideWith((ref) => profiles.stream),
            profileImageServiceProvider.overrideWithValue(_Images()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatAvatar(name: 'Bob', uid: 'bob'),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.text('B'), findsNothing);
      for (final path in ['bob/first.jpg', 'bob/second.png']) {
        profiles.add(_profile(path));
        await tester.pump();
        await tester.pump();
        final image = tester.widget<Image>(find.byType(Image));
        expect(
          (image.image as NetworkImage).url,
          'https://images.example.test/profile-images/$path',
        );
      }
      profiles.add(_profile(null));
      await tester.pump();
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.text('B'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unavailable profile and failed photo keep the avatar fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProfileProvider(
            'missing',
          ).overrideWith((ref) => Stream.error(StateError('unavailable'))),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ChatAvatar(name: 'Bob', uid: 'missing'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.text('B'), findsNothing);
    expect(tester.takeException(), isNull);

    // Flutter's test HTTP client returns 400: this verifies the image error fallback.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileImageServiceProvider.overrideWithValue(_Images())],
        child: const MaterialApp(
          home: Scaffold(
            body: ChatAvatar(
              name: 'Bob',
              photoPath: 'bob/missing.jpg',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.text('B'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
