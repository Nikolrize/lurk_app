import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/providers/verification_provider.dart';

class PlayerVerificationBadge extends ConsumerWidget {
  const PlayerVerificationBadge({
    super.key,
    required this.uid,
    this.size = 20,
  });

  final String uid;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(verificationSummaryProvider(uid)).when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (summary) {
        if (summary?.isVerified != true) {
          return const SizedBox.shrink();
        }

        return Tooltip(
          message: 'ID submission approved',
          child: Semantics(
            label: 'Verified player',
            child: Icon(
              Icons.verified,
              size: size,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        );
      },
    );
  }
}