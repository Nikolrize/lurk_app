import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/models/player_presence.dart';
import 'package:lurk_app/models/player_status.dart';

void main() {
  test('No connected sessions means Offline, even with DND selected', () {
    const presence = PlayerPresence(
      preference: PlayerStatus.doNotDisturb,
      sessions: [],
    );

    expect(presence.effectiveStatus, PlayerStatus.offline);
  });

  test('An active device keeps the player Online', () {
    const presence = PlayerPresence(
      preference: PlayerStatus.online,
      sessions: [
        PlayerStatus.idle,
        PlayerStatus.online,
      ],
    );

    expect(presence.effectiveStatus, PlayerStatus.online);
  });

  test('Only idle sessions means Idle', () {
    const presence = PlayerPresence(
      preference: PlayerStatus.online,
      sessions: [PlayerStatus.idle],
    );

    expect(presence.effectiveStatus, PlayerStatus.idle);
  });

  test('Manual choices override connected session activity', () {
    for (final preference in [
      PlayerStatus.idle,
      PlayerStatus.doNotDisturb,
      PlayerStatus.offline,
    ]) {
      final presence = PlayerPresence(
        preference: preference,
        sessions: const [PlayerStatus.online],
      );

      expect(presence.effectiveStatus, preference);
    }
  });
}