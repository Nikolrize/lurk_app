import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/core/theme/app_theme.dart';
import 'package:lurk_app/features/find/screens/find_screen.dart';

void main() {
  testWidgets('Find switches lists, searches and filters players', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: FindSreen()),
      ),
    );
    expect(find.text('Late Night Ranked'), findsOneWidget);
    expect(find.text('Jay'), findsNothing);
    await tester.enterText(find.byType(TextField), 'no-match');
    await tester.pump();
    expect(find.text('0 parties found'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    await tester.tap(find.text('Player'));
    await tester.pumpAndSettle();
    expect(find.text('Jay'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Late Night Ranked'), findsNothing);
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active players only'));
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(find.text('Jay'), findsOneWidget);
    expect(find.text('Alex'), findsNothing);
    expect(find.text('1 players found'), findsOneWidget);
    await tester.tap(find.text('Party'));
    await tester.pumpAndSettle();
    expect(find.text('3 parties found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
