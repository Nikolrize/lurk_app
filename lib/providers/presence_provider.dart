import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/player_presence.dart';
import '../services/presence_service.dart';
import 'auth_provider.dart';

final presenceServiceProvider = Provider<PresenceService>((ref) {
  return PresenceService();
});

final playerPresenceProvider = StreamProvider.autoDispose
    .family<PlayerPresence?, String>((ref, uid) {
      final auth = ref.watch(authStateProvider);

      if (auth.hasError) {
        return Stream<PlayerPresence?>.error(auth.error!);
      }

      final user = auth.asData?.value;

      if (user == null) {
        return Stream<PlayerPresence?>.value(null);
      }

      return ref.watch(presenceServiceProvider).watchPresence(uid);
    });

//connection provider
final presenceConnectionProvider = StreamProvider.autoDispose<bool>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;

  if (user == null) {
    return Stream<bool>.value(false);
  }

  return ref.watch(presenceServiceProvider).connectionChanges;
});