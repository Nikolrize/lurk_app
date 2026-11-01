import 'package:flutter/material.dart';

import 'package:lurk_app/features/player/models/player_availability.dart';

class AvailabilityDayCard extends StatelessWidget {
  const AvailabilityDayCard({
    super.key,
    required this.weekday,
    required this.slot,
    required this.onChanged,
    this.enabled = true,
  });

  final int weekday;
  final WeeklyGamingSlot? slot;
  final ValueChanged<WeeklyGamingSlot?> onChanged;
  final bool enabled;

  String _formatTime(BuildContext context, int minutes) {
    if (minutes == 1440) return 'Midnight (end of day)';

    return TimeOfDay(
      hour: minutes ~/ 60,
      minute: minutes % 60,
    ).format(context);
  }

  Future<void> _pickTime(
    BuildContext context, {
    required bool pickingStart,
  }) async {
    final current = slot;

    if (current == null || !enabled) return;

    final minutes = pickingStart
        ? current.startMinute
        : current.endMinute;

    final selected = await showTimePicker( //returns selected time, or null when cancelled
      context: context,
      initialTime: TimeOfDay(
        hour: (minutes ~/ 60) % 24,
        minute: minutes % 60,
      ),
      helpText: pickingStart
          ? 'Choose start time - Malaysia time'
          : 'Choose end time - Malaysia time',
    );

    if (!context.mounted || selected == null) return;

    final selectedMinutes = selected.hour * 60 + selected.minute;

    final updated = WeeklyGamingSlot(
      weekday: weekday,
      startMinute:
          pickingStart ? selectedMinutes : current.startMinute,
      endMinute:
          pickingStart ? current.endMinute : selectedMinutes,
    );

    if (updated.startMinute == updated.endMinute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start and end times must be different.'),
        ),
      );
      return;
    }

    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final current = slot;

    final overnight = current != null &&
        current.endMinute < current.startMinute;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                PlayerAvailability.weekdays[weekday - 1],
              ),
              subtitle: Text(
                current == null ? 'Not scheduled' : 'Scheduled',
              ),
              value: current != null,
              onChanged: !enabled
                  ? null
                  : (selected) {
                      onChanged(
                        selected
                            ? WeeklyGamingSlot(
                                weekday: weekday,
                                startMinute: 1200,
                                endMinute: 1320,
                              )
                            : null,
                      );
                    },
            ),
            if (current != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: !enabled
                        ? null
                        : () => _pickTime(
                              context,
                              pickingStart: true,
                            ),
                    child: Text(
                      'From ${_formatTime(context, current.startMinute)}',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: !enabled
                        ? null
                        : () => _pickTime(
                              context,
                              pickingStart: false,
                            ),
                    child: Text(
                      'Until ${_formatTime(context, current.endMinute)}',
                    ),
                  ),
                ],
              ),
              if (overnight) ...[
                const SizedBox(height: 8),
                const Text('Ends the following day.'),
              ],
            ],
          ],
        ),
      ),
    );
  }
}