import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// Native C function type definitions.

// Lifecycle
typedef PlInitNative = Int32 Function();
typedef PlShutdownNative = Void Function();

// Process data
typedef PlEnumerateProcessesDiffJsonNative = Pointer<Utf8> Function();
typedef PlGetStatsJsonNative = Pointer<Utf8> Function();

// Process actions
typedef PlTerminateNative = Int32 Function(Uint32 pid);
typedef PlTerminateTreeNative = Int32 Function(Uint32 pid);
typedef PlTerminateBatchNative = Int32 Function(
    Pointer<Uint32> pids, Int32 count);
typedef PlCloseWindowNative = Int32 Function(Int64 hwnd);

// Dangerous process
typedef PlCheckDangerousNative = Int32 Function(Uint32 pid);

// Icons
typedef PlGetIconNative = Pointer<Utf8> Function(Uint32 pid);
typedef PlGetIconsBatchJsonNative = Pointer<Utf8> Function(
    Pointer<Uint32> pids, Int32 count);
typedef PlGetAumidIconNative = Pointer<Utf8> Function(Pointer<Utf8> aumid);

// Services
typedef PlEnumerateServicesJsonNative = Pointer<Utf8> Function();
typedef PlStartServiceNative = Int32 Function(Pointer<Utf16> name);
typedef PlStopServiceNative = Int32 Function(Pointer<Utf16> name);
typedef PlRestartServiceNative = Int32 Function(Pointer<Utf16> name);
typedef PlGetLastServiceErrorNative = Pointer<Utf8> Function();

// Users
typedef PlListUsersJsonNative = Pointer<Utf8> Function();

// Shell
typedef PlOpenServicesNative = Int32 Function();
typedef PlOpenPropertiesNative = Int32 Function(Uint32 pid);
typedef PlOpenFileLocationNative = Int32 Function(Uint32 pid);
typedef PlOpenWindowTopmostNative = Void Function(Pointer<Utf16> appName);

// Memory management
typedef PlFreeStringNative = Void Function(Pointer<Utf8> str);

// Dart function type definitions.

// Lifecycle
typedef PlInitDart = int Function();
typedef PlShutdownDart = void Function();

// Process data
typedef PlEnumerateProcessesDiffJsonDart = Pointer<Utf8> Function();
typedef PlGetStatsJsonDart = Pointer<Utf8> Function();

// Process actions
typedef PlTerminateDart = int Function(int pid);
typedef PlTerminateTreeDart = int Function(int pid);
typedef PlTerminateBatchDart = int Function(Pointer<Uint32> pids, int count);
typedef PlCloseWindowDart = int Function(int hwnd);

// Dangerous process
typedef PlCheckDangerousDart = int Function(int pid);

// Icons
typedef PlGetIconDart = Pointer<Utf8> Function(int pid);
typedef PlGetIconsBatchJsonDart = Pointer<Utf8> Function(
    Pointer<Uint32> pids, int count);
typedef PlGetAumidIconDart = Pointer<Utf8> Function(Pointer<Utf8> aumid);

// Services
typedef PlEnumerateServicesJsonDart = Pointer<Utf8> Function();
typedef PlStartServiceDart = int Function(Pointer<Utf16> name);
typedef PlStopServiceDart = int Function(Pointer<Utf16> name);
typedef PlRestartServiceDart = int Function(Pointer<Utf16> name);
typedef PlGetLastServiceErrorDart = Pointer<Utf8> Function();

// Users
typedef PlListUsersJsonDart = Pointer<Utf8> Function();

// Shell
typedef PlOpenServicesDart = int Function();
typedef PlOpenPropertiesDart = int Function(int pid);
typedef PlOpenFileLocationDart = int Function(int pid);
typedef PlOpenWindowTopmostDart = void Function(Pointer<Utf16> appName);

// Memory management
typedef PlFreeStringDart = void Function(Pointer<Utf8> str);

// SysPieLibrary

/// Loads the SysPie native library and resolves all exported functions.
class SysPieLibrary {
  SysPieLibrary._(this._dylib);

  final DynamicLibrary _dylib;

  // Lifecycle functions.

  late final PlInitDart plInit =
      _dylib.lookupFunction<PlInitNative, PlInitDart>('pl_init');

  late final PlShutdownDart plShutdown =
      _dylib.lookupFunction<PlShutdownNative, PlShutdownDart>('pl_shutdown');

  // Process data functions.

  late final PlEnumerateProcessesDiffJsonDart plEnumerateProcessesDiffJson =
      _dylib.lookupFunction<PlEnumerateProcessesDiffJsonNative,
          PlEnumerateProcessesDiffJsonDart>('pl_enumerate_processes_diff_json');

  late final PlGetStatsJsonDart plGetStatsJson =
      _dylib.lookupFunction<PlGetStatsJsonNative, PlGetStatsJsonDart>(
          'pl_get_stats_json');

  // Process action functions.

  late final PlTerminateDart plTerminate =
      _dylib.lookupFunction<PlTerminateNative, PlTerminateDart>('pl_terminate');

  late final PlTerminateTreeDart plTerminateTree =
      _dylib.lookupFunction<PlTerminateTreeNative, PlTerminateTreeDart>(
          'pl_terminate_tree');

  late final PlTerminateBatchDart plTerminateBatch =
      _dylib.lookupFunction<PlTerminateBatchNative, PlTerminateBatchDart>(
          'pl_terminate_batch');

  late final PlCloseWindowDart plCloseWindow =
      _dylib.lookupFunction<PlCloseWindowNative, PlCloseWindowDart>(
          'pl_close_window');

  // Dangerous process check.

  late final PlCheckDangerousDart plCheckDangerous =
      _dylib.lookupFunction<PlCheckDangerousNative, PlCheckDangerousDart>(
          'pl_check_dangerous');

  // Icon functions.

  late final PlGetIconDart plGetIcon =
      _dylib.lookupFunction<PlGetIconNative, PlGetIconDart>('pl_get_icon');

  late final PlGetIconsBatchJsonDart plGetIconsBatchJson =
      _dylib.lookupFunction<PlGetIconsBatchJsonNative, PlGetIconsBatchJsonDart>(
          'pl_get_icons_batch_json');

  late final PlGetAumidIconDart plGetAumidIcon =
      _dylib.lookupFunction<PlGetAumidIconNative, PlGetAumidIconDart>(
          'pl_get_aumid_icon');

  // Service functions.

  late final PlEnumerateServicesJsonDart plEnumerateServicesJson =
      _dylib.lookupFunction<PlEnumerateServicesJsonNative,
          PlEnumerateServicesJsonDart>('pl_enumerate_services_json');

  late final PlStartServiceDart plStartService =
      _dylib.lookupFunction<PlStartServiceNative, PlStartServiceDart>(
          'pl_start_service');

  late final PlStopServiceDart plStopService =
      _dylib.lookupFunction<PlStopServiceNative, PlStopServiceDart>(
          'pl_stop_service');

  late final PlRestartServiceDart plRestartService =
      _dylib.lookupFunction<PlRestartServiceNative, PlRestartServiceDart>(
          'pl_restart_service');

  late final PlGetLastServiceErrorDart plGetLastServiceError = _dylib
      .lookupFunction<PlGetLastServiceErrorNative, PlGetLastServiceErrorDart>(
          'pl_get_last_service_error');

  // User functions.

  late final PlListUsersJsonDart plListUsersJson =
      _dylib.lookupFunction<PlListUsersJsonNative, PlListUsersJsonDart>(
          'pl_list_users_json');

  // Shell functions.

  late final PlOpenServicesDart plOpenServices =
      _dylib.lookupFunction<PlOpenServicesNative, PlOpenServicesDart>(
          'pl_open_services');

  late final PlOpenPropertiesDart plOpenProperties =
      _dylib.lookupFunction<PlOpenPropertiesNative, PlOpenPropertiesDart>(
          'pl_open_properties');

  late final PlOpenFileLocationDart plOpenFileLocation =
      _dylib.lookupFunction<PlOpenFileLocationNative, PlOpenFileLocationDart>(
          'pl_open_file_location');

  late final PlOpenWindowTopmostDart plOpenWindowTopmost =
      _dylib.lookupFunction<PlOpenWindowTopmostNative, PlOpenWindowTopmostDart>(
          'pl_open_window_topmost');

  // Memory management functions.

  late final PlFreeStringDart plFreeString = _dylib
      .lookupFunction<PlFreeStringNative, PlFreeStringDart>('pl_free_string');

  /// Frees a C string previously returned by the native library.
  void freeString(Pointer<Utf8> str) => plFreeString(str);

  /// Releases the library reference. The underlying DynamicLibrary is managed
  /// by the Dart VM and needs no explicit cleanup; the method exists for
  /// clarity.
  void release() {
    // DynamicLibrary instances are not explicitly closed by the VM's FFI API.
    // The VM handles unloading when the isolate shuts down.
  }

  // Factory and path resolution.

  /// Loads the native library from an explicit path.
  factory SysPieLibrary.loadAt(String dllPath) {
    final dylib = DynamicLibrary.open(dllPath);
    return SysPieLibrary._(dylib);
  }

  /// Finds the native library file. It checks the dedicated environment
  /// variable first, then the development and build folders, and finally the
  /// one placed next to the running executable.
  static String resolveDllPath() {
    // First check the environment variable override.
    final envPath = Platform.environment['SYSPIE_DLL_PATH'];
    if (envPath != null && envPath.isNotEmpty && File(envPath).existsSync()) {
      return envPath;
    }

    // Determine the Flutter project root. In dev mode the working directory is
    // the app folder; in production the executable sits in windows/runner/
    // Release or similar relative to the project root.
    final projectRoot = _findProjectRoot();

    // Next, try the dev build path for the Release configuration.
    final devPath = '$projectRoot\\native\\build\\Release\\syspie_native.dll';
    if (File(devPath).existsSync()) return devPath;

    // Then try the CMake default build path.
    final cmakePath = '$projectRoot\\native\\build\\syspie_native.dll';
    if (File(cmakePath).existsSync()) return cmakePath;

    // Then check the directory of the running executable for production.
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final prodPath = '$exeDir\\syspie_native.dll';
    if (File(prodPath).existsSync()) return prodPath;

    // If nothing was found, return the dev path and let the caller handle the
    // resulting missing file error with a clear message.
    return devPath;
  }

  /// Walks up from the current working directory to find the Flutter project
  /// root by looking for a native directory, which marks the monorepo root.
  static String _findProjectRoot() {
    var dir = Directory.current;

    // Start from the parent of the current directory because the working
    // directory is the app folder which has its own pubspec.yaml, while the
    // DLL lives at the monorepo root under native/build.
    final parent = dir.parent;
    if (parent.path != dir.path) {
      dir = parent;
    }

    // Walk up at most 10 levels to avoid infinite loops.
    for (var i = 0; i < 10; i++) {
      final nativeDir = Directory('${dir.path}\\native');
      if (nativeDir.existsSync()) return dir.path;
      final nextParent = dir.parent;
      if (nextParent.path == dir.path) break;
      dir = nextParent;
    }

    // Fall back to two levels up from the app folder.
    return Directory.current.parent.parent.path;
  }
}
