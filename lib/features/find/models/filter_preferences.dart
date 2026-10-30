import 'package:lurk_app/core/data/game_catalog.dart';

import '../../player/models/player_availability.dart';

class FilterPreferences {
  const FilterPreferences({
    this.game,
    this.region,
    this.mode,
    this.minRank = 0,
    this.maxRank, //optional
    this.playstyles = const {},
    this.communication,
    this.minimumRating = 0,
    this.availableNowOnly = false,
    this.preferredTimes = const {},
    this.scheduleWindow,
    this.maxPartySize,
    this.onlyAvailable = false,
  });

  final String? game;
  final String? region;
  final String? mode;
  final String? communication;

  final int minRank;
  final int? maxRank;

  final Set<String> playstyles;
  final double minimumRating;
  final bool availableNowOnly;
  final Set<String> preferredTimes;
  final WeeklyGamingSlot? scheduleWindow;
  final int? maxPartySize;
  final bool onlyAvailable;

  static List<String> ranksForGame(String? game) {
    final definition = GameCatalog.find(game);

    if (definition == null) return const [];

    return definition.ranks.values.toList(growable: false);
  }

  List<String> get rankNames => ranksForGame(game);

  int get effectiveMaxRank => maxRank ?? rankNames.length - 1;

  bool get hasRankFilter {
    final names = rankNames;

    return names.isNotEmpty &&
        (minRank != 0 || effectiveMaxRank != names.length - 1);
  }

  int get count => [
    game != null,
    region != null,
    mode != null,
    hasRankFilter,
    playstyles.isNotEmpty,
    communication != null,
    minimumRating > 0,
    availableNowOnly,
    preferredTimes.isNotEmpty,
    scheduleWindow != null,
    maxPartySize != null,
    onlyAvailable,
  ].where((enabled) => enabled).length;

  bool _matchesGame(String? gameName) {
    if (game == null) return true;
    if (game == gameName) return true;

    final selected = GameCatalog.find(game);
    final candidate = GameCatalog.find(gameName);

    return selected != null &&
        candidate != null &&
        selected.id == candidate.id;
  }

  bool _matchesRank({
    required int? rank,
    required int? minAllowedRank,
    required int? maxAllowedRank,
  }) {
    if (!hasRankFilter) return true;

    final upper = effectiveMaxRank;
    final last = rankNames.length - 1;

    if (minRank < 0 || upper > last || upper < minRank) {
      return false;
    }

    //party rank ranges match when to the two ranges overlap
    if (minAllowedRank != null && maxAllowedRank != null) {
      if (minAllowedRank < 0 ||
          maxAllowedRank > last ||
          minAllowedRank > maxAllowedRank) {
        return false;
      }

      return minAllowedRank <= upper && maxAllowedRank >= minRank;
    }

    //indv players must have rank inside selected range
    return rank != null && rank >= minRank && rank <= upper;
  }

  bool matches({
    required String? gameName,
    required String? regionName,
    required String? gameMode,
    required int? rank,
    int? minAllowedRank,
    int? maxAllowedRank,
    Iterable<String> styleOptions = const [],
    required String? style,
    required String? comms,
    required double? rating,
    PlayerAvailability? playerAvailability,
    required bool hasAvailability,
    int? partySize,
  }) {
    return _matchesGame(gameName) &&
        (region == null || region == regionName) &&
        (mode == null || mode == gameMode) &&
        _matchesRank(
          rank: rank,
          minAllowedRank: minAllowedRank,
          maxAllowedRank: maxAllowedRank,
        ) &&
        (playstyles.isEmpty ||
            playstyles.contains(style) ||
            styleOptions.any(playstyles.contains)) &&
        (communication == null || communication == comms) &&
        (minimumRating == 0 ||
            (rating != null && rating >= minimumRating)) &&
        (!availableNowOnly ||
            playerAvailability?.availableNow == true) &&
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