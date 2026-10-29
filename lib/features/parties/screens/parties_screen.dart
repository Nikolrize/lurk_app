import 'package:flutter/material.dart';
import '../../../core/widgets/action_card.dart';

class PartiesScreen extends StatelessWidget {
  const PartiesScreen({super.key, this.onQuickMatch});
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
  Widget build(BuildContext context) {
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
                      onTap: () => _preview(
                        context,
                        'Create Party',
                        'Party creation is coming next. No party has been created.',
                      ),
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
                    ActionCard(
                      icon: Icons.groups_rounded,
                      title: 'Back to Current Party',
                      subtitle: '3 / 5 players · Private party',
                      highlighted: true,
                      onTap: () => _preview(
                        context,
                        'Current Party',
                        'Sample party: 3 / 5 players · Private party.\n\nLive membership and the lobby are not connected yet.',
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
