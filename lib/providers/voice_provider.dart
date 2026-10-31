import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/party_voice_service.dart';

final partyVoiceServiceProvider = Provider<PartyVoiceService>((ref) {
  final service = PartyVoiceService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
final voiceStateProvider = StreamProvider<VoiceState>((ref) async* {
  final service = ref.watch(partyVoiceServiceProvider);
  yield service.state;
  yield* service.changes;
});
