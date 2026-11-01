import '../../../core/data/game_catalog.dart';
import '../../../core/data/gaming_regions.dart';
import '../../../models/gaming_preferences.dart';
import 'party.dart';

int? matchmakingRank(GamingPreferences preferences, String gameId) {
  final game = GameCatalog.find(gameId);
  final saved = preferences.gameRanks[game?.id];
  if (saved != null && game != null) {
    final index = game.ranks.keys.toList().indexOf(saved);
    return index < 0 ? null : index;
  }
  return preferences.gameRanks.isEmpty && preferences.currentGame == game?.id
      ? preferences.rank
      : null;
}

bool meetsMatchRequirements(
  Party party, {
  required String? region,
  required GamingPreferences preferences,
  double? rating,
  Set<String> blockedHosts = const {},
}) {
  final game =
      GameCatalog.find(party.gameId) ?? GameCatalog.find(party.gameName);
  final rank = matchmakingRank(preferences, game?.id ?? party.gameId);
  final hasRankRange = party.minRank != null && party.maxRank != null;
  final allRanks =
      hasRankRange &&
      party.minRank == 0 &&
      party.maxRank == (game?.ranks.length ?? 0) - 1;
  return GamingRegions.idFor(region) != null &&
      GamingRegions.idFor(region) == GamingRegions.idFor(party.region) &&
      !blockedHosts.contains(party.hostId) &&
      (party.minimumRating == 0 ||
          rating != null && rating >= party.minimumRating) &&
      (!hasRankRange ||
          allRanks ||
          rank != null && rank >= party.minRank! && rank <= party.maxRank!);
}
