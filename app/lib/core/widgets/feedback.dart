import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shows a floating app-wide SnackBar with the given message. Pass isError to
/// use a red background with white text, otherwise it uses the default card
/// styling. Override backgroundColor, textColor, and duration for custom
/// styling.
void showAppSnackBar(BuildContext context, String message,
    {bool isError = false,
    Color? backgroundColor,
    Color? textColor,
    Duration? duration}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: textColor ?? (isError ? Colors.white : AppColors.textPrimary),
          fontSize: 13,
        ),
      ),
      backgroundColor:
          backgroundColor ?? (isError ? AppColors.statusRed : AppColors.cardBg),
      duration: duration ?? const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

/// Centered error state shown when the SysPie native library is unavailable.
class AppErrorState extends StatelessWidget {
  final String error;

  const AppErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.statusRed),
          const SizedBox(height: 16),
          const Text(
            'Cannot connect to Native Library',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Make sure the SysPie native library is available',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
