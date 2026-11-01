import 'discovery_limits.dart';
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
      return ref
          .watch(partyServiceProvider)
          .watchHistory(uid, limit: ref.watch(historyLimitProvider));
    }, retry: (retryCount, error) => null);

final archivedPartyVisitsProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, partyId) {
      final uid = ref.watch(authStateProvider).asData?.value?.uid;
      if (uid == null) return Stream.value(const []);
      return FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId)
          .collection('visits')
          .where('uid', isEqualTo: uid)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
    }, retry: (retryCount, error) => null);

Duration? participationDuration(
  Map<String, dynamic> member,
  List<Map<String, dynamic>> archived,
  DateTime? end,
) {
  final start = (member['joinedAt'] as Timestamp?)?.toDate();
  if (start == null || end == null || end.isBefore(start)) return null;
  var total = end.difference(start);
  for (final visit in archived) {
    final from = (visit['joinedAt'] as Timestamp?)?.toDate();
    final until = (visit['leftAt'] as Timestamp?)?.toDate();
    if (from != null && until != null && !until.isBefore(from)) {
      total += until.difference(from);
    }
  }
  return total;
}

final partyHistoryEntryProvider = Provider.autoDispose
    .family<AsyncValue<PartyHistoryEntry?>, PartyHistoryRecord>((ref, record) {
      final membership = ref.watch(myPartyMembershipProvider(record.partyId));
      if (membership.hasError) {
        return AsyncError(membership.error!, membership.stackTrace!);
      }
      if (!membership.hasValue) return const AsyncLoading();
      final member = membership.asData!.value;
      if (member == null) return const AsyncData(null);
      final archives = ref.watch(archivedPartyVisitsProvider(record.partyId));
      if (archives.hasError) {
        return AsyncError(archives.error!, archives.stackTrace!);
      }
      if (archives.asData == null) return const AsyncLoading();
      final left = member['leftAt'];
      if (left is Timestamp) {
        return AsyncData(
          PartyHistoryEntry(
            record: record,
            endedAt: left.toDate(),
            participationDuration: participationDuration(
              member,
              archives.asData!.value,
              left.toDate(),
            ),
          ),
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
          participationDuration: participationDuration(
            member,
            archives.asData!.value,
            session.completedAt,
          ),
        ),
      );
    });
