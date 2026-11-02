import 'dart:async';

enum PartySound { join, leave, mute, unmute }

class PartyMembershipEvent {
  const PartyMembershipEvent(this.uid, this.partyId, this.sound);
  final String uid, partyId;
  final PartySound sound;
}

// notify listeners after the player joins or leaves a party
class PartyMembershipEvents {
  static final _events = StreamController<PartyMembershipEvent>.broadcast(
    sync: true,
  );
  static Stream<PartyMembershipEvent> get changes => _events.stream;
  // send the player join or leave event after the database update succeeds
  static void emit(String uid, String id, PartySound sound) =>
      _events.add(PartyMembershipEvent(uid, id, sound));
}
class PartySoundTracker {
  PartySoundTracker({required this.uid, required this.onSound});
  final String uid;
  final void Function(PartySound) onSound;
  String? partyId;
  Set<String>? _members;
  final _left = <String>{};
  final _joined = <String>{};
  // start tracking a party without playing sounds for members already there
  void observeParty(String id) {
    if (id == partyId || _left.contains(id)) return;
    partyId = id;
    _members = null;
  }

  // play the current player join or leave sound without repeating the same event
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

  // compare member lists and play sounds only for later joins or leaves
  void roster(String id, Iterable<String> members) {
    if (id != partyId || _left.contains(id)) return;
    final next = members.where((member) => member != uid).toSet();
    final previous = _members;
    _members = next;
    if (previous == null) return;
    if (previous.difference(next).isNotEmpty) onSound(PartySound.leave);
    if (next.difference(previous).isNotEmpty) onSound(PartySound.join);
  }

  // play one leave sound and stop tracking the departed party
  void leave(String id) {
    if (!_left.add(id)) return;
    _joined.remove(id);
    if (partyId == id) {
      partyId = null;
      _members = null;
    }
    onSound(PartySound.leave);
  }

  // use the next member list as a silent starting point after resuming
  void resetRoster() => _members = null;
}
