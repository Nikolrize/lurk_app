import '../actions/join_party.dart';
import 'package:flutter/material.dart';

import '../models/party.dart';

class PartyCard extends StatelessWidget {
  final Party party;
  final VoidCallback? onJoin;

  const PartyCard({super.key, required this.party, this.onJoin});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              party.gameName,
              style: textStyles.bodySmall?.copyWith(color: colors.secondary),
            ),
            const SizedBox(height: 8),
            Text(party.title, style: textStyles.titleMedium),
            const SizedBox(height: 8),
            Text(
              '${party.playStyle} • '
              '${party.currentPlayers}/${party.maxPlayers} players',
              style: textStyles.bodySmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: onJoin == null
                  ? PartyJoinButton(party: party)
                  : FilledButton(
                      onPressed: party.isFull ? null : onJoin,
                      child: Text(party.isFull ? 'Party Full' : 'Join Party'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
