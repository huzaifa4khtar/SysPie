import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../shared/models/process_table.dart';
import '../../../shared/models/process_model.dart';
import '../../processes/process_controller.dart';
import '../../users/user_controller.dart';
import '../../../shared/services/icon_service.dart';
import '../../../shared/services/os_actions.dart';
import '../../processes/process_service.dart';
import '../../../core/widgets/data_table.dart';
import '../../../core/widgets/context_menu.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/table_keyboard.dart';

class DetailsScreen extends ConsumerStatefulWidget {
  final int? highlightPid;
  final void Function(int pid)? onNavigateToProcesses;
  final void Function(int pid)? onNavigateToUsers;
  final String searchQuery;

  const DetailsScreen({
    super.key,
    this.highlightPid,
    this.onNavigateToProcesses,
    this.onNavigateToUsers,
    this.searchQuery = '',
  });

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  int? _selectedRowIndex;

  final ScrollController _hScrollController = ScrollController();
  final ScrollController _vScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  void _highlightPid(int pid) {
    final processState = ref.read(processProvider);
    final visibleRows = _buildRows(processState.processes);
    for (int i = 0; i < visibleRows.length; i++) {
      if (visibleRows[i].pid == pid.toString()) {
        setState(() => _selectedRowIndex = i);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_vScrollController.hasClients) {
            final targetOffset =
                (i * AppDimensions.rowHeight) - (AppDimensions.rowHeight * 3);
            _vScrollController.animateTo(
              targetOffset.clamp(
                  0.0, _vScrollController.position.maxScrollExtent),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
        break;
      }
    }
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
  void didUpdateWidget(covariant DetailsScreen oldWidget) {
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
    _focusNode.dispose();
    super.dispose();
  }

  static const List<ProcessTableColumn> _columns = [
    ProcessTableColumn(label: 'NAME', width: AppDimensions.colDetailsName),
    ProcessTableColumn(label: 'PID', width: AppDimensions.colDetailsPid),
    ProcessTableColumn(label: 'STATUS', width: AppDimensions.colDetailsStatus),
    ProcessTableColumn(
        label: 'USERNAME', width: AppDimensions.colDetailsUsername),
    ProcessTableColumn(label: 'UACV', width: AppDimensions.colDetailsUacv),
    ProcessTableColumn(
        label: 'DISK PERMISSION',
        width: AppDimensions.colDetailsDiskPermission),
    ProcessTableColumn(label: 'PARENT', width: AppDimensions.colDetailsParent),
  ];

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

  static String _exeName(ProcessModel p) {
    return p.name;
  }

  static String _shortUserName(String full) {
    if (full.contains('\\')) return full.split('\\').last;
    return full;
  }

  List<ProcessTableRow> _buildRows(List<ProcessModel> processes) {
    // Filters rows by the search query, matching exe name, PID, and username.
    List<ProcessModel> filtered = processes;
    if (widget.searchQuery.isNotEmpty) {
      final query = widget.searchQuery.toLowerCase();
      filtered = processes.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.pid.toString().contains(query) ||
            p.userName.toLowerCase().contains(query);
      }).toList();
    }

    final pidToName = <int, String>{};
    for (final p in processes) {
      pidToName[p.pid] = _displayName(p);
    }

    final rows = filtered.map((p) {
      final iconUri = IconService.getCachedIcon(p.pid);
      final parentName = pidToName[p.parentPid] ?? '';

      final displayName = _exeName(p);

      return ProcessTableRow(
        name: displayName,
        exePath: p.exePath,
        subLabel: null,
        pid: p.pid.toString(),
        iconDataUri: iconUri,
        statusLabel: p.status,
        statusType: p.statusType,
        username: _shortUserName(p.userName),
        cpu: '',
        memory: '',
        disk: '',
        network: '',
        gpu: '',
        uacVirtualization: p.uacVirtualization,
        diskPermission: p.diskPermission,
        parentProcessName: parentName,
        rowType: ProcessRowType.process,
      );
    }).toList();

    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return rows;
  }

  void _showContextMenu(
      int index, Offset position, List<ProcessTableRow> visibleRows) {
    final row = visibleRows[index];
    final pid = int.tryParse(row.pid);
    if (pid == null || pid == 0) return;

    final realUsers = ref.read(userProvider).realUsers;
    final processState = ref.read(processProvider);
    final process =
        processState.processes.where((p) => p.pid == pid).firstOrNull;
    final isUserProcess = process != null &&
        realUsers.any((u) => u.toLowerCase() == process.userName.toLowerCase());

    showContextMenu(
      context: context,
      position: position,
      items: [
        ContextMenuActions.terminate(
            onTap: () => _terminateProcess(pid, row.name)),
        ContextMenuActions.separator(),
        ContextMenuActions.openFileLocation(
            onTap: () => _openFileLocation(pid)),
        ContextMenuActions.goToProcesses(
            onTap: () => widget.onNavigateToProcesses?.call(pid)),
        isUserProcess
            ? ContextMenuActions.goToUsers(
                onTap: () => widget.onNavigateToUsers?.call(pid))
            : ContextMenuActions.goToUsersDisabled(),
        ContextMenuActions.searchOnline(onTap: () => searchOnline(row.name)),
        ContextMenuActions.properties(onTap: () => _openProperties(pid)),
      ],
    );
  }

  void _openProperties(int pid) {
    if (pid <= 0) return;
    ProcessService().openProperties(pid);
  }

  void _openFileLocation(int pid) {
    if (pid <= 0) return;
    ProcessService().openFileLocation(pid);
  }

  Future<void> _terminateProcess(int pid, String processName) async {
    try {
      final service = ProcessService();
      final success = await service.terminateProcess(pid);
      if (mounted) {
        showAppSnackBar(
          context,
          success
              ? 'Process terminated'
              : 'Failed to terminate process (access denied)',
          isError: !success,
        );
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Error: $e', isError: true);
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    final processState = ref.read(processProvider);
    final visibleRows = _buildRows(processState.processes);
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
    final visibleRows = _buildRows(processState.processes);

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
                    hScrollController: _hScrollController,
                    vScrollController: _vScrollController,
                    onRowSelected: (index) {
                      setState(() => _selectedRowIndex = index);
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
