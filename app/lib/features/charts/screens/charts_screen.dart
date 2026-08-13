import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/context_menu.dart';
import '../chart_models.dart';
import '../widgets/charts_card.dart';

class ChartsScreen extends ConsumerStatefulWidget {
  const ChartsScreen({super.key});

  @override
  ConsumerState<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends ConsumerState<ChartsScreen> {
  ChartTab _selectedTab = ChartTab.cpu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        child: GestureDetector(
          onSecondaryTapUp: (details) =>
              _showContextMenu(context, details.globalPosition),
          child: ChartsCard(
            selectedTab: _selectedTab,
            onTabChanged: (tab) => setState(() => _selectedTab = tab),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showContextMenu(
      context: context,
      position: position,
      items: [
        ContextMenuItem(
          label: 'View CPU Chart',
          icon: Icons.memory,
          onTap: () => setState(() => _selectedTab = ChartTab.cpu),
        ),
        ContextMenuItem(
          label: 'View GPU Chart',
          icon: Icons.speed,
          onTap: () => setState(() => _selectedTab = ChartTab.gpu),
        ),
        ContextMenuItem(
          label: 'View Memory Chart',
          icon: Icons.storage,
          onTap: () => setState(() => _selectedTab = ChartTab.memory),
        ),
        ContextMenuItem(
          label: 'View Disk Chart',
          icon: Icons.disc_full,
          onTap: () => setState(() => _selectedTab = ChartTab.disk),
        ),
        ContextMenuItem(
          label: 'View Network Chart',
          icon: Icons.wifi,
          onTap: () => setState(() => _selectedTab = ChartTab.network),
        ),
      ],
    );
  }
}
