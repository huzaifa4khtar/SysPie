import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../processes/process_controller.dart';

/// One snapshot of system stats, organized by subsystem for CPU, memory,
/// disk, network, and GPU.
class ChartDataPoint {
  final DateTime timestamp;
  final double cpuUsage;
  final double cpuKernel;
  final double cpuUser;
  final double gpuUsage;
  final double memoryUsedMB;
  final double memoryAvailableMB;
  final double memoryTotalMB;
  final double commitChargeMB;
  final double commitLimitMB;
  final double diskReadMBps;
  final double diskWriteMBps;
  final double networkSendBps;
  final double networkRecvBps;
  final int totalProcesses;
  final int totalThreads;
  final int totalHandles;
  final double cpuSpeedMHz;
  final double cpuBaseSpeedMHz;
  final String cpuName;
  final int cpuSockets;
  final int cpuCores;
  final int cpuLogicalProcessors;
  final bool cpuVirtualization;
  final int cpuL1CacheKB;
  final int cpuL2CacheKB;
  final int cpuL3CacheKB;
  final int uptimeSeconds;
  final double memoryCompressedMB;
  final double memoryCachedMB;
  final double memoryPagedPoolMB;
  final double memoryNonPagedPoolMB;
  final int memorySpeedMHz;
  final int memorySlotsUsed;
  final int memorySlotsTotal;
  final String memoryFormFactor;
  final String memoryType;
  final double memoryHardwareReservedMB;
  final double diskActivePercent;
  final double diskAvgResponseMs;
  final double diskCapacityGB;
  final bool diskIsSystem;
  final bool diskHasPageFile;
  final String diskType;
  final String diskModel;
  final String netAdapterName;
  final String netNicModel;
  final String netSsid;
  final String netConnectionType;
  final String netIpv4Address;
  final String netIpv6Address;
  final int netSignalPercent;
  final double gpuDedicatedMB;
  final double gpuSharedMB;
  final double gpuTotalMemoryMB;
  final double gpuDedicatedTotalMB;
  final double gpuSharedTotalMB;
  final String gpuName;
  final String gpuDriverVersion;
  final String gpuDriverDate;
  final String gpuDirectXVersion;
  final String gpuPhysicalLocation;
  final double gpuHardwareReservedMB;

  const ChartDataPoint({
    required this.timestamp,
    this.cpuUsage = 0,
    this.cpuKernel = 0,
    this.cpuUser = 0,
    this.gpuUsage = 0,
    this.memoryUsedMB = 0,
    this.memoryAvailableMB = 0,
    this.memoryTotalMB = 0,
    this.commitChargeMB = 0,
    this.commitLimitMB = 0,
    this.diskReadMBps = 0,
    this.diskWriteMBps = 0,
    this.networkSendBps = 0,
    this.networkRecvBps = 0,
    this.totalProcesses = 0,
    this.totalThreads = 0,
    this.totalHandles = 0,
    this.cpuSpeedMHz = 0,
    this.cpuBaseSpeedMHz = 0,
    this.cpuName = '',
    this.cpuSockets = 0,
    this.cpuCores = 0,
    this.cpuLogicalProcessors = 0,
    this.cpuVirtualization = false,
    this.cpuL1CacheKB = 0,
    this.cpuL2CacheKB = 0,
    this.cpuL3CacheKB = 0,
    this.uptimeSeconds = 0,
    this.memoryCompressedMB = 0,
    this.memoryCachedMB = 0,
    this.memoryPagedPoolMB = 0,
    this.memoryNonPagedPoolMB = 0,
    this.memorySpeedMHz = 0,
    this.memorySlotsUsed = 0,
    this.memorySlotsTotal = 0,
    this.memoryFormFactor = '',
    this.memoryType = '',
    this.memoryHardwareReservedMB = 0,
    this.diskActivePercent = 0,
    this.diskAvgResponseMs = 0,
    this.diskCapacityGB = 0.0,
    this.diskIsSystem = false,
    this.diskHasPageFile = false,
    this.diskType = '',
    this.diskModel = '',
    this.netAdapterName = '',
    this.netNicModel = '',
    this.netSsid = '',
    this.netConnectionType = '',
    this.netIpv4Address = '',
    this.netIpv6Address = '',
    this.netSignalPercent = 0,
    this.gpuDedicatedMB = 0.0,
    this.gpuSharedMB = 0.0,
    this.gpuTotalMemoryMB = 0.0,
    this.gpuDedicatedTotalMB = 0.0,
    this.gpuSharedTotalMB = 0.0,
    this.gpuName = '',
    this.gpuDriverVersion = '',
    this.gpuDriverDate = '',
    this.gpuDirectXVersion = '',
    this.gpuPhysicalLocation = '',
    this.gpuHardwareReservedMB = 0.0,
  });

  ChartDataPoint copyWith({
    double? cpuUsage,
    double? cpuKernel,
    double? cpuUser,
    double? gpuUsage,
    double? memoryUsedMB,
    double? memoryAvailableMB,
    double? memoryTotalMB,
    double? commitChargeMB,
    double? commitLimitMB,
    double? diskReadMBps,
    double? diskWriteMBps,
    double? networkSendBps,
    double? networkRecvBps,
    int? totalProcesses,
    int? totalThreads,
    int? totalHandles,
    double? cpuSpeedMHz,
    double? cpuBaseSpeedMHz,
    String? cpuName,
    int? cpuSockets,
    int? cpuCores,
    int? cpuLogicalProcessors,
    bool? cpuVirtualization,
    int? cpuL1CacheKB,
    int? cpuL2CacheKB,
    int? cpuL3CacheKB,
    int? uptimeSeconds,
    double? memoryCompressedMB,
    double? memoryCachedMB,
    double? memoryPagedPoolMB,
    double? memoryNonPagedPoolMB,
    int? memorySpeedMHz,
    int? memorySlotsUsed,
    int? memorySlotsTotal,
    String? memoryFormFactor,
    String? memoryType,
    double? memoryHardwareReservedMB,
    double? diskActivePercent,
    double? diskAvgResponseMs,
    double? diskCapacityGB,
    bool? diskIsSystem,
    bool? diskHasPageFile,
    String? diskType,
    String? diskModel,
    String? netAdapterName,
    String? netNicModel,
    String? netSsid,
    String? netConnectionType,
    String? netIpv4Address,
    String? netIpv6Address,
    int? netSignalPercent,
    double? gpuDedicatedMB,
    double? gpuSharedMB,
    double? gpuTotalMemoryMB,
    double? gpuDedicatedTotalMB,
    double? gpuSharedTotalMB,
    String? gpuName,
    String? gpuDriverVersion,
    String? gpuDriverDate,
    String? gpuDirectXVersion,
    String? gpuPhysicalLocation,
    double? gpuHardwareReservedMB,
  }) {
    return ChartDataPoint(
      timestamp: timestamp,
      cpuUsage: cpuUsage ?? this.cpuUsage,
      cpuKernel: cpuKernel ?? this.cpuKernel,
      cpuUser: cpuUser ?? this.cpuUser,
      gpuUsage: gpuUsage ?? this.gpuUsage,
      memoryUsedMB: memoryUsedMB ?? this.memoryUsedMB,
      memoryAvailableMB: memoryAvailableMB ?? this.memoryAvailableMB,
      memoryTotalMB: memoryTotalMB ?? this.memoryTotalMB,
      commitChargeMB: commitChargeMB ?? this.commitChargeMB,
      commitLimitMB: commitLimitMB ?? this.commitLimitMB,
      diskReadMBps: diskReadMBps ?? this.diskReadMBps,
      diskWriteMBps: diskWriteMBps ?? this.diskWriteMBps,
      networkSendBps: networkSendBps ?? this.networkSendBps,
      networkRecvBps: networkRecvBps ?? this.networkRecvBps,
      totalProcesses: totalProcesses ?? this.totalProcesses,
      totalThreads: totalThreads ?? this.totalThreads,
      totalHandles: totalHandles ?? this.totalHandles,
      cpuSpeedMHz: cpuSpeedMHz ?? this.cpuSpeedMHz,
      cpuBaseSpeedMHz: cpuBaseSpeedMHz ?? this.cpuBaseSpeedMHz,
      cpuName: cpuName ?? this.cpuName,
      cpuSockets: cpuSockets ?? this.cpuSockets,
      cpuCores: cpuCores ?? this.cpuCores,
      cpuLogicalProcessors: cpuLogicalProcessors ?? this.cpuLogicalProcessors,
      cpuVirtualization: cpuVirtualization ?? this.cpuVirtualization,
      cpuL1CacheKB: cpuL1CacheKB ?? this.cpuL1CacheKB,
      cpuL2CacheKB: cpuL2CacheKB ?? this.cpuL2CacheKB,
      cpuL3CacheKB: cpuL3CacheKB ?? this.cpuL3CacheKB,
      uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
      memoryCompressedMB: memoryCompressedMB ?? this.memoryCompressedMB,
      memoryCachedMB: memoryCachedMB ?? this.memoryCachedMB,
      memoryPagedPoolMB: memoryPagedPoolMB ?? this.memoryPagedPoolMB,
      memoryNonPagedPoolMB: memoryNonPagedPoolMB ?? this.memoryNonPagedPoolMB,
      memorySpeedMHz: memorySpeedMHz ?? this.memorySpeedMHz,
      memorySlotsUsed: memorySlotsUsed ?? this.memorySlotsUsed,
      memorySlotsTotal: memorySlotsTotal ?? this.memorySlotsTotal,
      memoryFormFactor: memoryFormFactor ?? this.memoryFormFactor,
      memoryType: memoryType ?? this.memoryType,
      memoryHardwareReservedMB:
          memoryHardwareReservedMB ?? this.memoryHardwareReservedMB,
      diskActivePercent: diskActivePercent ?? this.diskActivePercent,
      diskAvgResponseMs: diskAvgResponseMs ?? this.diskAvgResponseMs,
      diskCapacityGB: diskCapacityGB ?? this.diskCapacityGB,
      diskIsSystem: diskIsSystem ?? this.diskIsSystem,
      diskHasPageFile: diskHasPageFile ?? this.diskHasPageFile,
      diskType: diskType ?? this.diskType,
      diskModel: diskModel ?? this.diskModel,
      netAdapterName: netAdapterName ?? this.netAdapterName,
      netNicModel: netNicModel ?? this.netNicModel,
      netSsid: netSsid ?? this.netSsid,
      netConnectionType: netConnectionType ?? this.netConnectionType,
      netIpv4Address: netIpv4Address ?? this.netIpv4Address,
      netIpv6Address: netIpv6Address ?? this.netIpv6Address,
      netSignalPercent: netSignalPercent ?? this.netSignalPercent,
      gpuDedicatedMB: gpuDedicatedMB ?? this.gpuDedicatedMB,
      gpuSharedMB: gpuSharedMB ?? this.gpuSharedMB,
      gpuTotalMemoryMB: gpuTotalMemoryMB ?? this.gpuTotalMemoryMB,
      gpuDedicatedTotalMB: gpuDedicatedTotalMB ?? this.gpuDedicatedTotalMB,
      gpuSharedTotalMB: gpuSharedTotalMB ?? this.gpuSharedTotalMB,
      gpuName: gpuName ?? this.gpuName,
      gpuDriverVersion: gpuDriverVersion ?? this.gpuDriverVersion,
      gpuDriverDate: gpuDriverDate ?? this.gpuDriverDate,
      gpuDirectXVersion: gpuDirectXVersion ?? this.gpuDirectXVersion,
      gpuPhysicalLocation: gpuPhysicalLocation ?? this.gpuPhysicalLocation,
      gpuHardwareReservedMB:
          gpuHardwareReservedMB ?? this.gpuHardwareReservedMB,
    );
  }
}

class ChartDataState {
  final List<ChartDataPoint> points;
  final bool isLoading;

  const ChartDataState({
    this.points = const [],
    this.isLoading = true,
  });

  ChartDataState copyWith({
    List<ChartDataPoint>? points,
    bool? isLoading,
  }) {
    return ChartDataState(
      points: points ?? this.points,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ChartDataNotifier extends Notifier<ChartDataState> {
  // Holds up to 60 points, about one minute of one second samples.
  static const int _maxPoints = 60;
  StreamSubscription<Map<String, dynamic>>? _statsSubscription;

  ChartDataPoint _currentPoint = ChartDataPoint(timestamp: DateTime.now());

  @override
  ChartDataState build() {
    final ffiClient = ref.read(sysPieClientProvider);

    _statsSubscription = ffiClient.events.listen((event) {
      if (event['type'] == 'stats') {
        final data = event['data'] as Map<String, dynamic>;
        _currentPoint = _currentPoint.copyWith(
          cpuUsage: ((data['cpuUsagePercent'] as num?)?.toDouble() ?? 0)
              .clamp(0, 100),
          cpuKernel: ((data['cpuKernelPercent'] as num?)?.toDouble() ?? 0)
              .clamp(0, 100),
          cpuUser:
              ((data['cpuUserPercent'] as num?)?.toDouble() ?? 0).clamp(0, 100),
          gpuUsage: ((data['gpuUsagePercent'] as num?)?.toDouble() ?? 0)
              .clamp(0, 100),
          memoryUsedMB: (data['usedPhysicalMB'] as num?)?.toDouble() ?? 0,
          memoryAvailableMB:
              (data['availablePhysicalMB'] as num?)?.toDouble() ?? 0,
          memoryTotalMB: (data['totalPhysicalMB'] as num?)?.toDouble() ?? 0,
          commitChargeMB: (data['commitChargeMB'] as num?)?.toDouble() ?? 0,
          commitLimitMB: (data['commitLimitMB'] as num?)?.toDouble() ?? 0,
          diskReadMBps: (data['diskReadMBps'] as num?)?.toDouble() ?? 0,
          diskWriteMBps: (data['diskWriteMBps'] as num?)?.toDouble() ?? 0,
          networkSendBps: (data['netSendBps'] as num?)?.toDouble() ?? 0,
          networkRecvBps: (data['netRecvBps'] as num?)?.toDouble() ?? 0,
          totalProcesses: (data['totalProcesses'] as num?)?.toInt() ?? 0,
          totalThreads: (data['totalThreads'] as num?)?.toInt() ?? 0,
          totalHandles: (data['totalHandles'] as num?)?.toInt() ?? 0,
          cpuSpeedMHz: (data['cpuSpeedMHz'] as num?)?.toDouble() ?? 0,
          cpuBaseSpeedMHz: (data['cpuBaseSpeedMHz'] as num?)?.toDouble() ?? 0,
          cpuName: (data['cpuName'] as String?) ?? '',
          cpuSockets: (data['cpuSockets'] as num?)?.toInt() ?? 0,
          cpuCores: (data['cpuCores'] as num?)?.toInt() ?? 0,
          cpuLogicalProcessors:
              (data['cpuLogicalProcessors'] as num?)?.toInt() ?? 0,
          cpuVirtualization: (data['cpuVirtualization'] as bool?) ?? false,
          cpuL1CacheKB: (data['cpuL1CacheKB'] as num?)?.toInt() ?? 0,
          cpuL2CacheKB: (data['cpuL2CacheKB'] as num?)?.toInt() ?? 0,
          cpuL3CacheKB: (data['cpuL3CacheKB'] as num?)?.toInt() ?? 0,
          uptimeSeconds: (data['uptimeSeconds'] as num?)?.toInt() ?? 0,
          memoryCompressedMB:
              (data['memoryCompressedMB'] as num?)?.toDouble() ?? 0,
          memoryCachedMB: (data['memoryCachedMB'] as num?)?.toDouble() ?? 0,
          memoryPagedPoolMB:
              (data['memoryPagedPoolMB'] as num?)?.toDouble() ?? 0,
          memoryNonPagedPoolMB:
              (data['memoryNonPagedPoolMB'] as num?)?.toDouble() ?? 0,
          memorySpeedMHz: (data['memorySpeedMHz'] as num?)?.toInt() ?? 0,
          memorySlotsUsed: (data['memorySlotsUsed'] as num?)?.toInt() ?? 0,
          memorySlotsTotal: (data['memorySlotsTotal'] as num?)?.toInt() ?? 0,
          memoryFormFactor: (data['memoryFormFactor'] as String?) ?? '',
          memoryType: (data['memoryType'] as String?) ?? '',
          memoryHardwareReservedMB:
              (data['memoryHardwareReservedMB'] as num?)?.toDouble() ?? 0,
          diskActivePercent:
              (data['diskActivePercent'] as num?)?.toDouble() ?? 0,
          diskAvgResponseMs:
              (data['diskAvgResponseMs'] as num?)?.toDouble() ?? 0,
          diskCapacityGB:
              ((data['diskCapacityBytes'] as num?)?.toDouble() ?? 0) /
                  (1024 * 1024 * 1024),
          diskIsSystem: (data['diskIsSystem'] as bool?) ?? false,
          diskHasPageFile: (data['diskHasPageFile'] as bool?) ?? false,
          diskType: (data['diskType'] as String?) ?? '',
          diskModel: (data['diskModel'] as String?) ?? '',
          netAdapterName: (data['netAdapterName'] as String?) ?? '',
          netNicModel: (data['netNicModel'] as String?) ?? '',
          netSsid: (data['netSsid'] as String?) ?? '',
          netConnectionType: (data['netConnectionType'] as String?) ?? '',
          netIpv4Address: (data['netIpv4Address'] as String?) ?? '',
          netIpv6Address: (data['netIpv6Address'] as String?) ?? '',
          netSignalPercent: (data['netSignalPercent'] as num?)?.toInt() ?? 0,
          gpuDedicatedMB: (data['gpuDedicatedMB'] as num?)?.toDouble() ?? 0.0,
          gpuSharedMB: (data['gpuSharedMB'] as num?)?.toDouble() ?? 0.0,
          gpuTotalMemoryMB:
              (data['gpuTotalMemoryMB'] as num?)?.toDouble() ?? 0.0,
          gpuDedicatedTotalMB:
              (data['gpuDedicatedTotalMB'] as num?)?.toDouble() ?? 0.0,
          gpuSharedTotalMB:
              (data['gpuSharedTotalMB'] as num?)?.toDouble() ?? 0.0,
          gpuName: (data['gpuName'] as String?) ?? '',
          gpuDriverVersion: (data['gpuDriverVersion'] as String?) ?? '',
          gpuDriverDate: (data['gpuDriverDate'] as String?) ?? '',
          gpuDirectXVersion: (data['gpuDirectXVersion'] as String?) ?? '',
          gpuPhysicalLocation: (data['gpuPhysicalLocation'] as String?) ?? '',
          gpuHardwareReservedMB:
              (data['gpuHardwareReservedMB'] as num?)?.toDouble() ?? 0.0,
        );
        _addPoint();
      }
    });

    ref.onDispose(() {
      _statsSubscription?.cancel();
    });

    return const ChartDataState();
  }

  void _addPoint() {
    final newPoint = ChartDataPoint(
      timestamp: DateTime.now(),
      cpuUsage: _currentPoint.cpuUsage,
      cpuKernel: _currentPoint.cpuKernel,
      cpuUser: _currentPoint.cpuUser,
      gpuUsage: _currentPoint.gpuUsage,
      memoryUsedMB: _currentPoint.memoryUsedMB,
      memoryAvailableMB: _currentPoint.memoryAvailableMB,
      memoryTotalMB: _currentPoint.memoryTotalMB,
      commitChargeMB: _currentPoint.commitChargeMB,
      commitLimitMB: _currentPoint.commitLimitMB,
      diskReadMBps: _currentPoint.diskReadMBps,
      diskWriteMBps: _currentPoint.diskWriteMBps,
      networkSendBps: _currentPoint.networkSendBps,
      networkRecvBps: _currentPoint.networkRecvBps,
      totalProcesses: _currentPoint.totalProcesses,
      totalThreads: _currentPoint.totalThreads,
      totalHandles: _currentPoint.totalHandles,
      cpuSpeedMHz: _currentPoint.cpuSpeedMHz,
      cpuBaseSpeedMHz: _currentPoint.cpuBaseSpeedMHz,
      cpuName: _currentPoint.cpuName,
      cpuSockets: _currentPoint.cpuSockets,
      cpuCores: _currentPoint.cpuCores,
      cpuLogicalProcessors: _currentPoint.cpuLogicalProcessors,
      cpuVirtualization: _currentPoint.cpuVirtualization,
      cpuL1CacheKB: _currentPoint.cpuL1CacheKB,
      cpuL2CacheKB: _currentPoint.cpuL2CacheKB,
      cpuL3CacheKB: _currentPoint.cpuL3CacheKB,
      uptimeSeconds: _currentPoint.uptimeSeconds,
      memoryCompressedMB: _currentPoint.memoryCompressedMB,
      memoryCachedMB: _currentPoint.memoryCachedMB,
      memoryPagedPoolMB: _currentPoint.memoryPagedPoolMB,
      memoryNonPagedPoolMB: _currentPoint.memoryNonPagedPoolMB,
      memorySpeedMHz: _currentPoint.memorySpeedMHz,
      memorySlotsUsed: _currentPoint.memorySlotsUsed,
      memorySlotsTotal: _currentPoint.memorySlotsTotal,
      memoryFormFactor: _currentPoint.memoryFormFactor,
      memoryType: _currentPoint.memoryType,
      memoryHardwareReservedMB: _currentPoint.memoryHardwareReservedMB,
      diskActivePercent: _currentPoint.diskActivePercent,
      diskAvgResponseMs: _currentPoint.diskAvgResponseMs,
      diskCapacityGB: _currentPoint.diskCapacityGB,
      diskIsSystem: _currentPoint.diskIsSystem,
      diskHasPageFile: _currentPoint.diskHasPageFile,
      diskType: _currentPoint.diskType,
      diskModel: _currentPoint.diskModel,
      netAdapterName: _currentPoint.netAdapterName,
      netNicModel: _currentPoint.netNicModel,
      netSsid: _currentPoint.netSsid,
      netConnectionType: _currentPoint.netConnectionType,
      netIpv4Address: _currentPoint.netIpv4Address,
      netIpv6Address: _currentPoint.netIpv6Address,
      netSignalPercent: _currentPoint.netSignalPercent,
      gpuDedicatedMB: _currentPoint.gpuDedicatedMB,
      gpuSharedMB: _currentPoint.gpuSharedMB,
      gpuTotalMemoryMB: _currentPoint.gpuTotalMemoryMB,
      gpuDedicatedTotalMB: _currentPoint.gpuDedicatedTotalMB,
      gpuSharedTotalMB: _currentPoint.gpuSharedTotalMB,
      gpuName: _currentPoint.gpuName,
      gpuDriverVersion: _currentPoint.gpuDriverVersion,
      gpuDriverDate: _currentPoint.gpuDriverDate,
      gpuDirectXVersion: _currentPoint.gpuDirectXVersion,
      gpuPhysicalLocation: _currentPoint.gpuPhysicalLocation,
      gpuHardwareReservedMB: _currentPoint.gpuHardwareReservedMB,
    );

    final points = [...state.points, newPoint];
    if (points.length > _maxPoints) {
      points.removeRange(0, points.length - _maxPoints);
    }

    state = state.copyWith(
      points: points,
      isLoading: false,
    );
  }
}

final chartDataProvider = NotifierProvider<ChartDataNotifier, ChartDataState>(
  ChartDataNotifier.new,
);
