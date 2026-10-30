import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/availability/widgets/availability_summary_card.dart';
import 'package:lurk_app/features/player/models/player_availability.dart';
import 'package:lurk_app/features/profile/screens/player_profile_screen.dart';
import 'package:lurk_app/features/profile/widgets/gaming_preferences_card.dart';
import 'package:lurk_app/models/gaming_preferences.dart';
import 'package:lurk_app/models/player_profile.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/profile_provider.dart';
import 'package:lurk_app/services/player_safety_service.dart';

void main() {
  for (final blocked in [false, true]) {
    testWidgets(
      'merged profile preserves preferences, schedule and actions (blocked=$blocked)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(null)),
              blockedPlayersProvider.overrideWith(
                (ref) => Stream.value(blocked ? {'peer'} : <String>{}),
              ),
              playerProfileProvider('peer').overrideWith(
                (ref) => Stream.value(
                  const PlayerProfile(
                    uid: 'peer',
                    username: 'Alex',
                    bio: 'Team player',
                    region: 'Malaysia',
                    createdAt: null,
                    updatedAt: null,
                  ),
                ),
              ),
              gamingPreferencesProvider('peer').overrideWith(
                (ref) => Stream.value(
                  const GamingPreferences(
                    games: ['valorant'],
                    currentGame: 'valorant',
                    communication: 'chat_only',
                  ),
                ),
              ),
              playerAvailabilityProvider('peer').overrideWith(
                (ref) => Stream.value(
                  const PlayerAvailability(
                    availableNow: true,
                    preferredTimes: {'Evening'},
                    weeklySchedule: [
                      WeeklyGamingSlot(
                        weekday: 1,
                        startMinute: 1200,
                        endMinute: 1320,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: PlayerProfileScreen(uid: 'peer')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Alex'), findsOneWidget);
        expect(find.byType(GamingPreferencesCard), findsOneWidget);
        expect(find.text('Valorant'), findsOneWidget);
        expect(find.byType(AvailabilitySummaryCard), findsOneWidget);
        expect(find.text('Looking for a game'), findsOneWidget);
        expect(find.text('Mon'), findsOneWidget);
        expect(find.text('Report'), findsOneWidget);
        expect(find.text(blocked ? 'Unblock' : 'Block'), findsOneWidget);
        final invite = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Invite to Party'),
        );
        expect(invite.onPressed, blocked ? isNull : isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
