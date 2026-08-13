import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../platform/elevation.dart';

/// A dismissible inline banner shown when a service action fails due to
/// insufficient privileges. Offers a "Run as Admin" button to relaunch
/// with elevation and a close button to dismiss.
class ElevationBanner extends StatelessWidget {
  final VoidCallback? onDismiss;

  const ElevationBanner({super.key, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.statusYellow.withAlpha(30),
        border: Border(
          bottom: BorderSide(color: AppColors.statusYellow.withAlpha(80)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 18, color: AppColors.statusYellow),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Some actions require administrator privileges.',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () {
              relaunchAsAdmin();
            },
            child: const Text(
              'Run as Admin',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 16,
              icon: const Icon(Icons.close, color: AppColors.textMuted),
              onPressed: onDismiss,
            ),
          ),
        ],
      ),
    );
  }
}
