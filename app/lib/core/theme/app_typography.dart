import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography tokens for font sizes, weights, and prebuilt TextStyle values.
/// Every TextStyle in the app should reference one of these tokens so font
/// sizing can be tuned from a single place.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Segoe UI';

  // Font size tokens.
  static const double fontSizeNav = 14.0;
  static const double fontSizeButton = 12.0;
  static const double fontSizeHeader = 11.0;
  static const double fontSizeCell = 11.0;
  static const double fontSizeCellSub = 10.0;
  static const double fontSizeBadge = 10.0;
  static const double fontSizeCategoryText = 13.0;
  static const double contextMenuTextSize = 10.0;

  // Chart specific font size tokens.
  static const double fontSizeChartTitle = 24.0;
  static const double fontSizeChartSubtitle = 12.0;
  static const double fontSizeChartHardwareInfo = 14.0;
  static const double fontSizeChartLegend = 10.0;
  static const double fontSizeChartAxisLabel = 10.0;
  static const double fontSizeFooterLabel = 11.0;
  static const double fontSizeFooterValue = 12.0;
  static const double fontSizeFooterValueLarge = 12.0;

  // Prebuilt text styles for convenience.
  static const TextStyle chartTitleStyle = TextStyle(
    fontSize: fontSizeChartTitle,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle chartSubtitleStyle = TextStyle(
    fontSize: fontSizeChartSubtitle,
    color: AppColors.textMuted,
    fontFamily: fontFamily,
  );

  static const TextStyle footerLabelStyle = TextStyle(
    fontSize: fontSizeFooterLabel,
    color: AppColors.onSurfaceVariant,
    fontFamily: fontFamily,
  );

  static const TextStyle footerValueStyle = TextStyle(
    fontSize: fontSizeFooterValue,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle footerValueLargeStyle = TextStyle(
    fontSize: fontSizeFooterValueLarge,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFamily: fontFamily,
  );
}
