import '../../../models/gaming_preferences.dart';
import 'party_matching.dart';
import '../../../core/data/gaming_regions.dart';
import 'dart:math';
import '../../../core/data/game_catalog.dart';
import 'party.dart';

Party? pickQuickMatchParty(
  Iterable<Party> parties, {
  required String mainGameId,
  required String regionId,
  required String viewerUid,
  String? currentPartyId,
  Random? random,
  GamingPreferences? preferences,
  double? rating,
  Set<String> blockedHosts = const {},
}) {
  final candidates = parties
      .where(
        (party) =>
            (GameCatalog.find(party.gameId)?.id ??
                    GameCatalog.find(party.gameName)?.id) ==
                mainGameId &&
            GamingRegions.idFor(party.region) == regionId &&
            party.status == 'open' &&
            party.visibility == 'public' &&
            !party.isFull &&
            party.hostId != viewerUid &&
            party.id != currentPartyId &&
            !blockedHosts.contains(party.hostId) &&
            (preferences == null ||
                meetsMatchRequirements(
                  party,
                  region: regionId,
                  preferences: preferences,
                  rating: rating,
                  blockedHosts: blockedHosts,
                )),
      )
      .toList();
  if (candidates.isEmpty) return null;
  return candidates[(random ?? Random()).nextInt(candidates.length)];
}
