import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/models/process_table.dart';
import '../../../shared/models/process_model.dart';
import '../process_controller.dart';
import '../../users/user_controller.dart';
import '../../../shared/services/icon_service.dart';
import '../../../shared/services/os_actions.dart';
import '../process_service.dart';
import '../../../core/widgets/data_table.dart';
import '../../../core/widgets/context_menu.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/table_keyboard.dart';
import '../../../shared/value_formatters.dart';

class ProcessesScreen extends ConsumerStatefulWidget {
  /// Optionally highlights and selects this PID when arriving from another screen.
  final int? highlightPid;

  final void Function(int pid)? onNavigateToDetails;
  final void Function(int pid)? onNavigateToUsers;
  final String searchQuery;

  const ProcessesScreen({
    super.key,
    this.highlightPid,
    this.onNavigateToDetails,
    this.onNavigateToUsers,
    this.searchQuery = '',
  });

  @override
  ConsumerState<ProcessesScreen> createState() => _ProcessesScreenState();
}

class _ProcessesScreenState extends ConsumerState<ProcessesScreen> {
  int? _selectedRowIndex;

  final ScrollController _hScrollController = ScrollController();
  final ScrollController _vScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final Set<ProcessCategory> _expandedGroups = {
    ProcessCategory.apps,
    ProcessCategory.background,
    ProcessCategory.windowsProcesses,
  };

  final Set<String> _expandedGroupKeys = {};

  /// Saves the expansion state before a search and restores it when the search clears.
  Set<ProcessCategory> _savedExpandedGroups = {};
  Set<String> _savedExpandedGroupKeys = {};
  String _lastSearchQuery = '';

  /// Caches the child PIDs, computed once per build instead of twice.
  Set<String> _cachedChildPids = const {};

  /// Filters processes by the search query, matching the exe name, display name, detail name, AUMID display name, PID, username, exe path, window titles, and service display names.
  List<ProcessModel> _filterProcesses(List<ProcessModel> allProcesses) {
    if (widget.searchQuery.isEmpty) return allProcesses;
    final query = widget.searchQuery.toLowerCase();

    return allProcesses.where((p) {
      if (p.name.toLowerCase().contains(query)) return true;
      if (p.friendlyName.toLowerCase().contains(query)) return true;
      if (p.detailName.toLowerCase().contains(query)) return true;
      if (p.pid.toString().contains(query)) return true;
      if (p.userName.toLowerCase().contains(query)) return true;
      if (p.exePath.toLowerCase().contains(query)) return true;
      for (final t in p.windowTitles) {
        if (t.toLowerCase().contains(query)) return true;
      }
      for (final s in p.serviceDisplayNames) {
        if (s.toLowerCase().contains(query)) return true;
      }
      if (p.aumid.isNotEmpty) {
        final aumidName = _aumidBaseName(p.aumid, [p]);
        if (aumidName.toLowerCase().contains(query)) return true;
      }
      return false;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    if (widget.highlightPid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _highlightPid(widget.highlightPid!);
      });
    }
  }

  @override
  void dispose() {
    _hScrollController.dispose();
    _vScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProcessesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightPid != null &&
        widget.highlightPid != oldWidget.highlightPid) {
      _highlightPid(widget.highlightPid!);
    }
  }

  void _highlightPid(int pid) {
    final processState = ref.read(processProvider);
    final allRows = _buildRows(processState.processes);

    // If the PID is already visible, select and scroll to it.
    final visibleRows = _buildVisibleRows(processState.processes);
    for (int i = 0; i < visibleRows.length; i++) {
      if (visibleRows[i].pid == pid.toString()) {
        _selectAndScroll(i);
        return;
      }
    }

    // If not visible, search all rows to find which groups contain the PID.
    bool expanded = false;
    for (final row in allRows) {
      if (row.pid == pid.toString()) {
        // The row exists in the full list, so expand its parent groups.
        if (row.category != null && !_expandedGroups.contains(row.category)) {
          _expandedGroups.add(row.category!);
          expanded = true;
        }
        // For app group rows, also expand the group itself.
        if (row.rowType == ProcessRowType.appGroup) {
          final key = row.expansionKey;
          if (!_expandedGroupKeys.contains(key)) {
            _expandedGroupKeys.add(key);
            expanded = true;
          }
        }
        break;
      }
      // Also check the children of app groups.
      if (row.rowType == ProcessRowType.appGroup) {
        for (final child in row.children) {
          if (child.pid == pid.toString()) {
            // Expand the parent category if it is collapsed.
            if (row.category != null &&
                !_expandedGroups.contains(row.category)) {
              _expandedGroups.add(row.category!);
              expanded = true;
            }
            // Expand the app group itself.
            final key = row.expansionKey;
            if (!_expandedGroupKeys.contains(key)) {
              _expandedGroupKeys.add(key);
              expanded = true;
            }
            break;
          }
        }
      }
    }

    // After expanding, wait for the rebuild and then highlight the row.
    if (expanded) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final updatedVisible = _buildVisibleRows(processState.processes);
        for (int i = 0; i < updatedVisible.length; i++) {
          if (updatedVisible[i].pid == pid.toString()) {
            _selectAndScroll(i);
            return;
          }
        }
      });
    }
  }

  void _selectAndScroll(int index) {
    setState(() => _selectedRowIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_vScrollController.hasClients) {
        final targetOffset =
            (index * AppDimensions.rowHeight) - (AppDimensions.rowHeight * 3);
        _vScrollController.animateTo(
          targetOffset.clamp(0.0, _vScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<bool> _showDangerousWarning(String processName, int pid) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
            ),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.statusRed, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Warning',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            content: Text(
              'You are about to terminate "$processName" (PID $pid). '
              'This is a critical system process. Terminating it may cause '
              'system instability or immediate shutdown.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.statusRed.withValues(alpha: 0.1),
                ),
                child: const Text(
                  'End Process',
                  style: TextStyle(
                    color: AppColors.statusRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  static const List<ProcessTableColumn> _columns = [
    ProcessTableColumn(label: 'NAME', width: AppDimensions.colName),
    ProcessTableColumn(label: 'CPU', width: AppDimensions.colCpu),
    ProcessTableColumn(label: 'MEMORY', width: AppDimensions.colMemory),
    ProcessTableColumn(label: 'DISK', width: AppDimensions.colDisk),
    ProcessTableColumn(label: 'NETWORK', width: AppDimensions.colNetwork),
    ProcessTableColumn(label: 'GPU', width: AppDimensions.colGpu),
    ProcessTableColumn(label: 'GPU ENGINE', width: AppDimensions.colGpuEngine),
    ProcessTableColumn(
        label: 'POWER USAGE', width: AppDimensions.colPowerUsage),
  ];

  static const List<ProcessCategory> _categoryOrder = [
    ProcessCategory.apps,
    ProcessCategory.background,
    ProcessCategory.windowsProcesses,
  ];

  /// Hard coded list of Windows processes that are always categorized as Windows Processes regardless of their window state or critical flag, matching Windows Task Manager's behavior.
  static final Set<String> _windowsProcessNames = {
    'applicationframehost.exe',
    'audiodg.exe',
    'backgroundtransferhost.exe',
    'backgroundtaskhost.exe',
    'computedeef.exe',
    'conhost.exe',
    'csrss.exe',
    'dcomlaunch.exe',
    'dwm.exe',
    'lsass.exe',
    'lsm.exe',
    'ngenserver.exe',
    'registry.exe',
    'rundll32.exe',
    'searchindexer.exe',
    'searchprotocolhost.exe',
    'services.exe',
    'sihost.exe',
    'smss.exe',
    'svchost.exe',
    'vmms.exe',
    'werfault.exe',
    'wininit.exe',
    'wlanext.exe',
    'wudfhost.exe',
  };

  static ProcessCategory _categorizeProcess(ProcessModel p) {
    // First check the hard coded Windows Process list.
    final exeName = p.name.toLowerCase();
    if (_windowsProcessNames.contains(exeName)) {
      return ProcessCategory.windowsProcesses;
    }

    // Then check the critical flag, which marks system processes.
    if (p.isSystemProcess) return ProcessCategory.windowsProcesses;

    // Then check for a visible window, which makes it an App.
    if (p.hasVisibleWindow) {
      // Explorer.exe always counts as visible because of the taskbar, so only show it as an App when it has open windows.
      if (exeName == 'explorer.exe' && p.windowInfos.isEmpty) {
        return ProcessCategory.background;
      }
      return ProcessCategory.apps;
    }

    // Everything else becomes a background process.
    return ProcessCategory.background;
  }

  static String _shortUserName(String full) {
    if (full.contains('\\')) return full.split('\\').last;
    return full;
  }

  static int _powerUsageRank(String level) {
    switch (level) {
      case 'Very High':
        return 4;
      case 'High':
        return 3;
      case 'Moderate':
        return 2;
      case 'Low':
        return 1;
      case 'Very Low':
        return 0;
      default:
        return -1;
    }
  }

  /// Returns the display name, using the native friendlyName or the exe name without the extension.
  static String _displayName(ProcessModel p) {
    String name = p.friendlyName;
    if (name.isEmpty) {
      name = p.name;
      if (name.toLowerCase().endsWith('.exe')) {
        name = name.substring(0, name.length - 4);
      }
    }
    return name;
  }

  /// Maps a known AUMID AppId to its base display name without collision disambiguation.
  static String _aumidBaseName(String aumid, List<ProcessModel> group) {
    if (aumid.contains('!ShellFeedsUI')) return 'News and Interests';
    if (aumid.contains('!CortanaUI')) return 'Search';
    return _displayName(group.first);
  }

  /// Extracts the AppId suffix from a full AUMID, meaning the part after the exclamation mark.
  static String _aumidAppId(String aumid) {
    final idx = aumid.indexOf('!');
    return idx >= 0 ? aumid.substring(idx + 1) : aumid;
  }

  /// Creates a process row for a single real process. Window titles and service names become subtitles, not child rows. The displayNameOverride changes the shown name, used when the name is resolved from an AUMID.
  static ProcessTableRow _createProcessRow(
    ProcessModel p, {
    ProcessCategory? category,
    String? iconDataUri,
    String? displayNameOverride,
  }) {
    // Uses detailName as a subtitle when it differs from the display name and adds information.
    final displayName = displayNameOverride ?? _displayName(p);
    String? detailSubtitle;
    if (p.detailName.isNotEmpty) {
      final lowerDetail = p.detailName.toLowerCase();
      final lowerDisplay = displayName.toLowerCase();
      // Skips the subtitle when the detail name just appends .exe to the display name.
      if (lowerDetail != lowerDisplay && lowerDetail != '$lowerDisplay.exe') {
        detailSubtitle = p.detailName;
      }
    }

    return ProcessTableRow(
      name: displayName,
      exePath: p.exePath,
      subLabel: detailSubtitle,
      pid: p.pid.toString(),
      iconDataUri: iconDataUri,
      statusLabel: p.status,
      statusType: p.statusType,
      username: _shortUserName(p.userName),
      cpu: formatCpuPercent(p.cpuUsage),
      memory: p.memoryAccessDenied ? 'N/A' : formatMemoryMB(p.memoryMB),
      disk: formatDiskMBps(p.diskReadMB + p.diskWriteMB),
      network: formatNetworkBps(p.networkBps),
      gpu: formatGpuPercent(p.gpuPercent),
      gpuEngine: p.gpuEngine,
      powerUsage: p.powerUsage,
      uacVirtualization: p.uacVirtualization,
      hasExpandArrow: false,
      rowType: ProcessRowType.process,
      category: category,
      windowTitles: p.windowTitles,
      serviceDisplayNames: const [],
    );
  }

  /// Builds rows with app level grouping by friendly name. App groups hold multiple processes under one name, or a single process with several windows or services, show a count, and are always expandable. Process rows are single processes with at most one window or service, always show their own PID, and keep window titles as subtitles.
  List<ProcessTableRow> _buildRows(List<ProcessModel> processes) {
    final groups = <String, List<ProcessModel>>{};
    final usedPids = <int>{};

    // Groups processes by AUMID, since packaged apps and their children share one AUMID. This matches Task Manager, so processes like the webview children of News and Interests end up under the same app name. The full AUMID is the group key so different AppIds like CortanaUI and ShellFeedsUI do not collide even when the native returns the same friendlyName.
    final aumidGroups = <String, List<ProcessModel>>{};
    for (final p in processes) {
      if (p.aumid.isNotEmpty && p.name.toLowerCase() != 'runtimebroker.exe') {
        aumidGroups.putIfAbsent(p.aumid, () => []).add(p);
        usedPids.add(p.pid);
      }
    }
    for (final entry in aumidGroups.entries) {
      final group = entry.value;
      groups[entry.key] = group;
    }

    // Groups non AUMID App processes by friendlyName, leaving background and Windows processes ungrouped for later nesting.
    for (final p in processes) {
      if (usedPids.contains(p.pid)) continue;
      if (p.aumid.isNotEmpty) continue;

      final category = _categorizeProcess(p);

      // svchost.exe is special, so each instance gets its own group.
      if (p.name.toLowerCase() == 'svchost.exe') {
        final actualKey = '${_displayName(p)} (${p.pid})';
        groups.putIfAbsent(actualKey, () => []).add(p);
        usedPids.add(p.pid);
        _collectChildren(p, processes, groups[actualKey]!, usedPids);
        continue;
      }

      if (category == ProcessCategory.apps) {
        final groupKey = _displayName(p);
        groups.putIfAbsent(groupKey, () => []).add(p);
        usedPids.add(p.pid);
        _collectChildren(p, processes, groups[groupKey]!, usedPids);
      }
    }

    // Then nest remaining background processes under their nearest App ancestor.
    _groupDirectChildren(processes, groups, usedPids);

    // Remaining ungrouped processes, which are background or Windows processes without an App ancestor, get their own top level entries.
    for (final p in processes) {
      if (usedPids.contains(p.pid)) continue;
      // All RuntimeBroker.exe instances share the Runtime Broker name regardless of the hosted app.
      final groupKey = p.name.toLowerCase() == 'runtimebroker.exe'
          ? 'Runtime Broker'
          : _displayName(p);
      groups.putIfAbsent(groupKey, () => []).add(p);
      usedPids.add(p.pid);
    }

    // Resolves display names for AUMID based groups. When two different AUMIDs resolve to the same base name, it appends the AppId suffix to tell them apart, like Search application with CortanaUI in parentheses.
    final aumidDisplayNames = <String, String>{};
    {
      final tentative = <String, List<String>>{};
      for (final entry in groups.entries) {
        final group = entry.value;
        if (group.isEmpty || group.first.aumid.isEmpty) continue;
        final name = _aumidBaseName(entry.key, group);
        tentative.putIfAbsent(name, () => []).add(entry.key);
      }
      for (final entry in tentative.entries) {
        final keys = entry.value;
        if (keys.length == 1) {
          aumidDisplayNames[keys.first] = entry.key;
        } else {
          for (final aumidKey in keys) {
            aumidDisplayNames[aumidKey] =
                '${entry.key} (${_aumidAppId(aumidKey)})';
          }
        }
      }
    }

    // Builds the rows for each group.
    final rows = <ProcessTableRow>[];
    for (final entry in groups.entries) {
      final groupProcesses = entry.value;
      if (groupProcesses.isEmpty) continue;

      final firstP = groupProcesses.first;
      final category = _categorizeProcess(firstP);

      // A group row is needed when there are multiple processes with the same name, or when a single process has window titles so the user can close each window.
      final multiProcess = groupProcesses.length > 1;
      final hasWindows =
          !multiProcess && groupProcesses.first.windowInfos.isNotEmpty;
      final isSvchostMultiService =
          firstP.name.toLowerCase() == 'svchost.exe' &&
              firstP.serviceDisplayNames.length > 1;
      final needsGroup = multiProcess || hasWindows || isSvchostMultiService;

      if (!needsGroup) {
        // A single process with at most one window or service becomes a standalone row.
        final p = groupProcesses.first;
        final iconUri = IconService.getCachedIcon(p.pid);
        final aumidName = p.aumid.isNotEmpty
            ? (aumidDisplayNames[p.aumid] ?? _displayName(p))
            : null;
        rows.add(_createProcessRow(
          p,
          category: category,
          iconDataUri: iconUri,
          displayNameOverride: aumidName,
        ));
      } else {
        // Multiple processes, or one process with several windows or services, become an app group row with child rows.
        double accumMem = 0, accumCpu = 0, accumDiskR = 0, accumDiskW = 0;
        double accumNet = 0, accumGpu = 0;
        String groupGpuEngine = '';
        for (final p in groupProcesses) {
          accumMem += p.memoryMB;
          accumCpu += p.cpuUsage;
          accumDiskR += p.diskReadMB;
          accumDiskW += p.diskWriteMB;
          accumNet += p.networkBps;
          accumGpu += p.gpuPercent;
          if (groupGpuEngine.isEmpty && p.gpuEngine.isNotEmpty) {
            groupGpuEngine = p.gpuEngine;
          }
        }

        // Uses the highest power usage found among the children.
        String groupPowerUsage = '';
        for (final p in groupProcesses) {
          if (p.powerUsage.isNotEmpty) {
            if (groupPowerUsage.isEmpty ||
                _powerUsageRank(p.powerUsage) >
                    _powerUsageRank(groupPowerUsage)) {
              groupPowerUsage = p.powerUsage;
            }
          }
        }
        if (groupPowerUsage.isEmpty) groupPowerUsage = 'Very Low';

        // Builds the child rows.
        final childRows = <ProcessTableRow>[];
        if (multiProcess) {
          // Each process in a multi process group is a child row with its own PID.
          for (final p in groupProcesses) {
            String? iconUri = IconService.getCachedIcon(p.pid);
            // RuntimeBroker.exe uses the AUMID based icon of the hosted app.
            if (p.name.toLowerCase() == 'runtimebroker.exe' &&
                p.aumid.isNotEmpty) {
              final aumidIcon = IconService.getCachedAumidIcon(p.aumid);
              if (aumidIcon != null && aumidIcon.isNotEmpty) {
                iconUri = aumidIcon;
              } else {
                // Triggers an async load so the icon appears on the next cycle.
                IconService.loadIconByAumid(p.aumid);
              }
            }
            childRows.add(
                _createProcessRow(p, category: category, iconDataUri: iconUri));
          }
        } else {
          // For one process with several windows or services, window titles become sub items and service names become child rows.
          final p = groupProcesses.first;
          final iconUri = IconService.getCachedIcon(p.pid);
          for (final info in p.windowInfos) {
            childRows.add(ProcessTableRow(
              name: info.title,
              pid: '',
              iconDataUri: iconUri,
              username: '',
              cpu: '',
              memory: '',
              disk: '',
              network: '',
              gpu: '',
              gpuEngine: '',
              powerUsage: '',
              uacVirtualization: '',
              rowType: ProcessRowType.window,
              isIndentedChild: true,
              windowHandle: info.hwnd,
              windowOwnerPid: info.pid,
            ));
          }
          for (final srv in p.serviceDisplayNames) {
            childRows.add(ProcessTableRow(
              name: srv,
              pid: p.pid.toString(),
              iconDataUri: iconUri,
              username: '',
              cpu: '',
              memory: '',
              disk: '',
              network: '',
              gpu: '',
              gpuEngine: '',
              powerUsage: '',
              uacVirtualization: '',
              rowType: ProcessRowType.process,
              isIndentedChild: true,
            ));
          }
        }
        childRows.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        final childCount =
            multiProcess ? groupProcesses.length : childRows.length;

        final groupName = firstP.name.toLowerCase() == 'svchost.exe'
            ? (firstP.serviceDisplayNames.isNotEmpty
                ? 'Service Host: ${firstP.serviceDisplayNames.first}'
                : 'Service Host')
            : firstP.name.toLowerCase() == 'runtimebroker.exe'
                ? 'Runtime Broker'
                : firstP.aumid.isNotEmpty
                    ? (aumidDisplayNames[firstP.aumid] ?? _displayName(firstP))
                    : entry.key;

        final iconUri = IconService.getCachedIcon(firstP.pid);

        // Uses the first child PID for icon fallback on group rows.
        int? firstChildPid;
        if (childRows.isNotEmpty) {
          firstChildPid = int.tryParse(childRows.first.pid);
        }
        // Single process groups with several windows use the parent process PID instead.
        if (firstChildPid == null && !multiProcess) {
          firstChildPid = firstP.pid;
        }

        // Collects every PID in the group for batch termination.
        final groupPids = <int>[];
        for (final p in groupProcesses) {
          groupPids.add(p.pid);
        }

        // Svchost groups with several services show the service count in the subtitle.
        String? groupSubLabel;
        if (firstP.name.toLowerCase() == 'svchost.exe' &&
            firstP.serviceDisplayNames.length > 1) {
          groupSubLabel = '${firstP.serviceDisplayNames.length}';
        }

        rows.add(ProcessTableRow.appGroup(
          name: groupName,
          processCount: childCount,
          category: category,
          iconDataUri: iconUri,
          cpu: formatCpuPercent(accumCpu),
          memory: formatMemoryMB(accumMem),
          disk: formatDiskMBps(accumDiskR + accumDiskW),
          network: formatNetworkBps(accumNet),
          gpu: formatGpuPercent(accumGpu),
          gpuEngine: groupGpuEngine,
          powerUsage: groupPowerUsage,
          children: childRows,
          firstChildPid: firstChildPid,
          childPids: groupPids,
          exePath: groupProcesses.length == 1 ? firstP.exePath : '',
          subLabel: groupSubLabel,
        ));
      }
    }

    return rows;
  }

  /// Collects the direct children (same name and parentPid) into the group.
  /// Only goes one level deep, deeper nesting is handled separately.
  static void _collectChildren(
    ProcessModel parent,
    List<ProcessModel> allProcesses,
    List<ProcessModel> groupProcesses,
    Set<int> usedPids,
  ) {
    for (final p in allProcesses) {
      if (usedPids.contains(p.pid)) continue;
      if (p.parentPid != parent.pid) continue;
      if (p.name.toLowerCase() != parent.name.toLowerCase()) continue;

      usedPids.add(p.pid);
      groupProcesses.add(p);
    }
  }

  /// Groups eligible background processes under their nearest App ancestor. Direct children nest under any exe name, same name descendants nest when the parent chain is unbroken, and IDE tagged processes nest under the nearest App ancestor. Windows Processes always stay at the top level.
  static void _groupDirectChildren(
    List<ProcessModel> allProcesses,
    Map<String, List<ProcessModel>> groups,
    Set<int> usedPids,
  ) {
    final pidToProcess = <int, ProcessModel>{};
    for (final p in allProcesses) {
      pidToProcess[p.pid] = p;
    }

    bool isApp(ProcessModel p) => _categorizeProcess(p) == ProcessCategory.apps;

    bool isWindowsProcess(ProcessModel p) =>
        _categorizeProcess(p) == ProcessCategory.windowsProcesses;

    // A group is AUMID based when its first member has an AUMID, which happens for packaged apps.
    bool isAumidGroup(
        Map<String, List<ProcessModel>> currentGroups, String key) {
      final group = currentGroups[key];
      return group != null && group.isNotEmpty && group.first.aumid.isNotEmpty;
    }

    Map<int, String> buildPidToGroupKey(
        Map<String, List<ProcessModel>> currentGroups) {
      final map = <int, String>{};
      for (final entry in currentGroups.entries) {
        for (final p in entry.value) {
          map[p.pid] = entry.key;
        }
      }
      return map;
    }

    bool didGroup = true;
    while (didGroup) {
      didGroup = false;
      final pidToGroupKey = buildPidToGroupKey(groups);

      for (final p in allProcesses) {
        if (usedPids.contains(p.pid)) continue;
        if (p.parentPid == 0) continue;
        if (p.aumid.isNotEmpty) continue;

        // Skips processes that are already Apps since they own their own groups.
        if (isApp(p)) continue;

        // Windows Processes are never nested under App groups.
        if (isWindowsProcess(p)) continue;

        // Nests the process when its parent is in an App or AUMID group.
        final parentGroupKey = pidToGroupKey[p.parentPid];
        if (parentGroupKey != null) {
          final parentGroup = groups[parentGroupKey]!;
          final parentIsApp = parentGroup.any((pp) => isApp(pp));
          // Also nests children of AUMID grouped processes, like the webview children of SearchApp.exe.
          final parentIsAumid = isAumidGroup(groups, parentGroupKey);
          if (parentIsApp || parentIsAumid) {
            groups[parentGroupKey]!.add(p);
            usedPids.add(p.pid);
            didGroup = true;
            continue;
          }
        }

        // Nests same name descendants found through an unbroken parent chain.
        final sameNameGroup = _findSameNameAppAncestor(
          p,
          pidToProcess,
          pidToGroupKey,
          groups,
        );
        if (sameNameGroup != null) {
          groups[sameNameGroup]!.add(p);
          usedPids.add(p.pid);
          didGroup = true;
          continue;
        }

        // Nests IDE tagged processes, ones flagged by the native side.
        if (p.hasIdeMatch) {
          final appAncestor = _findNearestAppAncestorGroup(
            p.parentPid,
            pidToProcess,
            pidToGroupKey,
            groups,
          );
          if (appAncestor != null) {
            groups[appAncestor]!.add(p);
            usedPids.add(p.pid);
            didGroup = true;
          }
        }
      }
    }
  }

  /// Walks the parent chain looking for an App ancestor with the same name. Only passes through processes with the same executable name, and stops with null when an ancestor is missing, has a different name, or the maximum depth is reached.
  static String? _findSameNameAppAncestor(
    ProcessModel p,
    Map<int, ProcessModel> pidToProcess,
    Map<int, String> pidToGroupKey,
    Map<String, List<ProcessModel>> groups,
  ) {
    final visited = <int>{};
    final targetName = p.name.toLowerCase();
    var currentPid = p.parentPid;
    const maxDepth = 20;

    for (var depth = 0; depth < maxDepth; depth++) {
      if (currentPid == 0 || visited.contains(currentPid)) break;
      visited.add(currentPid);

      final ancestor = pidToProcess[currentPid];
      if (ancestor == null) break;

      if (ancestor.name.toLowerCase() != targetName) break;

      final groupKey = pidToGroupKey[currentPid];
      if (groupKey != null && groups.containsKey(groupKey)) {
        if (groups[groupKey]!.any(
          (pp) => _categorizeProcess(pp) == ProcessCategory.apps,
        )) {
          return groupKey;
        }
      }

      currentPid = ancestor.parentPid;
    }
    return null;
  }

  /// Walks up the parent chain looking for a process in an App group, one with at least one visible window, and returns the group key if found. Stops when an ancestor is missing from the snapshot.
  static String? _findNearestAppAncestorGroup(
    int pid,
    Map<int, ProcessModel> pidToProcess,
    Map<int, String> pidToGroupKey,
    Map<String, List<ProcessModel>> groups,
  ) {
    final visited = <int>{};
    var currentPid = pid;
    const maxDepth = 15;

    for (var depth = 0; depth < maxDepth; depth++) {
      if (currentPid == 0 || visited.contains(currentPid)) break;
      visited.add(currentPid);

      final groupKey = pidToGroupKey[currentPid];
      if (groupKey != null && groups.containsKey(groupKey)) {
        if (groups[groupKey]!.any(
          (pp) => _categorizeProcess(pp) == ProcessCategory.apps,
        )) {
          return groupKey;
        }
      }

      final currentProcess = pidToProcess[currentPid];
      if (currentProcess == null) break;
      currentPid = currentProcess.parentPid;
    }
    return null;
  }

  void _toggleExpand(int visibleIndex, List<ProcessTableRow> visibleRows) {
    final row = visibleRows[visibleIndex];

    setState(() {
      if (row.isGroupHeader && row.category != null) {
        // Category headers toggle the whole category.
        if (_expandedGroups.contains(row.category)) {
          _expandedGroups.remove(row.category);
        } else {
          _expandedGroups.add(row.category!);
        }
      } else if (row.rowType == ProcessRowType.appGroup) {
        // App group rows toggle using their expansion key.
        final key = row.expansionKey;
        if (_expandedGroupKeys.contains(key)) {
          _expandedGroupKeys.remove(key);
        } else {
          _expandedGroupKeys.add(key);
        }
      }
      // Process rows have nothing to expand.
    });
  }

  List<ProcessTableRow> _buildVisibleRows(List<ProcessModel> processes) {
    final query = widget.searchQuery;
    final isSearching = query.isNotEmpty;

    // Saves the expansion state when a search starts and restores it when the search ends.
    if (isSearching && _lastSearchQuery.isEmpty) {
      // Search just started, so save the expansion state.
      _savedExpandedGroups = Set.from(_expandedGroups);
      _savedExpandedGroupKeys = Set.from(_expandedGroupKeys);
    } else if (!isSearching && _lastSearchQuery.isNotEmpty) {
      // Search just ended, so restore the saved expansion state.
      _expandedGroups
        ..clear()
        ..addAll(_savedExpandedGroups);
      _expandedGroupKeys
        ..clear()
        ..addAll(_savedExpandedGroupKeys);
    }
    _lastSearchQuery = query;

    // Filters processes by the search query.
    final filtered = _filterProcesses(processes);
    final allRows = _buildRows(filtered);

    // During a search, auto expand every category and group that has matches.
    if (isSearching) {
      _expandedGroups.addAll(ProcessCategory.values);
      for (final row in allRows) {
        if (row.rowType == ProcessRowType.appGroup) {
          _expandedGroupKeys.add(row.expansionKey);
        }
      }
    }

    final visible = <ProcessTableRow>[];

    // Computes the child PIDs once to avoid a second buildRows call.
    final childPids = <String>{};
    for (final row in allRows) {
      if (row.rowType == ProcessRowType.appGroup) {
        for (final child in row.children) {
          if (child.pid.isNotEmpty && child.pid != '0') {
            childPids.add(child.pid);
          }
        }
      }
    }
    _cachedChildPids = childPids;

    for (final category in _categoryOrder) {
      final categoryRows =
          allRows.where((r) => r.category == category).toList();
      categoryRows
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final isExpanded = _expandedGroups.contains(category);

      visible.add(
        ProcessTableRow.groupHeader(
          category,
          categoryRows.length,
          isExpanded: isExpanded,
        ),
      );

      if (isExpanded) {
        for (final row in categoryRows) {
          visible.add(row);
          // App group rows expand their children using the expansion key.
          if (row.rowType == ProcessRowType.appGroup) {
            final key = row.expansionKey;
            if (_expandedGroupKeys.contains(key) && row.children.isNotEmpty) {
              visible.addAll(row.children);
            }
          }
          // Process rows have no children to expand.
        }
      }
    }

    return visible;
  }

  /// PIDs of process rows that are children of app groups, used for indentation and computed once per build.
  Set<String> get _childPids => _cachedChildPids;

  void _openProperties(int pid) {
    if (pid <= 0) return;
    ProcessService().openProperties(pid);
  }

  void _openFileLocation(int pid) {
    if (pid <= 0) return;
    ProcessService().openFileLocation(pid);
  }

  void _showContextMenu(
      int index, Offset position, List<ProcessTableRow> visibleRows) {
    final row = visibleRows[index];
    final realUsers = ref.read(userProvider).realUsers;

    if (row.rowType == ProcessRowType.window) {
      final pid = row.windowOwnerPid;
      if (pid <= 0) return;
      showContextMenu(
        context: context,
        position: position,
        items: [
          ContextMenuActions.terminate(
              onTap: () => _terminateProcess(pid, row.name,
                  tree: false, hwnd: row.windowHandle)),
          ContextMenuActions.separator(),
          ContextMenuActions.openFileLocation(
              onTap: () => _openFileLocation(pid)),
          ContextMenuActions.goToDetails(
              onTap: () => widget.onNavigateToDetails?.call(pid)),
          ContextMenuActions.goToUsersDisabled(),
          ContextMenuActions.searchOnline(onTap: () => searchOnline(row.name)),
          ContextMenuActions.properties(onTap: () => _openProperties(pid)),
        ],
      );
      return;
    }

    if (row.rowType == ProcessRowType.appGroup) {
      if (row.childPids.isEmpty) return;
      final isUserProcess = _isProcessInUsers(row.firstChildPid, realUsers);
      showContextMenu(
        context: context,
        position: position,
        items: [
          ContextMenuActions.terminate(
              onTap: () => _terminateProcessGroup(row.childPids, row.name)),
          ContextMenuActions.separator(),
          ContextMenuActions.openFileLocation(
              onTap: () => _openFileLocation(row.firstChildPid ?? 0)),
          ContextMenuActions.goToDetails(
              onTap: () =>
                  widget.onNavigateToDetails?.call(row.firstChildPid ?? 0)),
          isUserProcess
              ? ContextMenuActions.goToUsers(
                  onTap: () =>
                      widget.onNavigateToUsers?.call(row.firstChildPid ?? 0))
              : ContextMenuActions.goToUsersDisabled(),
          ContextMenuActions.searchOnline(onTap: () => searchOnline(row.name)),
          ContextMenuActions.properties(
              onTap: () => _openProperties(row.firstChildPid ?? 0)),
        ],
      );
      return;
    }

    if (row.rowType != ProcessRowType.process) return;

    // A single process row.
    final pidNum = int.tryParse(row.pid);
    if (pidNum == null || pidNum == 0) return;
    final isUserProcess = _isProcessInUsers(pidNum, realUsers);

    showContextMenu(
      context: context,
      position: position,
      items: [
        ContextMenuActions.terminate(
            onTap: () => _terminateProcess(pidNum, row.name, tree: false)),
        ContextMenuActions.separator(),
        ContextMenuActions.openFileLocation(
            onTap: () => _openFileLocation(pidNum)),
        ContextMenuActions.goToDetails(
            onTap: () => widget.onNavigateToDetails?.call(pidNum)),
        isUserProcess
            ? ContextMenuActions.goToUsers(
                onTap: () => widget.onNavigateToUsers?.call(pidNum))
            : ContextMenuActions.goToUsersDisabled(),
        ContextMenuActions.searchOnline(onTap: () => searchOnline(row.name)),
        ContextMenuActions.properties(onTap: () => _openProperties(pidNum)),
      ],
    );
  }

  bool _isProcessInUsers(int? pid, List<String> realUsers) {
    if (pid == null || pid == 0 || realUsers.isEmpty) return false;
    final processState = ref.read(processProvider);
    final process =
        processState.processes.where((p) => p.pid == pid).firstOrNull;
    if (process == null) return false;
    final userName = process.userName;
    return realUsers.any((u) => u.toLowerCase() == userName.toLowerCase());
  }

  Future<void> _terminateProcess(int pid, String processName,
      {bool tree = false, int hwnd = 0}) async {
    try {
      final service = ProcessService();

      final isDangerous = await service.checkDangerous(pid);
      if (isDangerous) {
        final confirmed = await _showDangerousWarning(processName, pid);
        if (!confirmed) return;
      }

      bool success;
      if (hwnd > 0) {
        success = await service.terminateProcess(pid, hwnd: hwnd);
      } else if (tree) {
        success = await service.terminateProcessTree(pid);
      } else {
        success = await service.terminateProcess(pid);
      }

      if (mounted) {
        if (success) {
          showAppSnackBar(
            context,
            hwnd > 0
                ? 'Window closed'
                : (tree ? 'Process tree terminated' : 'Process terminated'),
          );
        } else {
          showAppSnackBar(
            context,
            'Failed to terminate process (access denied)',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Error: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _terminateProcessGroup(List<int> pids, String groupName) async {
    try {
      final service = ProcessService();

      // Checks whether any process in the group is dangerous.
      bool hasDangerous = false;
      for (final pid in pids) {
        if (await service.checkDangerous(pid)) {
          hasDangerous = true;
          break;
        }
      }

      if (hasDangerous) {
        final confirmed = await _showDangerousWarning(groupName, pids.first);
        if (!confirmed) return;
      }

      final terminated = await service.terminateProcesses(pids);

      if (mounted) {
        if (terminated > 0) {
          showAppSnackBar(
            context,
            '$terminated of ${pids.length} processes terminated',
          );
        } else {
          showAppSnackBar(
            context,
            'Failed to terminate processes (access denied)',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Error: $e',
          isError: true,
        );
      }
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    final processState = ref.read(processProvider);
    final visibleRows = _buildVisibleRows(processState.processes);
    if (visibleRows.isEmpty) return;

    final currentIndex = _selectedRowIndex ?? -1;
    final newIndex = tableKeySelection(event, currentIndex, visibleRows.length);
    if (newIndex == null) return;

    setState(() {
      _selectedRowIndex = newIndex >= 0 ? newIndex : null;
    });

    if (newIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_vScrollController.hasClients) {
          final targetOffset = (newIndex * AppDimensions.rowHeight) -
              (AppDimensions.rowHeight * 3);
          _vScrollController.animateTo(
            targetOffset.clamp(
                0.0, _vScrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final processState = ref.watch(processProvider);
    final visibleRows = _buildVisibleRows(processState.processes);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            setState(() => _selectedRowIndex = null);
          },
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMedium),
            child: processState.error != null && processState.processes.isEmpty
                ? AppErrorState(error: processState.error!)
                : ProcessDataTable(
                    columns: _columns,
                    rows: visibleRows,
                    selectedIndex: _selectedRowIndex,
                    expandedParentPids: _expandedGroupKeys,
                    childPids: _childPids,
                    hScrollController: _hScrollController,
                    vScrollController: _vScrollController,
                    onRowSelected: (index) {
                      setState(() => _selectedRowIndex = index);
                    },
                    onRowExpanded: (index) {
                      _toggleExpand(index, visibleRows);
                    },
                    onRowRightTap: (index, position) {
                      _showContextMenu(index, position, visibleRows);
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
