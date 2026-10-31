import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/rating_provider.dart';

class PlayerRatingSummary extends ConsumerWidget {
  const PlayerRatingSummary({super.key, required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(ratingSummaryProvider(uid))
      .when(
        loading: () => const Text('Loading ratings…'),
        error: (_, stack) => TextButton(
          onPressed: () => ref.invalidate(ratingSummaryProvider(uid)),
          child: const Text('Ratings unavailable. Retry'),
        ),
        data: (summary) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                summary.count == 0
                    ? 'No reviews yet'
                    : '${summary.average.toStringAsFixed(1)} (${summary.count} ${summary.count == 1 ? 'review' : 'reviews'})',
              ),
            ),
          ],
        ),
      );
}
