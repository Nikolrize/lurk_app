import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/models/gaming_preferences.dart';
import 'package:lurk_app/providers/profile_provider.dart';
import 'package:lurk_app/core/data/game_catalog.dart';
import 'package:lurk_app/core/widgets/game_icon.dart';

import '../widgets/profile_page_layout.dart';

class GamingPreferencesScreen extends ConsumerWidget {
  const GamingPreferencesScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesState = ref.watch(gamingPreferencesProvider(uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Gaming Preferences')),
      body: preferencesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: FilledButton(
            onPressed: () {
              ref.invalidate(gamingPreferencesProvider(uid));
            },
            child: const Text('Unable to load preferences. Retry'),
          ),
        ),
        data: (preferences) => _GamingPreferencesForm(
          key: ValueKey(uid),
          uid: uid,
          initialData: preferences,
        ),
      ),
    );
  }
}

class _GamingPreferencesForm extends ConsumerStatefulWidget {
  const _GamingPreferencesForm({
    super.key,
    required this.uid,
    required this.initialData,
  });

  final String uid;
  final GamingPreferences initialData;

  @override
  ConsumerState<_GamingPreferencesForm> createState() =>
      _GamingPreferencesFormState();
}

class _GamingPreferencesFormState
    extends ConsumerState<_GamingPreferencesForm> {
  late Set<String> _games;
  late Set<String> _playstyles;

  String? _currentGame;
  String? _mode;
  String? _communication;
  late Map<String, String> _gameRanks;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final data = widget.initialData;

    _games = Set<String>.of(data.games);
    _playstyles = Set<String>.of(data.playstyles);
    _currentGame = data.currentGame;
    _mode = data.mode;
    _communication = data.communication;
    _gameRanks = Map<String, String>.of(data.gameRanks);
  }

  void _toggleGame(String game, bool selected) {
    setState(() {
      if (selected) {
        _games.add(game);
      } else {
        _games.remove(game);
        _gameRanks.remove(game);
      }

      if (!_games.contains(_currentGame)) {
        _currentGame = _games.isEmpty ? null : _games.first;
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final preferences = GamingPreferences(
      games: _games.toList()..sort(),
      currentGame: _currentGame,
      mode: _mode,
      playstyles: _playstyles.toList()..sort(),
      communication: _communication,
      gameRanks: Map<String, String>.of(_gameRanks),
    );

    setState(() {
      _isSaving = true;
    });

    try {
      await ref
          .read(profileServiceProvider)
          .saveMyGamingPreferences(
            expectedUid: widget.uid,
            preferences: preferences,
          );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on ArgumentError catch (error) {
      if (!mounted) return;

      _showMessage(error.message.toString());
    } on FirebaseException catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to save preferences. Check your connection and try again.',
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage('Unable to save. Reopen this screen and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _heading(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _optionalDropdown({
    required String label,
    required String? value,
    required Map<String, String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label:$value'),
      initialValue: value ?? '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('No preference')),
        for (final entry in options.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: _isSaving
          ? null
          : (value) {
              setState(() {
                onChanged(value == '' ? null : value);
              });
            },
    );
  }

  //each dropdown reads and changes on entry in _gameRanks
  Widget _rankDropdown(String gameId) {
    final game = GameCatalog.games[gameId]!;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: DropdownButtonFormField<String>(
        key: ValueKey('rank:$gameId:${_gameRanks[gameId]}'),
        initialValue: _gameRanks[gameId] ?? '',
        isExpanded: true,
        decoration: InputDecoration(
          labelText: '${game.name} rank',
          helperText: game.rankHelp,
          helperMaxLines: 3,
        ),
        items: [
          const DropdownMenuItem(
            value: '',
            child: Text('Unranked / not specified'),
          ),
          for (final entry in game.ranks.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: _isSaving
            ? null
            : (value) {
                setState(() {
                  if (value == null || value.isEmpty) {
                    _gameRanks.remove(gameId);
                  } else {
                    _gameRanks[gameId] = value;
                  }
                });
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: ProfilePageLayout(
        introduction: const ProfileIntroduction(
          title: 'Find your kind of teammates.',
          description:
              'Choose your games and how you like to play. '
              'These preferences are visible to other signed-in players '
              'and can help them find compatible teammates.',
        ),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your gaming preferences',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                _heading('Games you play'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in GamingPreferences.gameLabels.entries)
                      FilterChip(
                        avatar: GameIcon(game: entry.key, size: 24),
                        label: Text(entry.value),
                        selected: _games.contains(entry.key),
                        onSelected: _isSaving
                            ? null
                            : (selected) {
                                _toggleGame(entry.key, selected);
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  key: ValueKey('main:$_currentGame'),
                  initialValue: _currentGame,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Main game for matchmaking',
                  ),
                  hint: const Text('Select games above first'),
                  items: [
                    for (final entry in GamingPreferences.gameLabels.entries)
                      if (_games.contains(entry.key))
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                  ],
                  onChanged: _isSaving || _games.isEmpty
                      ? null
                      : (value) {
                          setState(() {
                            _currentGame = value;
                          });
                        },
                ),
                const SizedBox(height: 20),
                _optionalDropdown(
                  label: 'Preferred mode',
                  value: _mode,
                  options: GamingPreferences.modeLabels,
                  onChanged: (value) => _mode = value,
                ),
                _heading('Playstyles'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in GamingPreferences.styleLabels.entries)
                      FilterChip(
                        label: Text(entry.value),
                        selected: _playstyles.contains(entry.key),
                        onSelected: _isSaving
                            ? null
                            : (selected) {
                                setState(() {
                                  if (selected) {
                                    _playstyles.add(entry.key);
                                  } else {
                                    _playstyles.remove(entry.key);
                                  }
                                });
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _optionalDropdown(
                  label: 'Communication',
                  value: _communication,
                  options: GamingPreferences.communicationLabels,
                  onChanged: (value) => _communication = value,
                ),
                //creates one drop down for each game that supports ranks
                for (final gameId in _games)
                  if (GameCatalog.games[gameId]?.supportsRanks == true)
                    _rankDropdown(gameId),

                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving...' : 'Save preferences'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
