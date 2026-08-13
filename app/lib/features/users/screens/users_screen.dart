import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/models/process_table.dart';
import '../../../shared/models/process_model.dart';
import '../../processes/process_controller.dart';
import '../user_controller.dart';
import '../../../shared/services/os_actions.dart';
import '../../processes/process_service.dart';
import '../../../core/widgets/data_table.dart';
import '../../../core/widgets/context_menu.dart';
import '../../../core/widgets/feedback.dart';
import '../../../shared/value_formatters.dart';

class UsersScreen extends ConsumerStatefulWidget {
  final int? highlightPid;
  final void Function(int pid)? onNavigateToProcesses;
  final void Function(int pid)? onNavigateToDetails;
  final String searchQuery;

  const UsersScreen({
    super.key,
    this.highlightPid,
    this.onNavigateToProcesses,
    this.onNavigateToDetails,
    this.searchQuery = '',
  });

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  int? _selectedRowIndex;
  final Set<String> _expandedUsers = {};

  /// Saves the expansion state before a search and restores it when the search clears.
  Set<String> _savedExpandedUsers = {};
  String _lastSearchQuery = '';

  final ScrollController _hScrollController = ScrollController();
  final ScrollController _vScrollController = ScrollController();

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
  void didUpdateWidget(covariant UsersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightPid != null &&
        widget.highlightPid != oldWidget.highlightPid) {
      _highlightPid(widget.highlightPid!);
    }
  }

  @override
  void dispose() {
    _hScrollController.dispose();
    _vScrollController.dispose();
    super.dispose();
  }

  // Formatting helpers.

  static int _powerRank(String level) {
    switch (level) {
      case 'Very Low':
        return 0;
      case 'Low':
        return 1;
      case 'Moderate':
        return 2;
      case 'High':
        return 3;
      case 'Very High':
        return 4;
      default:
        return 0;
    }
  }

  // PID highlighting.

  void _highlightPid(int pid) {
    final processState = ref.read(processProvider);
    final userState = ref.read(userProvider);

    // If the PID is already visible, select and scroll to it.
    final visibleRows =
        _buildVisibleRows(processState.processes, userState.realUsers);
    for (int i = 0; i < visibleRows.length; i++) {
      if (visibleRows[i].pid == pid.toString()) {
        _selectAndScroll(i);
        return;
      }
    }

    // If not visible, find which user group contains the PID.
    bool expanded = false;
    for (final p in processState.processes) {
      if (p.pid == pid) {
        final user = p.userName.isEmpty ? 'Unknown' : p.userName;
        if (!_expandedUsers.contains(user)) {
          _expandedUsers.add(user);
          expanded = true;
        }
        break;
      }
    }

    // After expanding, wait for the rebuild and then highlight the row.
    if (expanded) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final updatedVisible =
            _buildVisibleRows(processState.processes, userState.realUsers);
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

  // Row building.

  List<ProcessTableRow> _buildRows(
      List<ProcessModel> processes, List<String> realUsers) {
    final query = widget.searchQuery;
    final isSearching = query.isNotEmpty;

    // Saves the expansion state when a search starts and restores it when the search ends.
    if (isSearching && _lastSearchQuery.isEmpty) {
      _savedExpandedUsers = Set.from(_expandedUsers);
    } else if (!isSearching && _lastSearchQuery.isNotEmpty) {
      _expandedUsers
        ..clear()
        ..addAll(_savedExpandedUsers);
    }
    _lastSearchQuery = query;

    // Filters processes by the search query, matching the exe name, display name, PID, and username.
    List<ProcessModel> filtered = processes;
    if (isSearching) {
      final q = query.toLowerCase();
      filtered = processes.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.friendlyName.toLowerCase().contains(q) ||
            p.pid.toString().contains(q) ||
            p.userName.toLowerCase().contains(q);
      }).toList();
    }

    final Map<String, List<ProcessModel>> userGroups = {};
    for (final p in filtered) {
      final user = p.userName.isEmpty ? 'Unknown' : p.userName;
      userGroups.putIfAbsent(user, () => []).add(p);
    }

    // Keeps only real users, meaning those with an RID of 1000 or higher.
    final realUserSet = realUsers.toSet();
    final sortedUsers = userGroups.keys
        .where((user) => realUserSet.contains(user))
        .toList()
      ..sort();
    final rows = <ProcessTableRow>[];

    // During a search, auto expand every user group that has matches.
    if (isSearching) {
      for (final user in sortedUsers) {
        _expandedUsers.add(user);
      }
    }

    for (final user in sortedUsers) {
      final procs = userGroups[user]!;

      final totalCpu = procs.fold(0.0, (sum, p) => sum + p.cpuUsage);
      final totalMemory = procs.fold(0.0, (sum, p) => sum + p.memoryMB);
      final totalDisk =
          procs.fold(0.0, (sum, p) => sum + p.diskReadMB + p.diskWriteMB);
      final totalNetwork = procs.fold(0.0, (sum, p) => sum + p.networkBps);
      final totalGpu = procs.fold(0.0, (sum, p) => sum + p.gpuPercent);

      String highestPower = 'Very Low';
      for (final p in procs) {
        if (_powerRank(p.powerUsage) > _powerRank(highestPower)) {
          highestPower = p.powerUsage;
        }
      }

      rows.add(ProcessTableRow(
        name: '$user (${procs.length})',
        pid: '',
        username: '',
        cpu: formatCpuPercent(totalCpu),
        memory: formatMemoryMB(totalMemory),
        disk: formatDiskMBps(totalDisk),
        network: formatNetworkBps(totalNetwork),
        gpu: formatGpuPercent(totalGpu),
        uacVirtualization: '',
        rowType: ProcessRowType.groupHeader,
        category: ProcessCategory.apps,
        isExpanded: _expandedUsers.contains(user),
        gpuEngine: '',
        powerUsage: highestPower,
        firstChildPid: procs.isNotEmpty ? procs.first.pid : null,
      ));

      if (_expandedUsers.contains(user)) {
        procs.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        for (final p in procs) {
          rows.add(ProcessTableRow(
            name: p.name,
            exePath: p.exePath,
            subLabel: null,
            pid: p.pid.toString(),
            iconDataUri: null,
            username: p.userName,
            cpu: formatCpuPercent(p.cpuUsage),
            memory: p.memoryAccessDenied ? 'N/A' : formatMemoryMB(p.memoryMB),
            disk: formatDiskMBps(p.diskReadMB + p.diskWriteMB),
            network: formatNetworkBps(p.networkBps),
            gpu: formatGpuPercent(p.gpuPercent),
            uacVirtualization: '',
            rowType: ProcessRowType.process,
            category: ProcessCategory.apps,
            isIndentedChild: true,
            gpuEngine: p.gpuEngine,
            powerUsage: p.powerUsage,
            firstChildPid: p.pid,
          ));
        }
      }
    }
    return rows;
  }

  List<ProcessTableRow> _buildVisibleRows(
      List<ProcessModel> processes, List<String> realUsers) {
    return _buildRows(processes, realUsers);
  }

  // Build method.

  @override
  Widget build(BuildContext context) {
    final processState = ref.watch(processProvider);
    final userState = ref.watch(userProvider);
    final rows = _buildVisibleRows(processState.processes, userState.realUsers);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        child: processState.error != null && processState.processes.isEmpty
            ? AppErrorState(error: processState.error!)
            : ProcessDataTable(
                columns: _columns,
                rows: rows,
                selectedIndex: _selectedRowIndex,
                hScrollController: _hScrollController,
                vScrollController: _vScrollController,
                onRowSelected: (index) {
                  setState(() => _selectedRowIndex = index);
                },
                onRowExpanded: (index) {
                  final row = rows[index];
                  if (row.isGroupHeader) {
                    final name =
                        row.name.replaceAll(RegExp(r'\s*\(\d+\)$'), '');
                    setState(() {
                      if (_expandedUsers.contains(name)) {
                        _expandedUsers.remove(name);
                      } else {
                        _expandedUsers.add(name);
                      }
                      _selectedRowIndex = null;
                    });
                  }
                },
                onRowRightTap: (index, position) {
                  setState(() => _selectedRowIndex = index);
                  _showContextMenu(rows[index], position);
                },
              ),
      ),
    );
  }

  // Context menu.

  void _showContextMenu(ProcessTableRow row, Offset position) {
    final items = <ContextMenuItem>[];

    if (row.rowType == ProcessRowType.process) {
      items.addAll([
        ContextMenuActions.terminate(
            onTap: () => _terminateProcess(int.parse(row.pid), row.name)),
        ContextMenuActions.openFileLocation(
            onTap: () => _openFileLocation(int.parse(row.pid))),
        ContextMenuActions.separator(),
        ContextMenuActions.goToProcesses(
            onTap: () =>
                widget.onNavigateToProcesses?.call(int.parse(row.pid))),
        ContextMenuActions.goToDetails(
            onTap: () => widget.onNavigateToDetails?.call(int.parse(row.pid))),
        ContextMenuActions.separator(),
        ContextMenuActions.searchOnline(onTap: () => searchOnline(row.name)),
        ContextMenuActions.properties(
            onTap: () => _openProperties(int.parse(row.pid))),
      ]);
    } else if (row.isGroupHeader) {
      final firstPid = row.firstChildPid ?? 0;
      items.addAll([
        ContextMenuActions.terminateAll(
            onTap: () => _terminateAllUserProcesses(row.name)),
        firstPid > 0
            ? ContextMenuActions.goToProcesses(
                onTap: () => widget.onNavigateToProcesses?.call(firstPid))
            : ContextMenuActions.goToProcessesDisabled(),
      ]);
    }

    showContextMenu(context: context, position: position, items: items);
  }

  Future<void> _terminateProcess(int pid, String name) async {
    final service = ProcessService();
    final isDangerous = await service.checkDangerous(pid);
    if (!mounted) return;

    if (isDangerous) {
      final confirmed = await _showDangerousWarning(name, pid);
      if (!confirmed) return;
    }

    await service.terminateProcess(pid);
    if (!mounted) return;
    showAppSnackBar(context, 'Process $name (PID: $pid) terminated');
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
                const Text('Warning',
                    style:
                        TextStyle(color: AppColors.textPrimary, fontSize: 18)),
              ],
            ),
            content: Text(
              'Process "$processName" (PID: $pid) is a system process.\n\n'
              'Terminating it may cause system instability.\n\n'
              'Are you sure you want to continue?',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Terminate',
                    style: TextStyle(color: AppColors.statusRed)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _terminateAllUserProcesses(String userName) async {
    final cleanName = userName.replaceAll(RegExp(r'\s*\(\d+\)$'), '');
    final processState = ref.read(processProvider);
    final userProcesses = processState.processes
        .where(
            (p) => (p.userName.isEmpty ? 'Unknown' : p.userName) == cleanName)
        .toList();

    if (userProcesses.isEmpty) return;

    final pids = userProcesses.map((p) => p.pid).toList();
    final service = ProcessService();
    await service.terminateProcesses(pids);
    if (!mounted) return;
    showAppSnackBar(
        context, 'Terminated ${pids.length} processes for user $cleanName');
  }

  void _openProperties(int pid) {
    if (pid <= 0) return;
    ProcessService().openProperties(pid);
  }

  void _openFileLocation(int pid) {
    if (pid <= 0) return;
    ProcessService().openFileLocation(pid);
  }
}
