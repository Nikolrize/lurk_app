import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Public endpoint only. Firebase server credentials belong in Worker secrets.
class NotificationTriggerService {
  static const endpoint = String.fromEnvironment(
    'NOTIFICATION_WORKER_URL',
    defaultValue: 'https://lurk-notifications.zychong1121.workers.dev/notify',
  );

  static Future<void> notify({
    required FirebaseFirestore firestore,
    required String uid,
    required String conversationId,
    required String messageId,
    bool party = false,
  }) async {
    if (endpoint.isEmpty) return;
    final client = http.Client();
    try {
      final uri = Uri.parse(endpoint);
      if (uri.scheme != 'https' ||
          !uri.hasAuthority ||
          uri.userInfo.isNotEmpty) {
        throw StateError('Notification endpoint must use HTTPS.');
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != uid) return;
      final token = await user.getIdToken().timeout(
        const Duration(seconds: 10),
      );
      if (token == null) return;
      final recipients = <String?>[null];
      if (party) {
        final members = await firestore
            .collection('parties')
            .doc(conversationId)
            .collection('members')
            .where('leftAt', isNull: true)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 10));
        recipients
          ..clear()
          ..addAll(
            members.docs.where((doc) => doc.id != uid).map((doc) => doc.id),
          );
      }
      await Future.wait(
        recipients.map((recipient) async {
          // Retry transient transport/server failures using the same deterministic
          // server claim. A failed push must never make the saved chat look unsent.
          for (var attempt = 0; attempt < 2; attempt++) {
            try {
              final response = await client
                  .post(
                    uri,
                    headers: {
                      'Authorization': 'Bearer $token',
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode({
                      'kind': party ? 'party' : 'direct',
                      'conversationId': conversationId,
                      'messageId': messageId,
                      'recipientId': ?recipient,
                    }),
                  )
                  .timeout(const Duration(seconds: 15));
              if (response.statusCode == 200) return;
              debugPrint(
                'Notification Worker returned HTTP ${response.statusCode}.',
              );
              if (response.statusCode < 500 && response.statusCode != 429) {
                break;
              }
            } catch (_) {
              // One bounded retry; no sensitive response data is logged.
            }
            if (attempt == 0) {
              await Future<void>.delayed(const Duration(milliseconds: 500));
            }
          }
          debugPrint('Notification request failed; message is saved.');
        }),
      );
    } catch (_) {
      debugPrint('Notification request unavailable; message is saved.');
    } finally {
      client.close();
    }
  }
}
