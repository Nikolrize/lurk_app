import 'player_status.dart';
import '../core/data/game_catalog.dart';
class PlayerPresence {
  const PlayerPresence({
    required this.preference,
    required this.sessions,
    this.activeGameId,
  });

  final PlayerStatus preference;
  final List<PlayerStatus> sessions;

  final String? activeGameId;

  String? get playingGameId {
    return effectiveStatus == PlayerStatus.offline
        ? null
        : activeGameId;
  }

  factory PlayerPresence.fromMap(Map<Object?, Object?> data) {
    final rawPreference = data['preference'];
    final rawSessions = data['sessions'];
    final rawActivities = data['activities'];

    final preference = rawPreference is String
        ? PlayerStatus.fromId(rawPreference)
        : null;

    final sessions = <PlayerStatus>[];
    String? onlineGame;
    String? idleGame;

    if (rawSessions is Map) {
      for (final entry in rawSessions.entries) {
        final status = entry.value == 'online'
            ? PlayerStatus.online
            : entry.value == 'idle'
                ? PlayerStatus.idle
                : null;

        if (status == null) continue;

        sessions.add(status);

        final gameId = rawActivities is Map
            ? rawActivities[entry.key]
            : null;

        if (gameId is! String ||
            !GameCatalog.games.containsKey(gameId)) {
          continue;
        }

        if (status == PlayerStatus.online) {
          onlineGame ??= gameId;
        } else {
          idleGame ??= gameId;
        }
      }
    }

    return PlayerPresence(
      preference: preference ?? PlayerStatus.online,
      sessions: List<PlayerStatus>.unmodifiable(sessions),
      activeGameId: onlineGame ?? idleGame,
    );
  }

  PlayerStatus get effectiveStatus {
    if (preference == PlayerStatus.offline || sessions.isEmpty) {
      return PlayerStatus.offline;
    }

    if (preference == PlayerStatus.doNotDisturb) {
      return PlayerStatus.doNotDisturb;
    }

    if (preference == PlayerStatus.idle) {
      return PlayerStatus.idle;
    }

    return sessions.contains(PlayerStatus.online) ? PlayerStatus.online : PlayerStatus.idle;
  }

}


//both preference and effectivestatus
//preference - what the player chose
//effective status - considers their connections