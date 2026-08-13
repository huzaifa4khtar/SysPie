import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_dimensions.dart';
import 'core/theme/app_theme.dart';
import 'core/syspie_client.dart';
import 'features/processes/process_controller.dart';
import 'features/processes/process_service.dart';
import 'features/services/service_service.dart';
import 'shared/services/icon_service.dart';
import 'features/shell/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Initialize native client
  final client = SysPieClient();
  await client.init();

  // Set default clients for services (used by screens)
  ProcessService.setDefaultClient(client);
  ServiceService.setDefaultClient(client);
  IconService.client = client;

  const windowOptions = WindowOptions(
    minimumSize: Size(AppDimensions.minWidth, AppDimensions.minHeight),
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setTitle('SysPie');
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    ProviderScope(
      overrides: [
        sysPieClientProvider.overrideWithValue(client),
      ],
      child: const SysPieApp(),
    ),
  );
}

class SysPieApp extends StatefulWidget {
  const SysPieApp({super.key});

  @override
  State<SysPieApp> createState() => _SysPieAppState();
}

class _SysPieAppState extends State<SysPieApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SysPie',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _NoDefaultScrollbar(),
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: const AppShell(),
    );
  }
}

class _NoDefaultScrollbar extends ScrollBehavior {
  const _NoDefaultScrollbar();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
