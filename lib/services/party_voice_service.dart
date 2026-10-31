import 'dart:async';
import 'dart:convert';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class VoiceState {
  const VoiceState({
    this.partyId,
    this.connecting = false,
    this.connected = false,
    this.muted = true,
    this.error,
    this.remoteMics = const {},
    this.remoteCount = 0,
    this.inputLevel = 0,
  });
  final String? partyId, error;
  final bool connecting, connected, muted;
  final Map<String, bool> remoteMics;
  final int remoteCount, inputLevel;
}

/// Foreground-only voice for the free local-server demo. No certificate belongs in this client.
class PartyVoiceService with WidgetsBindingObserver {
  static const appId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: '8e12f857aa6641dc894b3a7b241d0b21',
  );
  static const tokenUrl = String.fromEnvironment('VOICE_TOKEN_URL');
  final _changes = StreamController<VoiceState>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  VoiceState state = const VoiceState();
  Stream<VoiceState> get changes => _changes.stream;
  RtcEngine? _engine;
  Timer? _renewTimer;
  Completer<void>? _joined;
  int _generation = 0;
  bool _busy = false, _renewing = false, _observing = false, _disposed = false;
  String? _uid;
  final _accounts = <int, String>{};
  final _remoteMics = <int, bool>{};
  int _inputLevel = 0;
  void _refresh() => _emit(state);
  Future<void> _resolveAccount(int uid, int generation) async {
    try {
      final info = await _engine?.getUserInfoByUid(uid);
      if (_generation == generation && info?.userAccount != null) {
        _accounts[uid] = info!.userAccount!;
        _refresh();
      }
    } catch (_) {
      /* Mapping also arrives through onUserInfoUpdated. */
    }
  }

  void _emit(VoiceState next) {
    state = VoiceState(
      partyId: next.partyId,
      connecting: next.connecting,
      connected: next.connected,
      muted: next.muted,
      error: next.error,
      remoteCount: _remoteMics.length,
      inputLevel: _inputLevel,
      remoteMics: Map.unmodifiable({
        for (final entry in _remoteMics.entries)
          if (_accounts[entry.key] != null) _accounts[entry.key]!: entry.value,
      }),
    );
    if (!_changes.isClosed) _changes.add(state);
  }

  Future<Map<String, dynamic>> _token(String partyId, String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.uid != uid) throw StateError('Sign in again to use voice chat.');
    final idToken = await user!.getIdToken();
    final response = await http
        .post(
          Uri.parse(tokenUrl),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'partyId': partyId}),
        )
        .timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError(
        data['error'] is String
            ? data['error'] as String
            : 'Unable to join voice chat.',
      );
    }
    if (data['appId'] != appId ||
        data['account'] != uid ||
        data['token'] is! String ||
        data['channel'] is! String) {
      throw StateError('Voice server configuration does not match this app.');
    }
    return data;
  }

  Future<void> toggle(String partyId) async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      if (state.connected && state.partyId == partyId) {
        final muted = !state.muted;
        if (muted) {
          await _engine!.muteLocalAudioStream(true);
          await _engine!.enableLocalAudio(false);
        } else {
          await _engine!.enableLocalAudio(true);
          await _engine!.muteLocalAudioStream(false);
        }
        _emit(VoiceState(partyId: partyId, connected: true, muted: muted));
        return;
      }
      final endpoint = Uri.tryParse(tokenUrl);
      if (endpoint == null ||
          !endpoint.hasAuthority ||
          !['http', 'https'].contains(endpoint.scheme)) {
        throw StateError(
          'Voice chat is not configured. Run with config/voice.local.json.',
        );
      }
      if (kReleaseMode && endpoint.scheme != 'https') {
        throw StateError('Release voice chat requires an HTTPS token server.');
      }
      if (kIsWeb ||
          ![
            TargetPlatform.android,
            TargetPlatform.iOS,
          ].contains(defaultTargetPlatform)) {
        throw StateError(
          'Party voice currently supports Android and iOS only.',
        );
      }
      await disconnect();
      final generation = _generation;
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        throw StateError(
          'Allow microphone access in phone settings to use voice chat.',
        );
      }
      if (_generation != generation || _disposed) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Sign in to use voice chat.');
      _uid = uid;
      _emit(VoiceState(partyId: partyId, connecting: true));
      final token = await _token(partyId, uid);
      if (_generation != generation) return;
      final engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(
        const RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      if (_generation != generation) return;
      await engine.enableAudio();
      await engine.disableVideo();
      await engine.enableLocalAudio(true);
      await engine.muteLocalAudioStream(false);
      await engine.enableAudioVolumeIndication(
        interval: 500,
        smooth: 3,
        reportVad: true,
      );
      await engine.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioDefault,
      );
      await engine.setDefaultAudioRouteToSpeakerphone(true);
      final joined = Completer<void>();
      _joined = joined;
      // Attach the error handler before native callbacks can complete the future.
      final connected = joined.future.timeout(const Duration(seconds: 20));
      unawaited(connected.catchError((Object _) {}));
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (!joined.isCompleted) joined.complete();
          },
          onError: (code, message) {
            if (!joined.isCompleted) {
              joined.completeError(
                StateError(
                  'Agora could not connect. Check the project settings and try again.',
                ),
              );
            }
          },
          onConnectionStateChanged: (_, connectionState, reason) {
            if (_generation == generation &&
                connectionState == ConnectionStateType.connectionStateFailed) {
              unawaited(
                disconnect(
                  error: 'Voice connection lost. Tap Mic to reconnect.',
                ),
              );
            }
          },
          onUserJoined: (_, uid, elapsed) {
            if (_generation != generation) return;
            _remoteMics[uid] = true;
            _refresh();
            unawaited(_resolveAccount(uid, generation));
          },
          onUserInfoUpdated: (uid, info) {
            if (_generation != generation || info.userAccount == null) return;
            _accounts[uid] = info.userAccount!;
            _refresh();
          },
          onUserOffline: (_, uid, reason) {
            if (_generation != generation) return;
            _remoteMics.remove(uid);
            _accounts.remove(uid);
            _refresh();
          },
          onUserMuteAudio: (_, uid, muted) {
            if (_generation != generation) return;
            _remoteMics[uid] = !muted;
            _refresh();
            unawaited(_resolveAccount(uid, generation));
          },
          onRemoteAudioStateChanged: (_, uid, audioState, reason, elapsed) {
            if (_generation != generation) return;
            if (reason == RemoteAudioStateReason.remoteAudioReasonRemoteMuted) {
              _remoteMics[uid] = false;
            } else if (audioState ==
                    RemoteAudioState.remoteAudioStateDecoding ||
                reason ==
                    RemoteAudioStateReason.remoteAudioReasonRemoteUnmuted) {
              _remoteMics[uid] = true;
            }
            _refresh();
            unawaited(_resolveAccount(uid, generation));
          },
          onLocalAudioStateChanged: (_, audioState, reason) {
            if (_generation == generation &&
                audioState ==
                    LocalAudioStreamState.localAudioStreamStateFailed) {
              unawaited(
                disconnect(
                  error:
                      'Microphone failed (${reason.name}). Check microphone access and other recording apps.',
                ),
              );
            }
          },
          onAudioVolumeIndication: (_, speakers, speakerCount, total) {
            if (_generation != generation) return;
            _inputLevel = 0;
            for (final speaker in speakers) {
              if (speaker.uid == 0) _inputLevel = speaker.volume ?? 0;
            }
            _refresh();
          },
          onRequestToken: (_) => unawaited(_renew()),
          onTokenPrivilegeWillExpire: (_, token) => unawaited(_renew()),
        ),
      );
      _watchParty(partyId, uid);
      if (!_observing) {
        WidgetsBinding.instance.addObserver(this);
        _observing = true;
      }
      await engine.joinChannelWithUserAccount(
        token: token['token'] as String,
        channelId: token['channel'] as String,
        userAccount: uid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          enableAudioRecordingOrPlayout: true,
          publishMicrophoneTrack: true,
          publishCameraTrack: false,
        ),
      );
      await connected;
      if (_generation != generation) return;
      await engine.muteAllRemoteAudioStreams(false);
      await engine.setEnableSpeakerphone(true);
      _emit(VoiceState(partyId: partyId, connected: true, muted: false));
      _renewTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => unawaited(_renew()),
      );
    } catch (error) {
      final message = error is StateError
          ? error.message.toString()
          : 'Unable to connect voice chat. Check the local server and your connection.';
      await disconnect(error: message);
      throw StateError(message);
    } finally {
      _busy = false;
    }
  }

  void _watchParty(String id, String uid) {
    final party = FirebaseFirestore.instance.collection('parties').doc(id);
    void unavailable(Object error) => unawaited(
      disconnect(
        error: 'Voice disconnected because party access could not be verified.',
      ),
    );
    _subscriptions.add(
      party.snapshots().listen((doc) {
        if (!doc.exists || doc.data()?['status'] != 'open') {
          unawaited(disconnect(error: 'The party session has ended.'));
        }
      }, onError: unavailable),
    );
    _subscriptions.add(
      party.collection('members').doc(uid).snapshots().listen((doc) {
        if (!doc.exists || doc.data()?['leftAt'] != null) {
          unawaited(disconnect(error: 'You are no longer in this party.'));
        }
      }, onError: unavailable),
    );
    _subscriptions.add(
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user?.uid != uid) unawaited(disconnect());
      }),
    );
  }

  Future<void> _renew() async {
    if (_renewing ||
        !state.connected ||
        state.partyId == null ||
        _uid == null) {
      return;
    }
    _renewing = true;
    final generation = _generation;
    try {
      final data = await _token(state.partyId!, _uid!);
      if (_generation == generation) {
        await _engine?.renewToken(data['token'] as String);
      }
    } catch (_) {
      if (_generation == generation) {
        await disconnect(
          error:
              'Voice disconnected. Check your connection and party membership before reconnecting.',
        );
      }
    } finally {
      _renewing = false;
    }
  }

  Future<void> disconnect({String? error}) async {
    _generation++;
    _accounts.clear();
    _remoteMics.clear();
    _inputLevel = 0;
    _renewTimer?.cancel();
    _renewTimer = null;
    final engine = _engine;
    _engine = null;
    final subscriptions = [..._subscriptions];
    _subscriptions.clear();
    final joined = _joined;
    _joined = null;
    if (joined != null && !joined.isCompleted) {
      joined.completeError(StateError('Voice connection cancelled.'));
    }
    _emit(VoiceState(error: error));
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    if (engine != null) {
      try {
        await engine.muteLocalAudioStream(true);
        await engine.leaveChannel();
      } catch (_) {
        /* Already disconnected. */
      }
      try {
        await engine.release();
      } catch (_) {
        /* Engine may already be released. */
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) &&
        (this.state.connected || this.state.connecting)) {
      unawaited(
        disconnect(
          error:
              'Voice paused while the app is in the background. Tap Mic to reconnect.',
        ),
      );
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    await disconnect();
    await _changes.close();
  }
}
