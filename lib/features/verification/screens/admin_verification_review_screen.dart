import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/verification_provider.dart';

import '../models/verification_request.dart';
import '../models/verification_status.dart';
import '../widgets/private_verification_photo.dart';
import '../widgets/verification_reject_dialog.dart';

class AdminVerificationReviewScreen extends ConsumerStatefulWidget {
  const AdminVerificationReviewScreen({
    super.key,
    required this.adminUid,
    required this.playerUid,
    required this.submissionId,
  });

  final String adminUid;
  final String playerUid;
  final String submissionId;

  @override
  ConsumerState<AdminVerificationReviewScreen> createState() =>
      _AdminVerificationReviewScreenState();
}

class _AdminVerificationReviewScreenState
    extends ConsumerState<AdminVerificationReviewScreen> {
  bool _reviewing = false;

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _approve() async {
    if (_reviewing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve submission?'),
        content: const Text(
          'This will mark the player as verified. '
          'Confirm that you have reviewed their ID photo and details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    await _review(approve: true);
  }

  Future<void> _reject() async {
    if (_reviewing) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const VerificationRejectDialog(),
    );

    if (!mounted || reason == null) return;

    await _review(
      approve: false,
      reason: reason,
    );
  }

  Future<void> _review({
    required bool approve,
    String reason = '',
  }) async {
    if (_reviewing) return;

    final service = ref.read(verificationServiceProvider);

    setState(() => _reviewing = true);

    try {
      await service.reviewRequest(
        expectedAdminUid: widget.adminUid,
        playerUid: widget.playerUid,
        expectedSubmissionId: widget.submissionId,
        approve: approve,
        rejectionReason: reason,
      );

      if (!mounted) return;

      _message(
        approve ? 'Submission approved.' : 'Submission rejected.',
      );

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on StateError catch (error) {
      _message(error.message);
    } on ArgumentError catch (error) {
      _message(error.message.toString());
    } on FirebaseException catch (error) {
      _message(
        error.code == 'permission-denied'
            ? 'You do not have permission to review this submission.'
            : 'Unable to save the review. '
                'Check your connection and retry.',
      );
    } catch (_) {
      _message('Unable to save the review. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _reviewing = false);
      }
    }
  }

  Widget _page(Widget child) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review verification')),
      body: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(authStateProvider).asData?.value;

    if (actor?.uid != widget.adminUid) {
      return _page(
        const Center(
          child: Text('This admin session is no longer active.'),
        ),
      );
    }

    final access = ref.watch(verificationAdminProvider);

    if (access.isLoading) {
      return _page(
        const Center(child: CircularProgressIndicator()),
      );
    }

    if (access.hasError) {
      return _page(
        Center(
          child: FilledButton(
            onPressed: () {
              ref.invalidate(verificationAdminProvider);
            },
            child: const Text('Unable to check admin access. Retry'),
          ),
        ),
      );
    }

    if (access.asData?.value != true) {
      return _page(
        const Center(
          child: Text('Administrator access is required.'),
        ),
      );
    }

    final state = ref.watch(
      verificationRequestProvider(widget.playerUid),
    );

    return PopScope(
      canPop: !_reviewing,
      child: _page(
        state.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: FilledButton(
              onPressed: () {
                ref.invalidate(
                  verificationRequestProvider(widget.playerUid),
                );
              },
              child: const Text('Unable to load request. Retry'),
            ),
          ),
          data: (request) {
            if (request == null) {
              return const Center(
                child: Text('This request no longer exists.'),
              );
            }

            if (request.submissionId != widget.submissionId) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'This submission was replaced. '
                    'Return to the inbox and open the latest request.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return _details(context, request);
          },
        ),
      ),
    );
  }

  Widget _details(
    BuildContext context,
    VerificationRequest request,
  ) {
    final pending = request.status == VerificationStatus.pending;

    final date = MaterialLocalizations.of(context).formatMediumDate(
      DateTime(
        request.dateOfBirth.year,
        request.dateOfBirth.month,
        request.dateOfBirth.day,
      ),
    );

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'ID submission',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Chip(
                    avatar: Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 18,
                    ),
                    label: Text('Admin'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detail(context, 'Full name', request.fullName),
                      _detail(
                        context,
                        'ID type',
                        request.idType == 'nric' ? 'NRIC' : 'Passport',
                      ),
                      _detail(context, 'ID number', request.idNumber),
                      _detail(context, 'Date of birth', date),
                      _detail(context, 'Status', request.status.label),
                      if (request.rejectionReason.isNotEmpty)
                        _detail(
                          context,
                          'Rejection reason',
                          request.rejectionReason,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Private ID photo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              PrivateVerificationPhoto(
                viewerUid: widget.adminUid,
                path: request.idPhotoPath,
              ),
              const SizedBox(height: 8),
              const Text(
                'Pinch or scroll to zoom and inspect the photo.',
              ),
              const SizedBox(height: 24),
              if (pending && request.uid != widget.adminUid)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _reviewing ? null : _approve,
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Approve'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _reviewing ? null : _reject,
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                    ),
                  ],
                )
              else
                Text(
                  pending
                      ? 'You cannot review your own submission.'
                      : 'This submission has already been reviewed.',
                ),
              if (_reviewing) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(
    BuildContext context,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
  }
}