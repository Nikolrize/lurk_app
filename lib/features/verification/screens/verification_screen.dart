import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/verification_provider.dart';
import 'package:lurk_app/features/profile/widgets/profile_page_layout.dart';
import '../models/verification_request.dart';
import '../models/verification_status.dart';
import '../widgets/private_verification_photo.dart';
import '../widgets/verification_submission_form.dart';

class VerificationScreen extends ConsumerWidget {
  const VerificationScreen({super.key, required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).asData?.value;
    if (user?.uid != uid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Identity verification')),
        body: const Center(child: Text('Sign in to view your verification.')),
      );
    }
    final state = ref.watch(verificationRequestProvider(uid));
    return Scaffold(
      appBar: AppBar(title: const Text('Identity verification')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unable to load verification. Check your connection and account permissions.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(verificationRequestProvider(uid)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (request) => ProfilePageLayout(
          introduction: const ProfileIntroduction(
            title: 'Build trust with your teammates',
            description:
                'Submit one ID photo for an admin to review. Your identification details stay separate from your public profile.',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (request != null) ...[
                _VerificationStatusCard(request: request),
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    title: const Text('View submitted ID photo'),
                    leading: const Icon(Icons.lock_outline),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      PrivateVerificationPhoto(
                        viewerUid: uid,
                        path: request.idPhotoPath,
                      ),
                      const SizedBox(height: 8),
                      const Text('Pinch or scroll to zoom.'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (request == null ||
                  request.status == VerificationStatus.rejected)
                VerificationSubmissionForm(
                  key: ValueKey(request?.submissionId ?? 'first-submission'),
                  uid: uid,
                  previousRequest: request,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationStatusCard extends StatelessWidget {
  const _VerificationStatusCard({required this.request});
  final VerificationRequest request;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color, message) = switch (request.status) {
      VerificationStatus.pending => (
        Icons.hourglass_top,
        colors.primary,
        'An admin will review your submission. The result will appear here.',
      ),
      VerificationStatus.verified => (
        Icons.verified,
        colors.secondary,
        'Your ID submission has been approved.',
      ),
      VerificationStatus.rejected => (
        Icons.error_outline,
        colors.error,
        request.rejectionReason,
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    request.status.label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      ),
    );
  }
}
