import 'voice_token_client.dart';
import '../core/config/voice_config.dart';
import 'voice_activity_tracker.dart';
import 'dart:async';
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
    this.serverWaking = false,
    this.connected = false,
    this.muted = true,
    this.error,
    this.remoteMics = const {},
    this.remoteCount = 0,
    this.inputLevel = 0,
    this.speakingPlayers = const {},
  });
  final String? partyId, error;
  final bool connecting, connected, muted, serverWaking;
  final Map<String, bool> remoteMics;
  final Set<String> speakingPlayers;
  final int remoteCount, inputLevel;
}

/// Foreground-only voice for the free local-server demo. No certificate belongs in this client.
class PartyVoiceService with WidgetsBindingObserver {
  static String get appId => VoiceConfig.current.appId;
  static String get tokenUrl => VoiceConfig.current.tokenUrl;
  bool get configured => tokenUrl.isNotEmpty;
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
  final _activity = VoiceActivityTracker();
  Set<int> get _speaking => _activity.activeAt(DateTime.now());
  Timer? _speakingExpiry;
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
      serverWaking: next.serverWaking,
      connected: next.connected,
      muted: next.muted,
      error: next.error,
      remoteCount: _remoteMics.length,
      inputLevel: _inputLevel,
      speakingPlayers: Set.unmodifiable({
        if (_uid != null &&
            next.connected &&
            !next.muted &&
            _speaking.contains(0))
          _uid!,
        for (final uid in _speaking)
          if (uid != 0 && _accounts[uid] != null && _remoteMics[uid] == true)
            _accounts[uid]!,
      }),
      remoteMics: Map.unmodifiable({
        for (final entry in _remoteMics.entries)
          if (_accounts[entry.key] != null) _accounts[entry.key]!: entry.value,
      }),
    );
    if (!_changes.isClosed) _changes.add(state);
  }

  Future<Map<String, dynamic>> _token(
    String partyId,
    String uid, {
    bool warmUp = false,
    void Function(bool waiting)? onServerWaitChanged,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.uid != uid) throw StateError('Sign in again to use voice chat.');
    final idToken = await user!.getIdToken();
    final client = http.Client();
    late Map<String, dynamic> data;
    try {
      data = await VoiceTokenClient(client: client).request(
        endpoint: Uri.parse(tokenUrl),
        idToken: idToken!,
        partyId: partyId,
        warmUp: warmUp,
        onServerWaitChanged: onServerWaitChanged,
      );
    } finally {
      client.close();
    }
    if (data['appId'] != appId ||
        data['account'] != uid ||
        data['token'] is! String ||
        data['channel'] is! String) {
      throw StateError('Voice server configuration does not match this app.');
    }
    return data;
  }

  /// Mic controls never join a channel or start capture without permission.
  Future<void> toggle(String partyId) async {
    if (_busy || _disposed || !state.connected || state.partyId != partyId) {
      return;
    }
    _busy = true;
    final generation = _generation;
    try {
      final muted = !state.muted;
      if (!muted) {
        final permission = await Permission.microphone.request();
        if (_generation != generation || _disposed) return;
        if (!permission.isGranted) {
          _emit(
            VoiceState(
              partyId: partyId,
              connected: true,
              muted: true,
              error:
                  'Allow microphone access in phone settings to unmute. You can still listen.',
            ),
          );
          return;
        }
      }
      final engine = _engine;
      if (engine == null || _generation != generation) return;
      if (muted) {
        await engine.muteLocalAudioStream(true);
        await engine.enableLocalAudio(false);
      } else {
        await engine.enableLocalAudio(true);
        await engine.updateChannelMediaOptions(
          const ChannelMediaOptions(publishMicrophoneTrack: true),
        );
        await engine.muteLocalAudioStream(false);
      }
      if (_generation == generation) {
        _emit(VoiceState(partyId: partyId, connected: true, muted: muted));
      }
    } finally {
      _busy = false;
    }
  }

  /// Join as a listener. Capture remains disabled until the player unmutes.
  Future<void> connect(String partyId) async {
    if (_busy || _disposed || (state.connected && state.partyId == partyId)) {
      return;
    }
    _busy = true;
    try {
      final endpoint = Uri.tryParse(tokenUrl);
      if (endpoint == null ||
          !endpoint.hasAuthority ||
          !['http', 'https'].contains(endpoint.scheme)) {
        throw StateError(
          'Voice chat is not configured. Set VOICE_TOKEN_URL in config/voice.local.json and restart the app.',
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Sign in to use voice chat.');
      _uid = uid;
      _emit(VoiceState(partyId: partyId, connecting: true));
      final token = await _token(
        partyId,
        uid,
        warmUp: true,
        onServerWaitChanged: (waiting) {
          if (_generation == generation && !_disposed) {
            _emit(
              VoiceState(
                partyId: partyId,
                connecting: true,
                serverWaking: waiting,
              ),
            );
          }
        },
      );
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        throw StateError('Sign in again to use voice chat.');
      }
      if (_generation != generation) return;
      final engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      if (_generation != generation) return;
      await engine.enableLocalAudio(false);
      await engine.muteLocalAudioStream(true);
      await engine.enableAudio();
      await engine.disableVideo();
      await engine.enableAudioVolumeIndication(
        interval: 200,
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
                  error: 'Voice connection lost. Tap Join voice to reconnect.',
                ),
              );
            }
          },
          onUserJoined: (_, uid, elapsed) {
            if (_generation != generation) return;
            _remoteMics.putIfAbsent(uid, () => false);
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
            _activity.remove(uid);
            _remoteMics.remove(uid);
            _accounts.remove(uid);
            _refresh();
          },
          onUserMuteAudio: (_, uid, muted) {
            if (_generation != generation) return;
            _remoteMics[uid] = !muted;
            if (muted) _activity.remove(uid);
            _refresh();
            unawaited(_resolveAccount(uid, generation));
          },
          onRemoteAudioStateChanged: (_, uid, audioState, reason, elapsed) {
            if (_generation != generation) return;
            if (reason == RemoteAudioStateReason.remoteAudioReasonRemoteMuted) {
              _remoteMics[uid] = false;
              _activity.remove(uid);
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
            final levels = <int, int>{};
            for (final speaker in speakers) {
              final uid = speaker.uid;
              if (uid == null) continue;
              final volume = speaker.volume ?? 0;
              levels[uid] = volume;
              if (uid == 0) {
                _inputLevel = volume;
              } else if (volume > 10) {
                // Received audio confirms publishing even if a mute event was missed.
                _remoteMics[uid] = true;
                if (!_accounts.containsKey(uid)) {
                  unawaited(_resolveAccount(uid, generation));
                }
              }
            }
            _activity.update(levels, DateTime.now());
            _speakingExpiry ??= Timer.periodic(
              const Duration(milliseconds: 200),
              (_) {
                if (_generation != generation || _disposed) return;
                if (!_speaking.contains(0)) _inputLevel = 0;
                _refresh();
              },
            );
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
          publishMicrophoneTrack: false,
          publishCameraTrack: false,
        ),
      );
      await connected;
      if (_generation != generation) return;
      await engine.muteAllRemoteAudioStreams(false);
      await engine.setEnableSpeakerphone(true);
      _emit(VoiceState(partyId: partyId, connected: true, muted: true));
      _renewTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => unawaited(_renew()),
      );
    } catch (error) {
      final message = error is StateError
          ? error.message.toString()
          : 'Unable to connect voice chat. Check your connection and try Join voice again.';
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
    _speakingExpiry?.cancel();
    _speakingExpiry = null;
    _activity.clear();
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
              'Voice paused while the app is in the background. Tap Join voice to reconnect.',
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
