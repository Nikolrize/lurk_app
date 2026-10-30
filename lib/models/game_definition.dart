class GameDefinition {
  const GameDefinition({
    required this.id,
    required this.name,
    this.ranks = const{}, //empty map if no ranks
  });

  final String id;
  final String name;
  final Map<String, String> ranks;

  bool get supportsRanks => ranks.isNotEmpty; //asks whether this game has rank
  
}