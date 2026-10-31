import 'package:cloud_firestore/cloud_firestore.dart';

class ChatReceipt {
  const ChatReceipt({this.readThrough});
  final DateTime? readThrough;
  factory ChatReceipt.fromData(Map<String, dynamic>? data) =>
      ChatReceipt(readThrough: (data?['readThrough'] as Timestamp?)?.toDate());
  bool covers(DateTime? time) =>
      time != null && readThrough != null && !time.isAfter(readThrough!);
}
