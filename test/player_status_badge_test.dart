import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lurk_app/core/widgets/player_status_badge.dart';
import 'package:lurk_app/models/player_presence.dart';
import 'package:lurk_app/models/player_status.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/presence_provider.dart';

void main() {
  testWidgets(
    'Appear Offline hides an online session in the public badge',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
            playerPresenceProvider('alice').overrideWith(
              (ref) => Stream.value(
                const PlayerPresence(
                  preference: PlayerStatus.offline,
                  sessions: [PlayerStatus.online],
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PlayerStatusBadge(uid: 'alice'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Online'), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsNothing);
    },
  );
}