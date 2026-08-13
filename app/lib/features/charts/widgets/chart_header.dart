import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../chart_controller.dart';
import '../chart_models.dart';

class ChartHeader extends StatelessWidget {
  final ChartTab tab;
  final ChartDataPoint latest;
  final double maxY;

  const ChartHeader({
    super.key,
    required this.tab,
    required this.latest,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingExtraLarge,
        vertical: AppDimensions.paddingSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(ChartTabData.getTitle(tab),
                  style: AppTypography.chartTitleStyle),
              Text(ChartTabData.getHardwareInfo(tab, latest),
                  style: AppTypography.chartSubtitleStyle.copyWith(
                      color: AppColors.onSurface,
                      fontSize: AppTypography.fontSizeChartHardwareInfo,
                      fontWeight: FontWeight.w400)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(ChartTabData.getUnitLabel(tab),
                      style: AppTypography.chartSubtitleStyle),
                  const SizedBox(width: AppDimensions.spacingXl),
                  ...ChartTabData.getLegendItems(tab, latest)
                      .map((item) => Padding(
                            padding: const EdgeInsets.only(
                                right: AppDimensions.chartsLegendSpacing),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: AppDimensions.chartsLegendDotSize,
                                  height: AppDimensions.chartsLegendDotSize,
                                  decoration: BoxDecoration(
                                      color: item.color,
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: AppDimensions.spacingSm),
                                Text(item.label,
                                    style: AppTypography.chartSubtitleStyle),
                                const SizedBox(width: AppDimensions.spacingSm),
                                Text(item.value,
                                    style: AppTypography.footerValueStyle),
                              ],
                            ),
                          )),
                ],
              ),
              Text(
                ChartTabData.formatValue(maxY, tab),
                style: AppTypography.chartSubtitleStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
