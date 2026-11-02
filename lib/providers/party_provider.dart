import 'discovery_limits.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/parties/models/party.dart';
import '../services/party_service.dart';
import 'auth_provider.dart';
import '../core/data/game_catalog.dart'; 

final partyServiceProvider = Provider<PartyService>((ref) => PartyService());

// fetch one extra party to check whether another page exists
final partyDiscoveryPageProvider = StreamProvider.autoDispose<List<Party>>((
  ref,
) {
  final auth = ref.watch(authStateProvider);
  if (auth.hasError) return Stream.error(auth.error!);
  if (auth.isLoading) return const Stream<List<Party>>.empty();
  if (auth.asData?.value == null) return Stream.value(const <Party>[]);
  return ref
      .watch(partyServiceProvider)
      .watchDiscoverableParties(
        limit: ref.watch(partyDiscoveryLimitProvider) + 1,
      );
}, retry: (retryCount, error) => null);

// show Load More only when the extra party confirms more results exist
final hasMorePartiesProvider = Provider.autoDispose<bool>((ref) {
  final page = ref.watch(partyDiscoveryPageProvider).asData?.value;
  return page != null && page.length > ref.watch(partyDiscoveryLimitProvider);
});

// expose only the requested page size without showing the extra record
final availablePartiesProvider = StreamProvider.autoDispose<List<Party>>((ref) {
  final page = ref.watch(partyDiscoveryPageProvider);
  final limit = ref.watch(partyDiscoveryLimitProvider);
  return page.when(
    data: (parties) =>
        Stream.value(parties.take(limit).toList(growable: false)),
    loading: () => const Stream<List<Party>>.empty(),
    error: (error, stack) => Stream<List<Party>>.error(error, stack),
  );
}, retry: (retryCount, error) => null);

// keep the player hosted party updated from Firestore
final currentHostedPartyProvider = StreamProvider.autoDispose<Party?>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.hasError) return Stream.error(auth.error!);
  if (auth.isLoading) return const Stream<Party?>.empty();
  final uid = auth.asData?.value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(partyServiceProvider).watchLatestHostedParty(uid);
}, retry: (retryCount, error) => null);

// watch one party by ID for previews and lobby updates
final partyByIdProvider = StreamProvider.autoDispose.family<Party?, String>((
  ref,
  id,
) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading) return const Stream<Party?>.empty();
  if (auth.asData?.value == null) return Stream.value(null);
  return ref.watch(partyServiceProvider).watchParty(id);
}, retry: (retryCount, error) => null);

// watch the saved reference to the party this player joined
final joinedPartyIdProvider = StreamProvider.autoDispose<String?>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(partyServiceProvider).watchJoinedPartyId(uid);
}, retry: (count, error) => null);

// resolve the active joined or hosted party and ignore ended memberships
final currentPartyProvider = Provider<AsyncValue<Party?>>((ref) {
  final hosted = ref.watch(currentHostedPartyProvider);
  final joined = ref.watch(joinedPartyIdProvider);
  if (joined.hasError) return AsyncError(joined.error!, joined.stackTrace!);
  final id = joined.asData?.value;
  if (id == null) return hosted;
  final membership = ref.watch(myPartyMembershipProvider(id));
  if (membership.asData != null &&
      (membership.asData!.value == null ||
          membership.asData!.value!['leftAt'] != null)) {
    return hosted;
  }
  final party = ref.watch(partyByIdProvider(id));
  if (party.asData != null &&
      (party.asData!.value == null || party.asData!.value!.status != 'open')) {
    return hosted;
  }
  return party;
});

// watch active squad member IDs for the selected party
final partyMemberIdsProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, id) {
      final uid = ref.watch(authStateProvider).asData?.value?.uid;
      if (uid == null) return const Stream<List<String>>.empty();
      return ref.watch(partyServiceProvider).watchMemberIds(id);
    }, retry: (count, error) => null);

class LobbyNavigation extends Notifier<({Party party, int serial})?> {
  // start without a pending request to open a lobby
  @override
  ({Party party, int serial})? build() => null;
  // request the lobby again even when the party ID has not changed
  void open(Party party) =>
      state = (party: party, serial: (state?.serial ?? 0) + 1);
}

// let party actions ask the app shell to open a lobby
final lobbyNavigationProvider =
    NotifierProvider<LobbyNavigation, ({Party party, int serial})?>(
      LobbyNavigation.new,
    );

// watch the signed in player membership and removal status
final myPartyMembershipProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, id) {
      final uid = ref.watch(authStateProvider).asData?.value?.uid;
      if (uid == null) return const Stream<Map<String, dynamic>?>.empty();
      return ref.watch(partyServiceProvider).watchMembership(id, uid);
    }, retry: (count, error) => null);

// watch all past and current member IDs for a history preview
final partyHistoryMemberIdsProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, id) {
      final uid = ref.watch(authStateProvider).asData?.value?.uid;
      if (uid == null) return Stream.value(const []);
      return ref.watch(partyServiceProvider).watchHistoryMemberIds(id);
    }, retry: (retryCount, error) => null);

// expose the party game only while the player remains an active member
final activePartyGameProvider = Provider.autoDispose<String?>((ref) {
  final partyState = ref.watch(currentPartyProvider);

  if (partyState.isLoading || partyState.hasError) return null;

  final party = partyState.asData?.value;

  if (party == null || party.status != 'open') return null;

  final membershipState = ref.watch(
    myPartyMembershipProvider(party.id),
  );

  if (membershipState.isLoading || membershipState.hasError) {
    return null;
  }

  final membership = membershipState.asData?.value;

  if (membership == null || membership['leftAt'] != null) {
    return null;
  }

  return GameCatalog.find(party.gameId)?.id;
});