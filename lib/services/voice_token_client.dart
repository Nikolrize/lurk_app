import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Initial connections may wait for Render Free to wake. Renewals stay bounded.
class VoiceTokenClient {
  VoiceTokenClient({
    required this.client,
    this.startupTimeout = const Duration(seconds: 90),
    this.requestTimeout = const Duration(seconds: 15),
    this.wakeNoticeDelay = const Duration(seconds: 3),
  });
  final http.Client client;
  final Duration startupTimeout, requestTimeout, wakeNoticeDelay;

  Future<Map<String, dynamic>> request({
    required Uri endpoint,
    required String idToken,
    required String partyId,
    bool warmUp = false,
    void Function(bool waiting)? onServerWaitChanged,
  }) async {
    if (warmUp) {
      final notice = Timer(
        wakeNoticeDelay,
        () => onServerWaitChanged?.call(true),
      );
      try {
        final health = await client
            .get(endpoint.resolve('/health'))
            .timeout(startupTimeout);
        if (health.statusCode != 200) {
          throw StateError(
            'Voice server is starting or unavailable. Please try Join voice again shortly.',
          );
        }
      } finally {
        notice.cancel();
        onServerWaitChanged?.call(false);
      }
    }
    final response = await client
        .post(
          endpoint,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'partyId': partyId}),
        )
        .timeout(requestTimeout);
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw StateError(
        'Voice server is unavailable. Please try Join voice again shortly.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Voice server returned an invalid response.');
    }
    if (response.statusCode != 200) {
      throw StateError(
        decoded['error'] is String
            ? decoded['error'] as String
            : 'Unable to join voice chat.',
      );
    }
    return decoded;
  }
}
