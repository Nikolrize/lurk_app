import '../services/player_safety_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/player/models/player.dart';
import '../services/player_service.dart';
import 'auth_provider.dart';

final playerServiceProvider = Provider<PlayerService>((ref) => PlayerService());
final discoverablePlayersProvider = StreamProvider.autoDispose<List<Player>>((
  ref,
) {
  final auth = ref.watch(authStateProvider);
  if (auth.hasError) return Stream.error(auth.error!);
  if (auth.isLoading) return const Stream<List<Player>>.empty();
  final uid = auth.asData?.value?.uid;
  if (uid == null) return Stream.value(const <Player>[]);
  final blocked = ref.watch(blockedPlayersProvider);
  if (blocked.hasError) return Stream.error(blocked.error!);
  if (!blocked.hasValue) return const Stream<List<Player>>.empty();
  final ids = blocked.requireValue;
  return ref
      .watch(playerServiceProvider)
      .watchDiscoverablePlayers(uid)
      .map(
        (players) =>
            players.where((player) => !ids.contains(player.id)).toList(),
      );
}, retry: (retryCount, error) => null);
