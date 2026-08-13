import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';

/// The three possible states for a status badge. Green maps to active,
/// running, or established, yellow to intermediate, bound, or pending, and
/// red to inactive, suspended, or closed.
enum StatusBadgeState { green, yellow, red }

/// A compact pill-shaped badge that shows a status label with a colored dot.
/// The Processes screen uses it for RUNNING and SUSPENDED, and the Sockets
/// screen for ESTABLISHED, BOUND, and LISTEN, but any screen can use all
/// three states.
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusBadgeState state;

  const StatusBadge({
    super.key,
    required this.label,
    required this.state,
  });

  Color get _color {
    switch (state) {
      case StatusBadgeState.green:
        return AppColors.statusGreen;
      case StatusBadgeState.yellow:
        return AppColors.statusYellow;
      case StatusBadgeState.red:
        return AppColors.statusRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingSmall,
        vertical: AppDimensions.paddingTiny,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.fontSizeBadge,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
