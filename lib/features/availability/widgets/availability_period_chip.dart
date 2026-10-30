import 'package:flutter/material.dart';

class AvailabilityPeriodChip extends StatelessWidget {
  const AvailabilityPeriodChip({
    super.key,
    required this.period,
  });

  final String period;

  static IconData iconFor(String period) {
    return switch (period) {
      'Morning' => Icons.wb_cloudy_outlined,
      'Afternoon' => Icons.wb_sunny_outlined,
      'Evening' => Icons.wb_twilight,
      'Night' => Icons.nights_stay_outlined,
      _ => Icons.schedule,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        iconFor(period),
        size: 18,
        color: Theme.of(context).colorScheme.secondary,
      ),
      label: Text(period),
    );
  }
}