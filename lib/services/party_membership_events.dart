import 'dart:async';

enum PartySound { join, leave, mute, unmute }

class PartyMembershipEvent {
  const PartyMembershipEvent(this.uid, this.partyId, this.sound);
  final String uid, partyId;
  final PartySound sound;
}

/// Emitted only after a local membership transaction commits successfully.
class PartyMembershipEvents {
  static final _events = StreamController<PartyMembershipEvent>.broadcast(
    sync: true,
  );
  static Stream<PartyMembershipEvent> get changes => _events.stream;
  static void emit(String uid, String id, PartySound sound) =>
      _events.add(PartyMembershipEvent(uid, id, sound));
}

/// Tracks confirmed roster changes without replaying initial snapshots.
class PartySoundTracker {
  PartySoundTracker({required this.uid, required this.onSound});
  final String uid;
  final void Function(PartySound) onSound;
  String? partyId;
  Set<String>? _members;
  final _left = <String>{};
  final _joined = <String>{};
  void observeParty(String id) {
    if (id == partyId || _left.contains(id)) return;
    partyId = id;
    _members = null;
  }

  void localEvent(PartyMembershipEvent event) {
    if (event.uid != uid) return;
    if (event.sound == PartySound.leave) {
      leave(event.partyId);
      return;
    }
    _left.remove(event.partyId);
    if (!_joined.add(event.partyId)) return;
    observeParty(event.partyId);
    onSound(PartySound.join);
  }

  void roster(String id, Iterable<String> members) {
    if (id != partyId || _left.contains(id)) return;
    final next = members.where((member) => member != uid).toSet();
    final previous = _members;
    _members = next;
    if (previous == null) return;
    if (previous.difference(next).isNotEmpty) onSound(PartySound.leave);
    if (next.difference(previous).isNotEmpty) onSound(PartySound.join);
  }

  void leave(String id) {
    if (!_left.add(id)) return;
    _joined.remove(id);
    if (partyId == id) {
      partyId = null;
      _members = null;
    }
    onSound(PartySound.leave);
  }

  void resetRoster() => _members = null;
}
