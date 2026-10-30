import '../models/party.dart';
import 'party_lobby_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/party_provider.dart';
import '../widgets/party_load_error.dart';
import 'create_party_screen.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/action_card.dart';

class PartiesScreen extends ConsumerWidget {
  const PartiesScreen({super.key, this.onQuickMatch, this.onOpenLobby});
  final ValueChanged<Party>? onOpenLobby;
  final VoidCallback? onQuickMatch;

  void _preview(BuildContext context, String title, String message) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentParty = ref.watch(currentHostedPartyProvider);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 44).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Parties',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    ActionCard(
                      icon: Icons.bolt_rounded,
                      title: 'Quick Match',
                      subtitle: 'Join a party or find players now',
                      onTap:
                          onQuickMatch ??
                          () => _preview(
                            context,
                            'Quick Match',
                            'Matchmaking is not connected yet.',
                          ),
                    ),
                    const SizedBox(height: 14),
                    ActionCard(
                      icon: Icons.add_rounded,
                      title: 'Create Party',
                      subtitle: 'Create a new party for players to join',
                      onTap: () => openCreateParty(context),
                    ),
                    const SizedBox(height: 14),
                    ActionCard(
                      icon: Icons.history_rounded,
                      title: 'Party History',
                      subtitle: 'List of completed party sessions',
                      onTap: () => _preview(
                        context,
                        'Party History',
                        'Completed sessions will appear here once party history is connected.',
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Spacer(),
                    currentParty.when(
                      loading: () => const SizedBox.shrink(),
                      error: (error, _) => PartyLoadError(
                        error: error,
                        onRetry: () =>
                            ref.invalidate(currentHostedPartyProvider),
                      ),
                      data: (party) => party == null
                          ? const SizedBox.shrink()
                          : ActionCard(
                              icon: Icons.groups_rounded,
                              title: 'Back to Current Party',
                              subtitle:
                                  '${party.currentPlayers} / ${party.maxPlayers} players · ${party.visibility == "private" ? "Private" : "Public"} party',
                              highlighted: true,
                              onTap: () {
                                if (onOpenLobby != null) {
                                  onOpenLobby!(party);
                                } else {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (context) => Scaffold(
                                        body: PartyLobbyScreen(
                                          party: party,
                                          onBack: () => Navigator.pop(context),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
