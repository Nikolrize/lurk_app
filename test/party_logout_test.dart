import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/services/firebase_service.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'alice';
}

class _Auth extends Fake implements FirebaseAuth {
  final events = <String>[];
  User? user = _User();
  @override
  User? get currentUser => user;
  @override
  Future<void> signOut() async {
    events.add('signOut');
    user = null;
  }
}

void main() {
  test(
    'Party cleanup finishes before presence cleanup and auth sign-out',
    () async {
      final auth = _Auth();
      final service = FirebaseService(
        auth: auth,
        leaveParties: (uid) async {
          expect(uid, 'alice');
          expect(auth.currentUser, isNotNull);
          auth.events.add('leaveParty');
        },
        unregisterNotifications: () async {
          auth.events.add('notifications');
        },
      );
      service.beforeSignOut = () async {
        auth.events.add('presence');
      };
      await service.signOut();
      expect(auth.events, [
        'leaveParty',
        'notifications',
        'presence',
        'signOut',
      ]);
    },
  );
  test(
    'A failed party departure keeps authentication and presence available for retry',
    () async {
      final auth = _Auth();
      var attempts = 0;
      final service = FirebaseService(
        auth: auth,
        leaveParties: (_) async {
          if (++attempts == 1) throw StateError('Offline');
        },
        unregisterNotifications: () async {
          auth.events.add('notifications');
        },
      );
      service.beforeSignOut = () async {
        auth.events.add('presence');
      };
      await expectLater(service.signOut(), throwsStateError);
      expect(auth.currentUser, isNotNull);
      expect(auth.events, isEmpty);
      await service.signOut();
      expect(auth.currentUser, isNull);
    },
  );
}
