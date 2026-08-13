import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Builds ThemeData from the design tokens. SysPie uses a single light theme.
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: AppTypography.fontFamily,
        colorScheme: AppColors.colorScheme(),
        scaffoldBackgroundColor: Colors.transparent,
      );

  static const BoxDecoration backgroundGradient = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.2, 0.7, 0.8],
      colors: [
        AppColors.gradientTop,
        AppColors.gradientMiddle,
        AppColors.gradientBottom,
      ],
    ),
  );
}
