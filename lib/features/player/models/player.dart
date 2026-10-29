class Player {
  const Player({
    required this.id,
    required this.name,
    required this.isActive,
    this.currentGame,
  });

  final String id;
  final String name;
  final bool isActive;
  final String? currentGame;
}
