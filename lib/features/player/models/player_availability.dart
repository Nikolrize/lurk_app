// Times are minutes after midnight in the same local timezone.
// Weekdays use DateTime's convention: Monday = 1, Sunday = 7.
class WeeklyGamingSlot {
  const WeeklyGamingSlot({
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
  });
  final int weekday, startMinute, endMinute;


    Map<String, dynamic> toMap() {
    return {
      'weekday': weekday,
      'startMinute': startMinute,
      'endMinute': endMinute,

      // how it works weekday: 1, startMinute: 1200, endMinute: 1320 = Monday 8 - 10 pm
    };
  }

  bool overlaps(WeeklyGamingSlot other) {
    final start = (weekday - 1) * 1440 + startMinute;
    final end =
        (weekday - 1) * 1440 +
        endMinute +
        (endMinute <= startMinute ? 1440 : 0);
    final otherStart = (other.weekday - 1) * 1440 + other.startMinute;
    final otherEnd =
        (other.weekday - 1) * 1440 +
        other.endMinute +
        (other.endMinute <= other.startMinute ? 1440 : 0);
    for (final shift in [-10080, 0, 10080]) {
      if (start < otherEnd + shift && end > otherStart + shift) return true;
    }
    return false;
  }
}

class PlayerAvailability {
  const PlayerAvailability({
    this.availableNow = false,
    this.preferredTimes = const {},
    this.weeklySchedule = const [],
  });
  static const gamingTimes = ['Morning', 'Afternoon', 'Evening', 'Night'];
  static const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final bool availableNow;
  final Set<String> preferredTimes;
  // Only enabled days are included in this list.
  final List<WeeklyGamingSlot> weeklySchedule;

  //read saved availability
  factory PlayerAvailability.fromMap(Map<String, dynamic> data) {
    final rawPeriods = data['preferredTimes'] as List? ?? [];
    final rawSchedule = data['weeklySchedule'] as List? ?? [];

    final periods = <String>{};

    for (final value in rawPeriods.whereType<String>()) {
      for (final period in gamingTimes) {
        if (period.toLowerCase() == value.toLowerCase()) {
          periods.add(period);
        }
      }
    }

    final slots = <WeeklyGamingSlot>[];

    for (final entry in rawSchedule) {
      final slot = Map<String, dynamic>.from(entry as Map);

      if (slot['enabled'] == false) continue;

      slots.add(
        WeeklyGamingSlot(
          weekday: slot['weekday'] as int,
          startMinute: slot['startMinute'] as int,
          endMinute: slot['endMinute'] as int,
        ),
      );
    }

    return PlayerAvailability(
      availableNow: data['availableNow'] as bool? ?? false,
      preferredTimes: Set<String>.unmodifiable(periods),
      weeklySchedule: List<WeeklyGamingSlot>.unmodifiable(slots),
    );
  }

  void validate() {
    if (preferredTimes.length > gamingTimes.length ||
        preferredTimes.any(
          (period) => !gamingTimes.contains(period),
        )) {
      throw ArgumentError('Please select valid gaming periods.');
    }

    if (weeklySchedule.length > 7) {
      throw ArgumentError('Choose at most one time slot per day.');
    }

    final usedDays = <int>{}; //creates a set of weekday numbers

    for (final slot in weeklySchedule) {
      if (slot.weekday < 1 || slot.weekday > 7) {
        throw ArgumentError('Invalid schedule day.');
      }

      if (!usedDays.add(slot.weekday)) { //detects a duplicate
        throw ArgumentError('Choose only one time slot per day.');
      }

      if (slot.startMinute < 0 ||
          slot.startMinute >= 1440 ||
          slot.endMinute < 0 ||
          slot.endMinute > 1440 ||
          slot.startMinute == slot.endMinute) {
        throw ArgumentError('Choose valid start and end times.');
      }
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'availableNow': availableNow,
      'preferredTimes': preferredTimes.toList()..sort(),
      'weeklySchedule': [
        for (final slot in weeklySchedule) slot.toMap(),
      ],
      'timeZone': 'Asia/Kuala_Lumpur',
    };
  }
}
