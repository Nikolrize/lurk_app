import '../../providers/voice_provider.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/party_provider.dart';
import '../../providers/party_sound_provider.dart';
import '../../services/party_membership_events.dart';

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
  // keep sound effects silent while the app is in the background
  void _playSound(PartySound sound) {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) {
      ref.read(partySoundServiceProvider).play(sound);
    }
  }

  // listen for confirmed membership events belonging to the current player
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

  // reset member tracking after resuming so missed events are not replayed
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(_tracker.resetRoster);
    }
  }

  // stop membership events and lifecycle callbacks when this scope is removed
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_events.cancel());
    super.dispose();
  }

  // keep membership and local microphone sounds working across app tabs
  @override
  Widget build(BuildContext context) {
    // only play mic sounds when the local mute state changes within the same call
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
      // start with the current member list so existing members dont trigger join sounds
      final roster = ref.watch(partyMemberIdsProvider(id)).asData?.value;
      if (roster != null) _tracker.roster(id, roster);
      // confirm departure from party updates and not temporary loading states
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
