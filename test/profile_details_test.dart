import 'package:flutter_test/flutter_test.dart';

import 'package:lurk_app/models/player_profile.dart';

void main() {
  test('Age calculation handles birthdays correctly', () {
    final birthday = DateTime.utc(2000, 10, 30);

    expect(calculateAge(birthday, DateTime.utc(2026, 10, 29)), 25);

    expect(calculateAge(birthday, DateTime.utc(2026, 10, 30)), 26);
  });

  test('Sharing is disabled by default for existing profiles', () {
    const profile = PlayerProfile(
      uid: 'test-user',
      username: 'PlayerOne',
      bio: '',
      region: 'Malaysia',
      createdAt: null,
      updatedAt: null,
    );

    expect(profile.sharedAge, isNull);
    expect(profile.ageSharedAt, isNull);
    expect(profile.sharedGender, isNull);
  });
}
