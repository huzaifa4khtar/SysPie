import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';

/// A single item in the context menu.
class ContextMenuItem {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const ContextMenuItem({
    required this.label,
    this.icon,
    this.iconColor,
    this.onTap,
  });
}

/// Factory for common context menu actions, defined once with a consistent
/// icon, color, and label. Screens use these instead of creating menu items
/// directly.
class ContextMenuActions {
  ContextMenuActions._();

  // Primary actions.

  static ContextMenuItem terminate({required VoidCallback onTap}) =>
      ContextMenuItem(
        label: 'Terminate',
        icon: Icons.power_settings_new,
        iconColor: AppColors.statusRed,
        onTap: onTap,
      );

  static ContextMenuItem terminateAll({required VoidCallback onTap}) =>
      ContextMenuItem(
        label: 'Terminate All',
        icon: Icons.power_settings_new,
        iconColor: AppColors.statusRed,
        onTap: onTap,
      );

  static ContextMenuItem start({required VoidCallback onTap}) =>
      ContextMenuItem(
        label: 'Start',
        icon: Icons.play_arrow,
        iconColor: AppColors.statusGreen,
        onTap: onTap,
      );

  static ContextMenuItem stop({required VoidCallback onTap}) => ContextMenuItem(
        label: 'Stop',
        icon: Icons.stop,
        iconColor: AppColors.statusRed,
        onTap: onTap,
      );

  static ContextMenuItem restart({required VoidCallback onTap}) =>
      ContextMenuItem(
        label: 'Restart',
        icon: Icons.refresh,
        iconColor: AppColors.statusYellow,
        onTap: onTap,
      );

  // Navigation actions.

  static ContextMenuItem openFileLocation({required VoidCallback onTap}) =>
      ContextMenuItem(
        label: 'Open File Location',
        icon: Icons.folder_open,
        iconColor: null,
        onTap: onTap,
      );

  static ContextMenuItem goToProcesses({required VoidCallback onTap}) =>
      ContextMenuItem(
        label: 'Go to Processes',
        icon: Icons.launch,
        iconColor: null,
        onTap: onTap,
      );

  static ContextMenuItem goToDetails({required VoidCallback onTap}) =>
      ContextMenuItem(
        label: 'Go to Details',
        icon: Icons.launch,
        iconColor: null,
        onTap: onTap,
      );

  static ContextMenuItem goToUsers({required VoidCallback onTap}) =>
      ContextMenuItem(
        label: 'Go to Users',
        icon: Icons.people,
        iconColor: null,
        onTap: onTap,
      );

  // Utility actions.

  static ContextMenuItem searchOnline({required VoidCallback onTap}) =>
      ContextMenuItem(
        label: 'Search Online',
        icon: Icons.search,
        iconColor: null,
        onTap: onTap,
      );

  static ContextMenuItem properties({required VoidCallback onTap}) =>
      ContextMenuItem(
        label: 'Properties',
        icon: Icons.info_outline,
        iconColor: null,
        onTap: onTap,
      );

  static ContextMenuItem openServices({required VoidCallback onTap}) =>
      ContextMenuItem(
        label: 'Open Services',
        icon: Icons.miscellaneous_services,
        iconColor: null,
        onTap: onTap,
      );

  // Disabled variants for conditions like a missing process.

  static ContextMenuItem startDisabled() => const ContextMenuItem(
        label: 'Start',
        icon: Icons.play_arrow,
        iconColor: AppColors.statusGreen,
        onTap: null,
      );

  static ContextMenuItem stopDisabled() => const ContextMenuItem(
        label: 'Stop',
        icon: Icons.stop,
        iconColor: AppColors.statusRed,
        onTap: null,
      );

  static ContextMenuItem restartDisabled() => const ContextMenuItem(
        label: 'Restart',
        icon: Icons.refresh,
        iconColor: AppColors.statusYellow,
        onTap: null,
      );

  static ContextMenuItem goToProcessesDisabled() => const ContextMenuItem(
        label: 'Go to Processes',
        icon: Icons.launch,
        iconColor: null,
        onTap: null,
      );

  static ContextMenuItem openFileLocationDisabled() => const ContextMenuItem(
        label: 'Open File Location',
        icon: Icons.folder_open,
        iconColor: null,
        onTap: null,
      );

  static ContextMenuItem goToDetailsDisabled() => const ContextMenuItem(
        label: 'Go to Details',
        icon: Icons.launch,
        iconColor: null,
        onTap: null,
      );

  static ContextMenuItem goToUsersDisabled() => const ContextMenuItem(
        label: 'Go to Users',
        icon: Icons.people,
        iconColor: null,
        onTap: null,
      );

  // Separator.

  static ContextMenuItem separator() => const ContextMenuItem(
        label: '─────────────',
        icon: null,
      );
}

/// Shows a context menu overlay at the given position. It dismisses when an
/// item is tapped or when the user clicks outside it, and only one menu shows
/// at a time.
void showContextMenu({
  required BuildContext context,
  required Offset position,
  required List<ContextMenuItem> items,
}) {
  // Remove any existing context menu overlay.
  _ContextMenuOverlayState.remove();

  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _ContextMenuOverlay(
      position: position,
      items: items,
      onDismiss: () {
        if (_ContextMenuOverlayState.current == entry) {
          _ContextMenuOverlayState.current = null;
        }
        entry.remove();
      },
    ),
  );

  _ContextMenuOverlayState.current = entry;
  overlay.insert(entry);
}

/// Internal overlay widget that renders the context menu at the given position.
class _ContextMenuOverlay extends StatefulWidget {
  final Offset position;
  final List<ContextMenuItem> items;
  final VoidCallback onDismiss;

  const _ContextMenuOverlay({
    required this.position,
    required this.items,
    required this.onDismiss,
  });

  @override
  State<_ContextMenuOverlay> createState() => _ContextMenuOverlayState();
}

class _ContextMenuOverlayState extends State<_ContextMenuOverlay>
    with SingleTickerProviderStateMixin {
  static OverlayEntry? current;
  static void remove() {
    final entry = current;
    current = null;
    if (entry != null) {
      entry.remove();
    }
  }

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Estimate menu size.
    final menuHeight =
        widget.items.length * AppDimensions.contextMenuItemHeight + 8.0;

    // Adjust position so menu stays on-screen.
    var left = widget.position.dx;
    var top = widget.position.dy;

    if (left + AppDimensions.contextMenuWidth > screenWidth) {
      left = screenWidth - AppDimensions.contextMenuWidth - 8;
    }
    if (top + menuHeight > screenHeight) {
      top = screenHeight - menuHeight - 8;
    }

    return Stack(
      children: [
        // Dismiss area catches taps outside the menu.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              widget.onDismiss();
            },
            onSecondaryTapUp: (_) {
              widget.onDismiss();
            },
          ),
        ),
        // Menu container.
        Positioned(
          left: left,
          top: top,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildMenu(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenu() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: AppDimensions.contextMenuWidth,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius:
              BorderRadius.circular(AppDimensions.contextMenuBorderRadius),
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.contextMenuPaddingVertical),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.items.map((item) {
            return _buildItem(item);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildItem(ContextMenuItem item) {
    final isSeparator = item.icon == null && item.label.contains('─');
    if (isSeparator) {
      return Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.contextMenuSeparatorPadding, vertical: 2),
        child: const Divider(height: 1, color: AppColors.border),
      );
    }
    final disabled = item.onTap == null;
    return InkWell(
      onTap: () {
        widget.onDismiss();
        item.onTap?.call();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: AppDimensions.contextMenuItemHeight,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.contextMenuPaddingHorizontal),
        child: Row(
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: AppDimensions.contextMenuIconSize,
                color: disabled
                    ? AppColors.textMuted
                    : (item.iconColor ?? AppColors.contextMenuTextColor),
              ),
              const SizedBox(width: AppDimensions.contextMenuIconGap),
            ],
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: AppTypography.contextMenuTextSize,
                  fontWeight: FontWeight.w400,
                  color: disabled
                      ? AppColors.textMuted
                      : AppColors.contextMenuTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
