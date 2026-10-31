import 'dart:convert';
import '../features/chat/models/chat_receipt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/chat/models/chat.dart';
import '../features/chat/models/chat_message.dart';
import '../features/player/models/player.dart';
import '../features/parties/models/party.dart';
import '../features/chat/models/chat_settings.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  static int countUnread(
    Iterable<ChatMessage> messages,
    String uid,
    DateTime? after,
  ) => messages
      .where(
        (message) =>
            message.senderId != uid &&
            !message.pending &&
            message.createdAt != null &&
            (after == null || message.createdAt!.isAfter(after)),
      )
      .length;

  Stream<int> watchUnreadCount(String chatId, String uid, DateTime? after) {
    Query<Map<String, dynamic>> query = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages');
    if (after != null) {
      query = query.where(
        'createdAt',
        isGreaterThan: Timestamp.fromDate(after),
      );
    }
    return query
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => countUnread(
            snapshot.docs.map(ChatMessage.fromDocument),
            uid,
            after,
          ),
        );
  }

  Stream<ChatReceipt> watchReceipt(String chatId, String uid) => _db
      .collection('chats')
      .doc(chatId)
      .collection('receipts')
      .doc(uid)
      .snapshots()
      .map((doc) => ChatReceipt.fromData(doc.data()));

  Future<void> markRead(String chatId, String uid, ChatMessage message) async {
    if (message.pending || message.createdAt == null) return;
    final receipt = _db
        .collection('chats')
        .doc(chatId)
        .collection('receipts')
        .doc(uid);
    await _db.runTransaction((tx) async {
      final previous = ChatReceipt.fromData((await tx.get(receipt)).data());
      if (previous.covers(message.createdAt)) return;
      tx.set(receipt, {
        'messageId': message.id,
        'readThrough': Timestamp.fromDate(message.createdAt!),
      });
    });
  }

  Stream<ChatSettings> watchSettings(String chatId, String uid) => _db
      .collection('chats')
      .doc(chatId)
      .collection('settings')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .map((doc) {
        final settings = ChatSettings.fromData(doc.data());
        return doc.metadata.hasPendingWrites && settings.clearedAt == null
            ? ChatSettings(clearedAt: DateTime.now())
            : settings;
      });

  Future<void> clearHistory(String chatId, String uid) => _db
      .collection('chats')
      .doc(chatId)
      .collection('settings')
      .doc(uid)
      .set({'clearedAt': FieldValue.serverTimestamp()});

  Stream<Player?> watchPlayer(String uid) => _db
      .collection('players')
      .doc(uid)
      .snapshots()
      .map(
        (doc) =>
            doc.exists ? Player.fromFirestoreData(doc.id, doc.data()!) : null,
      );

  Stream<Party?> watchInviteParty(String id) => _db
      .collection('parties')
      .doc(id)
      .snapshots()
      .map(
        (doc) =>
            doc.exists ? Party.fromFirestoreData(doc.id, doc.data()!) : null,
      );

  static String directId(String first, String second) {
    final ids = [first, second]..sort();
    return base64Url.encode(utf8.encode(jsonEncode(ids))).replaceAll('=', '');
  }

  Stream<List<Chat>> watchChats(String uid) => _db
      .collection('chats')
      .where('userIds', arrayContains: uid)
      .snapshots()
      .map((snapshot) {
        // This inbox already loads all of the user's chats. Sort the loaded
        // results so reading does not depend on a composite index being ready.
        final chats = snapshot.docs.map(Chat.fromDocument).toList();
        chats.sort((a, b) {
          final order = (b.updatedAt ?? DateTime(1970)).compareTo(
            a.updatedAt ?? DateTime(1970),
          );
          return order != 0 ? order : a.id.compareTo(b.id);
        });
        return chats;
      });

  Stream<List<ChatMessage>> watchMessages(
    String id, {
    int limit = 50,
    DateTime? after,
  }) {
    Query<Map<String, dynamic>> query = _db
        .collection('chats')
        .doc(id)
        .collection('messages');
    if (after != null) {
      query = query.where(
        'createdAt',
        isGreaterThan: Timestamp.fromDate(after),
      );
    }
    return query
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => snapshot.docs.map(ChatMessage.fromDocument).toList(),
        );
  }

  Future<String> openDirect(String uid, String otherUid) async {
    if (uid == otherUid || uid.isEmpty || otherUid.isEmpty) {
      throw ArgumentError('Choose another player.');
    }
    final id = directId(uid, otherUid);
    final chat = _db.collection('chats').doc(id);
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(chat);
      if (!existing.exists) {
        final first = await transaction.get(_db.collection('players').doc(uid));
        final second = await transaction.get(
          _db.collection('players').doc(otherUid),
        );
        transaction.set(chat, {
          'type': 'direct',
          'userIds': [uid, otherUid]..sort(),
          'participantUsernames': {
            uid: first.data()!['username'],
            otherUid: second.data()!['username'],
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessageId': '',
          'lastMessagePreview': '',
          'lastSenderId': '',
        });
      }
    });
    return id;
  }

  Future<void> sendMessage(String chatId, String uid, String text) async {
    final clean = text.trim();
    if (clean.isEmpty || clean.length > 2000) {
      throw ArgumentError('Messages must contain 1–2000 characters.');
    }
    await _send(chatId, uid, clean, {'type': 'text'});
  }

  Future<void> sendPartyInvite(
    String chatId,
    String uid,
    String partyId,
  ) async {
    if (partyId.isEmpty || partyId.contains('/')) {
      throw ArgumentError('Choose a valid party.');
    }
    // Firestore rules independently verify host, visibility and open status.
    await _send(chatId, uid, 'Party invitation', {
      'type': 'party_invite',
      'partyId': partyId,
    });
  }

  Future<void> _send(
    String chatId,
    String uid,
    String text,
    Map<String, dynamic> extra,
  ) async {
    final chat = _db.collection('chats').doc(chatId);
    final message = chat.collection('messages').doc();
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(chat);
      final ids = List<String>.from(existing.data()!['userIds'] as List);
      final names = <String, String>{};
      for (final id in ids) {
        final player = await transaction.get(_db.collection('players').doc(id));
        names[id] = player.data()!['username'] as String;
      }
      transaction.set(message, {
        'senderId': uid,
        'senderUsername': names[uid],
        'text': text,
        ...extra,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(chat, {
        'participantUsernames': names,
        'lastMessageId': message.id,
        'lastMessagePreview': text,
        'lastSenderId': uid,
        'lastSenderUsername': names[uid],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
