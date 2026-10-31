import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/parties/models/party_history_entry.dart';
import 'auth_provider.dart';
import 'party_provider.dart';

final partyHistoryProvider =
    StreamProvider.autoDispose<List<PartyHistoryRecord>>((ref) {
      final auth = ref.watch(authStateProvider);
      if (auth.hasError) return Stream.error(auth.error!);
      if (auth.isLoading) return const Stream.empty();
      final uid = auth.asData?.value?.uid;
      if (uid == null) return Stream.value(const []);
      return ref.watch(partyServiceProvider).watchHistory(uid);
    }, retry: (retryCount, error) => null);

final partyHistoryEntryProvider = Provider.autoDispose
    .family<AsyncValue<PartyHistoryEntry?>, PartyHistoryRecord>((ref, record) {
      final membership = ref.watch(myPartyMembershipProvider(record.partyId));
      if (membership.hasError) {
        return AsyncError(membership.error!, membership.stackTrace!);
      }
      if (!membership.hasValue) return const AsyncLoading();
      final member = membership.asData!.value;
      if (member == null) return const AsyncData(null);
      final left = member['leftAt'];
      if (left is Timestamp) {
        return AsyncData(
          PartyHistoryEntry(record: record, endedAt: left.toDate()),
        );
      }
      // Remaining squad members receive the host's closed-party update live.
      // Past private-party members need only their own history and membership.
      final party = ref.watch(partyByIdProvider(record.partyId));
      if (party.hasError) return AsyncError(party.error!, party.stackTrace!);
      if (!party.hasValue) return const AsyncLoading();
      final session = party.asData!.value;
      if (session == null || session.status != 'closed') {
        return const AsyncData(null);
      }
      return AsyncData(
        PartyHistoryEntry(
          record: record,
          endedAt: session.completedAt,
          party: session,
        ),
      );
    });
