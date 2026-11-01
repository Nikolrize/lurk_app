import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/presence_provider.dart';
import 'package:lurk_app/services/firebase_service.dart';
import 'package:lurk_app/services/presence_service.dart';

import 'package:lurk_app/providers/party_provider.dart';

class PresenceScope extends ConsumerStatefulWidget {
  const PresenceScope({
    super.key,
    required this.uid,
    required this.child,
  });

  final String uid;
  final Widget child;

  @override
  ConsumerState<PresenceScope> createState() =>
      _PresenceScopeState();
}

class _PresenceScopeState extends ConsumerState<PresenceScope> {
  late final PresenceService _service;
  late final FirebaseService _authService;
  late final String _sessionId; // identifies running app instance
  late final Future<void> Function() _logoutCleanup;
  late final AppLifecycleListener _lifecycle; //detects background/foreground changes

  StreamSubscription<bool>? _connectionSubscription;
  Timer? _retryTimer;

  ProviderSubscription<String?>? _partySubscription;
  String? _gameId;

  Future<void> _operations = Future<void>.value(); //runs session updates in sequence
  Future<void>? _stopFuture;

  bool _running = true;
  bool _connected = false;
  bool _registered = false;
  bool _idle = false;
  bool _failed = false;

  int _connectionRevision = 0; //stops outdated connection work from being treated as curret 

  @override
  void initState() {
    super.initState();

    _service = ref.read(presenceServiceProvider);
    _authService = ref.read(firebaseServiceProvider);
    _sessionId = _service.createSessionId();

    _partySubscription = ref.listenManual<String?>(
      activePartyGameProvider,
      (previous, gameId) {
        if (!_running || _gameId == gameId) return;

        _gameId = gameId;
        _queueSync();
      },
      fireImmediately: true,
    );

    final initialState = WidgetsBinding.instance.lifecycleState;
    _idle = initialState != null &&
        initialState != AppLifecycleState.resumed;

    _logoutCleanup = _stop;
    _authService.beforeSignOut = _logoutCleanup;

    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (!_running) return;

        _idle = state != AppLifecycleState.resumed;
        _queueSync();
      },
    );

    _connectionSubscription = _service.connectionChanges.listen( //detects connection and reconnection
      (connected) {
        if (!_running) return;

        _connectionRevision++;
        _connected = connected;
        _registered = false;

        if (connected) {
          _queueSync();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _reportFailure(error);
      },
    );

    unawaited(_connect());
  }

  Future<void> _connect() async {
    try {
      await _service.connect();
    } catch (error) {
      _reportFailure(error);
    }
  }

  void _queueSync() {
    if (!_running || !_connected) return;

    final revision = _connectionRevision;

    _operations = _operations.then((_) async {
      bool isCurrent() =>
          _running &&
          _connected &&
          revision == _connectionRevision;

      if (!isCurrent()) return;

      if (!_registered) {
        await _service.openSession(
          expectedUid: widget.uid,
          sessionId: _sessionId,
          idle: _idle,
          shouldContinue: isCurrent,
          gameId: _gameId,
        );

        if (!isCurrent()) return;
        _registered = true;
      }

      //uses the latest lifecycle state after registration finishes
      await _service.updateSession(
        expectedUid: widget.uid,
        sessionId: _sessionId,
        idle: _idle,
        gameId: _gameId,
      );

      if (isCurrent() && mounted && _failed) {
        setState(() {
          _failed = false;
        });
      }
    }).catchError((Object error, StackTrace stackTrace) {
      if (!_running || revision != _connectionRevision) return;

      _registered = false;
      _reportFailure(error);
    });
  }

  void _reportFailure(Object error) {
    if (!_running) return;

    debugPrint('Presence update failed: $error');

    if (mounted && !_failed) {
      setState(() {
        _failed = true;
      });
    }

    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 10), () {
      if (_running && _connected) {
        _queueSync();
      }
    });
  }

  Future<void> _stop() {
    return _stopFuture ??= _stopInternal();
  }

  Future<void> _stopInternal() async {
    _running = false;
    _connectionRevision++;

    _retryTimer?.cancel();
    await _connectionSubscription?.cancel();

    try {
      //removes session while account is still authenticated
      await _service.closeSession(
        expectedUid: widget.uid,
        sessionId: _sessionId,
      ).timeout(const Duration(seconds: 3));
    } catch (error) {
      //dropped connection must not leave logout wiating indefinitely
      debugPrint('Presence cleanup deferred to disconnect: $error');
    }

    try {
      //server-side disconnect cleanup remains the fallback
      await _service.disconnect();
    } catch (error) {
      debugPrint('Presence disconnect failed: $error');
    }
  }

  @override
  void dispose() {
    _partySubscription?.close();
    _lifecycle.dispose();

    if (_authService.beforeSignOut == _logoutCleanup) {
      _authService.beforeSignOut = null;
    }

    unawaited(_stop());

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_failed) return widget.child;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Unable to update your online status.'),
                  ),
                  TextButton(
                    onPressed: _queueSync,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}