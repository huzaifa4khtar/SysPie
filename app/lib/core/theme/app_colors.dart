import 'package:flutter/material.dart';

/// All color tokens as static const values, using the light theme. Use
/// Theme.of(context).colorScheme for standard themed colors, or switch to
/// AppTheme.dark. Edit only the hex values in this file to retheme the app.
class AppColors {
  AppColors._();

  // Primary palette.
  static const Color primary = Color(0xFF4285F4); //olympic blue
  static const Color onPrimary = Color(0xFFFFFFFF); //plain white
  static const Color primaryContainer = Color(0xFFbee9f4); //ice cube
  static const Color onPrimaryContainer = Color(0xFF4285F4);

  // Surface and background colors.
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceContainerHighest = Color(0xFFf3e7fe);

  // Background gradient.
  static const Color gradientTop = Color.fromARGB(255, 219, 203, 143);
  static const Color gradientMiddle = Color.fromARGB(192, 43, 204, 196);
  static const Color gradientBottom = primaryContainer;

  // Text colors.
  static const Color onSurface = Color(0xFF000000);
  static const Color onSurfaceVariant = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Status colors.
  static const Color statusGreen = Color(0xFF22C55E);
  static const Color statusYellow = Color(0xFFF59E0B);
  static const Color statusRed = Color(0xFFEF4444);
  static const Color statusBlue = Color(0xFF3B82F6);
  static const Color statusPurple = Color(0xFF8B5CF6);
  static const Color statusCyan = Color(0xFF06B6D4);

  // Miscellaneous colors.
  static const Color outline = Color(0xFFCBD5E0);
  static const Color secondary = Color(0xFFdee1e6);
  static const Color categoryColumn = Color(0xFFFFD470);

  // Semantic aliases.
  static const Color border = outline;
  static const Color highlight = secondary;
  static const Color cardBg = surface;
  static const Color primaryBackground = surfaceContainerHighest;
  static const Color primaryPlain = surface;
  static const Color primaryLight = primaryContainer;
  static const Color primaryDark = primary;
  static const Color textPrimary = onSurface;
  static const Color textSecondary = onSurfaceVariant;
  static const Color sidebarBg = primaryContainer;
  static const Color headerTextColor = primary;
  static const Color sideMenuHighlightColor = primaryBackground;
  static const Color contextMenuTextColor = textPrimary;
  static const Color error = statusRed;

  /// Builds a ColorScheme from these tokens.
  static ColorScheme colorScheme() => ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        error: statusRed,
      );
}
