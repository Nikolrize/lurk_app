import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/player_safety_service.dart';
import '../../../providers/profile_provider.dart';
import 'player_profile_screen.dart';
import '../../../core/widgets/player_avatar.dart';

class BlockedPlayersScreen extends ConsumerWidget {
  const BlockedPlayersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Blocked Players')),
    body: ref
        .watch(blockedPlayersProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(blockedPlayersProvider),
              child: const Text('Unable to load blocked players. Retry'),
            ),
          ),
          data: (ids) => ids.isEmpty
              ? const Center(child: Text('No blocked players.'))
              : ListView(
                  children: [
                    for (final uid in ids)
                      ListTile(
                        leading: PlayerAvatar(uid: uid, radius: 20),
                        title: Text(
                          ref
                                  .watch(playerProfileProvider(uid))
                                  .asData
                                  ?.value
                                  ?.username ??
                              'Player',
                        ),
                        subtitle: const Text('Tap to view profile or unblock'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayerProfileScreen(uid: uid),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
  );
}
