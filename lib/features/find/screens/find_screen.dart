import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/party_provider.dart';
import '../../parties/widgets/party_load_error.dart';
import '../models/filter_preferences.dart';
import 'filter_preferences_screen.dart';
import 'package:flutter/material.dart';

import '../../../providers/player_provider.dart';
import '../../player/widgets/player_load_error.dart';
import '../../profile/screens/player_profile_screen.dart';
import '../../player/widgets/player_card.dart';

import '../../parties/widgets/party_card.dart';

class FindSreen extends ConsumerStatefulWidget {
  const FindSreen({super.key});

  @override
  ConsumerState<FindSreen> createState() => _FindSreenState();
}

class _FindSreenState extends ConsumerState<FindSreen> {
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
      ...(ref.read(availablePartiesProvider).asData?.value ?? []).map(
        (p) => p.gameName,
      ),
      ...(ref.read(discoverablePlayersProvider).asData?.value ?? [])
          .map((p) => p.currentGame)
          .whereType<String>(),
    }.toList()..sort();
    final result = await Navigator.of(context).push<FilterPreferences>(
      MaterialPageRoute(
        builder: (_) => FilterPreferencesScreen(
          initial: forPlayers ? _playerFilters : _partyFilters,
          games: games,
          forPlayers: forPlayers,
          regions: forPlayers
              ? ((ref.read(discoverablePlayersProvider).asData?.value ?? [])
                    .map((p) => p.region)
                    .whereType<String>()
                    .toSet()
                    .toList()
                  ..sort())
              : const ['Asia', 'Europe', 'North America', 'Oceania'],
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
    final partyState = ref.watch(availablePartiesProvider);
    final parties = (partyState.asData?.value ?? [])
        .where(
          (p) =>
              '${p.title} ${p.gameName} ${p.playStyle}'.toLowerCase().contains(
                query,
              ) &&
              _partyFilters.matches(
                gameName: p.gameName,
                regionName: p.region,
                gameMode: p.mode ?? p.playStyle,
                minAllowedRank: p.minRank,
                maxAllowedRank: p.maxRank,
                styleOptions: p.playstyles,
                rank: p.rank,
                style: p.style,
                comms: p.communication,
                rating: p.minimumRating,

                partySize: p.maxPlayers,
                hasAvailability: !p.isFull,
              ),
        )
        .toList();
    final playerState = ref.watch(discoverablePlayersProvider);
    final players = (playerState.asData?.value ?? [])
        .where(
          (p) =>
              '${p.name} ${p.currentGame ?? ''}'.toLowerCase().contains(
                query,
              ) &&
              _playerFilters.matches(
                gameName: p.currentGame,
                regionName: p.region,
                gameMode: p.mode,
                styleOptions: p.playstyles,
                rank: p.rank,
                style: p.style,
                comms: p.communication,
                rating: p.rating,
                playerAvailability: p.availability,
                hasAvailability: p.isActive == true,
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
              child: _showPlayers && playerState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _showPlayers && playerState.hasError
                  ? Center(
                      child: PlayerLoadError(
                        error: playerState.error!,
                        onRetry: () =>
                            ref.invalidate(discoverablePlayersProvider),
                      ),
                    )
                  : !_showPlayers && partyState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : !_showPlayers && partyState.hasError
                  ? Center(
                      child: PartyLoadError(
                        error: partyState.error!,
                        onRetry: () => ref.invalidate(availablePartiesProvider),
                      ),
                    )
                  : count == 0
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
                          ? PlayerCard(
                              player: players[index],
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PlayerProfileScreen(
                                    uid: players[index].id,
                                  ),
                                ),
                              ),
                            )
                          : PartyCard(
                              party: parties[index],
                              onJoin: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Party joining is not connected yet.',
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
