import 'dart:math';
import '../../../core/data/game_catalog.dart';
import 'party.dart';

Party? pickQuickMatchParty(
  Iterable<Party> parties, {
  required String mainGameId,
  required String viewerUid,
  String? currentPartyId,
  Random? random,
}) {
  final candidates = parties
      .where(
        (party) =>
            (GameCatalog.find(party.gameId)?.id ??
                    GameCatalog.find(party.gameName)?.id) ==
                mainGameId &&
            party.status == 'open' &&
            party.visibility == 'public' &&
            !party.isFull &&
            party.hostId != viewerUid &&
            party.id != currentPartyId,
      )
      .toList();
  if (candidates.isEmpty) return null;
  return candidates[(random ?? Random()).nextInt(candidates.length)];
}
