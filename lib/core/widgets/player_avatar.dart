import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/providers/profile_provider.dart';

class PlayerAvatar extends ConsumerWidget {
  const PlayerAvatar({
    super.key,
    this.photoPath,
    this.radius = 36,
  });

  final String? photoPath;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final path = photoPath;

    final placeholder = Icon(
      Icons.person_outline,
      size: radius,
      color: colors.secondary,
    );

    return ClipOval(
      child: SizedBox.square(
        dimension: radius * 2,
        child: ColoredBox(
          color: colors.primary.withValues(alpha: 0.18),
          child: path == null || path.isEmpty ? Center(child: placeholder) : Image.network(
                  ref.read(profileImageServiceProvider).publicUrl(path),
                  key: ValueKey(path),
                  fit: BoxFit.cover,
                  semanticLabel: 'Player profile photo',
                  errorBuilder: (_, error, stackTrace) =>
                      Center(child: placeholder),
                ),
        ),
      ),
    );
  }
}