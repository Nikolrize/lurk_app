import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/party_provider.dart';
import '../../find/models/filter_preferences.dart';
import '../models/party_draft.dart';
import '../models/party.dart';

Future<void> openCreateParty(BuildContext context) async {
  final created = await Navigator.of(
    context,
  ).push<String>(MaterialPageRoute(builder: (_) => const CreatePartyScreen()));
  if (created == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Party created. You are the host.')),
  );
}

class CreatePartyScreen extends ConsumerStatefulWidget {
  const CreatePartyScreen({super.key, this.party});
  final Party? party;
  @override
  ConsumerState<CreatePartyScreen> createState() => _CreatePartyScreenState();
}

class _CreatePartyScreenState extends ConsumerState<CreatePartyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _game = PartyDraft.games.keys.first;
  String _region = PartyDraft.regions.keys.first;
  String _mode = PartyDraft.modes.keys.first;
  String _visibility = 'public', _communication = 'mic_required';
  int _size = 5;
  double _rating = 0;
  RangeValues _ranks = RangeValues(
    0,
    (FilterPreferences.ranksForGame(PartyDraft.games.keys.first).length - 1)
        .clamp(0, double.infinity)
        .toDouble(),
  );
  final Set<String> _styles = {'chill'};
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final party = widget.party;
    if (party == null) return;
    String keyFor(Map<String, String> options, String? value) => options.entries
        .firstWhere(
          (entry) => entry.key == value || entry.value == value,
          orElse: () => options.entries.first,
        )
        .key;
    _name.text = party.title;
    _description.text = party.description;
    _game = party.gameId;
    _region = keyFor(PartyDraft.regions, party.region);
    _mode = keyFor(PartyDraft.modes, party.mode);
    _communication = keyFor(PartyDraft.communications, party.communication);
    _visibility = party.visibility;
    _size = party.maxPlayers;
    _rating = party.minimumRating;
    final ranks = FilterPreferences.ranksForGame(_game);
    _ranks = RangeValues(
      (party.minRank ?? 0).toDouble(),
      (party.maxRank ?? (ranks.length - 1).clamp(0, 100)).toDouble(),
    );
    _styles
      ..clear()
      ..addAll(party.playstyles.map((v) => keyFor(PartyDraft.styles, v)));
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_styles.isEmpty) {
      setState(() => _error = 'Choose at least one playstyle.');
      return;
    }
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) {
      setState(() => _error = 'Sign in before creating a party.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final draft = PartyDraft(
        title: _name.text,
        gameId: _game,
        maxPlayers: _size,
        region: _region,
        mode: _mode,
        visibility: _visibility,
        minimumRating: _rating,
        minRank: FilterPreferences.ranksForGame(_game).isNotEmpty
            ? _ranks.start.round()
            : null,
        maxRank: FilterPreferences.ranksForGame(_game).isNotEmpty
            ? _ranks.end.round()
            : null,
        playstyles: Set.unmodifiable(_styles),
        communication: _communication,
        description: _description.text,
      );
      final service = ref.read(partyServiceProvider);
      final existing = widget.party;
      final String id;
      if (existing == null) {
        id = await service.createParty(draft, expectedUid: uid);
      } else {
        await service.updateParty(existing.id, draft, expectedUid: uid);
        id = existing.id;
      }
      if (mounted) Navigator.pop(context, id);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = switch (error.code) {
          'permission-denied' =>
            'Unable to save the party. Check your sign-in and party permissions.',
          'unavailable' =>
            'Cannot reach the server. Check your connection and try again.',
          _ => 'Unable to save the party. Please try again.',
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is StateError
            ? error.message.toString()
            : error is ArgumentError
            ? error.toString()
            : 'Unable to save the party. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
  Widget _dropdown<T>(
    String label,
    T value,
    Map<T, String> options,
    ValueChanged<T> update,
  ) {
    return _field(
      label,
      DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        items: options.entries
            .map(
              (entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => update(v));
        },
      ),
    );
  }

  Widget _pair(Widget left, Widget right) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 290 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Column(children: [left, const SizedBox(height: 16), right]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 16),
          Expanded(child: right),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final ranks = FilterPreferences.ranksForGame(_game);
    final authState = ref.watch(authStateProvider);
    final joinedId = ref.watch(joinedPartyIdProvider).asData?.value;
    final joinedParty = joinedId == null
        ? null
        : ref.watch(partyByIdProvider(joinedId)).asData?.value;
    final membership = joinedId == null
        ? null
        : ref.watch(myPartyMembershipProvider(joinedId)).asData?.value;
    final activeJoined =
        widget.party == null &&
        joinedParty?.status == 'open' &&
        membership != null &&
        membership['leftAt'] == null;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.party == null ? 'Create Party' : 'Edit Party'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
        ),
        body: Form(
          key: _formKey,
          child: AbsorbPointer(
            absorbing: _saving,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (activeJoined)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Leave your current party before creating a new one.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                _field(
                  'Party name',
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Late Night Ranked',
                    ),
                    maxLength: 60,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter a party name.'
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                _pair(
                  _dropdown('Game', _game, PartyDraft.games, (v) {
                    _game = v;
                    final names = FilterPreferences.ranksForGame(v);
                    _ranks = RangeValues(
                      0,
                      (names.length - 1).clamp(0, double.infinity).toDouble(),
                    );
                  }),
                  _dropdown('Max size', _size, {
                    for (var n = 2; n <= 10; n++) n: '$n players',
                  }, (v) => _size = v),
                ),
                const SizedBox(height: 16),
                _pair(
                  _dropdown(
                    'Region',
                    _region,
                    PartyDraft.regions,
                    (v) => _region = v,
                  ),
                  _dropdown('Mode', _mode, PartyDraft.modes, (v) => _mode = v),
                ),
                const SizedBox(height: 16),
                _pair(
                  _dropdown('Visibility', _visibility, const {
                    'public': 'Public',
                    'private': 'Private',
                  }, (v) => _visibility = v),
                  _dropdown('Min rating', _rating, {
                    0.0: 'Any rating',
                    for (final v in [3.0, 3.5, 4.0, 4.5, 5.0])
                      v: '${v.toStringAsFixed(1)}+',
                  }, (v) => _rating = v),
                ),
                const SizedBox(height: 20),
                if (_visibility == 'private') ...[
                  Text(
                    'Private parties are hidden from Home and Find.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                ],
                if (ranks.isNotEmpty)
                  _field(
                    'Rank',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${ranks[_ranks.start.round()]} — ${ranks[_ranks.end.round()]}',
                        ),
                        RangeSlider(
                          values: _ranks,
                          min: 0,
                          max: (ranks.length - 1).toDouble(),
                          divisions: ranks.length > 1 ? ranks.length - 1 : null,
                          labels: RangeLabels(
                            ranks[_ranks.start.round()],
                            ranks[_ranks.end.round()],
                          ),
                          onChanged: (v) => setState(() => _ranks = v),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'This game has no rank requirements.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 16),
                _field(
                  'Playstyle',
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in PartyDraft.styles.entries)
                        FilterChip(
                          label: Text(entry.value),
                          selected: _styles.contains(entry.key),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _styles.add(entry.key);
                            } else {
                              _styles.remove(entry.key);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _field(
                  'Communication',
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in PartyDraft.communications.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: _communication == entry.key,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setState(() => _communication = entry.key),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _field(
                  'Description (optional)',
                  TextFormField(
                    controller: _description,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText: 'Tell players about your party…',
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: FilledButton(
              onPressed: _saving || authState.isLoading || activeJoined
                  ? null
                  : _create,
              child: _saving
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Saving…'),
                      ],
                    )
                  : Text(
                      widget.party == null ? 'Create Party' : 'Save Changes',
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
