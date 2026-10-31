import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/services/party_membership_events.dart';

void main() {
  test(
    'Initial roster and repeated snapshots are silent; peers joining/leaving sound once',
    () {
      final sounds = <PartySound>[];
      final tracker = PartySoundTracker(uid: 'me', onSound: sounds.add)
        ..observeParty('a');
      tracker.roster('a', ['me', 'one']);
      tracker.roster('a', ['one', 'me']);
      expect(sounds, isEmpty);
      tracker.roster('a', ['me', 'one', 'two']);
      tracker.roster('a', ['me', 'one', 'two']);
      tracker.roster('a', ['me', 'two']);
      expect(sounds, [PartySound.join, PartySound.leave]);
    },
  );
  test('Same-size member replacements play departure and arrival', () {
    final sounds = <PartySound>[];
    final tracker = PartySoundTracker(uid: 'me', onSound: sounds.add)
      ..observeParty('a');
    tracker.roster('a', ['me', 'one']);
    tracker.roster('a', ['me', 'two']);
    expect(sounds, [PartySound.leave, PartySound.join]);
  });
  test(
    'Own committed join and leave deduplicate roster and server closure notifications',
    () {
      final sounds = <PartySound>[];
      final tracker = PartySoundTracker(uid: 'me', onSound: sounds.add);
      tracker.localEvent(
        const PartyMembershipEvent('me', 'a', PartySound.join),
      );
      tracker.roster('a', ['me', 'one']);
      tracker.localEvent(
        const PartyMembershipEvent('me', 'a', PartySound.join),
      );
      tracker.leave('a');
      tracker.localEvent(
        const PartyMembershipEvent('me', 'a', PartySound.leave),
      );
      expect(sounds, [PartySound.join, PartySound.leave]);
      tracker.localEvent(
        const PartyMembershipEvent('me', 'a', PartySound.join),
      );
      expect(sounds.last, PartySound.join);
      expect(sounds.length, 3);
    },
  );
  test(
    'Opening another lobby or transferring host does not create a join sound',
    () {
      final sounds = <PartySound>[];
      final tracker = PartySoundTracker(uid: 'me', onSound: sounds.add)
        ..observeParty('a');
      tracker.roster('a', ['me', 'one']);
      tracker.observeParty('a');
      tracker.roster('a', ['one', 'me']);
      tracker.localEvent(
        const PartyMembershipEvent('other', 'b', PartySound.join),
      );
      expect(sounds, isEmpty);
    },
  );
  test('Switching parties announces self departure then arrival', () {
    final sounds = <PartySound>[];
    final tracker = PartySoundTracker(uid: 'me', onSound: sounds.add)
      ..observeParty('a');
    tracker.roster('a', ['me', 'one']);
    tracker.localEvent(const PartyMembershipEvent('me', 'a', PartySound.leave));
    tracker.localEvent(const PartyMembershipEvent('me', 'b', PartySound.join));
    tracker.roster('a', ['one']);
    tracker.roster('b', ['me', 'two']);
    expect(sounds, [PartySound.leave, PartySound.join]);
  });
}
