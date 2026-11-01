import '../../../core/data/game_catalog.dart';
import '../../../core/data/gaming_regions.dart';
import '../../../models/gaming_preferences.dart';

class PartyDraft {
  const PartyDraft({
    required this.title,
    required this.gameId,
    required this.maxPlayers,
    required this.region,
    required this.mode,
    required this.visibility,
    required this.minimumRating,
    required this.playstyles,
    required this.communication,
    this.minRank,
    this.maxRank,
    this.description = '',
  });
  static Map<String, String> get games => {
    for (final game in GameCatalog.games.values) game.id: game.name,
  };
  static Map<String, String> get regions => {
    for (final region in GamingRegions.values)
      region.toLowerCase().replaceAll(' ', '_'): region,
  };
  static const modes = GamingPreferences.modeLabels;
  static const styles = GamingPreferences.styleLabels;
  static const communications = GamingPreferences.communicationLabels;
  final String title,
      gameId,
      region,
      mode,
      visibility,
      communication,
      description;
  final int maxPlayers;
  final int? minRank, maxRank;
  final double minimumRating;
  final Set<String> playstyles;

  void validate() {
    if (title.trim().isEmpty || title.trim().length > 60) {
      throw ArgumentError('Enter a party name of 1-60 characters.');
    }
    if (!games.containsKey(gameId) ||
        !regions.containsKey(region) ||
        !modes.containsKey(mode) ||
        !['public', 'private'].contains(visibility) ||
        !communications.containsKey(communication)) {
      throw ArgumentError('Select valid party preferences.');
    }
    if (maxPlayers < 2 || maxPlayers > 10) {
      throw ArgumentError('Party size must be between 2 and 10.');
    }
    if (!minimumRating.isFinite || minimumRating < 0 || minimumRating > 5) {
      throw ArgumentError('Minimum rating must be between 0 and 5.');
    }
    if (playstyles.isEmpty ||
        playstyles.any((style) => !styles.containsKey(style))) {
      throw ArgumentError('Choose at least one playstyle.');
    }
    if (description.trim().length > 500) {
      throw ArgumentError('Description must not exceed 500 characters.');
    }
    final ranks = GameCatalog.find(gameId)?.ranks ?? const <String, String>{};
    if ((minRank == null) != (maxRank == null) ||
        (minRank != null &&
            (ranks.isEmpty ||
                minRank! < 0 ||
                maxRank! >= ranks.length ||
                minRank! > maxRank!))) {
      throw ArgumentError('Choose a valid rank range for the selected game.');
    }
  }

  Map<String, dynamic> toFirestoreFields() {
    validate();
    return {
      'title': title.trim(),
      'gameId': gameId,
      'maxPlayers': maxPlayers,
      'region': region,
      'mode': mode,
      'visibility': visibility,
      'minimumRating': minimumRating,
      'minRank': minRank,
      'maxRank': maxRank,
      'playstyles': playstyles.toList()..sort(),
      'communication': communication,
      'description': description.trim(),
    };
  }
}
