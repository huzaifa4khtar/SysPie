import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../chart_controller.dart';
import '../chart_models.dart';
import '../chart_formatters.dart';

class ChartFooter extends StatelessWidget {
  final ChartTab tab;
  final ChartDataPoint latest;

  const ChartFooter({
    super.key,
    required this.tab,
    required this.latest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingExtraLarge,
        vertical: AppDimensions.paddingLarge,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeftColumn(),
          SizedBox(width: AppDimensions.spacingXxl),
          _buildRightColumn(),
        ],
      ),
    );
  }

  Widget _buildLeftColumn() {
    if (tab == ChartTab.cpu) {
      return _buildCpuLeftColumn();
    }
    if (tab == ChartTab.gpu) {
      return _buildGpuLeftColumn();
    }
    if (tab == ChartTab.memory) {
      return _buildMemoryLeftColumn();
    }
    if (tab == ChartTab.disk) {
      return _buildDiskLeftColumn();
    }
    if (tab == ChartTab.network) {
      return _buildNetworkLeftColumn();
    }
    final stats = ChartTabData.getLeftColumnStats(tab, latest);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: stats.map((s) => _buildStatRow(s)).toList(),
    );
  }

  Widget _buildCpuLeftColumn() {
    const colWidth = 80.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: colWidth, child: _buildLabelOnly('Utilization')),
            SizedBox(width: colWidth, child: _buildLabelOnly('Speed')),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        Row(
          children: [
            SizedBox(
                width: colWidth,
                child:
                    _buildValueOnly('${latest.cpuUsage.toStringAsFixed(0)}%')),
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(
                    '${(latest.cpuSpeedMHz / 1000).toStringAsFixed(2)} GHz')),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        Row(
          children: [
            SizedBox(width: colWidth, child: _buildLabelOnly('Processes')),
            SizedBox(width: colWidth, child: _buildLabelOnly('Threads')),
            SizedBox(width: colWidth, child: _buildLabelOnly('Handles')),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        Row(
          children: [
            SizedBox(
                width: colWidth,
                child: _buildValueOnly('${latest.totalProcesses}')),
            SizedBox(
                width: colWidth,
                child: _buildValueOnly('${latest.totalThreads}')),
            SizedBox(
                width: colWidth,
                child: _buildValueOnly('${latest.totalHandles}')),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        _buildLabelOnly('Up time'),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        _buildValueOnly(ChartFormatters.formatDuration(latest.uptimeSeconds)),
      ],
    );
  }

  Widget _buildGpuLeftColumn() {
    const colWidth = 115.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: colWidth, child: _buildLabelOnly('Utilization')),
            SizedBox(
                width: colWidth,
                child: _buildLabelOnly('Dedicated GPU memory')),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        Row(
          children: [
            SizedBox(
                width: colWidth,
                child:
                    _buildValueOnly('${latest.gpuUsage.toStringAsFixed(0)}%')),
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(ChartFormatters.formatMemoryPair(
                    latest.gpuDedicatedMB, latest.gpuDedicatedTotalMB))),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        Row(
          children: [
            SizedBox(width: colWidth, child: _buildLabelOnly('GPU Memory')),
            SizedBox(
                width: colWidth, child: _buildLabelOnly('Shared GPU memory')),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        Row(
          children: [
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(ChartFormatters.formatMemoryPair(
                    latest.gpuDedicatedMB + latest.gpuSharedMB,
                    latest.gpuTotalMemoryMB))),
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(ChartFormatters.formatMemoryPair(
                    latest.gpuSharedMB, latest.gpuSharedTotalMB))),
          ],
        ),
      ],
    );
  }

  Widget _buildMemoryLeftColumn() {
    const colWidth = 80.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: colWidth, child: _buildLabelOnly('In use')),
            SizedBox(width: colWidth, child: _buildLabelOnly('Available')),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        Row(
          children: [
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(
                    ChartFormatters.formatMemory(latest.memoryUsedMB))),
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(
                    ChartFormatters.formatMemory(latest.memoryAvailableMB))),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        Row(
          children: [
            SizedBox(width: colWidth, child: _buildLabelOnly('Committed')),
            SizedBox(width: colWidth, child: _buildLabelOnly('Cached')),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        Row(
          children: [
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(ChartFormatters.formatMemoryPair(
                    latest.commitChargeMB, latest.commitLimitMB))),
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(
                    ChartFormatters.formatMemory(latest.memoryCachedMB))),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        Row(
          children: [
            SizedBox(width: colWidth, child: _buildLabelOnly('Paged pool')),
            SizedBox(width: colWidth, child: _buildLabelOnly('Non-paged pool')),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        Row(
          children: [
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(
                    ChartFormatters.formatMemory(latest.memoryPagedPoolMB))),
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(
                    ChartFormatters.formatMemory(latest.memoryNonPagedPoolMB))),
          ],
        ),
      ],
    );
  }

  Widget _buildDiskLeftColumn() {
    const colWidth = 110.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: colWidth, child: _buildLabelOnly('Active time')),
            SizedBox(
                width: colWidth,
                child: _buildLabelOnly('Average response time')),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        Row(
          children: [
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(
                    '${latest.diskActivePercent.toStringAsFixed(0)}%')),
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(
                    '${latest.diskAvgResponseMs.toStringAsFixed(1)} ms')),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        Row(
          children: [
            SizedBox(width: colWidth, child: _buildLabelOnly('Read speed')),
            SizedBox(width: colWidth, child: _buildLabelOnly('Write speed')),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        Row(
          children: [
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(
                    ChartFormatters.formatSpeed(latest.diskReadMBps))),
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(
                    ChartFormatters.formatSpeed(latest.diskWriteMBps))),
          ],
        ),
      ],
    );
  }

  Widget _buildNetworkLeftColumn() {
    const colWidth = 80.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: colWidth, child: _buildLabelOnly('Send')),
            SizedBox(width: colWidth, child: _buildLabelOnly('Receive')),
          ],
        ),
        const SizedBox(height: AppDimensions.chartsFooterStatSpacing),
        Row(
          children: [
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(
                    ChartFormatters.formatNetworkSpeed(latest.networkSendBps))),
            SizedBox(
                width: colWidth,
                child: _buildValueOnly(
                    ChartFormatters.formatNetworkSpeed(latest.networkRecvBps))),
          ],
        ),
      ],
    );
  }

  Widget _buildLabelOnly(String label) {
    return Text(label, style: AppTypography.footerLabelStyle);
  }

  Widget _buildValueOnly(String value) {
    return Text(value, style: AppTypography.footerValueLargeStyle);
  }

  Widget _buildRightColumn() {
    if (tab == ChartTab.network) {
      return _buildNetworkRightColumn();
    }
    final stats = ChartTabData.getRightColumnStats(tab, latest);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: stats.map((s) => _buildStatRow(s)).toList(),
    );
  }

  Widget _buildNetworkRightColumn() {
    final stats = ChartTabData.getRightColumnStats(tab, latest);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...stats.map((s) => _buildStatRow(s)),
        Padding(
          padding: const EdgeInsets.only(
              bottom: AppDimensions.chartsFooterStatSpacing),
          child: Row(
            children: [
              Text('Signal strength:', style: AppTypography.footerLabelStyle),
              const SizedBox(width: AppDimensions.spacingMd),
              _buildSignalBar(latest.netSignalPercent),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignalBar(int percent) {
    const barCount = 5;
    const barWidth = 4.0;
    const barSpacing = 2.0;
    const maxHeight = 16.0;
    final activeBars = (percent / 100 * barCount).ceil().clamp(0, barCount);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(barCount, (i) {
        final barHeight = maxHeight * (i + 1) / barCount;
        final isActive = i < activeBars;
        return Padding(
          padding: EdgeInsets.only(right: i < barCount - 1 ? barSpacing : 0),
          child: Container(
            width: barWidth,
            height: barHeight,
            decoration: BoxDecoration(
              color:
                  isActive ? AppColors.statusGreen : AppColors.onSurfaceVariant,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStatRow(FooterStat stat) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: AppDimensions.chartsFooterStatSpacing),
      child: Row(
        children: [
          Text(stat.label, style: AppTypography.footerLabelStyle),
          const SizedBox(width: AppDimensions.spacingMd),
          Text(
            stat.value,
            style: stat.isLarge
                ? AppTypography.footerValueLargeStyle
                : AppTypography.footerValueStyle,
          ),
        ],
      ),
    );
  }
}
