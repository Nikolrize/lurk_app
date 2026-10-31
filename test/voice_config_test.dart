import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/core/config/voice_config.dart';

class ConfigBundle extends CachingAssetBundle {
  ConfigBundle(this.contents, {this.sharedContents});
  final String? sharedContents;
  final String? contents;
  @override
  Future<ByteData> load(String key) async {
    expect(['config/voice.json', 'config/voice.local.json'], contains(key));
    final value = key == 'config/voice.json' ? sharedContents : contents;
    if (value == null) throw FlutterError('Asset is missing');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('A fresh checkout uses the shared hosted configuration', () async {
    final config = await VoiceConfig.load(
      bundle: ConfigBundle(
        null,
        sharedContents:
            '{"AGORA_APP_ID":"shared-app","VOICE_TOKEN_URL":"https://voice.example.com/voice/token"}',
      ),
    );
    expect(config.appId, 'shared-app');
    expect(config.tokenUrl, 'https://voice.example.com/voice/token');
  });
  test('Local settings override shared hosted defaults', () async {
    final config = await VoiceConfig.load(
      bundle: ConfigBundle(
        '{"VOICE_TOKEN_URL":"http://192.0.2.10:8787/voice/token"}',
        sharedContents:
            '{"AGORA_APP_ID":"shared-app","VOICE_TOKEN_URL":"https://voice.example.com/voice/token"}',
      ),
    );
    expect(config.appId, 'shared-app');
    expect(config.tokenUrl, 'http://192.0.2.10:8787/voice/token');
  });
  test('Plain launch reads public voice settings from the local asset', () async {
    final config = await VoiceConfig.load(
      bundle: ConfigBundle(
        '{"AGORA_APP_ID":"local-app","VOICE_TOKEN_URL":"http://192.0.2.10:8787/voice/token"}',
      ),
    );
    expect(config.appId, 'local-app');
    expect(config.tokenUrl, 'http://192.0.2.10:8787/voice/token');
  });
  test('Explicit launch settings override local settings', () async {
    final config = await VoiceConfig.load(
      bundle: ConfigBundle(
        '{"AGORA_APP_ID":"local-app","VOICE_TOKEN_URL":"http://192.0.2.10:8787/voice/token"}',
      ),
      appIdOverride: 'override-app',
      tokenUrlOverride: 'https://voice.example.com/voice/token',
    );
    expect(config.appId, 'override-app');
    expect(config.tokenUrl, 'https://voice.example.com/voice/token');
  });
  test(
    'Missing or invalid local config does not stop the rest of the app',
    () async {
      for (final contents in [null, 'invalid-json', '[]']) {
        final config = await VoiceConfig.load(bundle: ConfigBundle(contents));
        expect(config.tokenUrl, isEmpty);
        expect(config.appId, VoiceConfig.defaultAppId);
      }
    },
  );
}
