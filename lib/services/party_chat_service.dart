import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'notification_trigger_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/chat/models/chat_message.dart';

class PartyChatService {
  PartyChatService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Stream<List<ChatMessage>> watchMessages(String partyId, int limit) => _db
      .collection('parties')
      .doc(partyId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .orderBy(FieldPath.documentId, descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) => snapshot.docs.map(ChatMessage.fromDocument).toList());

  Future<void> send(String partyId, String uid, String text) async {
    final clean = text.trim();
    if (clean.isEmpty || clean.length > 2000) {
      throw ArgumentError('Messages must contain 1–2000 characters.');
    }
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Please sign in again.');
    }
    final message = _db
        .collection('parties')
        .doc(partyId)
        .collection('messages')
        .doc();
    await _db.runTransaction((tx) async {
      final player = await tx.get(_db.collection('players').doc(uid));
      tx.set(message, {
        'senderId': uid,
        'senderUsername': player.data()!['username'],
        'type': 'text',
        'text': clean,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    unawaited(
      NotificationTriggerService.notify(
        firestore: _db,
        uid: uid,
        conversationId: partyId,
        messageId: message.id,
        party: true,
      ),
    );
  }
}
