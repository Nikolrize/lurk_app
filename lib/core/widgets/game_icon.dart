import 'package:flutter/material.dart';

import '../data/game_catalog.dart';

/// A shared logo for game tiles and selectors. The adjacent text names the game.
class GameIcon extends StatelessWidget {
  const GameIcon({super.key, required this.game, this.size = 32});

  final String game;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = GameCatalog.find(game)?.iconAsset;
    final fallback = Icon(
      Icons.sports_esports_outlined,
      size: size,
      color: Theme.of(context).colorScheme.secondary,
    );

    return SizedBox.square(
      dimension: size,
      child: asset == null
          ? fallback
          : Image.asset(
              asset,
              fit: BoxFit.contain,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .ceil(),
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
    );
  }
}
