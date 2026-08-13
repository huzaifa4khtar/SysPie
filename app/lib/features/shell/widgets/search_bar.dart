import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// Pill shaped search input for the top bar. It hides itself when the available width is too small to render properly.
class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final double availableWidth;

  const SearchField({
    super.key,
    this.hint = 'Search...',
    this.onChanged,
    this.availableWidth = 300,
  });

  @override
  Widget build(BuildContext context) {
    if (availableWidth < 180) return const SizedBox.shrink();

    return Container(
      width: 240,
      constraints: const BoxConstraints(maxWidth: 240),
      height: AppDimensions.buttonHeight,
      decoration: BoxDecoration(
        color: AppColors.primaryPlain,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: AppDimensions.paddingSmall),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            color: AppColors.textMuted,
            size: AppTypography.fontSizeButton,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: AppTypography.fontSizeButton,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.fontSizeButton,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
