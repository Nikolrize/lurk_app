import 'discovery_limits.dart';
import '../services/player_safety_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/player/models/player.dart';
import '../services/player_service.dart';
import 'auth_provider.dart';

final playerServiceProvider = Provider<PlayerService>((ref) => PlayerService());
final playerDiscoveryPageProvider = StreamProvider.autoDispose<List<Player>>((
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
      .watchDiscoverablePlayers(
        uid,
        limit: ref.watch(playerDiscoveryLimitProvider) + 1,
        excludedIds: ids,
      );
}, retry: (retryCount, error) => null);

final hasMorePlayersProvider = Provider.autoDispose<bool>((ref) {
  final page = ref.watch(playerDiscoveryPageProvider).asData?.value;
  return page != null && page.length > ref.watch(playerDiscoveryLimitProvider);
});

final discoverablePlayersProvider = StreamProvider.autoDispose<List<Player>>((
  ref,
) {
  final page = ref.watch(playerDiscoveryPageProvider);
  final limit = ref.watch(playerDiscoveryLimitProvider);
  return page.when(
    data: (players) =>
        Stream.value(players.take(limit).toList(growable: false)),
    loading: () => const Stream<List<Player>>.empty(),
    error: (error, stack) => Stream<List<Player>>.error(error, stack),
  );
}, retry: (retryCount, error) => null);
