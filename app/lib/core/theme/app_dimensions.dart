/// Layout and spacing tokens for sizes, widths, heights, and breakpoints.
/// Every recurring dimensional value lives here so layout tuning happens in
/// one place instead of inside widgets.
class AppDimensions {
  AppDimensions._();

  // Corner radius.
  static const double cornerRadius = 24.0;

  // Widget sizes.
  static const double sideMenuWidth = 150.0;
  static const double buttonHeight = 25.0;
  static const double rowHeight = 35.0;
  static const double headerHeight = 35.0;
  static const double categoryColumnHeight = 35.0;
  static const double expandArrowWidth = 30.0;
  static const double processIconSize = 17.0;

  // Spacing.
  static const double spacingXs = 1.0;
  static const double spacingSm = 4.0;
  static const double spacingMd = 8.0;
  static const double spacingLg = 12.0;
  static const double spacingXl = 16.0;
  static const double spacingXxl = 20.0;

  // Semantic spacing aliases for readability.
  static const double paddingTiny = spacingXs;
  static const double paddingVerySmall = spacingSm;
  static const double paddingSmall = spacingMd;
  static const double paddingMedium = spacingLg;
  static const double paddingLarge = spacingXl;
  static const double paddingExtraLarge = spacingXxl;

  // Data column widths shared across screens.
  static const double dataColumnWidth = 30.0;

  // Name cell margins.
  static const double nameCellLeftMargin = 10.0;
  static const double nameCellChildLeftMargin = 20.0;

  // Process and users column widths shared across screens.
  static const double colName = 500.0;
  static const double colCpu = 70.0;
  static const double colMemory = 100.0;
  static const double colDisk = 90.0;
  static const double colNetwork = 90.0;
  static const double colGpu = 70.0;
  static const double colGpuEngine = 120.0;
  static const double colPowerUsage = 120.0;

  // Services column widths.
  static const double colServiceName = 300.0;
  static const double colServicePid = 80.0;
  static const double colServiceDisplayName = 300.0;
  static const double colServiceStatus = 105.0;
  static const double colServiceGroup = 200.0;
  static const double colServiceType = 180.0;

  // Details column widths.
  static const double colDetailsName = 300.0;
  static const double colDetailsPid = 80.0;
  static const double colDetailsStatus = 105.0;
  static const double colDetailsUsername = 125.0;
  static const double colDetailsUacv = 100.0;
  static const double colDetailsDiskPermission = 100.0;
  static const double colDetailsParent = 350.0;

  // Context menu.
  static const double contextMenuWidth = 130.0;
  static const double contextMenuItemHeight = 30.0;
  static const double contextMenuPaddingVertical = spacingMd;
  static const double contextMenuPaddingHorizontal = spacingMd;
  static const double contextMenuBorderRadius = cornerRadius;
  static const double contextMenuIconSize = processIconSize;
  static const double contextMenuIconGap = spacingLg;
  static const double contextMenuSeparatorPadding = spacingLg;

  // Responsive breakpoints.
  static const double breakpointTopButtons = 800.0;
  static const double breakpointSearchBar = 730.0;
  static const double breakpointSideMenu = 730.0;

  // Minimum window size.
  static const double minWidth = 600.0;
  static const double minHeight = 600.0;

  // Charts dimensions.
  static const double chartsTabHeight = 35.0;
  static const double chartsLineStrokeWidth = 2.0;
  static const double chartsGridLineWidth = 0.5;
  static const double chartsFixedHeight = 288.0;
  static const double scrollbarThickness = 14.0;

  // Charts layout dimensions.
  static const double chartsLegendDotSize = 8.0;
  static const double chartsLegendSpacing = 12.0;
  static const double chartsFooterStatSpacing = 6.0;
}
