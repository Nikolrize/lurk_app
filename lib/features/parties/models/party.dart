class Party {
  final String? region, mode, style, communication, availability;
  final int? rank;
  final double? rating;
  final String id;
  final String title;
  final String gameName;
  final String playStyle;
  final int currentPlayers;
  final int maxPlayers;

  const Party({
    this.region,
    this.mode,
    this.rank,
    this.style,
    this.communication,
    this.rating,
    this.availability,
    required this.id,
    required this.title,
    required this.gameName,
    required this.playStyle,
    required this.currentPlayers,
    required this.maxPlayers,
  });

  bool get isFull => currentPlayers >= maxPlayers;
}
