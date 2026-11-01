import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/features/player/models/player_availability.dart';
import 'package:lurk_app/providers/profile_provider.dart';

import 'availability_period_chip.dart';

class AvailabilitySummaryCard extends ConsumerWidget {
  const AvailabilitySummaryCard({
    super.key,
    required this.uid,
    this.onEdit,
  });

  final String uid;
  final VoidCallback? onEdit;

  String _formatTime(BuildContext context, int minutes) {
    if (minutes == 1440) return 'Midnight (end of day)';

    return TimeOfDay(
      hour: minutes ~/ 60,
      minute: minutes % 60,
    ).format(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerAvailabilityProvider(uid));
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: state.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stackTrace) => TextButton(
            onPressed: () {
              ref.invalidate(playerAvailabilityProvider(uid));
            },
            child: const Text('Unable to load availability. Retry'),
          ),
          data: (availability) {
            final slots = availability.weeklySchedule.toList()
              ..sort((a, b) => a.weekday.compareTo(b.weekday));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      availability.availableNow
                          ? Icons.sports_esports_outlined
                          : Icons.schedule_outlined,
                      color: colors.secondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        availability.availableNow
                            ? 'Looking for a game'
                            : 'Not looking right now',
                        style: text.titleMedium,
                      ),
                    ),
                    if (onEdit != null)
                      IconButton(
                        onPressed: onEdit,
                        tooltip: 'Edit availability',
                        icon: const Icon(Icons.edit_outlined),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Usually plays',
                  style: text.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                if (availability.preferredTimes.isEmpty)
                  const Text('No preferred periods set.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final period in PlayerAvailability.gamingTimes)
                        if (availability.preferredTimes.contains(period))
                          AvailabilityPeriodChip(period: period),
                    ],
                  ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                if (slots.isEmpty)
                  const Text('No weekly schedule set.')
                else ...[
                  for (final slot in slots)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              PlayerAvailability.weekdays[
                                slot.weekday - 1
                              ],
                              style: text.labelLarge,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${_formatTime(context, slot.startMinute)}'
                              ' - '
                              '${_formatTime(context, slot.endMinute)}'
                              '${slot.endMinute < slot.startMinute ? ' (next day)' : ''}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Malaysia time (UTC+8)',
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}