import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../chart_controller.dart';
import '../chart_models.dart';
import 'chart_tab_bar.dart';
import 'chart_header.dart';
import 'chart_area.dart';
import 'chart_footer.dart';

class ChartsCard extends ConsumerStatefulWidget {
  final ChartTab selectedTab;
  final ValueChanged<ChartTab> onTabChanged;

  const ChartsCard({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  ConsumerState<ChartsCard> createState() => _ChartsCardState();
}

class _ChartsCardState extends ConsumerState<ChartsCard> {
  @override
  Widget build(BuildContext context) {
    final chartData = ref.watch(chartDataProvider);
    final latest = chartData.points.isNotEmpty ? chartData.points.last : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            primary: true,
            child: Column(
              children: [
                // Tab bar, fixed at the top.
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingExtraLarge,
                    vertical: AppDimensions.paddingSmall,
                  ),
                  child: ChartTabBar(
                    selectedTab: widget.selectedTab,
                    onTabChanged: widget.onTabChanged,
                  ),
                ),
                // Header, fixed below the tabs.
                if (latest != null)
                  ChartHeader(
                    tab: widget.selectedTab,
                    latest: latest,
                    maxY: ChartTabData.getMaxY(widget.selectedTab, chartData),
                  ),
                const SizedBox(height: AppDimensions.spacingMd),
                // Chart area with a fixed height.
                ChartArea(
                  tab: widget.selectedTab,
                  chartData: chartData,
                ),
                // Footer, fixed at the bottom.
                if (latest != null)
                  ChartFooter(
                    tab: widget.selectedTab,
                    latest: latest,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
