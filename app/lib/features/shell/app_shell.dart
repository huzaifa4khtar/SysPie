import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../platform/elevation.dart';
import '../processes/process_controller.dart';
import '../processes/screens/processes_screen.dart';
import '../services/screens/services_screen.dart';
import '../details/screens/details_screen.dart';
import '../charts/screens/charts_screen.dart';
import '../users/screens/users_screen.dart';
import 'stats_controller.dart';
import 'widgets/side_menu.dart';
import 'widgets/top_buttons.dart';
import 'widgets/search_bar.dart';
import 'widgets/resource_usage_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  NavItem _selectedNav = NavItem.processes;
  int? _highlightPid;
  String _searchQuery = '';
  bool _startupElevationCheckDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_startupElevationCheckDone && !isRunningElevated()) {
        _startupElevationCheckDone = true;
        showAppSnackBar(
          context,
          'Note: some Features Require Admin elevation',
          backgroundColor: Colors.grey.shade700,
          textColor: Colors.white,
          duration: const Duration(seconds: 6),
        );
      }
    });
  }

  void _onNavItemSelected(NavItem item) {
    setState(() {
      _selectedNav = item;
      _highlightPid = null;
    });
  }

  void _navigateToProcessesWithPid(int pid) {
    setState(() {
      _selectedNav = NavItem.processes;
      _highlightPid = pid;
    });
  }

  void _navigateToDetailsWithPid(int pid) {
    setState(() {
      _selectedNav = NavItem.details;
      _highlightPid = pid;
    });
  }

  void _navigateToUsersWithPid(int pid) {
    setState(() {
      _selectedNav = NavItem.users;
      _highlightPid = pid;
    });
  }

  Widget _buildCurrentScreen() {
    switch (_selectedNav) {
      case NavItem.services:
        return ServicesScreen(
          key: const ValueKey('services'),
          highlightPid: _highlightPid,
          onNavigateToProcesses: _navigateToProcessesWithPid,
          onNavigateToDetails: _navigateToDetailsWithPid,
          searchQuery: _searchQuery,
        );
      case NavItem.details:
        return DetailsScreen(
          key: const ValueKey('details'),
          highlightPid: _highlightPid,
          onNavigateToProcesses: _navigateToProcessesWithPid,
          onNavigateToUsers: _navigateToUsersWithPid,
          searchQuery: _searchQuery,
        );
      case NavItem.charts:
        return const ChartsScreen(key: ValueKey('charts'));
      case NavItem.users:
        return UsersScreen(
          key: const ValueKey('users'),
          highlightPid: _highlightPid,
          onNavigateToProcesses: _navigateToProcessesWithPid,
          onNavigateToDetails: _navigateToDetailsWithPid,
          searchQuery: _searchQuery,
        );

      case NavItem.processes:
        return ProcessesScreen(
          key: const ValueKey('processes'),
          highlightPid: _highlightPid,
          onNavigateToDetails: _navigateToDetailsWithPid,
          onNavigateToUsers: _navigateToUsersWithPid,
          searchQuery: _searchQuery,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: Consumer(
        builder: (context, ref, child) {
          final statsState = ref.watch(statsProvider);

          return LayoutBuilder(
            builder: (context, constraints) {
              final showSideMenu =
                  constraints.maxWidth > AppDimensions.breakpointSideMenu;

              return Column(
                children: [
                  _buildTopBar(constraints.maxWidth, statsState, ref),
                  Expanded(
                    child: Row(
                      children: [
                        if (showSideMenu)
                          SideMenu(
                            selectedItem: _selectedNav,
                            onItemSelected: _onNavItemSelected,
                          ),
                        Expanded(
                          child: _buildCurrentScreen(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      ),
    );
  }

  Widget _buildTopBar(double totalWidth, StatsState statsState, WidgetRef ref) {
    final client = ref.read(sysPieClientProvider);
    final searchAvailable =
        totalWidth > AppDimensions.breakpointSearchBar ? 240.0 : 0.0;
    final buttonsAvailable =
        totalWidth > AppDimensions.breakpointTopButtons ? 150.0 : 0.0;

    String searchHint;
    switch (_selectedNav) {
      case NavItem.processes:
      case NavItem.details:
      case NavItem.users:
      case NavItem.services:
      case NavItem.charts:
        searchHint = 'Search...';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingMedium,
        AppDimensions.paddingMedium,
        AppDimensions.paddingMedium,
        0,
      ),
      child: Row(
        children: [
          ResourceUsageBar(
            cpuPercent: statsState.stats.cpuUsagePercent,
            gpuPercent: statsState.stats.gpuUsagePercent,
            ramPercent: statsState.stats.totalPhysicalMB > 0
                ? (statsState.stats.usedPhysicalMB /
                        statsState.stats.totalPhysicalMB *
                        100)
                    .clamp(0.0, 100.0)
                : 0,
          ),
          const Spacer(),
          if (buttonsAvailable > 0)
            TopButtons(
              availableWidth: buttonsAvailable,
              menuButtons: [
                TopMenuButton(
                  label: 'View',
                  items: [
                    TopMenuItem(
                      label: 'View Resource Monitor',
                      onTap: () => client.openWindowTopmost('resmon'),
                    ),
                    TopMenuItem(
                      label: 'View Task Manager',
                      onTap: () => client.openWindowTopmost('taskmgr'),
                    ),
                    TopMenuItem(
                      label: 'View Services',
                      onTap: () => client.openWindowTopmost('services'),
                    ),
                  ],
                ),
              ],
            ),
          if (buttonsAvailable > 0 && searchAvailable > 0)
            const SizedBox(width: AppDimensions.paddingSmall),
          if (searchAvailable > 0)
            SearchField(
              availableWidth: searchAvailable,
              hint: searchHint,
              onChanged: (query) {
                setState(() => _searchQuery = query);
              },
            ),
        ],
      ),
    );
  }
}
