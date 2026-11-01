import 'discovery_limits.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/parties/models/party.dart';
import '../services/party_service.dart';
import 'auth_provider.dart';

final partyServiceProvider = Provider<PartyService>((ref) => PartyService());

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

// Fetch one extra party to determine whether another page actually exists.
final hasMorePartiesProvider = Provider.autoDispose<bool>((ref) {
  final page = ref.watch(partyDiscoveryPageProvider).asData?.value;
  return page != null && page.length > ref.watch(partyDiscoveryLimitProvider);
});

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

// Host-owned parties remain available alongside the current joined squad.
final currentHostedPartyProvider = StreamProvider.autoDispose<Party?>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.hasError) return Stream.error(auth.error!);
  if (auth.isLoading) return const Stream<Party?>.empty();
  final uid = auth.asData?.value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(partyServiceProvider).watchLatestHostedParty(uid);
}, retry: (retryCount, error) => null);

final partyByIdProvider = StreamProvider.autoDispose.family<Party?, String>((
  ref,
  id,
) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading) return const Stream<Party?>.empty();
  if (auth.asData?.value == null) return Stream.value(null);
  return ref.watch(partyServiceProvider).watchParty(id);
}, retry: (retryCount, error) => null);

final joinedPartyIdProvider = StreamProvider.autoDispose<String?>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(partyServiceProvider).watchJoinedPartyId(uid);
}, retry: (count, error) => null);

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

final partyMemberIdsProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, id) {
      final uid = ref.watch(authStateProvider).asData?.value?.uid;
      if (uid == null) return const Stream<List<String>>.empty();
      return ref.watch(partyServiceProvider).watchMemberIds(id);
    }, retry: (count, error) => null);

class LobbyNavigation extends Notifier<({Party party, int serial})?> {
  @override
  ({Party party, int serial})? build() => null;
  void open(Party party) =>
      state = (party: party, serial: (state?.serial ?? 0) + 1);
}

final lobbyNavigationProvider =
    NotifierProvider<LobbyNavigation, ({Party party, int serial})?>(
      LobbyNavigation.new,
    );

final myPartyMembershipProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, id) {
      final uid = ref.watch(authStateProvider).asData?.value?.uid;
      if (uid == null) return const Stream<Map<String, dynamic>?>.empty();
      return ref.watch(partyServiceProvider).watchMembership(id, uid);
    }, retry: (count, error) => null);

final partyHistoryMemberIdsProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, id) {
      final uid = ref.watch(authStateProvider).asData?.value?.uid;
      if (uid == null) return Stream.value(const []);
      return ref.watch(partyServiceProvider).watchHistoryMemberIds(id);
    }, retry: (retryCount, error) => null);
