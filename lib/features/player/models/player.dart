import 'player_availability.dart';

class Player {
  const Player({
    this.region,
    this.mode,
    this.rank,
    this.style,
    this.communication,
    this.rating,
    this.availability = const PlayerAvailability(),
    required this.id,
    required this.name,
    required this.isActive,
    this.currentGame,
  });

  final String? region, mode, style, communication;
  final PlayerAvailability availability;
  final int? rank;
  final double? rating;
  final String id;
  final String name;
  final bool isActive;
  final String? currentGame;
}
