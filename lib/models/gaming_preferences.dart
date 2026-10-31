import 'package:lurk_app/core/data/game_catalog.dart';

class GamingPreferences {
  const GamingPreferences({
    this.games = const [],
    this.currentGame,
    this.mode,
    this.playstyles = const [],
    this.communication,
    this.rank,
    this.gameRanks = const {},
  });

  static final Map<String, String> gameLabels =
      Map<String, String>.unmodifiable({
        for (final game in GameCatalog.games.values) game.id: game.name,
      });

  static const modeLabels = {'competitive': 'Competitive', 'casual': 'Casual'};

  static const styleLabels = {
    'chill': 'Chill',
    'serious': 'Serious',
    'fun': 'Fun',
  };

  static const communicationLabels = {
    'mic_required': 'Mic required',
    'voice_optional': 'Voice optional',
    'chat_only': 'Chat only',
  };

  static List<String> ranksForGame(String? game) =>
      GameCatalog.find(game)?.ranks.values.toList(growable: false) ?? const [];
  static List<String> get valorantRanks => ranksForGame('valorant');
  final List<String> games;
  final String? currentGame;
  final String? mode;
  final List<String> playstyles;
  final String? communication;
  final int? rank;
  final Map<String, String> gameRanks;

  factory GamingPreferences.fromMap(Map<String, dynamic> data) {
    final currentGame = data['currentGame'] as String?;
    final rawGames = data['games'] as List?;
    final rawGameRanks = data['gameRanks'];

    final savedRanks = <String, String>{};

    if (rawGameRanks != null) {
      savedRanks.addAll(
        Map<String, String>.from(rawGameRanks as Map),
      );
    } else {
      //older profiles stored only one numeric val rank
      final legacyRank = data['rank'];

      if (currentGame == 'valorant' && legacyRank is int) {
        final rankIds =
            GameCatalog.games['valorant']!.ranks.keys.toList();

        if (legacyRank >= 0 && legacyRank < rankIds.length) {
          savedRanks['valorant'] = rankIds[legacyRank];
        }
      }
    }

  return GamingPreferences(
    games: List<String>.unmodifiable(
      rawGames?.cast<String>() ??
          (currentGame == null ? <String>[] : [currentGame]),
    ),
    currentGame: currentGame,
    mode: data['mode'] as String?,
    playstyles: List<String>.unmodifiable(
      (data['playstyles'] as List?)?.cast<String>() ?? <String>[],
    ),
    communication: data['communication'] as String?,
    rank: data['rank'] as int?,
    gameRanks: Map<String, String>.unmodifiable(savedRanks),
  );
}

  //translates saved rank ID into readable text
  String? rankLabelFor(String gameId) {
    final game = GameCatalog.games[gameId];
    final rankId = gameRanks[gameId];

    if (game == null || rankId == null) {
      return null;
    }

    return game.ranks[rankId];
  }

  void validate() {
    if (games.isEmpty ||
        games.length > gameLabels.length ||
        games.toSet().length != games.length ||
        games.any((game) => !gameLabels.containsKey(game))) {
      throw ArgumentError('Choose at least one supported game.');
    }

    if (!games.contains(currentGame)) {
      throw ArgumentError('Choose a main game from your selected games.');
    }

    if (mode != null && !modeLabels.containsKey(mode)) {
      throw ArgumentError('Invalid game mode.');
    }

    if (playstyles.length > styleLabels.length ||
        playstyles.toSet().length != playstyles.length ||
        playstyles.any((style) => !styleLabels.containsKey(style))) {
      throw ArgumentError('Invalid playstyle selection.');
    }

    if (communication != null &&
        !communicationLabels.containsKey(communication)) {
      throw ArgumentError('Invalid communication preference.');
    }

    //checks map pair for ranks
    for (final entry in gameRanks.entries) {
      final game = GameCatalog.games[entry.key];

      if (!games.contains(entry.key) ||
          game == null ||
          !game.supportsRanks ||
          !game.ranks.containsKey(entry.value)) {
        throw ArgumentError('Invalid rank for ${entry.key}.');
      }
    }
  }

  Map<String, dynamic> toMap() {
    final mainGame = GameCatalog.games[currentGame];
    final mainRankId = gameRanks[currentGame];

    final rankIndex = mainGame == null || mainRankId == null ? -1 : mainGame.ranks.keys.toList().indexOf(mainRankId); //indexOf - find rank position in game list

    return {
      'games': List<String>.of(games),
      'currentGame': currentGame,
      'mode': mode,
      'playstyles': List<String>.of(playstyles),
      'communication': communication,
      'gameRanks': Map<String, String>.of(gameRanks),
      'rank': rankIndex < 0 ? null : rankIndex,
    };
  }
}
