import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/models/process_table.dart';
import '../../shared/services/icon_service.dart';
import 'custom_scrollbar.dart';
import 'status_badge.dart';

/// A full-featured process data table with a fixed header, custom scrollbars,
/// row selection, group header rows, expand and collapse support, and status
/// badges. It renders category headers for Apps, Background, and Windows
/// Processes, app group rows like Notepad which have no PID and are
/// expandable, and individual process rows that always show their PID with
/// window titles as subtitles.
class ProcessDataTable extends StatefulWidget {
  final List<ProcessTableColumn> columns;
  final List<ProcessTableRow> rows;
  final int? selectedIndex;
  final Set<String> expandedParentPids;
  final Set<String> childPids;
  final ValueChanged<int>? onRowSelected;
  final ValueChanged<int>? onRowExpanded;
  final void Function(int index, Offset position)? onRowRightTap;
  final ScrollController hScrollController;
  final ScrollController vScrollController;

  const ProcessDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.selectedIndex,
    this.expandedParentPids = const {},
    this.childPids = const {},
    this.onRowSelected,
    this.onRowExpanded,
    this.onRowRightTap,
    required this.hScrollController,
    required this.vScrollController,
  });

  static const double thumbRadius = 4.0;

  @override
  State<ProcessDataTable> createState() => _ProcessDataTableState();
}

class _ProcessDataTableState extends State<ProcessDataTable> {
  bool _isHovered = false;
  Timer? _iconLoadTimer;

  @override
  void initState() {
    super.initState();
    _batchLoadIcons();
    _iconLoadTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _batchLoadIcons(),
    );
  }

  @override
  void dispose() {
    _iconLoadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: AppDimensions.headerHeight,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppDimensions.cornerRadius),
                      topRight: Radius.circular(AppDimensions.cornerRadius),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: AppDimensions.scrollbarThickness,
                bottom: AppDimensions.scrollbarThickness,
                child: SingleChildScrollView(
                  controller: widget.hScrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _totalWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        Flexible(
                          child: ListView.builder(
                            controller: widget.vScrollController,
                            itemCount: widget.rows.length,
                            itemExtent: AppDimensions.rowHeight,
                            itemBuilder: (context, index) =>
                                _buildRow(context, widget.rows[index], index),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: AppDimensions.headerHeight,
                bottom: AppDimensions.scrollbarThickness,
                width: AppDimensions.scrollbarThickness,
                child: AnimatedOpacity(
                  opacity: _isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: CustomVerticalScrollbar(
                    controller: widget.vScrollController,
                    trackColor: AppColors.border.withValues(alpha: 0.3),
                    thumbColor: AppColors.textMuted,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                right: AppDimensions.scrollbarThickness,
                height: AppDimensions.scrollbarThickness,
                child: AnimatedOpacity(
                  opacity: _isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: CustomHorizontalScrollbar(
                    controller: widget.hScrollController,
                    trackColor: AppColors.border.withValues(alpha: 0.3),
                    thumbColor: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sum of all column widths, which determines the scrollable content width.
  double get _totalWidth =>
      widget.columns.fold<double>(0, (sum, col) => sum + col.width);

  /// Builds the header row with column labels.
  Widget _buildHeader() {
    return SizedBox(
      height: AppDimensions.headerHeight,
      child: Row(
        children: widget.columns.map((col) {
          return SizedBox(
            width: col.width,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingLarge,
              ),
              child: Text(
                col.label,
                style: const TextStyle(
                  fontSize: AppTypography.fontSizeHeader,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Builds a single row, dispatching on the row type.
  Widget _buildRow(BuildContext context, ProcessTableRow row, int index) {
    Widget child;
    switch (row.rowType) {
      case ProcessRowType.groupHeader:
        child = _buildGroupHeaderRow(row, index);
        break;
      case ProcessRowType.appGroup:
        child = _buildAppGroupRow(row, index);
        break;
      case ProcessRowType.process:
        child = _buildProcessRow(row, index);
        break;
      case ProcessRowType.window:
        child = _buildProcessRow(row, index);
        break;
    }
    return RepaintBoundary(child: child);
  }

  /// Builds a category group header row for sections like Apps and Background
  /// Processes.
  Widget _buildGroupHeaderRow(ProcessTableRow row, int index) {
    final isSelected = index == widget.selectedIndex;

    return GestureDetector(
      onTap: () => widget.onRowExpanded?.call(index),
      child: Container(
        height: AppDimensions.categoryColumnHeight,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.highlight
              : AppColors.categoryColumn.withValues(alpha: 0.3),
          border: Border(
            bottom: BorderSide(
              color: AppColors.border.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: AppDimensions.expandArrowWidth,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.paddingSmall,
                ),
                child: Icon(
                  row.isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingMedium,
                ),
                child: Text(
                  row.name,
                  style: const TextStyle(
                    fontSize: AppTypography.fontSizeCategoryText,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cache of decoded icon bytes keyed by data URI. It avoids creating new
  /// byte lists on every build, which would make Image.memory reload and
  /// flicker.
  static final Map<String, Uint8List> _iconBytesCache = {};

  /// Batch loads icons for all visible process rows and app group children.
  /// Failed icons are retried each cycle so newly launched apps eventually
  /// get icons.
  void _batchLoadIcons() {
    final pids = <int>{};
    for (final row in widget.rows) {
      if (row.isGroupHeader) continue;
      if (row.rowType == ProcessRowType.appGroup) {
        bool foundChildWithPid = false;
        for (final child in row.children) {
          final pid = int.tryParse(child.pid);
          if (pid != null && pid > 0) {
            pids.add(pid);
            foundChildWithPid = true;
          }
        }
        if (!foundChildWithPid && row.firstChildPid != null) {
          pids.add(row.firstChildPid!);
        }
        continue;
      }
      final pid = int.tryParse(row.pid);
      if (pid == null || pid <= 0) continue;
      pids.add(pid);
    }
    if (pids.isNotEmpty) {
      IconService.loadIconsForPids(pids);
    }
  }

  /// Builds an app group row like Notepad which shows a process count as its
  /// sub-label, has no PID, and can expand.
  Widget _buildAppGroupRow(ProcessTableRow row, int index) {
    final isSelected = index == widget.selectedIndex;
    final isExpanded = widget.expandedParentPids.contains(row.expansionKey);

    return GestureDetector(
      onTap: () => widget.onRowExpanded?.call(index),
      onSecondaryTapUp: (details) =>
          widget.onRowRightTap?.call(index, details.globalPosition),
      child: Container(
        height: AppDimensions.rowHeight,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.highlight : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: AppColors.border.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: _buildCellsFromColumns(row,
              isExpanded: isExpanded, rowIndex: index),
        ),
      ),
    );
  }

  /// Builds a real process row that always shows its own PID. Window titles
  /// render as subtitles instead of child rows.
  Widget _buildProcessRow(ProcessTableRow row, int index) {
    final isSelected = index == widget.selectedIndex;
    final isChild = widget.childPids.contains(row.pid) || row.isIndentedChild;

    return GestureDetector(
      onTap: () => widget.onRowSelected?.call(index),
      onSecondaryTapUp: (details) =>
          widget.onRowRightTap?.call(index, details.globalPosition),
      child: Container(
        height: AppDimensions.rowHeight,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.highlight : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: AppColors.border.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children:
              _buildCellsFromColumns(row, isChild: isChild, rowIndex: index),
        ),
      ),
    );
  }

  /// Builds cell widgets based on the column definitions, mapping each column
  /// label to the matching data from the row.
  List<Widget> _buildCellsFromColumns(ProcessTableRow row,
      {bool isChild = false, bool? isExpanded, int rowIndex = 0}) {
    final cells = <Widget>[];
    for (final col in widget.columns) {
      final label = col.label.toUpperCase();
      if (label == 'NAME') {
        if (row.hasExpandArrow) {
          cells.add(_buildExpandCell(row, rowIndex, isExpanded: isExpanded));
          cells.add(_buildNameCell(
              row, col.width - AppDimensions.dataColumnWidth,
              isChild: isChild));
        } else {
          cells.add(SizedBox(width: AppDimensions.dataColumnWidth));
          cells.add(_buildNameCell(
              row, col.width - AppDimensions.dataColumnWidth,
              isChild: isChild));
        }
      } else if (label == 'PID') {
        cells.add(_buildTextCell(row.pid, col.width, isPid: true));
      } else if (label == 'STATUS') {
        cells.add(_buildStatusCell(row, col.width));
      } else if (label == 'GROUP') {
        cells.add(_buildTextCell(row.group, col.width));
      } else {
        // Remaining labels belong to the process screen columns like USERNAME,
        // CPU, MEMORY, DISK, NETWORK, GPU, and UACV.
        cells.add(_buildTextCell(_getFieldValue(row, label), col.width));
      }
    }
    return cells;
  }

  /// Returns the value of a named field from the row.
  String _getFieldValue(ProcessTableRow row, String field) {
    if (row.rowType == ProcessRowType.appGroup) {
      switch (field) {
        case 'CPU':
          return row.cpu;
        case 'MEMORY':
          return row.memory;
        case 'DISK':
          return row.disk;
        case 'NETWORK':
          return row.network;
        case 'GPU':
          return row.gpu;
        case 'GPU ENGINE':
          return row.gpuEngine;
        case 'POWER USAGE':
          return row.powerUsage;
        case 'PROTOCOL':
          return row.protocol;
        default:
          return '';
      }
    }
    switch (field) {
      case 'USERNAME':
        return row.username;
      case 'CPU':
        return row.cpu;
      case 'MEMORY':
        return row.memory;
      case 'DISK':
        return row.disk;
      case 'NETWORK':
        return row.network;
      case 'GPU':
        return row.gpu;
      case 'UACV':
        return row.uacVirtualization;
      case 'DISPLAY NAME':
        return row.displayName;
      case 'TYPE':
        return row.serviceType;
      case 'LOCAL ADDRESS':
        return row.localAddress;
      case 'LOCAL PORT':
        return row.localPort.toString();
      case 'REMOTE ADDRESS':
        return row.remoteAddress;
      case 'REMOTE PORT':
        return row.remotePort.toString();
      case 'PROTOCOL':
        return row.protocol;
      // Details screen
      case 'PARENT':
        return row.parentProcessName;
      case 'DISK PERMISSION':
        return row.diskPermission;
      // Users screen
      case 'GPU ENGINE':
        return row.gpuEngine;
      case 'POWER USAGE':
        return row.powerUsage;
      // App History screen
      case 'CPU TIME':
        return row.cpuTime;
      case 'METERED NETWORK':
        return row.meteredNetwork;
      case 'TIE UPDATE':
        return row.tieUpdate;

      default:
        return '';
    }
  }

  /// Expand and collapse arrow cell. App group rows use the expansion key,
  /// group headers use their own expanded flag, and plain process rows have
  /// no arrow because they have no children.
  Widget _buildExpandCell(ProcessTableRow row, int visibleIndex,
      {bool? isExpanded}) {
    if (!row.hasExpandArrow) {
      return const SizedBox(width: AppDimensions.dataColumnWidth);
    }

    // Determine the expanded state based on the row type.
    bool expanded;
    if (isExpanded != null) {
      // Use the state the caller provided for app group rows.
      expanded = isExpanded;
    } else if (row.isGroupHeader) {
      expanded = row.isExpanded;
    } else {
      expanded = false;
    }

    return GestureDetector(
      onTap: () => widget.onRowExpanded?.call(visibleIndex),
      child: SizedBox(
        width: AppDimensions.dataColumnWidth,
        child: Icon(
          expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
          size: 16,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Name cell with the icon, process name, and optional subtitles. Process
  /// rows show window titles and service names, app group rows show the
  /// process count, and child rows get extra left padding for indentation.
  Widget _buildNameCell(ProcessTableRow row, double width,
      {bool isChild = false}) {
    // Collect all subtitle lines.
    final subtitleLines = <String>[];
    if (row.subLabel != null) {
      subtitleLines.add(row.subLabel!);
    }
    subtitleLines.addAll(row.windowTitles);
    // Hide service names for the Service Host app group because they show as
    // expanded children instead.
    if (!(row.rowType == ProcessRowType.appGroup &&
        row.name == 'Service Host')) {
      for (final srv in row.serviceDisplayNames) {
        subtitleLines.add('Service Host: $srv');
      }
    }

    return SizedBox(
      width: width,
      child: Padding(
        padding: EdgeInsets.only(
          left: isChild
              ? AppDimensions.nameCellChildLeftMargin
              : AppDimensions.nameCellLeftMargin,
          right: AppDimensions.paddingMedium,
          top: AppDimensions.paddingTiny,
          bottom: AppDimensions.paddingTiny,
        ),
        child: Row(
          children: [
            _buildIconWidget(row.iconDataUri,
                fallbackPid: row.firstChildPid, iconAsset: row.iconAsset),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    style: const TextStyle(
                      fontSize: AppTypography.fontSizeCell,
                      fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitleLines.isNotEmpty)
                    Text(
                      subtitleLines.join(' · '),
                      style: const TextStyle(
                        fontSize: AppTypography.fontSizeCellSub,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Status cell using the reusable StatusBadge widget.
  Widget _buildStatusCell(ProcessTableRow row, double width) {
    if (row.statusLabel == null) {
      return SizedBox(width: width);
    }

    StatusBadgeState state;
    switch (row.statusType) {
      case 0:
        state = StatusBadgeState.green;
        break;
      case 1:
        state = StatusBadgeState.yellow;
        break;
      case 2:
        state = StatusBadgeState.red;
        break;
      default:
        state = StatusBadgeState.green;
    }

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingSmall,
        ),
        child: StatusBadge(label: row.statusLabel!, state: state),
      ),
    );
  }

  /// Builds the process icon widget, showing the actual icon when loaded and
  /// a placeholder otherwise. App group rows fall back to the first child's
  /// cached icon when their own icon is not loaded yet.
  Widget _buildIconWidget(String? iconDataUri,
      {int? fallbackPid, String? iconAsset}) {
    // When a static asset is specified, show it directly.
    if (iconAsset != null && iconAsset.isNotEmpty) {
      return Image.asset(
        iconAsset,
        width: AppDimensions.processIconSize,
        height: AppDimensions.processIconSize,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderIcon();
        },
      );
    }

    // Check the passed URI first, then the IconService cache. This avoids
    // flicker because the icon stays cached even when the row is recreated.
    String? resolvedUri = iconDataUri;
    if ((resolvedUri == null || resolvedUri.isEmpty) && fallbackPid != null) {
      resolvedUri = IconService.getCachedIcon(fallbackPid);
    }
    if (resolvedUri != null && resolvedUri.isNotEmpty) {
      try {
        const prefix = 'data:image/png;base64,';
        if (resolvedUri.startsWith(prefix)) {
          final base64Data = resolvedUri.substring(prefix.length);
          final bytes = _iconBytesCache.putIfAbsent(
            resolvedUri,
            () => base64Decode(base64Data),
          );
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              bytes,
              width: AppDimensions.processIconSize,
              height: AppDimensions.processIconSize,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderIcon();
              },
            ),
          );
        }
      } catch (_) {}
    }
    return _buildPlaceholderIcon();
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      width: AppDimensions.processIconSize,
      height: AppDimensions.processIconSize,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.apps,
        size: 14,
        color: AppColors.textMuted,
      ),
    );
  }

  /// Generic text cell used for PID, username, CPU, memory, and similar
  /// values.
  Widget _buildTextCell(String text, double width, {bool isPid = false}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingLarge,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppTypography.fontSizeCell,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
