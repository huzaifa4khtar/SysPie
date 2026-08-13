import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'chart_controller.dart';
import 'chart_formatters.dart';

/// Tabs available in the charts feature.
enum ChartTab {
  cpu,
  memory,
  disk,
  network,
  gpu,
}

class LegendItem {
  final Color color;
  final String label;
  final String value;
  const LegendItem(this.color, this.label, this.value);
}

class FooterStat {
  final String label;
  final String value;
  final bool isLarge;
  const FooterStat(this.label, this.value, {this.isLarge = false});
}

class ChartTabData {
  const ChartTabData._();

  static Color getBorderColor(ChartTab tab) {
    switch (tab) {
      case ChartTab.cpu:
        return AppColors.statusGreen;
      case ChartTab.gpu:
        return AppColors.statusPurple;
      case ChartTab.memory:
        return AppColors.statusCyan;
      case ChartTab.disk:
        return AppColors.statusYellow;
      case ChartTab.network:
        return AppColors.statusBlue;
    }
  }

  static String getTitle(ChartTab tab) {
    switch (tab) {
      case ChartTab.cpu:
        return 'CPU';
      case ChartTab.gpu:
        return 'GPU';
      case ChartTab.memory:
        return 'Memory';
      case ChartTab.disk:
        return 'Disk 0';
      case ChartTab.network:
        return 'Wi-Fi';
    }
  }

  static String getHardwareInfo(ChartTab tab, ChartDataPoint latest) {
    switch (tab) {
      case ChartTab.cpu:
        return latest.cpuName.isNotEmpty ? latest.cpuName : 'Processor';
      case ChartTab.gpu:
        return latest.gpuName.isNotEmpty ? latest.gpuName : 'Graphics Card';
      case ChartTab.memory:
        final size = latest.memoryTotalMB / 1024;
        final label = latest.memoryType.isNotEmpty ? latest.memoryType : 'RAM';
        return '${size.toStringAsFixed(1)} GB $label';
      case ChartTab.disk:
        return latest.diskModel.isNotEmpty ? latest.diskModel : 'Disk';
      case ChartTab.network:
        return latest.netNicModel.isNotEmpty ? latest.netNicModel : 'Network';
    }
  }

  static String getUnitLabel(ChartTab tab) {
    switch (tab) {
      case ChartTab.cpu:
        return '% Utilization';
      case ChartTab.gpu:
        return '% Utilization';
      case ChartTab.memory:
        return 'Memory usage';
      case ChartTab.disk:
        return 'Disk transfer rate';
      case ChartTab.network:
        return 'Throughput';
    }
  }

  static List<LegendItem> getLegendItems(ChartTab tab, ChartDataPoint latest) {
    switch (tab) {
      case ChartTab.cpu:
        return [
          LegendItem(AppColors.statusGreen, 'CPU',
              '${latest.cpuUsage.toStringAsFixed(1)}%'),
          LegendItem(AppColors.statusYellow, 'Kernel',
              '${latest.cpuKernel.toStringAsFixed(1)}%'),
          LegendItem(AppColors.statusBlue, 'User',
              '${latest.cpuUser.toStringAsFixed(1)}%'),
        ];
      case ChartTab.gpu:
        return [
          LegendItem(AppColors.statusPurple, 'GPU',
              '${latest.gpuUsage.toStringAsFixed(1)}%')
        ];
      case ChartTab.memory:
        return [
          LegendItem(AppColors.statusGreen, 'In use',
              ChartFormatters.formatMemory(latest.memoryUsedMB)),
          LegendItem(AppColors.statusCyan, 'Available',
              ChartFormatters.formatMemory(latest.memoryAvailableMB)),
        ];
      case ChartTab.disk:
        return [
          LegendItem(AppColors.statusGreen, 'Read',
              ChartFormatters.formatSpeed(latest.diskReadMBps)),
          LegendItem(AppColors.statusYellow, 'Write',
              ChartFormatters.formatSpeed(latest.diskWriteMBps)),
        ];
      case ChartTab.network:
        return [
          LegendItem(AppColors.statusGreen, 'Send',
              ChartFormatters.formatNetworkSpeed(latest.networkSendBps)),
          LegendItem(AppColors.statusCyan, 'Receive',
              ChartFormatters.formatNetworkSpeed(latest.networkRecvBps)),
        ];
    }
  }

  static List<FooterStat> getLeftColumnStats(
      ChartTab tab, ChartDataPoint latest) {
    switch (tab) {
      case ChartTab.cpu:
        return [
          FooterStat('Utilization', '${latest.cpuUsage.toStringAsFixed(0)}%',
              isLarge: true),
          FooterStat(
              'Speed', '${(latest.cpuSpeedMHz / 1000).toStringAsFixed(2)} GHz',
              isLarge: true),
          FooterStat('Processes', '${latest.cpuSockets}', isLarge: true),
          FooterStat('Threads', '${latest.cpuCores}', isLarge: true),
          FooterStat('Handles', '${latest.cpuLogicalProcessors}',
              isLarge: true),
          FooterStat(
              'Up time', ChartFormatters.formatDuration(latest.uptimeSeconds)),
        ];
      case ChartTab.gpu:
        return [
          FooterStat('Utilization', '${latest.gpuUsage.toStringAsFixed(0)}%',
              isLarge: true),
          FooterStat(
              'GPU Memory',
              ChartFormatters.formatMemoryPair(
                  latest.gpuDedicatedMB, latest.gpuTotalMemoryMB),
              isLarge: true),
        ];
      case ChartTab.memory:
        return [
          FooterStat(
              'In use', ChartFormatters.formatMemory(latest.memoryUsedMB),
              isLarge: true),
          FooterStat('Committed',
              '${ChartFormatters.formatMemory(latest.commitChargeMB)}/${ChartFormatters.formatMemory(latest.commitLimitMB)}',
              isLarge: true),
          FooterStat('Paged pool',
              ChartFormatters.formatMemory(latest.memoryPagedPoolMB)),
        ];
      case ChartTab.disk:
        return [
          FooterStat(
              'Active time', '${latest.diskActivePercent.toStringAsFixed(0)}%',
              isLarge: true),
          FooterStat(
              'Read speed', ChartFormatters.formatSpeed(latest.diskReadMBps),
              isLarge: true),
        ];
      case ChartTab.network:
        return [
          FooterStat(
              'Send', ChartFormatters.formatNetworkSpeed(latest.networkSendBps),
              isLarge: true),
          FooterStat('Receive',
              ChartFormatters.formatNetworkSpeed(latest.networkRecvBps),
              isLarge: true),
        ];
    }
  }

  static List<FooterStat> getRightColumnStats(
      ChartTab tab, ChartDataPoint latest) {
    switch (tab) {
      case ChartTab.cpu:
        return [
          FooterStat('Base speed:',
              '${(latest.cpuBaseSpeedMHz / 1000).toStringAsFixed(2)} GHz'),
          FooterStat('Sockets:', '${latest.cpuSockets}'),
          FooterStat('Cores:', '${latest.cpuCores}'),
          FooterStat('Logical processors:', '${latest.cpuLogicalProcessors}'),
          FooterStat('Virtualization:',
              latest.cpuVirtualization ? 'Enabled' : 'Disabled'),
          FooterStat('L1 cache:',
              ChartFormatters.formatCacheKB(latest.cpuL1CacheKB)),
          FooterStat('L2 cache:',
              ChartFormatters.formatCacheKB(latest.cpuL2CacheKB)),
          FooterStat('L3 cache:',
              ChartFormatters.formatCacheKB(latest.cpuL3CacheKB)),
        ];
      case ChartTab.gpu:
        return [
          FooterStat('Driver version:', latest.gpuDriverVersion),
          FooterStat('Driver date:', latest.gpuDriverDate),
          FooterStat('DirectX version:', latest.gpuDirectXVersion),
          FooterStat('Physical location:', latest.gpuPhysicalLocation),
          FooterStat('Hardware reserved memory:',
              ChartFormatters.formatMemory(latest.gpuHardwareReservedMB)),
        ];
      case ChartTab.memory:
        return [
          FooterStat('Speed:', '${latest.memorySpeedMHz} MHz'),
          FooterStat('Slots used:',
              '${latest.memorySlotsUsed} of ${latest.memorySlotsTotal}'),
          FooterStat('Form factor:', latest.memoryFormFactor),
          FooterStat('Hardware reserved:',
              ChartFormatters.formatMemory(latest.memoryHardwareReservedMB)),
        ];
      case ChartTab.disk:
        return [
          FooterStat(
              'Capacity:', '${latest.diskCapacityGB.toStringAsFixed(2)} GB'),
          FooterStat(
              'Formatted:', '${latest.diskCapacityGB.toStringAsFixed(2)} GB'),
          FooterStat('System disk:', latest.diskIsSystem ? 'Yes' : 'No'),
          FooterStat('Page file:', latest.diskHasPageFile ? 'Yes' : 'No'),
          FooterStat('Type:', latest.diskType),
        ];
      case ChartTab.network:
        return [
          FooterStat('Adapter name:', latest.netAdapterName),
          FooterStat('SSID:', latest.netSsid),
          FooterStat('Connection type:', latest.netConnectionType),
          FooterStat('IPv4 address:', latest.netIpv4Address),
          FooterStat('IPv6 address:', latest.netIpv6Address),
        ];
    }
  }

  static double getMaxY(ChartTab tab, ChartDataState chartData) {
    if (chartData.points.isEmpty) return 100;
    if (tab == ChartTab.cpu || tab == ChartTab.gpu) return 100;

    if (tab == ChartTab.memory) {
      final total = chartData.points.last.memoryTotalMB;
      if (total <= 0) return 100;
      return total;
    }

    double maxVal = 0;
    for (final point in chartData.points) {
      switch (tab) {
        case ChartTab.disk:
          maxVal = math.max(
              maxVal, math.max(point.diskReadMBps, point.diskWriteMBps));
          break;
        case ChartTab.network:
          maxVal = math.max(
              maxVal, math.max(point.networkSendBps, point.networkRecvBps));
          break;
        default:
          break;
      }
    }

    maxVal = maxVal * 1.1;
    if (maxVal <= 0) return 100;
    if (maxVal <= 100) return 100;
    if (maxVal <= 1000) return 1000;
    return (maxVal / 1000).ceil() * 1000;
  }

  static String formatValue(double value, ChartTab tab) {
    if (tab == ChartTab.memory) {
      if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)} GB';
      return '${value.toStringAsFixed(0)} MB';
    }
    if (tab == ChartTab.network) {
      return ChartFormatters.formatNetworkSpeed(value);
    }
    if (tab == ChartTab.disk) {
      if (value >= 1024 * 1024) {
        return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB/s';
      }
      if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)} KB/s';
      return '${value.toStringAsFixed(0)} B/s';
    }
    return '${value.toStringAsFixed(0)}%';
  }

  static List<LineExtractor> getLineExtractors(ChartTab tab) {
    switch (tab) {
      case ChartTab.cpu:
        return [
          LineExtractor((p) => p.cpuUsage, AppColors.statusGreen),
          LineExtractor((p) => p.cpuKernel, AppColors.statusYellow),
          LineExtractor((p) => p.cpuUser, AppColors.statusBlue),
        ];
      case ChartTab.gpu:
        return [LineExtractor((p) => p.gpuUsage, AppColors.statusPurple)];
      case ChartTab.memory:
        return [
          LineExtractor((p) => p.memoryUsedMB, AppColors.statusGreen),
          LineExtractor((p) => p.memoryAvailableMB, AppColors.statusCyan),
        ];
      case ChartTab.disk:
        return [
          LineExtractor((p) => p.diskReadMBps, AppColors.statusGreen),
          LineExtractor((p) => p.diskWriteMBps, AppColors.statusYellow),
        ];
      case ChartTab.network:
        return [
          LineExtractor((p) => p.networkSendBps, AppColors.statusGreen),
          LineExtractor((p) => p.networkRecvBps, AppColors.statusCyan),
        ];
    }
  }
}

class LineExtractor {
  final double Function(ChartDataPoint) extract;
  final Color color;
  const LineExtractor(this.extract, this.color);
}
