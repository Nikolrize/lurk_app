import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lurk_app/services/voice_token_client.dart';

void main() {
  test('Slow startup shows waiting status and clears it when ready', () async {
    final ready = Completer<void>();
    final events = <bool>[];
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        await ready.future;
        return http.Response('{"ready":true}', 200);
      }
      return http.Response('{"token":"test"}', 200);
    });
    final result =
        VoiceTokenClient(
          client: client,
          wakeNoticeDelay: Duration.zero,
        ).request(
          endpoint: Uri.parse('https://voice.example.com/voice/token'),
          idToken: 'id',
          partyId: 'squad',
          warmUp: true,
          onServerWaitChanged: events.add,
        );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(events, [true]);
    ready.complete();
    await result;
    expect(events, [true, false]);
    client.close();
  });
  test('Fast startup cancels the delayed waking notice', () async {
    final events = <bool>[];
    final client = MockClient(
      (request) async => http.Response(
        request.method == 'GET' ? '{"ready":true}' : '{"token":"test"}',
        200,
      ),
    );
    await VoiceTokenClient(client: client).request(
      endpoint: Uri.parse('https://voice.example.com/voice/token'),
      idToken: 'id',
      partyId: 'squad',
      warmUp: true,
      onServerWaitChanged: events.add,
    );
    expect(events, [false]);
    client.close();
  });
  test(
    'Initial connection warms the server before sending authenticated token request',
    () async {
      final methods = <String>[];
      final ready = Completer<void>();
      final client = MockClient((request) async {
        methods.add(request.method);
        if (request.method == 'GET') {
          expect(request.url.path, '/health');
          expect(request.headers.containsKey('Authorization'), isFalse);
          await ready.future;
          return http.Response('{"ready":true}', 200);
        }
        expect(request.url.path, '/voice/token');
        expect(request.headers['Authorization'], 'Bearer firebase-id-token');
        expect(jsonDecode(request.body), {'partyId': 'squad'});
        return http.Response('{"token":"test-token"}', 200);
      });
      final future = VoiceTokenClient(client: client).request(
        endpoint: Uri.parse('https://voice.example.com/voice/token'),
        idToken: 'firebase-id-token',
        partyId: 'squad',
        warmUp: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(methods, ['GET']);
      ready.complete();
      expect((await future)['token'], 'test-token');
      expect(methods, ['GET', 'POST']);
      client.close();
    },
  );

  test('Renewal skips cold start and preserves membership denial', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      return http.Response(
        '{"error":"Only active party members can use voice chat."}',
        403,
      );
    });
    await expectLater(
      VoiceTokenClient(client: client).request(
        endpoint: Uri.parse('https://voice.example.com/voice/token'),
        idToken: 'id-token',
        partyId: 'squad',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Only active party members'),
        ),
      ),
    );
    client.close();
  });

  test('A failed wakeup does not send the Firebase token', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      return http.Response('Starting...', 503);
    });
    await expectLater(
      VoiceTokenClient(client: client).request(
        endpoint: Uri.parse('https://voice.example.com/voice/token'),
        idToken: 'id-token',
        partyId: 'squad',
        warmUp: true,
      ),
      throwsStateError,
    );
    client.close();
  });
}
