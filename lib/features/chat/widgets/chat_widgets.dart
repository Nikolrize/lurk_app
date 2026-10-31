import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/player_avatar.dart';

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.name,
    this.uid,
    this.photoPath,
    this.radius = 24,
  });
  final String name;
  final String? uid, photoPath;
  final double radius;
  @override
  Widget build(BuildContext context) => PlayerAvatar(
    uid: uid,
    photoPath: photoPath,
    radius: radius,
  );
}

class ChatNotice extends StatelessWidget {
  const ChatNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.onRetry,
  });
  final IconData icon;
  final String title, description;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.secondary),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

String chatTime(DateTime? date) {
  if (date == null) return '';
  final elapsed = DateTime.now().difference(date);
  if (elapsed.inMinutes < 1) return 'Now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d';
  return '${date.day}/${date.month}/${date.year}';
}
