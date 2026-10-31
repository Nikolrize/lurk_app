import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/game_catalog.dart';
import '../../../providers/party_history_provider.dart';
import '../models/party_history_entry.dart';
import '../widgets/party_history_card.dart';
import '../widgets/party_load_error.dart';
import '../../ratings/screens/rate_party_teammates_screen.dart';

class PartyHistoryScreen extends ConsumerStatefulWidget {
  const PartyHistoryScreen({super.key, required this.onBack, this.onRate});
  final VoidCallback onBack;

  /// The ratings feature can supply this callback without changing history.
  final ValueChanged<PartyHistoryEntry>? onRate;
  @override
  ConsumerState<PartyHistoryScreen> createState() => _PartyHistoryScreenState();
}

class _PartyHistoryScreenState extends ConsumerState<PartyHistoryScreen> {
  String? _game;
  @override
  Widget build(BuildContext context) {
    final history = ref.watch(partyHistoryProvider);
    final colors = Theme.of(context).colorScheme;
    final entries = <PartyHistoryEntry>[];
    var loading = history.isLoading;
    Object? error = history.error;
    for (final record in history.asData?.value ?? <PartyHistoryRecord>[]) {
      final session = ref.watch(partyHistoryEntryProvider(record));
      loading = loading || session.isLoading;
      error ??= session.error;
      final entry = session.asData?.value;
      if (entry != null && (_game == null || entry.gameId == _game)) {
        entries.add(entry);
      }
    }
    entries.sort(
      (a, b) =>
          (b.endedAt ?? DateTime(1970)).compareTo(a.endedAt ?? DateTime(1970)),
    );
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 24, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back to Parties',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Party History',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _game == null,
                  onSelected: (_) => setState(() => _game = null),
                ),
                for (final game in GameCatalog.games.values) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(game.name),
                    selected: _game == game.id,
                    onSelected: (_) => setState(() => _game = game.id),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (history.asData?.value.length == 50)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'Showing your 50 most recently joined parties',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: loading && entries.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : error != null && entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: PartyLoadError(
                        error: error,
                        onRetry: () {
                          ref.invalidate(partyHistoryProvider);
                          ref.invalidate(partyHistoryEntryProvider);
                        },
                      ),
                    ),
                  )
                : entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 56,
                            color: colors.primary,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _game == null
                                ? 'No party history yet'
                                : 'No sessions for this game',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Parties appear here after you leave or the host ends the session.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount:
                        entries.length + (error != null || loading ? 1 : 0),
                    separatorBuilder: (_, index) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      if (index == entries.length) {
                        return loading
                            ? const LinearProgressIndicator()
                            : TextButton(
                                onPressed: () {
                                  ref.invalidate(partyHistoryProvider);
                                  ref.invalidate(partyHistoryEntryProvider);
                                },
                                child: const Text(
                                  'Some sessions could not load. Retry',
                                ),
                              );
                      }
                      final entry = entries[index];
                      return PartyHistoryCard(
                        entry: entry,
                        onRate: widget.onRate == null
                            ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => RatePartyTeammatesScreen(
                                    partyId: entry.record.partyId,
                                    partyTitle: entry.title,
                                  ),
                                ),
                              )
                            : () => widget.onRate!(entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
