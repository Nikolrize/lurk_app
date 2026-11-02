import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/core/config/voice_config.dart';

class ConfigBundle extends CachingAssetBundle {
  ConfigBundle(this.contents);
  final String? contents;

  @override
  Future<ByteData> load(String key) async {
    expect(key, 'config/voice.json');
    final value = contents;
    if (value == null) throw FlutterError('Asset is missing');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Plain launch reads the shared voice configuration', () async {
    final config = await VoiceConfig.load(
      bundle: ConfigBundle(
        '{"AGORA_APP_ID":"shared-app","VOICE_TOKEN_URL":"https://voice.example.com/voice/token"}',
      ),
    );
    expect(config.appId, 'shared-app');
    expect(config.tokenUrl, 'https://voice.example.com/voice/token');
  });

  test('A configuration without an App ID uses the default App ID', () async {
    final config = await VoiceConfig.load(
      bundle: ConfigBundle(
        '{"VOICE_TOKEN_URL":"https://voice.example.com/voice/token"}',
      ),
    );
    expect(config.appId, VoiceConfig.defaultAppId);
    expect(config.tokenUrl, 'https://voice.example.com/voice/token');
  });

  test('Explicit launch settings override shared settings', () async {
    final config = await VoiceConfig.load(
      bundle: ConfigBundle(
        '{"AGORA_APP_ID":"shared-app","VOICE_TOKEN_URL":"https://shared.example.com/voice/token"}',
      ),
      appIdOverride: 'override-app',
      tokenUrlOverride: 'https://override.example.com/voice/token',
    );
    expect(config.appId, 'override-app');
    expect(config.tokenUrl, 'https://override.example.com/voice/token');
  });

  test(
    'Blank overrides preserve shared settings and values are trimmed',
    () async {
      final config = await VoiceConfig.load(
        bundle: ConfigBundle(
          '{"AGORA_APP_ID":" shared-app ","VOICE_TOKEN_URL":" https://voice.example.com/voice/token "}',
        ),
        appIdOverride: ' ',
        tokenUrlOverride: ' ',
      );
      expect(config.appId, 'shared-app');
      expect(config.tokenUrl, 'https://voice.example.com/voice/token');
    },
  );

  test(
    'Missing, malformed or empty shared settings use safe defaults',
    () async {
      for (final contents in [
        null,
        'invalid-json',
        '[]',
        '{}',
        '{"AGORA_APP_ID":7,"VOICE_TOKEN_URL":null}',
      ]) {
        final config = await VoiceConfig.load(bundle: ConfigBundle(contents));
        expect(config.tokenUrl, isEmpty);
        expect(config.appId, VoiceConfig.defaultAppId);
      }
    },
  );
}
