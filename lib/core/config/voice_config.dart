import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Public client settings only. The Agora certificate stays on the server.
class VoiceConfig {
  const VoiceConfig({required this.appId, required this.tokenUrl});
  static const defaultAppId = '8e12f857aa6641dc894b3a7b241d0b21';
  static const _definedAppId = String.fromEnvironment('AGORA_APP_ID');
  static const _definedTokenUrl = String.fromEnvironment('VOICE_TOKEN_URL');
  static VoiceConfig current = const VoiceConfig(
    appId: _definedAppId == '' ? defaultAppId : _definedAppId,
    tokenUrl: _definedTokenUrl,
  );

  final String appId, tokenUrl;

  static Future<VoiceConfig> load({
    AssetBundle? bundle,
    String appIdOverride = _definedAppId,
    String tokenUrlOverride = _definedTokenUrl,
  }) async {
    var fileAppId = '', fileTokenUrl = '';
    for (final path in ['config/voice.json', 'config/voice.local.json']) {
      try {
        final raw = await (bundle ?? rootBundle).loadString(path);
        final data = jsonDecode(raw);
        if (data is Map<String, dynamic>) {
          final id = data['AGORA_APP_ID'], url = data['VOICE_TOKEN_URL'];
          if (id is String && id.trim().isNotEmpty) fileAppId = id.trim();
          if (url is String && url.trim().isNotEmpty) fileTokenUrl = url.trim();
        }
      } on FlutterError {
        // Local overrides are optional; a fresh clone uses shared settings.
      } on FormatException {
        // Keep valid defaults if a configuration file is malformed.
      }
    }
    return VoiceConfig(
      appId: appIdOverride.trim().isNotEmpty
          ? appIdOverride.trim()
          : fileAppId.isNotEmpty
          ? fileAppId
          : defaultAppId,
      tokenUrl: tokenUrlOverride.trim().isNotEmpty
          ? tokenUrlOverride.trim()
          : fileTokenUrl,
    );
  }
}
