import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  const Chat({
    required this.id,
    required this.userIds,
    required this.preview,
    required this.lastSenderId,
    this.updatedAt,
  });

  final String id;
  final List<String> userIds;
  final String preview;
  final String lastSenderId;
  final DateTime? updatedAt;

  String otherUid(String uid) => userIds.firstWhere((id) => id != uid);

  factory Chat.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Chat(
      id: doc.id,
      userIds: List<String>.from(data['userIds'] as List),
      preview: data['lastMessagePreview'] as String,
      lastSenderId: data['lastSenderId'] as String,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
