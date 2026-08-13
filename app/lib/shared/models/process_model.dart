/// API response model for process data from the native library.
class ProcessModel {
  final int pid;
  final int parentPid;
  final String name;
  final String exePath;
  final String friendlyName;
  final String detailName;
  final String aumid;
  final String userName;
  final String status;
  final int statusType;
  final int threadCount;
  final int handleCount;
  final double cpuUsage;
  final double memoryMB;
  final bool memoryAccessDenied;
  final double diskReadMB;
  final double diskWriteMB;
  final double networkBps;
  final double gpuPercent;
  final String gpuEngine;
  final String powerUsage;
  final String diskPermission;
  final String uacVirtualization;
  final bool isSystemProcess;
  final bool hasVisibleWindow;
  final bool hasIdeMatch;
  final List<String> windowTitles;
  final List<String> serviceDisplayNames;
  final List<WindowModel> windowInfos;

  const ProcessModel({
    required this.pid,
    required this.parentPid,
    required this.name,
    required this.exePath,
    required this.friendlyName,
    required this.detailName,
    required this.aumid,
    required this.userName,
    required this.status,
    required this.statusType,
    required this.threadCount,
    required this.handleCount,
    required this.cpuUsage,
    required this.memoryMB,
    required this.memoryAccessDenied,
    required this.diskReadMB,
    required this.diskWriteMB,
    required this.networkBps,
    required this.gpuPercent,
    required this.gpuEngine,
    required this.powerUsage,
    required this.diskPermission,
    required this.uacVirtualization,
    required this.isSystemProcess,
    required this.hasVisibleWindow,
    required this.hasIdeMatch,
    required this.windowTitles,
    required this.serviceDisplayNames,
    required this.windowInfos,
  });

  factory ProcessModel.fromJson(Map<String, dynamic> json) {
    return ProcessModel(
      pid: json['pid'] as int? ?? 0,
      parentPid: json['parentPid'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      exePath: json['exePath'] as String? ?? '',
      friendlyName: json['friendlyName'] as String? ?? '',
      detailName: json['detailName'] as String? ?? '',
      aumid: json['aumid'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      status: json['status'] as String? ?? 'UNKNOWN',
      statusType: json['statusType'] as int? ?? 0,
      threadCount: json['threadCount'] as int? ?? 0,
      handleCount: json['handleCount'] as int? ?? 0,
      cpuUsage: (json['cpuUsage'] as num?)?.toDouble() ?? 0.0,
      memoryMB: (json['memoryMB'] as num?)?.toDouble() ?? 0.0,
      memoryAccessDenied: json['memoryAccessDenied'] as bool? ?? false,
      diskReadMB: (json['diskReadMB'] as num?)?.toDouble() ?? 0.0,
      diskWriteMB: (json['diskWriteMB'] as num?)?.toDouble() ?? 0.0,
      networkBps: (json['networkBps'] as num?)?.toDouble() ?? 0.0,
      gpuPercent: (json['gpuPercent'] as num?)?.toDouble() ?? 0.0,
      gpuEngine: json['gpuEngine'] as String? ?? '',
      powerUsage: json['powerUsage'] as String? ?? '',
      diskPermission: json['diskPermission'] as String? ?? 'Read',
      uacVirtualization: json['uacVirtualization'] as String? ?? 'Disabled',
      isSystemProcess: json['isSystemProcess'] as bool? ?? false,
      hasVisibleWindow: json['hasVisibleWindow'] as bool? ?? false,
      hasIdeMatch: json['hasIdeMatch'] as bool? ?? false,
      windowTitles: (json['windowTitles'] as List<dynamic>?)?.map((e) {
            if (e is Map<String, dynamic>) {
              return e['title'] as String? ?? '';
            }
            return e as String? ?? '';
          }).toList() ??
          [],
      serviceDisplayNames: (json['serviceDisplayNames'] as List<dynamic>?)
              ?.map((e) => e as String? ?? '')
              .toList() ??
          [],
      windowInfos: (json['windowTitles'] as List<dynamic>?)?.map((e) {
            if (e is Map<String, dynamic>) {
              return WindowModel(
                title: e['title'] as String? ?? '',
                hwnd: e['hwnd'] as int? ?? 0,
                pid: e['pid'] as int? ?? 0,
              );
            }
            // Fallback for the old plain string format.
            return WindowModel(title: e as String? ?? '', hwnd: 0);
          }).toList() ??
          [],
    );
  }
}

/// API response model for system-wide statistics.
class SystemStatsModel {
  final double cpuUsagePercent;
  final int totalProcesses;
  final int totalThreads;
  final int totalHandles;
  final double totalPhysicalMB;
  final double usedPhysicalMB;
  final double availablePhysicalMB;
  final double commitChargeMB;
  final double commitLimitMB;
  final double diskReadMBps;
  final double diskWriteMBps;
  final double gpuUsagePercent;

  const SystemStatsModel({
    required this.cpuUsagePercent,
    required this.totalProcesses,
    required this.totalThreads,
    required this.totalHandles,
    required this.totalPhysicalMB,
    required this.usedPhysicalMB,
    required this.availablePhysicalMB,
    required this.commitChargeMB,
    required this.commitLimitMB,
    this.diskReadMBps = 0.0,
    this.diskWriteMBps = 0.0,
    this.gpuUsagePercent = 0.0,
  });

  factory SystemStatsModel.fromJson(Map<String, dynamic> json) {
    return SystemStatsModel(
      cpuUsagePercent: (json['cpuUsagePercent'] as num?)?.toDouble() ?? 0.0,
      totalProcesses: json['totalProcesses'] as int? ?? 0,
      totalThreads: json['totalThreads'] as int? ?? 0,
      totalHandles: json['totalHandles'] as int? ?? 0,
      totalPhysicalMB: (json['totalPhysicalMB'] as num?)?.toDouble() ?? 0.0,
      usedPhysicalMB: (json['usedPhysicalMB'] as num?)?.toDouble() ?? 0.0,
      availablePhysicalMB:
          (json['availablePhysicalMB'] as num?)?.toDouble() ?? 0.0,
      commitChargeMB: (json['commitChargeMB'] as num?)?.toDouble() ?? 0.0,
      commitLimitMB: (json['commitLimitMB'] as num?)?.toDouble() ?? 0.0,
      diskReadMBps: (json['diskReadMBps'] as num?)?.toDouble() ?? 0.0,
      diskWriteMBps: (json['diskWriteMBps'] as num?)?.toDouble() ?? 0.0,
      gpuUsagePercent: (json['gpuUsagePercent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Window information including the handle used for closing.
class WindowModel {
  final String title;
  final int hwnd;
  final int pid;

  const WindowModel({required this.title, required this.hwnd, this.pid = 0});
}
