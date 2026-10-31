import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/find/models/filter_preferences.dart';
import 'package:lurk_app/features/find/screens/filter_preferences_screen.dart';
import 'package:lurk_app/features/player/models/player_availability.dart';

void main() {
  testWidgets(
    'Player filter restores and applies a daily time window and reset clears it',
    (tester) async {
      FilterPreferences? result;
      const initial = FilterPreferences(
        scheduleWindow: WeeklyGamingSlot(
          weekday: 1,
          startMinute: 1200,
          endMinute: 1380,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<FilterPreferences>(
                    MaterialPageRoute(
                      builder: (_) => const FilterPreferencesScreen(
                        initial: initial,
                        games: [],
                        forPlayers: true,
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Match a time range'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Match a time range'),
            )
            .value,
        true,
      );
      await tester.scrollUntilVisible(
        find.textContaining('From '),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.textContaining('From '));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TimePickerDialog>(find.byType(TimePickerDialog))
            .initialTime,
        const TimeOfDay(hour: 20, minute: 0),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show Results'));
      await tester.pumpAndSettle();
      expect(result?.scheduleWindow?.weekday, 1);
      expect(result?.scheduleWindow?.startMinute, 1200);
      expect(result?.scheduleWindow?.endMinute, 1380);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show Results'));
      await tester.pumpAndSettle();
      expect(result?.scheduleWindow, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
