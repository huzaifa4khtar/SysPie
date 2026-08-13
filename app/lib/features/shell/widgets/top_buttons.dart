import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

/// A model representing a single top bar button.
class TopBarButton {
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;

  const TopBarButton({
    this.icon,
    required this.label,
    this.onTap,
  });
}

/// A model representing a dropdown menu button in the top bar.
class TopMenuButton {
  final IconData? icon;
  final String label;
  final List<TopMenuItem> items;

  const TopMenuButton({
    this.icon,
    required this.label,
    required this.items,
  });
}

/// A model for one item inside a dropdown menu button.
class TopMenuItem {
  final String label;
  final VoidCallback? onTap;

  const TopMenuItem({
    required this.label,
    this.onTap,
  });
}

/// Row of pill shaped buttons on the right side of the top bar. It supports regular buttons and dropdown menus, renders menu buttons first, and hides buttons one by one when space gets tight.
class TopButtons extends StatelessWidget {
  final List<TopBarButton> buttons;
  final List<TopMenuButton> menuButtons;
  final double availableWidth;

  const TopButtons({
    super.key,
    this.buttons = const [],
    this.menuButtons = const [],
    this.availableWidth = 300,
  });

  @override
  Widget build(BuildContext context) {
    // Each button needs about 120 pixels, so hide any that do not fit. Menu buttons take priority over regular buttons.
    final visibleItems = <Widget>[];
    var usedWidth = 0.0;
    const btnWidth = 120.0;

    for (final menu in menuButtons) {
      if (usedWidth + btnWidth <= availableWidth) {
        visibleItems.add(_TopMenuButtonWidget(button: menu));
        usedWidth += btnWidth;
      }
    }

    for (final btn in buttons) {
      if (usedWidth + btnWidth <= availableWidth) {
        visibleItems.add(_TopButtonWidget(button: btn));
        usedWidth += btnWidth;
      }
    }

    if (visibleItems.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < visibleItems.length; i++) ...[
          if (i > 0) const SizedBox(width: AppDimensions.paddingSmall),
          visibleItems[i],
        ],
      ],
    );
  }
}

class _TopButtonWidget extends StatelessWidget {
  final TopBarButton button;

  const _TopButtonWidget({required this.button});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: button.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: AppDimensions.buttonHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingExtraLarge,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (button.icon != null) ...[
                Icon(button.icon!, size: 16, color: AppColors.onPrimary),
                const SizedBox(width: 8),
              ],
              Text(
                button.label,
                style: const TextStyle(
                  fontSize: AppTypography.fontSizeButton,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopMenuButtonWidget extends StatelessWidget {
  final TopMenuButton button;

  const _TopMenuButtonWidget({required this.button});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final renderBox = context.findRenderObject() as RenderBox;
        final pos = renderBox.localToGlobal(
          Offset(0, renderBox.size.height + 4),
        );
        final size = renderBox.size;
        final position = RelativeRect.fromLTRB(
          pos.dx,
          pos.dy,
          pos.dx + size.width,
          pos.dy,
        );
        showMenu<TopMenuItem>(
          context: context,
          position: position,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: AppColors.primaryDark,
          popUpAnimationStyle:
              const AnimationStyle(duration: Duration(milliseconds: 200)),
          items: button.items.map((item) {
            return PopupMenuItem<TopMenuItem>(
              value: item,
              height: 32,
              child: Text(
                item.label,
                style: const TextStyle(
                  fontSize: AppTypography.fontSizeButton,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onPrimary,
                ),
              ),
            );
          }).toList(),
        ).then((item) {
          if (item != null) item.onTap?.call();
        });
      },
      child: Container(
        height: AppDimensions.buttonHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingExtraLarge,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (button.icon != null) ...[
              Icon(button.icon!, size: 16, color: AppColors.onPrimary),
              const SizedBox(width: 8),
            ],
            Text(
              button.label,
              style: const TextStyle(
                fontSize: AppTypography.fontSizeButton,
                fontWeight: FontWeight.w500,
                color: AppColors.onPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: AppColors.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
