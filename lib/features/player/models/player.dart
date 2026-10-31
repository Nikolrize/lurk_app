import '../../../core/data/game_catalog.dart';
import 'player_availability.dart';

class Player {
  const Player({
    this.bio = '',
    this.photoPath,
    this.games = const [],
    this.gameRanks = const {},
    this.playstyles = const [],
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
  final String bio;
  final String? photoPath;
  final List<String> games;
  final Map<String, String> gameRanks;

  int? rankForGame(String? value) {
    final game = GameCatalog.find(value);
    if (game == null || !game.supportsRanks) return null;
    final saved = gameRanks[game.id];
    if (saved != null) {
      final index = game.ranks.keys.toList().indexOf(saved);
      return index < 0 ? null : index;
    }
    return gameRanks.isEmpty && GameCatalog.find(currentGame)?.id == game.id
        ? rank
        : null;
  }

  final List<String> playstyles;
  final String id;
  final String name;
  final bool? isActive;
  final String? currentGame;

  /// Reads public profile data only. Missing presence is unknown, not offline.
  factory Player.fromFirestoreData(String uid, Map<String, dynamic> data) {
    String? string(String key) {
      final value = data[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    String label(String value) => value
        .split(RegExp(r'[_ -]+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
    final rawStyles = data['playstyles'];
    final styles = rawStyles is List
        ? rawStyles.whereType<String>().map(label).toList()
        : <String>[];
    final rawAvailability = data['availability'];
    final availability = rawAvailability is Map ? rawAvailability : const {};
    final rawTimes = availability['preferredTimes'];
    final times = rawTimes is List
        ? rawTimes
              .whereType<String>()
              .map(label)
              .where(PlayerAvailability.gamingTimes.contains)
              .toSet()
        : <String>{};
    final rawSchedule = availability['weeklySchedule'];
    final slots = <WeeklyGamingSlot>[];
    if (rawSchedule is List) {
      for (final entry in rawSchedule.whereType<Map>()) {
        if (entry['enabled'] == false) continue;
        final day = entry['weekday'];
        final start = entry['startMinute'];
        final end = entry['endMinute'];
        if (day is int &&
            day >= 1 &&
            day <= 7 &&
            start is int &&
            start >= 0 &&
            start < 1440 &&
            end is int &&
            end >= 0 &&
            end <= 1440) {
          slots.add(
            WeeklyGamingSlot(weekday: day, startMinute: start, endMinute: end),
          );
        }
      }
    }
    final game = string('currentGame');
    final rawGames = data['games'];
    final rawRanks = data['gameRanks'];
    final savedRanks = <String, String>{};
    if (rawRanks is Map) {
      for (final entry in rawRanks.entries) {
        if (entry.key is String && entry.value is String) {
          savedRanks[entry.key as String] = entry.value as String;
        }
      }
    }
    return Player(
      id: uid,
      name: string('username') ?? '',
      photoPath: string('photoPath'),
      games: List.unmodifiable(
        rawGames is List ? rawGames.whereType<String>() : [?game],
      ),
      gameRanks: Map.unmodifiable(savedRanks),
      bio: string('bio') ?? '',
      region: string('region') == null ? null : label(string('region')!),
      currentGame:
          GameCatalog.find(game)?.name ?? (game == null ? null : label(game)),
      isActive: data['isActive'] is bool ? data['isActive'] as bool : null,
      mode: string('mode') == null ? null : label(string('mode')!),
      rank: data['rank'] is num ? (data['rank'] as num).toInt() : null,
      style: styles.isEmpty ? null : styles.first,
      playstyles: List.unmodifiable(styles),
      communication:
          const {
            'mic_required': 'Mic required',
            'voice_optional': 'Voice optional',
            'chat_only': 'Chat only',
          }[string('communication')] ??
          string('communication'),
      rating: data['rating'] is num ? (data['rating'] as num).toDouble() : null,
      availability: PlayerAvailability(
        availableNow: availability['availableNow'] == true,
        preferredTimes: Set.unmodifiable(times),
        weeklySchedule: List.unmodifiable(slots),
      ),
    );
  }
}
