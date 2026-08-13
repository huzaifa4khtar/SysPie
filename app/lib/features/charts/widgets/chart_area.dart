import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../chart_controller.dart';
import '../chart_models.dart';

class ChartArea extends StatelessWidget {
  final ChartTab tab;
  final ChartDataState chartData;

  const ChartArea({
    super.key,
    required this.tab,
    required this.chartData,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingExtraLarge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: AppDimensions.chartsFixedHeight,
            child: _buildChart(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('60 seconds',
                  style: TextStyle(
                    fontSize: AppTypography.fontSizeChartAxisLabel,
                    color: AppColors.textMuted,
                  )),
              Text('0',
                  style: TextStyle(
                    fontSize: AppTypography.fontSizeChartAxisLabel,
                    color: AppColors.textMuted,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (chartData.isLoading || chartData.points.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.statusGreen));
    }

    final maxY = ChartTabData.getMaxY(tab, chartData);
    final borderColor = ChartTabData.getBorderColor(tab);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          verticalInterval: 10,
          horizontalInterval: maxY / 10,
          getDrawingHorizontalLine: (value) => FlLine(
            color: borderColor.withValues(alpha: 0.5),
            strokeWidth: AppDimensions.chartsGridLineWidth,
          ),
          getDrawingVerticalLine: (value) => FlLine(
            color: borderColor.withValues(alpha: 0.5),
            strokeWidth: AppDimensions.chartsGridLineWidth,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border:
              Border.all(color: borderColor.withValues(alpha: 0.8), width: 1.5),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.primaryContainer,
            getTooltipItems: (spots) => spots.map((spot) {
              return LineTooltipItem(
                ChartTabData.formatValue(spot.y, tab),
                const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.fontSizeCell),
              );
            }).toList(),
          ),
        ),
        lineBarsData: _getLineBarsData(),
        minX: 0,
        maxX: 59,
        minY: 0,
        maxY: maxY,
      ),
      duration: const Duration(milliseconds: 100),
    );
  }

  List<LineChartBarData> _getLineBarsData() {
    const int maxPoints = 60;
    final allPoints = chartData.points;
    final pointCount = allPoints.length;
    final padCount = pointCount < maxPoints ? maxPoints - pointCount : 0;
    final extractors = ChartTabData.getLineExtractors(tab);

    return extractors.map((ext) {
      final spots = <FlSpot>[];
      for (var i = 0; i < padCount; i++) {
        spots.add(FlSpot(i.toDouble(), 0));
      }
      for (var i = 0; i < allPoints.length; i++) {
        spots.add(FlSpot((padCount + i).toDouble(), ext.extract(allPoints[i])));
      }
      return LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.2,
        color: ext.color,
        barWidth: AppDimensions.chartsLineStrokeWidth,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData:
            BarAreaData(show: true, color: ext.color.withValues(alpha: 0.1)),
      );
    }).toList();
  }
}
