import 'package:flutter/material.dart';
import 'package:lurk_app/core/theme/app_colors.dart';

class AppTheme {
  static final dark = ThemeData(
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.secondary,
          onSecondary: AppColors.background,
          surface: AppColors.surface,
          onSurface: AppColors.text,
          onSurfaceVariant: AppColors.textSecondary,
          error: AppColors.error,
          onError: AppColors.background,
        ),
    scaffoldBackgroundColor: AppColors.background,
  );
}
