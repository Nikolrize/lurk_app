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
  static const games = {
    'valorant': 'Valorant',
    'mobile_legends': 'Mobile Legends',
    'fortnite': 'Fortnite',
  };
  static const regions = {
    'asia': 'Asia',
    'europe': 'Europe',
    'north_america': 'North America',
    'oceania': 'Oceania',
  };
  static const modes = {'competitive': 'Competitive', 'casual': 'Casual'};
  static const styles = {'chill': 'Chill', 'serious': 'Serious', 'fun': 'Fun'};
  static const communications = {
    'mic_required': 'Mic required',
    'voice_optional': 'Voice optional',
    'chat_only': 'Chat only',
  };
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
      throw ArgumentError('Enter a party name of 1–60 characters.');
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
    if (gameId != 'valorant' && (minRank != null || maxRank != null)) {
      throw ArgumentError(
        'Rank settings are currently available for Valorant only.',
      );
    }
    if ((minRank == null) != (maxRank == null) ||
        (minRank != null &&
            (minRank! < 0 || maxRank! > 7 || minRank! > maxRank!))) {
      throw ArgumentError('Choose a valid rank range.');
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
