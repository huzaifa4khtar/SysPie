import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/elevation_banner.dart';
import '../service_model.dart';
import '../../../shared/models/process_table.dart';
import '../service_controller.dart';
import '../../processes/process_service.dart';
import '../service_service.dart';
import '../../../core/widgets/data_table.dart';
import '../../../core/widgets/context_menu.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/table_keyboard.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  final int? highlightPid;
  final void Function(int pid)? onNavigateToProcesses;
  final void Function(int pid)? onNavigateToDetails;
  final String searchQuery;

  const ServicesScreen({
    super.key,
    this.highlightPid,
    this.onNavigateToProcesses,
    this.onNavigateToDetails,
    this.searchQuery = '',
  });

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  int? _selectedRowIndex;
  bool _showElevationBanner = false;

  final ScrollController _hScrollController = ScrollController();
  final ScrollController _vScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

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
  void didUpdateWidget(covariant ServicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightPid != null &&
        widget.highlightPid != oldWidget.highlightPid) {
      _highlightPid(widget.highlightPid!);
    }
  }

  void _highlightPid(int pid) {
    final serviceState = ref.read(serviceProvider);
    final visibleRows = _buildRows(serviceState.services);
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
  void dispose() {
    _hScrollController.dispose();
    _vScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  static const List<ProcessTableColumn> _columns = [
    ProcessTableColumn(label: 'NAME', width: AppDimensions.colServiceName),
    ProcessTableColumn(label: 'PID', width: AppDimensions.colServicePid),
    ProcessTableColumn(
        label: 'DISPLAY NAME', width: AppDimensions.colServiceDisplayName),
    ProcessTableColumn(label: 'STATUS', width: AppDimensions.colServiceStatus),
    ProcessTableColumn(label: 'TYPE', width: AppDimensions.colServiceType),
    ProcessTableColumn(label: 'GROUP', width: AppDimensions.colServiceGroup),
  ];

  static int _statusType(String status) {
    switch (status) {
      case 'Running':
        return 0;
      case 'Stopped':
        return 2;
      default:
        return 1;
    }
  }

  List<ProcessTableRow> _buildRows(List<ServiceModel> services) {
    // Filters services by the search query, matching the name, display name, PID, and group.
    List<ServiceModel> filtered = services;
    if (widget.searchQuery.isNotEmpty) {
      final query = widget.searchQuery.toLowerCase();
      filtered = services.where((s) {
        return s.serviceName.toLowerCase().contains(query) ||
            s.displayName.toLowerCase().contains(query) ||
            s.pid.toString().contains(query) ||
            s.group.toLowerCase().contains(query);
      }).toList();
    }

    return filtered.map((s) {
      return ProcessTableRow(
        name: s.serviceName,
        subLabel: null,
        pid: s.pid > 0 ? s.pid.toString() : '',
        statusLabel: s.status,
        statusType: _statusType(s.status),
        username: '',
        cpu: '',
        memory: '',
        disk: '',
        network: '',
        gpu: '',
        uacVirtualization: '',
        group: s.group,
        displayName: s.displayName,
        serviceType: s.type,
        iconAsset: 'assets/services_icon.png',
        rowType: ProcessRowType.process,
      );
    }).toList();
  }

  void _showContextMenu(
      int index, Offset position, List<ProcessTableRow> visibleRows) {
    final serviceState = ref.read(serviceProvider);
    final services = serviceState.services;

    if (index >= services.length) return;
    final service = services[index];
    final isRunning = service.status == 'Running';
    final isStopped = service.status == 'Stopped';

    showContextMenu(
      context: context,
      position: position,
      items: [
        isStopped
            ? ContextMenuActions.start(
                onTap: () => _startService(service.serviceName))
            : ContextMenuActions.startDisabled(),
        isRunning
            ? ContextMenuActions.stop(
                onTap: () => _stopService(service.serviceName))
            : ContextMenuActions.stopDisabled(),
        isRunning
            ? ContextMenuActions.restart(
                onTap: () => _restartService(service.serviceName))
            : ContextMenuActions.restartDisabled(),
        ContextMenuActions.separator(),
        service.pid > 0
            ? ContextMenuActions.goToProcesses(
                onTap: () => _goToProcesses(service.pid))
            : ContextMenuActions.goToProcessesDisabled(),
        service.pid > 0
            ? ContextMenuActions.goToDetails(
                onTap: () => widget.onNavigateToDetails?.call(service.pid))
            : ContextMenuActions.goToDetailsDisabled(),
        ContextMenuActions.goToUsersDisabled(),
        ContextMenuActions.searchOnline(
            onTap: () => _searchOnline(service.serviceName)),
        ContextMenuActions.openServices(onTap: () => _openServices()),
      ],
    );
  }

  void _searchOnline(String serviceName) {
    if (serviceName.isEmpty) return;
    final query = Uri.encodeComponent('$serviceName service');
    Process.run(
        'cmd', ['/c', 'start', '', 'https://www.google.com/search?q=$query']);
  }

  Future<void> _openServices() async {
    await ProcessService().openServices();
  }

  bool _checkAccessDenied(dynamic result) {
    if (result is Map && result['success'] == false) {
      final msg = (result['errorMessage'] as String?) ?? '';
      if (msg.toLowerCase().contains('access is denied') ||
          msg.toLowerCase().contains('access denied')) {
        if (mounted) setState(() => _showElevationBanner = true);
        return true;
      }
    }
    return false;
  }

  Future<void> _startService(String serviceName) async {
    try {
      final service = ServiceService();
      final result = await service.startService(serviceName);
      ref.read(serviceProvider.notifier).refresh();
      if (mounted) {
        final success = result['success'] == true;
        final errMsg = result['errorMessage'] as String?;
        if (_checkAccessDenied(result)) return;
        showAppSnackBar(
          context,
          success ? 'Service started' : 'Failed: ${errMsg ?? "unknown error"}',
          isError: !success,
        );
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Error: $e', isError: true);
    }
  }

  Future<void> _stopService(String serviceName) async {
    try {
      final service = ServiceService();
      final result = await service.stopService(serviceName);
      ref.read(serviceProvider.notifier).refresh();
      if (mounted) {
        final success = result['success'] == true;
        final errMsg = result['errorMessage'] as String?;
        if (_checkAccessDenied(result)) return;
        showAppSnackBar(
          context,
          success ? 'Service stopped' : 'Failed: ${errMsg ?? "unknown error"}',
          isError: !success,
        );
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Error: $e', isError: true);
    }
  }

  Future<void> _restartService(String serviceName) async {
    try {
      final service = ServiceService();
      final result = await service.restartService(serviceName);
      ref.read(serviceProvider.notifier).refresh();
      if (mounted) {
        final success = result['success'] == true;
        final errMsg = result['errorMessage'] as String?;
        if (_checkAccessDenied(result)) return;
        showAppSnackBar(
          context,
          success
              ? 'Service restarted'
              : 'Failed: ${errMsg ?? "unknown error"}',
          isError: !success,
        );
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Error: $e', isError: true);
    }
  }

  void _goToProcesses(int pid) {
    widget.onNavigateToProcesses?.call(pid);
  }

  void _handleKeyEvent(KeyEvent event) {
    final serviceState = ref.read(serviceProvider);
    final visibleRows = _buildRows(serviceState.services);
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
    final serviceState = ref.watch(serviceProvider);
    final visibleRows = _buildRows(serviceState.services);

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
          child: Column(
            children: [
              if (_showElevationBanner)
                ElevationBanner(
                  onDismiss: () =>
                      setState(() => _showElevationBanner = false),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                  child: serviceState.error != null &&
                          serviceState.services.isEmpty
                      ? AppErrorState(error: serviceState.error!)
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
            ],
          ),
        ),
      ),
    );
  }
}
