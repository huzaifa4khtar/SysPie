import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// Compact widget showing CPU, GPU, and RAM as horizontal gradient progress bars. It lives in the app bar, stays visible at any width, and compresses gracefully while keeping the labels and percentages readable.
class ResourceUsageBar extends StatelessWidget {
  final double cpuPercent;
  final double gpuPercent;
  final double ramPercent;

  const ResourceUsageBar({
    super.key,
    this.cpuPercent = 0,
    this.gpuPercent = 0,
    this.ramPercent = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MetricBar(label: 'CPU', value: cpuPercent),
        const SizedBox(width: AppDimensions.paddingMedium),
        _MetricBar(label: 'GPU', value: gpuPercent),
        const SizedBox(width: AppDimensions.paddingMedium),
        _MetricBar(label: 'RAM', value: ramPercent),
      ],
    );
  }
}

/// One metric made of a label, a fixed width gradient progress bar, and a percentage.
class _MetricBar extends StatelessWidget {
  final String label;
  final double value;

  const _MetricBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTypography.fontSizeButton,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppDimensions.paddingSmall),
        SizedBox(
          width: 80,
          child: _UsageProgressBar(value: value.clamp(0.0, 100.0)),
        ),
        const SizedBox(width: AppDimensions.paddingVerySmall),
        Text(
          '${value.round()}%',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTypography.fontSizeButton,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Thin horizontal bar whose color depends on the usage level and whose fill width is proportional to the value. Green up to 40 percent, yellow up to 80, and red above that.
class _UsageProgressBar extends StatelessWidget {
  final double value;

  const _UsageProgressBar({required this.value});

  Color _getColor(double percent) {
    if (percent <= 40) return AppColors.statusGreen;
    if (percent <= 80) return AppColors.statusYellow;
    return AppColors.statusRed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.primaryPlain,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value / 100.0,
        child: Container(
          decoration: BoxDecoration(
            color: _getColor(value),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
