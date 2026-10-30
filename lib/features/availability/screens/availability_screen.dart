import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/features/player/models/player_availability.dart';
import 'package:lurk_app/providers/profile_provider.dart';

import '../widgets/availability_day_card.dart';

import 'package:firebase_core/firebase_core.dart';

//loads saved information
class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availabilityState = ref.watch(
      playerAvailabilityProvider(uid),
    ); //listens to the provider for this player

    return Scaffold(
      appBar: AppBar(title: const Text('Availability')),
      body: availabilityState.when(
        //chooses what to show
        loading: () => const Center(
          //spinner
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          // retry button
          child: FilledButton(
            onPressed: () {
              ref.invalidate(playerAvailabilityProvider(uid));
            },
            child: const Text('Unable to load availability. Retry'),
          ),
        ),
        data: (availability) => _AvailabilityForm(
          //editing form
          key: ValueKey(uid),
          uid: uid,
          initialData: availability,
        ),
      ),
    );
  }
}

// holds unsaved choices
class _AvailabilityForm extends ConsumerStatefulWidget {
  const _AvailabilityForm({
    super.key,
    required this.uid,
    required this.initialData,
  });

  final String uid;
  final PlayerAvailability initialData;

  @override
  ConsumerState<_AvailabilityForm> createState() => _AvailabilityFormState();
}

class _AvailabilityFormState extends ConsumerState<_AvailabilityForm> {
  late bool _availableNow;
  late Set<String> _preferredTimes;
  late Map<int, WeeklyGamingSlot> _schedule;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _availableNow = widget
        .initialData
        .availableNow; // copies saved setting into local variable
    _preferredTimes = Set<String>.of(
      widget.initialData.preferredTimes,
    ); // creates an editable copy of the selected periods
    _schedule = {
      for (final slot in widget.initialData.weeklySchedule) slot.weekday: slot,
    }; // copies saved scheduled entires into the form, organized by weekday
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final slots = _schedule.values.toList()
      ..sort((a, b) => a.weekday.compareTo(b.weekday));

    final availability = PlayerAvailability(
      availableNow: _availableNow,
      preferredTimes: Set<String>.of(_preferredTimes),
      weeklySchedule: slots,
    );

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(profileServiceProvider).saveMyAvailability(
        expectedUid: widget.uid,
        availability: availability,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on ArgumentError catch (error) {
      if (!mounted) return;

      _showMessage(error.message.toString());
    } on FirebaseException catch (error) {
      if (!mounted) return;

      _showMessage(
        error.code == 'permission-denied'
            ? 'Unable to save availability. Check the published rules.'
            : 'Unable to save. Check your connection and try again.',
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage('Unable to save. Reopen availability and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_isSaving,
      child: AbsorbPointer(
        absorbing: _isSaving,
        child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                Text('When do you like to play?', style: text.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  'Your availability is visible to signed-in players. '
                  'Weekly schedules use Malaysia time (UTC+8).',
                ),
                const SizedBox(height: 24),
                Card(
                  child: SwitchListTile(
                    title: const Text('Available now'),
                    subtitle: const Text(
                      'Let other players know you are looking for a game.',
                    ),
                    value: _availableNow,
                    onChanged: (value) {
                      setState(() {
                        //stores new value and asks flutter to rebuild interface
                        _availableNow = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Text('Preferred gaming times', style: text.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Choose your usual periods. '
                  'Leave empty if you have no preference.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final period in PlayerAvailability.gamingTimes)
                      FilterChip(
                        label: Text(period),
                        selected: _preferredTimes.contains(period),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _preferredTimes.add(period);
                            } else {
                              _preferredTimes.remove(period);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Weekly schedule', style: text.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Enable the days you usually play and choose one time slot per day. '
                  'All times are Malaysia time (UTC+8).',
                ),
                const SizedBox(height: 12),
                for (var day = 1; day <= 7; day++)
                  AvailabilityDayCard(
                    weekday: day,
                    slot: _schedule[day],
                    onChanged: (slot) {
                      setState(() {
                        if (slot == null) {
                          _schedule.remove(day);
                        } else {
                          _schedule[day] = slot;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save availability',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
