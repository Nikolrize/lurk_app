import '../../../core/data/game_catalog.dart';
import '../../player/models/player_availability.dart';
import 'package:flutter/material.dart';
import '../models/filter_preferences.dart';
import 'package:lurk_app/core/data/gaming_regions.dart';

class FilterPreferencesScreen extends StatefulWidget {
  const FilterPreferencesScreen({
    super.key,
    required this.initial,
    required this.games,
    required this.forPlayers,
    this.regions = GamingRegions.values,
  });
  final FilterPreferences initial;
  final List<String> games;
  final bool forPlayers;
  final List<String> regions;
  @override
  State<FilterPreferencesScreen> createState() =>
      _FilterPreferencesScreenState();
}

class _FilterPreferencesScreenState extends State<FilterPreferencesScreen> {
  String? _game, _region, _mode, _communication;
  Set<String> _playstyles = {};
  bool _availableNowOnly = false;
  Set<String> _preferredTimes = {};
  int? _weekday;
  bool _matchScheduleTime = false;
  int _scheduleStart = 18 * 60, _scheduleEnd = 23 * 60;
  int? _maxPartySize;
  late RangeValues _ranks;
  late double _rating;
  late bool _onlyAvailable;

  List<String> get _rankNames => FilterPreferences.ranksForGame(_game);

  void _changeGame(String? value) {
    _game = value;

    final names = _rankNames;

    _ranks = names.isEmpty
        ? const RangeValues(0, 0)
        : RangeValues(0, (names.length - 1).toDouble());
  }

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _game = GameCatalog.find(f.game)?.name ?? f.game;
    _region = f.region;
    _mode = f.mode;
    _playstyles = Set.of(f.playstyles);
    _communication = f.communication;
    _availableNowOnly = f.availableNowOnly;
    _preferredTimes = Set.of(f.preferredTimes);
    _weekday = f.scheduleWindow?.weekday;
    final window = f.scheduleWindow;
    _matchScheduleTime =
        window != null && (window.startMinute != 0 || window.endMinute != 0);
    if (_matchScheduleTime) {
      _scheduleStart = window!.startMinute;
      _scheduleEnd = window.endMinute % 1440;
    }
    _maxPartySize = f.maxPartySize;
    final names = _rankNames;
    //restores selected range while keeping slider within bounds
    if (names.isEmpty) {
      _ranks = const RangeValues(0, 0);
    } else {
      final last = names.length - 1;
      final start = f.minRank.clamp(0, last).toDouble();
      final end = (f.maxRank ?? last).clamp(start.toInt(), last).toDouble();

      _ranks = RangeValues(start, end);
    }
    _rating = f.minimumRating;
    _onlyAvailable = f.onlyAvailable;
  }

  void _reset() => setState(() {
    _game = null;
    _region = null;
    _mode = null;
    _playstyles = {};
    _communication = null;
    _availableNowOnly = false;
    _preferredTimes = {};
    _weekday = null;
    _matchScheduleTime = false;
    _scheduleStart = 18 * 60;
    _scheduleEnd = 23 * 60;
    _maxPartySize = null;
    _ranks = const RangeValues(0, 0);
    _rating = 0;
    _onlyAvailable = false;
  });
  Future<void> _pickScheduleTime(bool start) async {
    final minute = start ? _scheduleStart : _scheduleEnd;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _scheduleStart = selected.hour * 60 + selected.minute;
      } else {
        _scheduleEnd = selected.hour * 60 + selected.minute;
      }
    });
  }

  String _timeLabel(int minutes) => MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));

  Widget _label(String label) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
  Widget _select(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> update,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(label),
        DropdownButtonFormField<String>(
          key: ValueKey('$label:$value'),
          initialValue: value ?? '',
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            // Labels remain available to screen readers without repeating visually.
            hintText: label,
          ),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text('Any ${label.toLowerCase()}'),
            ),
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (v) => setState(() => update(v == '' ? null : v)),
        ),
      ],
    );
  }

  Widget _chips(
    String label,
    String? selected,
    List<String> options,
    ValueChanged<String?> update,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        Wrap(
          spacing: 8,
          children: [
            for (final value in options)
              ChoiceChip(
                label: Text(value),
                selected: value == selected,
                showCheckmark: false,
                onSelected: (on) => setState(() => update(on ? value : null)),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = _rankNames;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Preferences'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        actionsPadding: const EdgeInsets.fromLTRB(0, 2, 8, 0),
        actions: [
          Center(
            child: TextButton(onPressed: _reset, child: const Text('Reset')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          _select(
            'Game',
            _game,
            {...widget.games, ?_game}.toList(),
            _changeGame,
          ),
          _select(
            'Region',
            _region,
            {...widget.regions, ?_region}.toList(),
            (v) => _region = v,
          ),
          _select('Mode', _mode, const [
            'Competitive',
            'Casual',
          ], (v) => _mode = v),
          if (names.length > 1) ...[
            _label('Rank'),
            Text(
              '${names[_ranks.start.round()]} - '
              '${names[_ranks.end.round()]}',
            ),
            RangeSlider(
              values: _ranks,
              min: 0,
              max: (names.length - 1).toDouble(),
              divisions: names.length - 1,
              labels: RangeLabels(
                names[_ranks.start.round()],
                names[_ranks.end.round()],
              ),
              onChanged: (value) {
                setState(() {
                  _ranks = value;
                });
              },
            ),
          ],
          _label('Playstyle'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final style in const ['Chill', 'Serious', 'Fun'])
                FilterChip(
                  label: Text(style),
                  selected: _playstyles.contains(style),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _playstyles.add(style);
                    } else {
                      _playstyles.remove(style);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Select any that suit you. Leave empty for any playstyle.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          _chips('Communication', _communication, const [
            'Mic required',
            'Voice optional',
            'Chat only',
          ], (v) => _communication = v),
          _label('Minimum rating'),
          DropdownButtonFormField<double>(
            key: ValueKey(_rating),
            initialValue: _rating,
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: 0, child: Text('Any rating')),
              for (final value in [3.0, 3.5, 4.0, 4.5, 5.0])
                DropdownMenuItem(
                  value: value,
                  child: Text('${value.toStringAsFixed(1)} and above'),
                ),
            ],
            onChanged: (v) => setState(() => _rating = v ?? 0),
          ),
          if (widget.forPlayers) ...[
            _label('Availability'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available now only'),
              subtitle: const Text('Players who are looking for games now'),
              value: _availableNowOnly,
              onChanged: (v) => setState(() => _availableNowOnly = v),
            ),
            _label('Preferred gaming times'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final period in PlayerAvailability.gamingTimes)
                  FilterChip(
                    label: Text(period),
                    selected: _preferredTimes.contains(period),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _preferredTimes.add(period);
                      } else {
                        _preferredTimes.remove(period);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Matches any selected time. Leave empty for any time.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            _label('Weekly schedule'),
            DropdownButtonFormField<int>(
              key: ValueKey('weekday:$_weekday'),
              initialValue: _weekday ?? 0,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: 0, child: Text('Any day')),
                for (var day = 1; day <= 7; day++)
                  DropdownMenuItem(
                    value: day,
                    child: Text(PlayerAvailability.weekdays[day - 1]),
                  ),
              ],
              onChanged: (v) => setState(() => _weekday = v == 0 ? null : v),
            ),
            if (_weekday != null) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Match a time range'),
                value: _matchScheduleTime,
                onChanged: (value) =>
                    setState(() => _matchScheduleTime = value),
              ),
              if (_matchScheduleTime) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickScheduleTime(true),
                      icon: const Icon(Icons.schedule),
                      label: Text('From ${_timeLabel(_scheduleStart)}'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickScheduleTime(false),
                      icon: const Icon(Icons.schedule),
                      label: Text('Until ${_timeLabel(_scheduleEnd)}'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _scheduleEnd < _scheduleStart
                      ? 'Ends the following day. Matches overlapping availability.'
                      : 'Matches players with overlapping availability.',
                ),
              ],
            ],
          ] else ...[
            _label('Max party size'),
            DropdownButtonFormField<int>(
              key: ValueKey('maxPartySize:$_maxPartySize'),
              initialValue: _maxPartySize ?? 0,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: 0, child: Text('Any size')),
                for (final size in [2, 3, 4, 5, 6, 8, 10])
                  DropdownMenuItem(
                    value: size,
                    child: Text('Up to $size players'),
                  ),
              ],
              onChanged: (v) =>
                  setState(() => _maxPartySize = v == 0 ? null : v),
            ),
          ],
          if (!widget.forPlayers)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available spots only'),
              value: _onlyAvailable,
              onChanged: (v) => setState(() => _onlyAvailable = v),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: FilledButton(
            onPressed: () {
              if (widget.forPlayers &&
                  _weekday != null &&
                  _matchScheduleTime &&
                  _scheduleStart == _scheduleEnd) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Choose different start and end times.'),
                  ),
                );
                return;
              }
              Navigator.pop(
                context,
                FilterPreferences(
                  game: _game,
                  region: _region,
                  mode: _mode,
                  minRank: names.isEmpty ? 0 : _ranks.start.round(),
                  maxRank: names.isEmpty ? null : _ranks.end.round(),
                  playstyles: Set.unmodifiable(_playstyles),
                  communication: _communication,
                  minimumRating: _rating,
                  availableNowOnly: widget.forPlayers && _availableNowOnly,
                  preferredTimes: widget.forPlayers
                      ? Set.unmodifiable(_preferredTimes)
                      : const {},
                  scheduleWindow: widget.forPlayers && _weekday != null
                      ? WeeklyGamingSlot(
                          weekday: _weekday!,
                          startMinute: _matchScheduleTime ? _scheduleStart : 0,
                          endMinute: _matchScheduleTime ? _scheduleEnd : 0,
                        )
                      : null,
                  maxPartySize: widget.forPlayers ? null : _maxPartySize,
                  onlyAvailable: !widget.forPlayers && _onlyAvailable,
                ),
              );
            },
            child: const Text('Show Results'),
          ),
        ),
      ),
    );
  }
}
