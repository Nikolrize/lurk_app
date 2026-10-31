import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/verification/data/verification_service.dart';
import '../features/verification/data/verification_storage_service.dart';
import '../features/verification/models/verification_request.dart';
import '../features/verification/models/verification_summary.dart';

import 'auth_provider.dart';

final verificationServiceProvider = Provider<VerificationService>((ref) {
  return VerificationService();
});

final verificationStorageServiceProvider =
    Provider<VerificationStorageService>((ref) {
      return VerificationStorageService();
    });

final verificationAdminProvider = StreamProvider.autoDispose<bool>((ref) {
  final auth = ref.watch(authStateProvider);

  if (auth.hasError) {
    return Stream<bool>.error(auth.error!, auth.stackTrace);
  }

  final user = auth.asData?.value;

  if (user == null) {
    return Stream<bool>.value(false);
  }

  return ref
      .watch(verificationServiceProvider)
      .watchIsAdmin(user.uid);
});

final verificationRequestProvider = StreamProvider.autoDispose
    .family<VerificationRequest?, String>((ref, uid) {
      final auth = ref.watch(authStateProvider);

      if (auth.hasError) {
        return Stream<VerificationRequest?>.error(
          auth.error!,
          auth.stackTrace,
        );
      }

      final user = auth.asData?.value;

      if (user == null) {
        return Stream<VerificationRequest?>.value(null);
      }

      final service = ref.watch(verificationServiceProvider);

      if (user.uid == uid) {
        return service.watchRequest(uid);
      }

      final admin = ref.watch(verificationAdminProvider);

      return admin.when(
        loading: () => const Stream<VerificationRequest?>.empty(),
        error: (error, stackTrace) =>
            Stream<VerificationRequest?>.error(error, stackTrace),
        data: (isAdmin) {
          if (!isAdmin) {
            return Stream<VerificationRequest?>.error(
              StateError('You cannot view this submission.'),
            );
          }

          return service.watchRequest(uid);
        },
      );
    });

final verificationSummaryProvider = StreamProvider.autoDispose
    .family<VerificationSummary?, String>((ref, uid) {
      final auth = ref.watch(authStateProvider);

      if (auth.hasError) {
        return Stream<VerificationSummary?>.error(
          auth.error!,
          auth.stackTrace,
        );
      }

      if (auth.asData?.value == null) {
        return Stream<VerificationSummary?>.value(null);
      }

      return ref
          .watch(verificationServiceProvider)
          .watchSummary(uid);
    });

final pendingVerificationsProvider =
    StreamProvider.autoDispose<List<VerificationRequest>>((ref) {
      final admin = ref.watch(verificationAdminProvider);

      return admin.when(
        loading: () => const Stream<List<VerificationRequest>>.empty(),
        error: (error, stackTrace) =>
            Stream<List<VerificationRequest>>.error(error, stackTrace),
        data: (isAdmin) {
          if (!isAdmin) {
            return Stream<List<VerificationRequest>>.error(
              StateError('Administrator access is required.'),
            );
          }

          return ref
              .watch(verificationServiceProvider)
              .watchPendingRequests();
        },
      );
    });