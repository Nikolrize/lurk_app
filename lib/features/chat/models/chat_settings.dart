import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSettings {
  const ChatSettings({this.clearedAt});
  final DateTime? clearedAt;
  factory ChatSettings.fromData(Map<String, dynamic>? data) =>
      ChatSettings(clearedAt: (data?['clearedAt'] as Timestamp?)?.toDate());
}
