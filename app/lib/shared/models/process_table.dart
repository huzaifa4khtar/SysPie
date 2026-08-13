/// Data models for the process data table. It defines ProcessTableColumn for
/// column definitions, ProcessTableRow for individual process entries,
/// ProcessRowType for the row types, and ProcessCategory for grouping
/// processes into sections.
library;

/// Defines a single column with a label shown in the header and a fixed width.
class ProcessTableColumn {
  final String label;
  final double width;

  const ProcessTableColumn({
    required this.label,
    required this.width,
  });
}

/// Categories for grouping processes into collapsible sections: apps,
/// background, and windows processes.
enum ProcessCategory {
  apps,
  background,
  windowsProcesses;

  /// Display name shown in the group header row.
  String get displayName {
    switch (this) {
      case ProcessCategory.apps:
        return 'Apps';
      case ProcessCategory.background:
        return 'Background Processes';
      case ProcessCategory.windowsProcesses:
        return 'Windows Processes';
    }
  }
}

/// The explicit type of a row in the process tree. Each type has its own
/// display rules for PID, expand arrows, and children.
enum ProcessRowType {
  /// Category header that groups rows, like Apps with a count, and expands to
  /// show its children.
  groupHeader,

  /// App level group like Notepad with a count, which groups multiple
  /// processes under one friendly name, shows no PID, and is always
  /// expandable.
  appGroup,

  /// A real process row with its own genuine PID that always shows its PID.
  /// Window titles appear as subtitles, never as separate child rows.
  process,

  /// A window title sub-item under a process group, showing the title with a
  /// close button and carrying the parent PID and window handle for closing.
  window,
}

/// Represents a single row of process data in the table. Group headers show a
/// category name with its total count, app groups show a process count as their
/// sub-label with no PID, and real process rows always show their own PID with
/// window titles and service names as subtitles.
class ProcessTableRow {
  final String name;
  final String exePath;
  final String? subLabel;
  final String pid;

  /// Data URI for the process icon as a base64 PNG, or null when not loaded.
  final String? iconDataUri;

  final String? statusLabel;
  final int? statusType;
  final String username;
  final String cpu;
  final String memory;
  final String disk;
  final String network;
  final String gpu;
  final String uacVirtualization;
  final bool hasExpandArrow;
  final bool isExpanded;
  final int childCount;
  final List<ProcessTableRow> children;

  final ProcessRowType rowType;

  /// The category this row belongs to, or null for child rows.
  final ProcessCategory? category;

  /// Window titles owned by this process, shown as subtitles below the name.
  final List<String> windowTitles;

  /// Service display names hosted by this process, usually svchost, shown as
  /// subtitles.
  final List<String> serviceDisplayNames;

  /// Whether this row is indented as a child that has no PID in the childPids
  /// set, used for window title and service host rows.
  final bool isIndentedChild;

  /// PID of the first child, used to fall back to its icon on app group rows.
  final int? firstChildPid;

  /// Window handle for closing a window sub-item.
  final int windowHandle;

  /// PID of the window owner, checked before closing a protected window.
  final int windowOwnerPid;

  /// All PIDs in an app group, used to terminate the whole group at once.
  final List<int> childPids;

  /// Service group name for the Services screen.
  final String group;

  /// Service friendly name for the Services screen.
  final String displayName;

  /// Service type for the Services screen, like Own process or Driver.
  final String serviceType;

  /// Socket specific fields.
  final String localAddress;
  final int localPort;
  final String remoteAddress;
  final int remotePort;
  final String protocol;

  // Details screen fields.
  final String parentProcessName;
  final String diskPermission;

  // Users screen fields.
  final String gpuEngine;
  final String powerUsage;

  // App History screen fields.
  final String cpuTime;
  final String meteredNetwork;
  final String tieUpdate;

  /// Local asset path shown instead of the native icon when set.
  final String? iconAsset;

  /// Whether this row is a category group header, derived from the row type.
  bool get isGroupHeader => rowType == ProcessRowType.groupHeader;

  /// Stable expansion key for app group rows, using the category and name.
  String get expansionKey {
    if (rowType == ProcessRowType.appGroup) {
      // svchost groups share the Service Host name, so use the PID for
      // uniqueness.
      if (name == 'Service Host') {
        return 'svchost_${firstChildPid ?? 0}';
      }
      return '${category?.index ?? 0}_$name';
    }
    return pid;
  }

  const ProcessTableRow({
    required this.name,
    this.exePath = '',
    this.subLabel,
    required this.pid,
    this.iconDataUri,
    this.statusLabel,
    this.statusType,
    required this.username,
    required this.cpu,
    required this.memory,
    required this.disk,
    required this.network,
    required this.gpu,
    required this.uacVirtualization,
    this.hasExpandArrow = false,
    this.isExpanded = false,
    this.childCount = 0,
    this.children = const [],
    this.rowType = ProcessRowType.process,
    this.category,
    this.windowTitles = const [],
    this.serviceDisplayNames = const [],
    this.isIndentedChild = false,
    this.firstChildPid,
    this.childPids = const [],
    this.windowHandle = 0,
    this.windowOwnerPid = 0,
    this.group = '',
    this.displayName = '',
    this.serviceType = '',
    this.localAddress = '',
    this.localPort = 0,
    this.remoteAddress = '',
    this.remotePort = 0,
    this.protocol = '',
    // Details screen fields
    this.parentProcessName = '',
    this.diskPermission = '',
    // Users screen fields
    this.gpuEngine = '',
    this.powerUsage = '',
    // App History screen fields
    this.cpuTime = '',
    this.meteredNetwork = '',
    this.tieUpdate = '',
    this.iconAsset,
  });

  /// Creates a category header row showing the group name and process count.
  factory ProcessTableRow.groupHeader(
    ProcessCategory category,
    int count, {
    bool isExpanded = true,
  }) {
    return ProcessTableRow(
      name: '${category.displayName} ($count)',
      pid: '',
      username: '',
      cpu: '',
      memory: '',
      disk: '',
      network: '',
      gpu: '',
      uacVirtualization: '',
      rowType: ProcessRowType.groupHeader,
      category: category,
      isExpanded: isExpanded,
    );
  }

  /// Creates a group row for several processes that share one name.
  /// It never shows a PID and uses the process count as the sub-label.
  factory ProcessTableRow.appGroup({
    required String name,
    required int processCount,
    required ProcessCategory category,
    List<ProcessTableRow> children = const [],
    String? iconDataUri,
    String? cpu,
    String? memory,
    String? disk,
    String? network,
    String? gpu,
    String? gpuEngine,
    String? powerUsage,
    int? firstChildPid,
    List<int> childPids = const [],
    String? exePath,
    String? subLabel,
  }) {
    return ProcessTableRow(
      name: name,
      exePath: exePath ?? '',
      subLabel: subLabel ?? '$processCount',
      pid: '',
      iconDataUri: iconDataUri,
      username: '',
      cpu: cpu ?? '',
      memory: memory ?? '',
      disk: disk ?? '',
      network: network ?? '',
      gpu: gpu ?? '',
      gpuEngine: gpuEngine ?? '',
      powerUsage: powerUsage ?? '',
      uacVirtualization: '',
      hasExpandArrow: children.isNotEmpty,
      childCount: children.length,
      children: children,
      rowType: ProcessRowType.appGroup,
      category: category,
      firstChildPid: firstChildPid,
      childPids: childPids,
    );
  }

  ProcessTableRow copyWith({
    String? name,
    String? exePath,
    String? subLabel,
    String? pid,
    String? iconDataUri,
    String? statusLabel,
    int? statusType,
    String? username,
    String? cpu,
    String? memory,
    String? disk,
    String? network,
    String? gpu,
    String? uacVirtualization,
    bool? hasExpandArrow,
    bool? isExpanded,
    int? childCount,
    List<ProcessTableRow>? children,
    ProcessRowType? rowType,
    ProcessCategory? category,
    List<String>? windowTitles,
    List<String>? serviceDisplayNames,
    bool? isIndentedChild,
    int? firstChildPid,
    List<int>? childPids,
    int? windowHandle,
    int? windowOwnerPid,
    String? group,
    String? displayName,
    String? serviceType,
    String? localAddress,
    int? localPort,
    String? remoteAddress,
    int? remotePort,
    String? protocol,
    String? iconAsset,
    String? parentProcessName,
    String? diskPermission,
    String? gpuEngine,
    String? powerUsage,
    String? cpuTime,
    String? meteredNetwork,
    String? tieUpdate,
  }) {
    return ProcessTableRow(
      name: name ?? this.name,
      exePath: exePath ?? this.exePath,
      subLabel: subLabel ?? this.subLabel,
      pid: pid ?? this.pid,
      iconDataUri: iconDataUri ?? this.iconDataUri,
      statusLabel: statusLabel ?? this.statusLabel,
      statusType: statusType ?? this.statusType,
      username: username ?? this.username,
      cpu: cpu ?? this.cpu,
      memory: memory ?? this.memory,
      disk: disk ?? this.disk,
      network: network ?? this.network,
      gpu: gpu ?? this.gpu,
      uacVirtualization: uacVirtualization ?? this.uacVirtualization,
      hasExpandArrow: hasExpandArrow ?? this.hasExpandArrow,
      isExpanded: isExpanded ?? this.isExpanded,
      childCount: childCount ?? this.childCount,
      children: children ?? this.children,
      rowType: rowType ?? this.rowType,
      category: category ?? this.category,
      windowTitles: windowTitles ?? this.windowTitles,
      serviceDisplayNames: serviceDisplayNames ?? this.serviceDisplayNames,
      isIndentedChild: isIndentedChild ?? this.isIndentedChild,
      firstChildPid: firstChildPid ?? this.firstChildPid,
      childPids: childPids ?? this.childPids,
      windowHandle: windowHandle ?? this.windowHandle,
      windowOwnerPid: windowOwnerPid ?? this.windowOwnerPid,
      group: group ?? this.group,
      displayName: displayName ?? this.displayName,
      serviceType: serviceType ?? this.serviceType,
      localAddress: localAddress ?? this.localAddress,
      localPort: localPort ?? this.localPort,
      remoteAddress: remoteAddress ?? this.remoteAddress,
      remotePort: remotePort ?? this.remotePort,
      protocol: protocol ?? this.protocol,
      iconAsset: iconAsset ?? this.iconAsset,
      parentProcessName: parentProcessName ?? this.parentProcessName,
      diskPermission: diskPermission ?? this.diskPermission,
      gpuEngine: gpuEngine ?? this.gpuEngine,
      powerUsage: powerUsage ?? this.powerUsage,
      cpuTime: cpuTime ?? this.cpuTime,
      meteredNetwork: meteredNetwork ?? this.meteredNetwork,
      tieUpdate: tieUpdate ?? this.tieUpdate,
    );
  }
}
