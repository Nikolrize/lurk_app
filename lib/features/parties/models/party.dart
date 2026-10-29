class Party {
  final String id;
  final String title;
  final String gameName;
  final String playStyle;
  final int currentPlayers;
  final int maxPlayers;

  const Party({
    required this.id,
    required this.title,
    required this.gameName,
    required this.playStyle,
    required this.currentPlayers,
    required this.maxPlayers,
  });

  bool get isFull => currentPlayers >= maxPlayers;
}
