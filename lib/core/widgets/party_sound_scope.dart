import '../../providers/voice_provider.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/party_provider.dart';
import '../../providers/party_sound_provider.dart';
import '../../services/party_membership_events.dart';

/// Mounted above every tab so roster sounds continue while browsing the app.
class PartySoundScope extends ConsumerStatefulWidget {
  const PartySoundScope({super.key, required this.uid, required this.child});
  final String uid;
  final Widget child;
  @override
  ConsumerState<PartySoundScope> createState() => _PartySoundScopeState();
}

class _PartySoundScopeState extends ConsumerState<PartySoundScope>
    with WidgetsBindingObserver {
  late final PartySoundTracker _tracker;
  late final StreamSubscription<PartyMembershipEvent> _events;
  void _playSound(PartySound sound) {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) {
      ref.read(partySoundServiceProvider).play(sound);
    }
  }

  @override
  void initState() {
    super.initState();
    _tracker = PartySoundTracker(uid: widget.uid, onSound: _playSound);
    _events = PartyMembershipEvents.changes.listen((event) {
      if (!mounted || event.uid != widget.uid) return;
      setState(() => _tracker.localEvent(event));
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(_tracker.resetRoster);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_events.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only this device's confirmed microphone state changes trigger these cues.
    // Remote mute events, initial connection and disconnection stay silent.
    ref.listen(voiceStateProvider, (previous, next) {
      final before = previous?.asData?.value;
      final after = next.asData?.value;
      if (before != null &&
          after != null &&
          before.connected &&
          after.connected &&
          before.partyId == after.partyId &&
          before.muted != after.muted) {
        _playSound(after.muted ? PartySound.mute : PartySound.unmute);
      }
    });
    final current = ref.watch(currentPartyProvider).asData?.value;
    if (current != null) _tracker.observeParty(current.id);
    final id = _tracker.partyId;
    if (id != null) {
      ref.listen(partyMemberIdsProvider(id), (previous, next) {
        if (next.asData != null) _tracker.roster(id, next.asData!.value);
      });
      // The first available roster is a silent baseline, even if already cached.
      final roster = ref.watch(partyMemberIdsProvider(id)).asData?.value;
      if (roster != null) _tracker.roster(id, roster);
      ref.listen(partyByIdProvider(id), (previous, next) {
        if (next.asData?.value?.status == 'closed') {
          setState(() => _tracker.leave(id));
        }
      });
      ref.listen(myPartyMembershipProvider(id), (previous, next) {
        if (next.asData?.value?['leftAt'] != null) {
          setState(() => _tracker.leave(id));
        }
      });
    }
    return widget.child;
  }
}
