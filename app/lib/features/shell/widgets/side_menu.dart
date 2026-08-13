import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// Navigation items available in the side menu.
enum NavItem {
  processes,
  details,
  services,
  charts,
  users,
}

/// Left side navigation with a pill shaped highlight for the active item. The parent hides it when the window is narrow, and it uses the sidebar highlight color for the active item and transparent for the rest.
class SideMenu extends StatelessWidget {
  final NavItem selectedItem;
  final ValueChanged<NavItem> onItemSelected;

  const SideMenu({
    super.key,
    required this.selectedItem,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimensions.sideMenuWidth,
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.paddingMedium,
        AppDimensions.paddingMedium,
        0,
        AppDimensions.paddingMedium,
      ),
      decoration: BoxDecoration(
        color: AppColors.sidebarBg,
        borderRadius: BorderRadius.circular(AppDimensions.cornerRadius),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Expanded(
            child: _buildNavItems(),
          ),
        ],
      ),
    );
  }

  /// Builds the list of navigation items.
  Widget _buildNavItems() {
    final items = [
      (NavItem.processes, Icons.auto_awesome_outlined, 'Processes'),
      (NavItem.details, Icons.list_alt_outlined, 'Details'),
      (NavItem.services, Icons.construction_outlined, 'Services'),
      (NavItem.charts, Icons.bar_chart_outlined, 'Charts'),
      (NavItem.users, Icons.people_outline, 'Users'),
    ];

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMedium),
      child: Column(
        children: items.map((item) {
          final isSelected = item.$1 == selectedItem;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.paddingTiny),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onItemSelected(item.$1),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingSmall,
                    vertical: AppDimensions.paddingSmall,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? AppColors.primaryDark : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.$2,
                        size: 18,
                        color: isSelected
                            ? AppColors.onPrimary
                            : AppColors.textPrimary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        item.$3,
                        style: TextStyle(
                          fontSize: AppTypography.fontSizeNav,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.onPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
