import '../../../core/data/game_catalog.dart';
import '../../../core/data/gaming_regions.dart';

/// Uses fresh transaction reads, rather than cached preview/profile values.
String? partyRequirementMessage({
  required Map<String, dynamic> party,
  required Map<String, dynamic>? profile,
  Map<String, dynamic>? ratingSummary,
}) {
  if (profile == null) {
    return 'Complete your player profile before joining a party.';
  }
  String? regionLabel(String? region) {
    final id = GamingRegions.idFor(region);
    for (final label in GamingRegions.values) {
      if (GamingRegions.idFor(label) == id && id != null) return label;
    }
    return null;
  }

  final requiredRegion = regionLabel(party['region'] as String?);
  final playerRegion = regionLabel(profile['region'] as String?);
  if (requiredRegion == null) {
    return 'This party’s region is not configured. Ask the host to update it.';
  }
  if (playerRegion == null) {
    return 'Set your region in Profile before joining this party.';
  }
  if (requiredRegion != playerRegion) {
    return 'This party requires region $requiredRegion. Your profile region is $playerRegion.';
  }
  final game = GameCatalog.find(party['gameId'] as String?);
  final min = (party['minRank'] as num?)?.toInt();
  final max = (party['maxRank'] as num?)?.toInt();
  final labels = game?.ranks.values.toList() ?? <String>[];
  if (min != null && max != null && !(min == 0 && max == labels.length - 1)) {
    if (min < 0 || max >= labels.length || min > max) {
      return 'This party’s rank settings need updating. Please contact the host.';
    }
    final saved = (profile['gameRanks'] as Map?)?[game?.id];
    final rank =
        game?.ranks.keys.toList().indexOf(saved is String ? saved : '') ?? -1;
    final range = labels[min] == labels[max]
        ? labels[min]
        : '${labels[min]}–${labels[max]}';
    if (rank < 0) {
      return 'Set your ${game!.name} rank in Gaming Preferences. This party requires $range.';
    }
    if (rank < min || rank > max) {
      return 'This party requires ${game!.name} rank $range. Your rank is ${labels[rank]}.';
    }
  }
  final minimum = (party['minimumRating'] as num?)?.toDouble() ?? 0;
  if (minimum > 0) {
    final count = (ratingSummary?['count'] as num?)?.toInt() ?? 0;
    final total = (ratingSummary?['total'] as num?)?.toDouble() ?? 0;
    final requiredRating = minimum.toStringAsFixed(1);
    if (count == 0) {
      return 'This party requires a $requiredRating+ player rating. You haven’t received any ratings yet.';
    }
    if (total < minimum * count) {
      return 'This party requires a $requiredRating+ player rating. Your current rating is below this requirement.';
    }
  }
  return null;
}

/// Native transaction failures must not replace a known eligibility rejection.
/// A new instance belongs to one join attempt; reset before each SDK retry.
class PartyJoinRejection {
  StateError? _reason;
  void reset() => _reason = null;
  Never reject(String message) {
    final reason = StateError(message);
    _reason = reason;
    throw reason;
  }

  Future<T> run<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stack) {
      final reason = _reason;
      if (reason != null) Error.throwWithStackTrace(reason, stack);
      rethrow;
    }
  }
}
