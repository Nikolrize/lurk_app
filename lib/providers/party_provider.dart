import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/parties/models/party.dart';
import '../services/party_service.dart';
import 'auth_provider.dart';

final partyServiceProvider = Provider<PartyService>((ref) => PartyService());

final availablePartiesProvider = StreamProvider.autoDispose<List<Party>>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.hasError) return Stream.error(auth.error!);
  if (auth.isLoading) return const Stream<List<Party>>.empty();
  if (auth.asData?.value == null) return Stream.value(const <Party>[]);
  return ref.watch(partyServiceProvider).watchDiscoverableParties();
}, retry: (retryCount, error) => null);

// Current host-owned party. Joined-party membership will be added with joining.
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
