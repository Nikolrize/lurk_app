import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lurk_app/features/verification/models/verification_request.dart';
import 'package:lurk_app/features/verification/models/verification_status.dart';
import 'package:lurk_app/features/verification/screens/verification_screen.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/verification_provider.dart';

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

VerificationRequest requestWith(VerificationStatus status) =>
    VerificationRequest(
      uid: 'alice',
      submissionId: '550e8400-e29b-41d4-a716-446655440000',
      fullName: 'Sample Player',
      idType: 'nric',
      idNumber: 'DEMO-1234',
      dateOfBirth: DateTime.utc(2000, 1, 1),
      idPhotoPath: 'alice/550e8400-e29b-41d4-a716-446655440000/id.jpg',
      confirmed: true,
      status: status,
      submittedAt: DateTime.utc(2026, 10, 31),
      rejectionReason: status == VerificationStatus.rejected
          ? 'Photo is blurred.'
          : '',
    );
Future<void> pumpScreen(
  WidgetTester tester, {
  VerificationRequest? request,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_User('alice'))),
        verificationRequestProvider.overrideWith(
          (ref, uid) => Stream.value(request),
        ),
      ],
      child: const MaterialApp(home: VerificationScreen(uid: 'alice')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Verification form fits a narrow phone with its keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await pumpScreen(tester);
    await tester.ensureVisible(find.byType(TextFormField).first);
    await tester.tap(find.byType(TextFormField).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Incomplete verification shows form errors without contacting storage',
    (tester) async {
      await pumpScreen(tester);
      await tester.ensureVisible(find.text('Submit for verification'));
      await tester.tap(find.text('Submit for verification'));
      await tester.pumpAndSettle();
      expect(find.text('Use 2-100 characters.'), findsOneWidget);
      expect(find.text('Select your date of birth.'), findsOneWidget);
      expect(find.text('Enter 12 digits, with optional hyphens.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Pending submission hides the submission form', (tester) async {
    await pumpScreen(tester, request: requestWith(VerificationStatus.pending));
    expect(find.text('Pending review'), findsOneWidget);
    expect(find.text('Submit for verification'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Approved submission shows the verified seal', (tester) async {
    await pumpScreen(tester, request: requestWith(VerificationStatus.verified));
    expect(find.byIcon(Icons.verified), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Submit for verification'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Rejected submission shows the reason and a new submission form',
    (tester) async {
      await pumpScreen(
        tester,
        request: requestWith(VerificationStatus.rejected),
      );
      expect(find.text('Photo is blurred.'), findsOneWidget);
      expect(find.text('Submit a new attempt'), findsOneWidget);
      expect(find.text('Sample Player'), findsOneWidget);
      expect(find.text('Choose ID photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Another account cannot open the player submission screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(_User('bob'))),
        ],
        child: const MaterialApp(home: VerificationScreen(uid: 'alice')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to view your verification.'), findsOneWidget);
    expect(find.text('Submit for verification'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
