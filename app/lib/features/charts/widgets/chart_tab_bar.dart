import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../chart_models.dart';

class ChartTabBar extends StatelessWidget {
  final ChartTab selectedTab;
  final ValueChanged<ChartTab> onTabChanged;

  const ChartTabBar({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.chartsTabHeight,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
      ),
      child: Row(
        children: ChartTab.values.map((tab) {
          final isSelected = tab == selectedTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(tab),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.primaryDark : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.cornerRadius),
                ),
                child: Center(
                  child: Text(
                    tab.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: AppTypography.fontSizeButton,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.onPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
