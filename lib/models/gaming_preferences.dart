class GamingPreferences {
  const GamingPreferences({
    this.games = const [],
    this.currentGame,
    this.mode,
    this.playstyles = const [],
    this.communication,
    this.rank,
  });

  static const gameLabels = {
    'valorant': 'Valorant',
    'mobile_legends': 'Mobile Legends',
    'fortnite': 'Fortnite',
  };

  static const modeLabels = {
    'competitive': 'Competitive',
    'casual': 'Casual',
  };

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

  static const valorantRanks = [
    'Iron',
    'Bronze',
    'Silver',
    'Gold',
    'Platinum',
    'Diamond',
    'Ascendant',
    'Immortal',
  ];  

  final List<String> games;
  final String? currentGame;
  final String? mode;
  final List<String> playstyles;
  final String? communication;
  final int? rank;

  factory GamingPreferences.fromMap(Map<String, dynamic> data) {
    final currentGame = data['currentGame'] as String?;
    final rawGames = data['games'] as List?;

    return GamingPreferences(
      games: List<String>.unmodifiable(
        rawGames?.cast<String>() ?? (currentGame == null ? <String>[] : [currentGame]),
      ),
      currentGame: currentGame,
      mode: data['mode'] as String?,
      playstyles: List<String>.unmodifiable(
        (data['playstyles'] as List?)?.cast<String>() ?? <String>[],
      ),
      communication: data['communication'] as String?,
      rank: data['rank'] as int?,
    );
  }

  void validate() {
    if (games.isEmpty || games.length > gameLabels.length || games.toSet().length != games.length || games.any((game)=> !gameLabels.containsKey(game))) {
      throw ArgumentError('Choose at least one supported game.');
    }

    if (!games.contains(currentGame)) {
      throw ArgumentError('Choose a main game from your selected games.');
    }

    if (mode != null && !modeLabels.containsKey(mode)) {
      throw ArgumentError('Invalid game mode.');
    }

    if (playstyles.length > styleLabels.length || playstyles.toSet().length != playstyles.length || playstyles.any((style)=> !styleLabels.containsKey(style))) {
      throw ArgumentError('Invalid playstyle selection.');
    }

    if (communication != null && !communicationLabels.containsKey(communication)) {
      throw ArgumentError('Invalid communication preference.');
    }

    if (rank != null && 
      (currentGame != 'valorant' || rank! < 0 || rank! >= valorantRanks.length)
    ) {
      throw ArgumentError('Invalid rank for the selected game.');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'games' : List<String>.of(games),
      'currentGame': currentGame,
      'mode': mode,
      'playstyles': List<String>.of(playstyles),
      'communication': communication,
      'rank': rank,
    };
  }
}