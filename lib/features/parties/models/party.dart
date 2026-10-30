import '../../../core/data/game_catalog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Party {
  final String? region, mode, style, communication, availability;
  final int? rank;
  final double? rating;
  final String hostId, gameId, visibility, status, description;
  final List<String> playstyles;
  final int? minRank, maxRank;
  final double minimumRating;
  final DateTime? createdAt;
  final String id;
  final String title;
  final String gameName;
  final String playStyle;
  final int currentPlayers;
  final int maxPlayers;

  const Party({
    this.hostId = '',
    this.gameId = '',
    this.visibility = 'public',
    this.status = 'open',
    this.description = '',
    this.playstyles = const [],
    this.minRank,
    this.maxRank,
    this.minimumRating = 0,
    this.createdAt,
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

  /// Maps the Firestore schema to the display fields used by party cards.
  factory Party.fromFirestoreData(String id, Map<String, dynamic> data) {
    String? string(String key) =>
        data[key] is String ? data[key] as String : null;
    int? integer(String key) => (data[key] as num?)?.toInt();
    String? label(String? value) {
      if (value == null || value.trim().isEmpty) return null;
      return value
          .split(RegExp(r'[_ -]+'))
          .map(
            (word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
          )
          .join(' ');
    }

    final gameId = string('gameId') ?? '';
    final mode = label(string('mode'));
    final styles =
        (data['playstyles'] as List?)
            ?.whereType<String>()
            .map((value) => label(value)!)
            .toList() ??
        <String>[];
    final created = data['createdAt'];
    return Party(
      id: id,
      hostId: string('hostId') ?? '',
      gameId: gameId,
      title: string('title') ?? 'Untitled party',
      gameName:
          GameCatalog.find(gameId)?.name ??
          string('gameName') ??
          label(gameId) ??
          'Unknown game',
      mode: mode,
      playStyle: mode ?? 'Any mode',
      region: label(string('region')),
      style: styles.isEmpty ? null : styles.first,
      playstyles: List.unmodifiable(styles),
      communication:
          const {
            'mic_required': 'Mic required',
            'voice_optional': 'Voice optional',
            'chat_only': 'Chat only',
          }[string('communication')] ??
          label(string('communication')),
      currentPlayers: integer('memberCount') ?? 0,
      maxPlayers: integer('maxPlayers') ?? 5,
      minRank: integer('minRank'),
      maxRank: integer('maxRank'),
      rank: integer('rank'),
      rating: (data['rating'] as num?)?.toDouble(),
      minimumRating: (data['minimumRating'] as num?)?.toDouble() ?? 0,
      description: string('description') ?? '',
      visibility: string('visibility') ?? 'public',
      status: string('status') ?? 'open',
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
  bool get isFull => currentPlayers >= maxPlayers;
}
