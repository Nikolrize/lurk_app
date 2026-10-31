import 'package:lurk_app/providers/voice_provider.dart';
import 'package:lurk_app/services/party_voice_service.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/core/widgets/party_sound_scope.dart';
import 'package:lurk_app/features/parties/models/party.dart';
import 'package:lurk_app/providers/party_provider.dart';
import 'package:lurk_app/providers/party_sound_provider.dart';
import 'package:lurk_app/services/party_membership_events.dart';
import 'package:lurk_app/services/party_sound_service.dart';

class _Sounds extends Fake implements PartySoundService {
  final played = <PartySound>[];
  @override
  void play(PartySound sound) => played.add(sound);
}

void main() {
  testWidgets('Only local successful mute transitions play cues', (
    tester,
  ) async {
    final states = StreamController<VoiceState>();
    addTearDown(states.close);
    final sounds = _Sounds();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentPartyProvider.overrideWith((ref) => const AsyncData(null)),
          voiceStateProvider.overrideWith((ref) => states.stream),
          partySoundServiceProvider.overrideWithValue(sounds),
        ],
        child: const MaterialApp(
          home: PartySoundScope(uid: 'me', child: SizedBox()),
        ),
      ),
    );
    states.add(const VoiceState(partyId: 'p', connected: true, muted: true));
    await tester.pumpAndSettle();
    expect(sounds.played, isEmpty);
    states.add(
      const VoiceState(
        partyId: 'p',
        connected: true,
        muted: true,
        remoteMics: {'other': true},
      ),
    );
    await tester.pumpAndSettle();
    expect(sounds.played, isEmpty);
    states.add(
      const VoiceState(
        partyId: 'p',
        connected: true,
        muted: true,
        error: 'Microphone permission denied',
      ),
    );
    await tester.pumpAndSettle();
    expect(sounds.played, isEmpty);
    states.add(const VoiceState(partyId: 'p', connected: true, muted: false));
    await tester.pumpAndSettle();
    expect(sounds.played, [PartySound.unmute]);
    states.add(
      const VoiceState(
        partyId: 'p',
        connected: true,
        muted: false,
        remoteMics: {'other': false},
      ),
    );
    await tester.pumpAndSettle();
    expect(sounds.played.length, 1);
    states.add(const VoiceState(partyId: 'p', connected: true, muted: true));
    await tester.pumpAndSettle();
    expect(sounds.played, [PartySound.unmute, PartySound.mute]);
    states.add(const VoiceState());
    await tester.pumpAndSettle();
    expect(sounds.played.length, 2);
    expect(tester.takeException(), isNull);
  });
  test('Join, leave, mute and unmute cues are bundled PCM WAV files', () async {
    final join = await rootBundle.load('assets/sounds/party_join.wav');
    final leave = await rootBundle.load('assets/sounds/party_leave.wav');
    final mute = await rootBundle.load('assets/sounds/party_mute.wav');
    final unmute = await rootBundle.load('assets/sounds/party_unmute.wav');
    for (final data in [join, leave, mute, unmute]) {
      expect(
        ascii.decode(data.buffer.asUint8List(data.offsetInBytes, 4)),
        'RIFF',
      );
      expect(data.getUint16(22, Endian.little), 1);
      expect(data.getUint32(24, Endian.little), 44100);
      expect(data.lengthInBytes, greaterThan(10000));
    }
    expect(
      mute.buffer.asUint8List().toString(),
      isNot(unmute.buffer.asUint8List().toString()),
    );
    expect(
      join.buffer.asUint8List().toString(),
      isNot(leave.buffer.asUint8List().toString()),
    );
  });
  testWidgets(
    'Roster sounds work across the app, suppress duplicates and background catch-up',
    (tester) async {
      final roster = StreamController<List<String>>();
      addTearDown(roster.close);
      final sounds = _Sounds();
      const party = Party(
        id: 'p',
        hostId: 'me',
        title: 'Squad',
        gameName: 'Valorant',
        playStyle: 'Chill',
        currentPlayers: 2,
        maxPlayers: 5,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentPartyProvider.overrideWith((ref) => const AsyncData(party)),
            partyMemberIdsProvider('p').overrideWith((ref) => roster.stream),
            partyByIdProvider('p').overrideWith((ref) => Stream.value(party)),
            myPartyMembershipProvider(
              'p',
            ).overrideWith((ref) => Stream.value({'leftAt': null})),
            partySoundServiceProvider.overrideWithValue(sounds),
          ],
          child: const MaterialApp(
            home: PartySoundScope(uid: 'me', child: SizedBox()),
          ),
        ),
      );
      roster.add(['me', 'one']);
      await tester.pumpAndSettle();
      expect(sounds.played, isEmpty);
      roster.add(['me', 'one', 'two']);
      await tester.pumpAndSettle();
      expect(sounds.played, [PartySound.join]);
      roster.add(['two', 'me', 'one']);
      await tester.pumpAndSettle();
      expect(sounds.played.length, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      roster.add(['me', 'one']);
      await tester.pumpAndSettle();
      expect(sounds.played.length, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      roster.add(['me', 'one', 'three']);
      await tester.pumpAndSettle();
      expect(sounds.played.length, 2);
      PartyMembershipEvents.emit('me', 'p', PartySound.leave);
      await tester.pumpAndSettle();
      expect(sounds.played.last, PartySound.leave);
      roster.add(['one', 'three']);
      await tester.pumpAndSettle();
      expect(sounds.played.length, 3);
      expect(tester.takeException(), isNull);
    },
  );
}
