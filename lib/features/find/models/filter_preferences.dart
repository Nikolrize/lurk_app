import '../../player/models/player_availability.dart';

class FilterPreferences {
  const FilterPreferences({
    this.game,
    this.region,
    this.mode,
    this.minRank = 0,
    this.maxRank = 7,
    this.playstyles = const {},
    this.communication,
    this.minimumRating = 0,
    this.availableNowOnly = false,
    this.preferredTimes = const {},
    this.scheduleWindow,
    this.maxPartySize,
    this.onlyAvailable = false,
  });
  static const ranks = [
    'Iron',
    'Bronze',
    'Silver',
    'Gold',
    'Platinum',
    'Diamond',
    'Ascendant',
    'Immortal',
  ];
  final String? game, region, mode, communication;
  final Set<String> playstyles;
  final bool availableNowOnly;
  final Set<String> preferredTimes;
  final WeeklyGamingSlot? scheduleWindow;
  final int minRank, maxRank;
  final int? maxPartySize;
  final double minimumRating;
  final bool onlyAvailable;
  int get count => [
    game != null,
    region != null,
    mode != null,
    minRank != 0 || maxRank != 7,
    playstyles.isNotEmpty,
    communication != null,
    minimumRating > 0,
    availableNowOnly,
    preferredTimes.isNotEmpty,
    scheduleWindow != null,
    maxPartySize != null,
    onlyAvailable,
  ].where((v) => v).length;

  bool matches({
    required String? gameName,
    required String? regionName,
    required String? gameMode,
    required int? rank,
    required String? style,
    required String? comms,
    required double? rating,
    PlayerAvailability? playerAvailability,
    required bool hasAvailability,
    int? partySize,
  }) {
    return (game == null || game == gameName) &&
        (region == null || region == regionName) &&
        (mode == null || mode == gameMode) &&
        ((minRank == 0 && maxRank == 7) ||
            (rank != null && rank >= minRank && rank <= maxRank)) &&
        (playstyles.isEmpty || playstyles.contains(style)) &&
        (communication == null || communication == comms) &&
        (minimumRating == 0 || (rating != null && rating >= minimumRating)) &&
        (!availableNowOnly || playerAvailability?.availableNow == true) &&
        (preferredTimes.isEmpty ||
            (playerAvailability != null &&
                preferredTimes.any(
                  playerAvailability.preferredTimes.contains,
                ))) &&
        (scheduleWindow == null ||
            (playerAvailability != null &&
                playerAvailability.weeklySchedule.any(
                  (slot) => slot.overlaps(scheduleWindow!),
                ))) &&
        (maxPartySize == null ||
            (partySize != null && partySize <= maxPartySize!)) &&
        (!onlyAvailable || hasAvailability);
  }
}
