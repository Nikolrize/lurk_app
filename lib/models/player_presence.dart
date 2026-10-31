import 'player_status.dart';

class PlayerPresence {
  const PlayerPresence({
    required this.preference,
    required this.sessions,
  });

  final PlayerStatus preference;
  final List<PlayerStatus> sessions;

  factory PlayerPresence.fromMap(Map<Object?, Object?> data) {
    final rawPreference = data['preference'];
    final rawSessions = data['sessions'];

    final preference = rawPreference is String
        ? PlayerStatus.fromId(rawPreference)
        : null;

    final sessions = <PlayerStatus>[];

    if (rawSessions is Map) {
      for (final value in rawSessions.values) {
        if (value == 'online') {
          sessions.add(PlayerStatus.online);
        } else if (value == 'idle') {
          sessions.add(PlayerStatus.idle);
        }
      }
    }

    return PlayerPresence(
      preference: preference ?? PlayerStatus.online,
      sessions: List<PlayerStatus>.unmodifiable(sessions),
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