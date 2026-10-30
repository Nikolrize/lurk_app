//testing the rank filter
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/find/models/filter_preferences.dart';

bool matchesPlayer(
  FilterPreferences filters, {
  required String game,
  int? rank,
}) {
  return filters.matches(
    gameName: game,
    regionName: null,
    gameMode: null,
    rank: rank,
    style: null,
    comms: null,
    rating: null,
    hasAvailability: false,
  );
}

void main() {
  test('Each game supplies its own rank labels', () {
    expect(
      FilterPreferences.ranksForGame('Valorant').last,
      'Radiant',
    );

    expect(
      FilterPreferences.ranksForGame('Mobile Legends').first,
      'Warrior',
    );

    expect(
      FilterPreferences.ranksForGame('Fortnite'),
      isEmpty,
    );

    expect(
      FilterPreferences.ranksForGame(null),
      isEmpty,
    );
  });

  test('Rank filtering applies only within the selected game', () {
    const filters = FilterPreferences(
      game: 'Mobile Legends',
      minRank: 3,
      maxRank: 5,
    );

    expect(
      matchesPlayer(filters, game: 'Mobile Legends', rank: 4),
      isTrue,
    );

    expect(
      matchesPlayer(filters, game: 'Mobile Legends', rank: 2),
      isFalse,
    );

    expect(
      matchesPlayer(filters, game: 'Valorant', rank: 4),
      isFalse,
    );

    expect(
      matchesPlayer(filters, game: 'Mobile Legends'),
      isFalse,
    );
  });

  test('Full rank range does not exclude unspecified ranks', () {
    const filters = FilterPreferences(
      game: 'Valorant',
      minRank: 0,
      maxRank: 8,
    );

    expect(filters.hasRankFilter, isFalse);

    expect(
      matchesPlayer(filters, game: 'Valorant'),
      isTrue,
    );
  });

  test('Fortnite ignores rank restrictions', () {
    const filters = FilterPreferences(
      game: 'Fortnite',
      minRank: 3,
      maxRank: 5,
    );

    expect(filters.hasRankFilter, isFalse);

    expect(
      matchesPlayer(filters, game: 'Fortnite'),
      isTrue,
    );
  });

  test('Party rank ranges match by overlap', () {
    const filters = FilterPreferences(
      game: 'Mobile Legends',
      minRank: 3,
      maxRank: 5,
    );

    bool matchesParty(int minimum, int maximum) {
      return filters.matches(
        gameName: 'Mobile Legends',
        regionName: null,
        gameMode: null,
        rank: null,
        minAllowedRank: minimum,
        maxAllowedRank: maximum,
        style: null,
        comms: null,
        rating: null,
        hasAvailability: true,
      );
    }

    expect(matchesParty(4, 6), isTrue);
    expect(matchesParty(6, 9), isFalse);
  });
}