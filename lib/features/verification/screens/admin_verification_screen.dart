import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/verification_provider.dart';

import 'admin_verification_review_screen.dart';

class AdminVerificationScreen extends ConsumerStatefulWidget {
  const AdminVerificationScreen({
    super.key,
    required this.uid,
  });

  final String uid;

  @override
  ConsumerState<AdminVerificationScreen> createState() =>
      _AdminVerificationScreenState();
}

class _AdminVerificationScreenState
    extends ConsumerState<AdminVerificationScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;

    final service = ref.read(firebaseServiceProvider);

    setState(() => _signingOut = true);

    try {
      await service.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to sign out. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _signingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;

    if (user?.uid != widget.uid) {
      return const Scaffold(
        body: Center(
          child: Text('Sign in with an administrator account.'),
        ),
      );
    }

    final access = ref.watch(verificationAdminProvider);

    if (access.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (access.hasError) {
      return Scaffold(
        body: Center(
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
      return const Scaffold(
        body: Center(
          child: Text('Administrator access is required.'),
        ),
      );
    }

    final state = ref.watch(pendingVerificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification admin'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: _signingOut ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  child: Icon(
                                    Icons.admin_panel_settings_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Chip(label: Text('Admin')),
                                      Text(
                                        user?.email ?? 'Administrator',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Review identity submissions '
                                        'and approve or reject them.',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Pending requests',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ),
                ...state.when<List<Widget>>(
                  loading: () => [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  ],
                  error: (error, stackTrace) => [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text(
                              'Unable to load requests. '
                              'Check your connection and permissions.',
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () {
                                ref.invalidate(
                                  pendingVerificationsProvider,
                                );
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  data: (requests) {
                    if (requests.isEmpty) {
                      return [
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text('No pending verifications.'),
                            ),
                          ),
                        ),
                      ];
                    }

                    return [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          24,
                        ),
                        sliver: SliverList.builder(
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final request = requests[index];
                            final submitted = request.submittedAt;

                            return Card(
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                leading: const Icon(
                                  Icons.badge_outlined,
                                ),
                                title: Text(
                                  request.fullName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  submitted == null
                                      ? 'Submission received'
                                      : 'Submitted ${MaterialLocalizations.of(context).formatMediumDate(submitted.toLocal())}',
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                ),
                                onTap: _signingOut
                                    ? null
                                    : () {
                                        Navigator.of(context).push<void>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                AdminVerificationReviewScreen(
                                                  adminUid: widget.uid,
                                                  playerUid: request.uid,
                                                  submissionId:
                                                      request.submissionId,
                                                ),
                                          ),
                                        );
                                      },
                              ),
                            );
                          },
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}