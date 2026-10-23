import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lurk_app/features/authentication/account_form_screen.dart';
import 'package:lurk_app/features/authentication/auth_gate.dart';
import 'package:lurk_app/providers/auth_provider.dart';

void main() {
  testWidgets('Signed-out users see the login screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('Empty login shows validation errors', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in'));
    await tester.pump();

    expect(find.text('Please enter your email.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
  });

  testWidgets('Sign-up rejects mismatched passwords', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AccountFormScreen(action: AccountAction.signUp),
        ),
      ),
    );

    final fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), 'player@example.com');
    await tester.enterText(fields.at(1), 'TestPassword123!');
    await tester.enterText(fields.at(2), 'DifferentPassword123!');

    final button = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });
}
