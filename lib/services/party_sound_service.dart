import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'party_membership_events.dart';

class PartySoundService {
  PartySoundService({required this.playInVoice});
  final Future<bool> Function(String path, int id) playInVoice;
  final _cache = AudioCache();
  AudioPlayer? _player;
  Future<void> _queue = Future.value();
  bool _disposed = false;
  // queue sound effects so they do not overlap or interrupt the voice session
  void play(PartySound sound) {
    _queue = _queue.then((_) async {
      if (_disposed) return;
      try {
        final asset = 'sounds/party_${sound.name}.wav';
        final path = await _cache.loadPath(asset);
        if (_disposed) return;
        // play sound effects in call
        if (!await playInVoice(path, switch (sound) {
          PartySound.join => 101,
          PartySound.leave => 102,
          PartySound.mute => 103,
          PartySound.unmute => 104,
        })) {
          if (_disposed) return;
          var player = _player;
          if (player == null) {
            player = AudioPlayer();
            _player = player;
            await player.setAudioContext(
              AudioContextConfig(
                focus: AudioContextConfigFocus.mixWithOthers,
              ).build(),
            );
          }
          if (_disposed) return;
          await player.play(AssetSource(asset), volume: .5);
        }
        await Future<void>.delayed(const Duration(milliseconds: 380));
      } catch (error) {
        debugPrint('Party sound could not play: ${error.runtimeType}');
      }
    });
  }

  // stop future sound requests and release the player and cached audio
  Future<void> dispose() async {
    _disposed = true;
    await _player?.dispose();
    await _cache.clearAll();
  }
}
