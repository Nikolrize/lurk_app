import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/parties/models/party.dart';
import '../features/parties/models/party_matching.dart';
import '../core/data/game_catalog.dart';
import '../services/player_safety_service.dart';
import 'auth_provider.dart';
import 'party_provider.dart';
import 'profile_provider.dart';
import 'rating_provider.dart';

// Only a get of the viewer's own block relationship is permitted, never a list
// of another player's block list.
final hostBlocksViewerProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, host) async* {
      final uid = ref.watch(authStateProvider).asData?.value?.uid;
      if (uid == null || uid == host || host.isEmpty) {
        yield false;
        return;
      }
      final db = FirebaseFirestore.instance;
      final values = <String, bool>{};
      final streams =
          <String, Stream<DocumentSnapshot<Map<String, dynamic>>>>{};
      for (final pair in [(host, uid), (uid, host)]) {
        for (final path in ['blocked', 'users']) {
          final key = '${pair.$1}/$path/${pair.$2}';
          streams[key] = db
              .collection('player_blocks')
              .doc(pair.$1)
              .collection(path)
              .doc(pair.$2)
              .snapshots();
        }
      }
      yield* Stream<bool>.multi((controller) {
        final subscriptions = streams.entries
            .map(
              (entry) => entry.value.listen((doc) {
                values[entry.key] = doc.exists;
                if (values.length == streams.length) {
                  controller.add(values.values.any((value) => value));
                }
              }, onError: controller.addError),
            )
            .toList();
        controller.onCancel = () async {
          for (final subscription in subscriptions) {
            await subscription.cancel();
          }
        };
      });
    }, retry: (retryCount, error) => null);

final recommendedPartiesProvider =
    Provider.autoDispose<AsyncValue<List<Party>>>((ref) {
      final uid = ref.watch(authStateProvider).asData?.value?.uid;
      if (uid == null) return const AsyncData([]);
      final parties = ref.watch(availablePartiesProvider);
      final profile = ref.watch(playerProfileProvider(uid));
      final preferences = ref.watch(gamingPreferencesProvider(uid));
      final rating = ref.watch(ratingSummaryProvider(uid));
      final blocked = ref.watch(blockedPlayersProvider);
      for (final state in [parties, profile, preferences, rating, blocked]) {
        if (state.hasError) return AsyncError(state.error!, state.stackTrace!);
        if (state.asData == null) return const AsyncLoading();
      }
      final prefs = preferences.asData!.value;
      final summary = rating.asData!.value;
      final games = {
        ...prefs.games,
        if (prefs.currentGame != null) prefs.currentGame!,
      };
      final current = ref.watch(currentPartyProvider).asData?.value?.id;
      final candidates = parties.asData!.value
          .where(
            (p) =>
                p.hostId != uid &&
                p.id != current &&
                p.status == 'open' &&
                !p.isFull &&
                games.contains(
                  GameCatalog.find(p.gameId)?.id ??
                      GameCatalog.find(p.gameName)?.id,
                ) &&
                meetsMatchRequirements(
                  p,
                  region: profile.asData!.value?.region,
                  preferences: prefs,
                  rating: summary.count > 0 ? summary.average : null,
                  blockedHosts: blocked.asData!.value,
                ),
          )
          .toList();
      final matches = <Party>[];
      var waiting = false;
      for (final party in candidates) {
        final reverse = ref.watch(hostBlocksViewerProvider(party.hostId));
        if (reverse.hasError) {
          return AsyncError(reverse.error!, reverse.stackTrace!);
        }
        if (reverse.asData == null) {
          waiting = true;
          continue;
        }
        if (!reverse.asData!.value) matches.add(party);
      }
      if (waiting) return const AsyncLoading();
      // Prefer the main game, then the most recently created eligible parties.
      matches.sort((a, b) {
        final main =
            ((GameCatalog.find(b.gameId)?.id ??
                        GameCatalog.find(b.gameName)?.id) ==
                    prefs.currentGame
                ? 1
                : 0) -
            ((GameCatalog.find(a.gameId)?.id ??
                        GameCatalog.find(a.gameName)?.id) ==
                    prefs.currentGame
                ? 1
                : 0);
        return main != 0
            ? main
            : (b.createdAt ?? DateTime(1970)).compareTo(
                a.createdAt ?? DateTime(1970),
              );
      });
      return AsyncData(matches);
    });

final visiblePartiesProvider = Provider.autoDispose<AsyncValue<List<Party>>>((
  ref,
) {
  final source = ref.watch(availablePartiesProvider);
  if (source.asData == null) return source;
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return source;
  final result = <Party>[];
  var waiting = false;
  for (final party in source.asData!.value) {
    final blocked = ref.watch(hostBlocksViewerProvider(party.hostId));
    if (blocked.hasError) {
      return AsyncError(blocked.error!, blocked.stackTrace!);
    }
    if (blocked.asData == null) {
      waiting = true;
      continue;
    }
    if (!blocked.asData!.value) result.add(party);
  }
  return waiting ? const AsyncLoading() : AsyncData(result);
});
