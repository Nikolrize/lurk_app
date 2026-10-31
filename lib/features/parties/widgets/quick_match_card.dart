import '../../../core/data/gaming_regions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/game_catalog.dart';
import '../../../core/widgets/action_card.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/party_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../profile/screens/gaming_preferences_screen.dart';
import '../models/quick_match.dart';
import 'party_preview_drawer.dart';

class QuickMatchCard extends ConsumerStatefulWidget {
  const QuickMatchCard({super.key});
  @override
  ConsumerState<QuickMatchCard> createState() => _QuickMatchCardState();
}

class _QuickMatchCardState extends ConsumerState<QuickMatchCard> {
  bool _finding = false;
  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _find() async {
    if (_finding) return;
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) {
      _notice('Sign in to use Quick Match.');
      return;
    }
    setState(() => _finding = true);
    try {
      final preferences = await ref
          .read(gamingPreferencesProvider(uid).future)
          .timeout(const Duration(seconds: 15));
      final game = GameCatalog.find(preferences.currentGame);
      if (!mounted || ref.read(authStateProvider).asData?.value?.uid != uid) {
        return;
      }
      if (game == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Choose your main game for matchmaking first.'),
            action: SnackBarAction(
              label: 'Set main game',
              onPressed: () {
                if (!mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GamingPreferencesScreen(uid: uid),
                  ),
                );
              },
            ),
          ),
        );
        return;
      }
      final profile = await ref
          .read(playerProfileProvider(uid).future)
          .timeout(const Duration(seconds: 15));
      final regionId = GamingRegions.idFor(profile?.region);
      if (regionId == null) {
        _notice('Set your region in your profile before using Quick Match.');
        return;
      }
      final region = GamingRegions.values.firstWhere(
        (value) => GamingRegions.idFor(value) == regionId,
      );
      final currentId = await ref
          .read(joinedPartyIdProvider.future)
          .timeout(const Duration(seconds: 15));
      final parties = await ref
          .read(partyServiceProvider)
          .findQuickMatchParties(game.id, regionId: regionId)
          .timeout(const Duration(seconds: 15));
      if (!mounted || ref.read(authStateProvider).asData?.value?.uid != uid) {
        return;
      }
      final match = pickQuickMatchParty(
        parties,
        mainGameId: game.id,
        regionId: regionId,
        viewerUid: uid,
        currentPartyId: currentId,
      );
      if (match == null) {
        _notice(
          'No open ${game.name} parties with space in $region right now. Try again soon.',
        );
        return;
      }
      await showPartyPreview(context, match);
    } catch (_) {
      _notice('Unable to find a party. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).asData?.value?.uid;
    final preferences = uid == null
        ? null
        : ref.watch(gamingPreferencesProvider(uid)).asData?.value;
    if (uid != null) ref.watch(playerProfileProvider(uid));
    // Keep these streams alive while their first values are awaited on tap.
    ref.watch(joinedPartyIdProvider);
    final game = GameCatalog.find(preferences?.currentGame);
    return Semantics(
      button: true,
      enabled: !_finding,
      child: ActionCard(
        icon: _finding ? Icons.hourglass_top_rounded : Icons.bolt_rounded,
        title: _finding ? 'Finding party…' : 'Quick Match',
        subtitle: _finding
            ? 'Looking for an open party'
            : game == null
            ? 'Find a party for your main game'
            : 'Find a ${game.name} party',
        onTap: _find,
      ),
    );
  }
}
