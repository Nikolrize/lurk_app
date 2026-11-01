import 'package:cloud_firestore/cloud_firestore.dart';
import 'party.dart';

/// A private reference and party summary captured when this player joined.
class PartyHistoryRecord {
  const PartyHistoryRecord({
    required this.partyId,
    required this.title,
    required this.gameId,
    required this.mode,
    required this.joinedAt,
  });
  final String partyId, title, gameId, mode;
  final DateTime? joinedAt;

  factory PartyHistoryRecord.fromMap(String id, Map<String, dynamic> data) =>
      PartyHistoryRecord(
        partyId: id,
        title: data['title'] as String? ?? 'Party',
        gameId: data['gameId'] as String? ?? '',
        mode: data['mode'] as String? ?? '',
        joinedAt: data['joinedAt'] is Timestamp
            ? (data['joinedAt'] as Timestamp).toDate()
            : null,
      );
}

class PartyHistoryEntry {
  const PartyHistoryEntry({
    required this.record,
    required this.endedAt,
    this.party,
    this.participationDuration,
  });
  final PartyHistoryRecord record;
  final DateTime? endedAt;
  final Party? party;
  final Duration? participationDuration;
  String get title => party?.title ?? record.title;
  String get gameId => party?.gameId ?? record.gameId;
  String get mode => party?.mode ?? record.mode;
  Duration? get duration {
    if (participationDuration != null) return participationDuration;
    final start = record.joinedAt, end = endedAt;
    return start == null || end == null || end.isBefore(start)
        ? null
        : end.difference(start);
  }
}
