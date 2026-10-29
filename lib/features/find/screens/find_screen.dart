import 'package:flutter/material.dart';

import '../../player/data/sample_players.dart';
import '../../player/widgets/player_card.dart';
import '../../parties/data/sample_parties.dart';
import '../../parties/widgets/party_card.dart';

class FindSreen extends StatefulWidget {
  const FindSreen({super.key});

  @override
  State<FindSreen> createState() => _FindSreenState();
}

class _FindSreenState extends State<FindSreen> {
  bool _showPlayers = false;
  final _searchController = TextEditingController();
  String _query = '';
  String? _partyGame;
  String? _playerGame;
  String? _playStyle;
  bool _availableOnly = false;
  bool _activeOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final players = _showPlayers;
    String? game = players ? _playerGame : _partyGame;
    String? style = _playStyle;
    bool only = players ? _activeOnly : _availableOnly;
    final games =
        (players
                ? samplePlayers
                      .map((p) => p.currentGame?.trim())
                      .whereType<String>()
                : sampleParties.map((p) => p.gameName))
            .where((g) => g.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final styles = sampleParties.map((p) => p.playStyle).toSet().toList()
      ..sort();
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      players ? 'Player filters' : 'Party filters',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    const Text('Game'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All games'),
                          selected: game == null,
                          onSelected: (_) => setSheetState(() => game = null),
                        ),
                        for (final value in games)
                          ChoiceChip(
                            label: Text(value),
                            selected: game == value,
                            onSelected: (_) =>
                                setSheetState(() => game = value),
                          ),
                      ],
                    ),
                    if (!players) ...[
                      const SizedBox(height: 16),
                      const Text('Play style'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Any style'),
                            selected: style == null,
                            onSelected: (_) =>
                                setSheetState(() => style = null),
                          ),
                          for (final value in styles)
                            ChoiceChip(
                              label: Text(value),
                              selected: style == value,
                              onSelected: (_) =>
                                  setSheetState(() => style = value),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        players
                            ? 'Active players only'
                            : 'Available spots only',
                      ),
                      value: only,
                      onChanged: (value) => setSheetState(() => only = value),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Apply filters'),
                    ),
                    TextButton(
                      onPressed: () => setSheetState(() {
                        game = null;
                        style = null;
                        only = false;
                      }),
                      child: const Text('Reset filters'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (applied != true || !mounted) return;
    setState(() {
      if (players) {
        _playerGame = game;
        _activeOnly = only;
      } else {
        _partyGame = game;
        _playStyle = style;
        _availableOnly = only;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final parties = sampleParties.where((party) {
      return '${party.title} ${party.gameName} ${party.playStyle}'
              .toLowerCase()
              .contains(query) &&
          (_partyGame == null || party.gameName == _partyGame) &&
          (_playStyle == null || party.playStyle == _playStyle) &&
          (!_availableOnly || !party.isFull);
    }).toList();
    final players = samplePlayers.where((player) {
      return '${player.name} ${player.currentGame ?? ''}'
              .toLowerCase()
              .contains(query) &&
          (_playerGame == null || player.currentGame?.trim() == _playerGame) &&
          (!_activeOnly || player.isActive);
    }).toList();
    final count = _showPlayers ? players.length : parties.length;
    final filterCount = _showPlayers
        ? (_playerGame != null ? 1 : 0) + (_activeOnly ? 1 : 0)
        : (_partyGame != null ? 1 : 0) +
              (_playStyle != null ? 1 : 0) +
              (_availableOnly ? 1 : 0);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Find',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            DefaultTabController(
              length: 2,
              child: TabBar(
                onTap: (index) => setState(() => _showPlayers = index == 1),
                tabs: const [
                  Tab(text: 'Party'),
                  Tab(text: 'Player'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: _showPlayers
                          ? 'Search players or games'
                          : 'Search parties or games',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: filterCount == 0
                      ? 'Filters'
                      : 'Filters ($filterCount active)',
                  onPressed: _openFilters,
                  isSelected: filterCount > 0,
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$count ${_showPlayers ? 'players' : 'parties'} found',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: count == 0
                  ? Center(
                      child: Text(
                        'No ${_showPlayers ? 'players' : 'parties'} match.\nTry another search or adjust your filters.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.paddingOf(context).bottom + 20,
                      ),
                      itemCount: count,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) => _showPlayers
                          ? PlayerCard(player: players[index])
                          : PartyCard(
                              party: parties[index],
                              onJoin: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'You selected ${parties[index].title}',
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
