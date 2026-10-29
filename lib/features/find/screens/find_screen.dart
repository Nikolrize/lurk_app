import '../models/filter_preferences.dart';
import 'filter_preferences_screen.dart';
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
  FilterPreferences _partyFilters = const FilterPreferences();
  FilterPreferences _playerFilters = const FilterPreferences();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final forPlayers = _showPlayers;
    final games = {
      ...sampleParties.map((p) => p.gameName),
      ...samplePlayers.map((p) => p.currentGame).whereType<String>(),
    }.toList()..sort();
    final result = await Navigator.of(context).push<FilterPreferences>(
      MaterialPageRoute(
        builder: (_) => FilterPreferencesScreen(
          initial: forPlayers ? _playerFilters : _partyFilters,
          games: games,
          forPlayers: forPlayers,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (forPlayers) {
        _playerFilters = result;
      } else {
        _partyFilters = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final parties = sampleParties
        .where(
          (p) =>
              '${p.title} ${p.gameName} ${p.playStyle}'.toLowerCase().contains(
                query,
              ) &&
              _partyFilters.matches(
                gameName: p.gameName,
                regionName: p.region,
                gameMode: p.mode ?? p.playStyle,
                rank: p.rank,
                style: p.style,
                comms: p.communication,
                rating: p.rating,

                partySize: p.maxPlayers,
                hasAvailability: !p.isFull,
              ),
        )
        .toList();
    final players = samplePlayers
        .where(
          (p) =>
              '${p.name} ${p.currentGame ?? ''}'.toLowerCase().contains(
                query,
              ) &&
              _playerFilters.matches(
                gameName: p.currentGame,
                regionName: p.region,
                gameMode: p.mode,
                rank: p.rank,
                style: p.style,
                comms: p.communication,
                rating: p.rating,
                playerAvailability: p.availability,
                hasAvailability: p.isActive,
              ),
        )
        .toList();
    final count = _showPlayers ? players.length : parties.length;
    final filterCount = (_showPlayers ? _playerFilters : _partyFilters).count;
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
                        bottom: MediaQuery.paddingOf(context).bottom,
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
