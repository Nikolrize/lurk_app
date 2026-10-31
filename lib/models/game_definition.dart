class GameDefinition {
  const GameDefinition({
    required this.id,
    required this.name,
    this.iconAsset,
    this.rankHelp,
    this.ranks = const {}, //empty map if no ranks
  });

  final String id;
  final String name;
  final String? iconAsset;
  final String? rankHelp;
  final Map<String, String> ranks;

  bool get supportsRanks => ranks.isNotEmpty; //asks whether this game has rank
}
