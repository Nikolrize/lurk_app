// Times are minutes after midnight in the same local timezone.
// Weekdays use DateTime's convention: Monday = 1, Sunday = 7.
class WeeklyGamingSlot {
  const WeeklyGamingSlot({
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
  });
  final int weekday, startMinute, endMinute;

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
}
