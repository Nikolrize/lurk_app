import 'package:flutter/material.dart';

class ProfileGameTile extends StatelessWidget {
  const ProfileGameTile({
    super.key,
    required this.name,
    required this.isMainGame,
    required this.onTap,
  });

  final String name;
  final bool isMainGame;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 104,
      child: Tooltip( // star on the desktop
        message: isMainGame ? '$name — main game' : name,
        child: Semantics(
          button: true,
          label: isMainGame ? '$name, main game' : name,
          child: InkWell( // handles tapping and provides visual feedback
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isMainGame
                                ? colors.primary
                                : colors.outline,
                          ),
                        ),
                        child: Icon(
                          Icons.sports_esports_outlined,
                          size: 32,
                          color: colors.secondary,
                        ),
                      ),
                      if (isMainGame)
                        Positioned(
                          top: 5,
                          right: 5,
                          child: Icon(
                            Icons.star,
                            size: 18,
                            color: colors.secondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}