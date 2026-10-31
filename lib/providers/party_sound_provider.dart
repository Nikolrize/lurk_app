import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/party_sound_service.dart';
import 'voice_provider.dart';

final partySoundServiceProvider = Provider<PartySoundService>((ref) {
  final service = PartySoundService(
    playInVoice: (path, id) =>
        ref.read(partyVoiceServiceProvider).playPartyEffect(path, id),
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
