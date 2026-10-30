import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.createdAt,
    this.pending = false,
    this.type = 'text',
    this.partyId,
  });
  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;
  final bool pending;
  final String type;
  final String? partyId;
  bool get isPartyInvite => type == 'party_invite';

  factory ChatMessage.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String,
      text: data['text'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      pending: doc.metadata.hasPendingWrites,
      type: data['type'] as String? ?? 'text',
      partyId: data['partyId'] as String?,
    );
  }
}
