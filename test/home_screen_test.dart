import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/core/theme/app_theme.dart';
import 'package:lurk_app/core/widgets/app_shell.dart';
import 'package:lurk_app/providers/auth_provider.dart';

void main() {
  testWidgets('Home fits a narrow phone and navigation switches tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hey, Player'), findsOneWidget);
    expect(find.text('Quick Match'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Quick Match'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.text('Parties'));
    await tester.pumpAndSettle();
    expect(find.text('Create Party'), findsOneWidget);
    expect(find.text('Back to Current Party'), findsOneWidget);
    await tester.tap(find.text('Party History'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Completed sessions will appear here once party history is connected.',
      ),
      findsOneWidget,
    );
    Navigator.of(
      tester.element(
        find.text(
          'Completed sessions will appear here once party history is connected.',
        ),
      ),
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Jay'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Jay').first, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
