import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/providers/profile_provider.dart';

class PlayerAvatar extends ConsumerWidget {
  const PlayerAvatar({
    super.key,
    this.photoPath,
    this.radius = 36,
    this.uid,
  });

  final String? photoPath;
  final double radius;
  final String? uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final path =
        photoPath ??
        (uid == null
            ? null
            : ref.watch(playerProfileProvider(uid!)).asData?.value?.photoPath);

    final fallback = Icon(
      Icons.person_outline,
      size: radius,
      color: colors.secondary,
    );

    return ClipOval(
      child: SizedBox.square(
        dimension: radius * 2,
        child: ColoredBox(
          color: colors.primary.withValues(alpha: 0.18),
          child: path == null || path.isEmpty
              ? Center(child: fallback)
              : Image.network(
                  ref.read(profileImageServiceProvider).publicUrl(path),
                  key: ValueKey(path),
                  fit: BoxFit.cover,
                  semanticLabel: 'Player profile photo',
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : Center(child: fallback),
                  errorBuilder: (_, error, stackTrace) =>
                      Center(child: fallback),
                ),
        ),
      ),
    );
  }
}
