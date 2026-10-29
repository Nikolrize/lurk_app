import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/find/models/filter_preferences.dart';
import 'package:lurk_app/features/player/models/player_availability.dart';

bool matches(
  FilterPreferences filters,
  PlayerAvailability availability, {
  bool active = false,
}) {
  return filters.matches(
    gameName: null,
    regionName: null,
    gameMode: null,
    rank: null,
    style: null,
    comms: null,
    rating: null,
    playerAvailability: availability,
    hasAvailability: active,
  );
}

void main() {
  test('Available now is independent of online status', () {
    const filters = FilterPreferences(availableNowOnly: true);
    expect(matches(filters, const PlayerAvailability(), active: true), isFalse);
    expect(
      matches(filters, const PlayerAvailability(availableNow: true)),
      isTrue,
    );
  });
  test('Preferred periods use any selected period and combine with status', () {
    const filters = FilterPreferences(
      availableNowOnly: true,
      preferredTimes: {'Evening', 'Night'},
    );
    expect(
      matches(
        filters,
        const PlayerAvailability(availableNow: true, preferredTimes: {'Night'}),
      ),
      isTrue,
    );
    expect(
      matches(
        filters,
        const PlayerAvailability(
          availableNow: true,
          preferredTimes: {'Morning'},
        ),
      ),
      isFalse,
    );
    expect(
      matches(filters, const PlayerAvailability(preferredTimes: {'Evening'})),
      isFalse,
    );
    expect(
      matches(const FilterPreferences(), const PlayerAvailability()),
      isTrue,
    );
  });
  test('Weekly filtering matches overlap, not adjacent or disabled days', () {
    const filters = FilterPreferences(
      scheduleWindow: WeeklyGamingSlot(
        weekday: 1,
        startMinute: 1080,
        endMinute: 1380,
      ),
    );
    expect(
      matches(
        filters,
        const PlayerAvailability(
          weeklySchedule: [
            WeeklyGamingSlot(weekday: 1, startMinute: 1200, endMinute: 1440),
          ],
        ),
      ),
      isTrue,
    );
    expect(
      matches(
        filters,
        const PlayerAvailability(
          weeklySchedule: [
            WeeklyGamingSlot(weekday: 1, startMinute: 900, endMinute: 1080),
          ],
        ),
      ),
      isFalse,
    );
    expect(matches(filters, const PlayerAvailability()), isFalse);
  });
  test(
    'Overnight schedule overlaps the next day including Sunday to Monday',
    () {
      const lateSunday = WeeklyGamingSlot(
        weekday: 7,
        startMinute: 1320,
        endMinute: 120,
      );
      expect(
        lateSunday.overlaps(
          const WeeklyGamingSlot(weekday: 1, startMinute: 60, endMinute: 180),
        ),
        isTrue,
      );
      expect(
        lateSunday.overlaps(
          const WeeklyGamingSlot(weekday: 2, startMinute: 60, endMinute: 180),
        ),
        isFalse,
      );
    },
  );
}
