import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'bindings/icon_api.dart';
import 'bindings/process_api.dart';
import 'bindings/service_api.dart';
import 'bindings/shell_api.dart';
import 'bindings/stats_api.dart';
import 'bindings/syspie_library.dart';
import 'bindings/user_api.dart';

// Top-level functions for one-shot isolate calls.

// Enumerates processes, stats, and network on a fresh isolate, then returns
// the combined JSON. It skips plShutdown so the process-wide globals the main
// isolate depends on stay alive, and plInit is idempotent so rerunning it is
// safe.
String _pollOnce(String dllPath) {
  final lib = SysPieLibrary.loadAt(dllPath);
  lib.plInit();
  try {
    final processApi = ProcessApi(lib);
    final statsApi = StatsApi(lib);
    return '{"diff":${processApi.enumerateProcessesDiffJson()},'
        '"stats":${statsApi.statsJson()}}';
  } finally {
    lib.release();
  }
}

// Enumerates services on a fresh isolate and returns the JSON string.
String _listServicesOnce(String dllPath) {
  final lib = SysPieLibrary.loadAt(dllPath);
  lib.plInit();
  try {
    return ServiceApi(lib).enumerateServicesJson();
  } finally {
    lib.release();
  }
}

// Lists users on a fresh isolate and returns the JSON string.
String _listUsersOnce(String dllPath) {
  final lib = SysPieLibrary.loadAt(dllPath);
  lib.plInit();
  try {
    return UserApi(lib).listUsersJson();
  } finally {
    lib.release();
  }
}

// SysPieClient

class SysPieClient {
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  SysPieLibrary? _lib;
  Timer? _pollTimer;
  Timer? _servicePollTimer;
  String? _dllPath;
  bool _polling = false;

  late final ProcessApi processApi;
  late final StatsApi statsApi;
  late final ServiceApi serviceApi;
  late final UserApi userApi;
  late final IconApi iconApi;
  late final ShellApi shellApi;

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  Future<void> init() async {
    _dllPath = SysPieLibrary.resolveDllPath();
    _lib = SysPieLibrary.loadAt(_dllPath!);
    _lib!.plInit();
    processApi = ProcessApi(_lib!);
    statsApi = StatsApi(_lib!);
    serviceApi = ServiceApi(_lib!);
    userApi = UserApi(_lib!);
    iconApi = IconApi(_lib!);
    shellApi = ShellApi(_lib!);
    debugPrint('[SysPieClient] DLL loaded at $_dllPath');
    _startPolling();
  }

  void _startPolling() {
    _pollData(); // immediate first poll
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pollData();
    });
    _refreshServices(); // immediate first services poll
    _servicePollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshServices();
    });
  }

  void _refreshServices() {
    if (_eventController.isClosed || _dllPath == null) return;
    final path = _dllPath!;
    compute(_listServicesOnce, path).then((json) {
      if (_eventController.isClosed) return;
      try {
        final decoded = jsonDecode(json);
        if (decoded is Map<String, dynamic> && decoded['data'] is List) {
          _eventController.add({'type': 'services', 'data': decoded['data']});
        }
      } catch (e) {
        debugPrint('[SysPieClient] Error decoding services: $e');
      }
    }).catchError((e) {
      debugPrint('[SysPieClient] Services poll error: $e');
    });
  }

  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;

  void _pollData() {
    if (_polling || _eventController.isClosed || _dllPath == null) return;
    _polling = true;

    final path = _dllPath!;

    compute(_pollOnce, path).then((json) {
      if (_eventController.isClosed) return;
      _polling = false;
      _consecutiveErrors = 0;
      try {
        final decoded = jsonDecode(json);
        if (decoded is Map<String, dynamic>) {
          if (decoded['diff'] is Map<String, dynamic>) {
            final diff = decoded['diff'] as Map<String, dynamic>;
            final diffType = diff['type'] as String?;
            if (diffType == 'processes') {
              _eventController.add({
                'type': 'processes',
                'data': diff['data'],
              });
            } else if (diffType == 'processes_diff') {
              _eventController.add({
                'type': 'processes_diff',
                'added': diff['added'] ?? [],
                'updated': diff['updated'] ?? [],
                'removed': diff['removed'] ?? [],
              });
            }
            // The nochange type means nothing changed, so it is skipped.
          }
          if (decoded['stats'] is Map<String, dynamic>) {
            _eventController.add({
              'type': 'stats',
              'data': decoded['stats'],
            });
          }
        }
      } catch (e) {
        debugPrint('[SysPieClient] Error decoding combined poll: $e');
      }
    }).catchError((e) {
      _polling = false;
      _consecutiveErrors++;
      debugPrint('[SysPieClient] Poll error: $e');
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        debugPrint('[SysPieClient] Too many consecutive errors, stopping poll');
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    });
  }

  // Command handlers run on the main isolate.

  void _emitIfOpen(Map<String, dynamic> event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _sendToBackground(
      String Function(String) computation, void Function(String) onResult) {
    final path = _dllPath!;
    compute(computation, path).then((json) {
      onResult(json);
    }).catchError((e) {
      debugPrint('[SysPieClient] Background command error: $e');
    });
  }

  void sendCommand(Map<String, dynamic> cmd) {
    final cmdName = cmd['cmd'] as String?;
    if (cmdName == null) return;

    try {
      switch (cmdName) {
        case 'list_services':
          _sendToBackground(_listServicesOnce, (json) {
            final decoded = jsonDecode(json);
            if (decoded is Map<String, dynamic> && decoded['data'] is List) {
              _emitIfOpen({'type': 'services', 'data': decoded['data']});
            }
          });
          break;
        case 'list_users':
          _sendToBackground(_listUsersOnce, (json) {
            final decoded = jsonDecode(json);
            if (decoded is Map<String, dynamic> && decoded['data'] is List) {
              _emitIfOpen({'type': 'users', 'data': decoded['data']});
            }
          });
          break;
        case 'get_icons':
          _handleGetIcons(cmd);
          break;
        case 'get_icon':
          _handleGetIcon(cmd);
          break;
        case 'get_aumid_icon':
          _handleGetAumidIcon(cmd);
          break;
        case 'check_dangerous':
          _handleCheckDangerous(cmd);
          break;
        case 'terminate':
          _handleTerminate(cmd);
          break;
        case 'terminate_tree':
          _handleTerminateTree(cmd);
          break;
        case 'terminate_batch':
          _handleTerminateBatch(cmd);
          break;
        case 'close_window':
          _handleCloseWindow(cmd);
          break;
        case 'properties':
          _handleProperties(cmd);
          break;
        case 'file_location':
          _handleFileLocation(cmd);
          break;
        case 'open_services':
          _handleOpenServices();
          break;
        case 'start_service':
          _handleStartService(cmd);
          Future.delayed(const Duration(milliseconds: 500), _refreshServices);
          break;
        case 'stop_service':
          _handleStopService(cmd);
          Future.delayed(const Duration(milliseconds: 500), _refreshServices);
          break;
        case 'restart_service':
          _handleRestartService(cmd);
          Future.delayed(const Duration(milliseconds: 500), _refreshServices);
          break;
        case 'ping':
          _eventController.add({'type': 'ack', 'cmd': 'ping', 'success': true});
          break;
        case 'shutdown':
          dispose();
          break;
      }
    } catch (e) {
      debugPrint('[SysPieClient] Error handling command $cmdName: $e');
    }
  }

  Future<Map<String, dynamic>> sendCommandWithAck(
    Map<String, dynamic> cmd, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final cmdName = cmd['cmd'] as String? ?? '';

    switch (cmdName) {
      case 'terminate':
        return _handleTerminate(cmd);
      case 'terminate_tree':
        return _handleTerminateTree(cmd);
      case 'terminate_batch':
        return _handleTerminateBatch(cmd);
      case 'close_window':
        return _handleCloseWindow(cmd);
      case 'check_dangerous':
        return _handleCheckDangerous(cmd);
      case 'get_icon':
        return _handleGetIcon(cmd);
      case 'get_aumid_icon':
        return _handleGetAumidIcon(cmd);
      case 'get_icons':
        return _handleGetIcons(cmd);
      case 'list_services':
        return _handleListServicesAsync();
      case 'start_service':
        return _handleStartService(cmd);
      case 'stop_service':
        return _handleStopService(cmd);
      case 'restart_service':
        return _handleRestartService(cmd);
      case 'list_users':
        return _handleListUsersAsync();
      case 'properties':
        return _handleProperties(cmd);
      case 'file_location':
        return _handleFileLocation(cmd);
      case 'open_services':
        return _handleOpenServices();
      case 'ping':
        return {'success': true};
      case 'shutdown':
        dispose();
        return {'success': true};
      default:
        return {'success': false, 'errorMessage': 'Unknown command: $cmdName'};
    }
  }

  Map<String, dynamic> _handleTerminate(Map<String, dynamic> cmd) {
    final pid = cmd['pid'] as int? ?? 0;
    final success = processApi.terminate(pid);
    return {'type': 'ack', 'cmd': 'terminate', 'success': success};
  }

  Map<String, dynamic> _handleTerminateTree(Map<String, dynamic> cmd) {
    final pid = cmd['pid'] as int? ?? 0;
    final success = processApi.terminateTree(pid);
    return {'type': 'ack', 'cmd': 'terminate_tree', 'success': success};
  }

  Map<String, dynamic> _handleTerminateBatch(Map<String, dynamic> cmd) {
    final pidsList = cmd['pids'] as List<dynamic>? ?? [];
    final pids = pidsList.cast<int>();
    final count = pids.length;

    final result = processApi.terminateBatch(pids);
    return {
      'type': 'ack',
      'cmd': 'terminate_batch',
      'success': result > 0,
      'terminated': result,
      'total': count,
    };
  }

  Map<String, dynamic> _handleCloseWindow(Map<String, dynamic> cmd) {
    final hwnd = cmd['hwnd'] as int? ?? 0;
    final success = processApi.closeWindow(hwnd);
    return {'type': 'ack', 'cmd': 'close_window', 'success': success};
  }

  Map<String, dynamic> _handleCheckDangerous(Map<String, dynamic> cmd) {
    final pid = cmd['pid'] as int? ?? 0;
    final dangerous = processApi.checkDangerous(pid);
    return {'type': 'dangerous', 'pid': pid, 'dangerous': dangerous};
  }

  Map<String, dynamic> _handleGetIcon(Map<String, dynamic> cmd) {
    final pid = cmd['pid'] as int? ?? 0;
    final icon = iconApi.getIcon(pid);
    return {'type': 'icon', 'pid': pid, 'icon': icon};
  }

  Map<String, dynamic> _handleGetAumidIcon(Map<String, dynamic> cmd) {
    final aumid = cmd['aumid'] as String? ?? '';
    final icon = iconApi.getAumidIcon(aumid);
    return {'type': 'aumid_icon', 'aumid': aumid, 'icon': icon};
  }

  Map<String, dynamic> _handleGetIcons(Map<String, dynamic> cmd) {
    final pidsList = cmd['pids'] as List<dynamic>? ?? [];
    final pids = pidsList.cast<int>();

    final json = iconApi.getIconsBatchJson(pids);
    final decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic> && decoded['icons'] is List) {
      return {'type': 'icons', 'icons': decoded['icons']};
    }
    return {'type': 'icons', 'icons': []};
  }

  Future<Map<String, dynamic>> _handleListServicesAsync() async {
    final path = _dllPath!;
    final json = await compute(_listServicesOnce, path);
    final decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic> && decoded['data'] is List) {
      return {'type': 'services', 'data': decoded['data']};
    }
    return {'type': 'services', 'data': []};
  }

  Map<String, dynamic> _handleStartService(Map<String, dynamic> cmd) {
    final name = cmd['name'] as String? ?? '';
    final success = serviceApi.start(name);
    String? errorMsg;
    if (!success) {
      errorMsg = serviceApi.lastServiceError();
    }
    return {
      'type': 'ack',
      'cmd': 'start_service',
      'success': success,
      'errorMessage': errorMsg,
    };
  }

  Map<String, dynamic> _handleStopService(Map<String, dynamic> cmd) {
    final name = cmd['name'] as String? ?? '';
    final success = serviceApi.stop(name);
    String? errorMsg;
    if (!success) {
      errorMsg = serviceApi.lastServiceError();
    }
    return {
      'type': 'ack',
      'cmd': 'stop_service',
      'success': success,
      'errorMessage': errorMsg,
    };
  }

  Map<String, dynamic> _handleRestartService(Map<String, dynamic> cmd) {
    final name = cmd['name'] as String? ?? '';
    final success = serviceApi.restart(name);
    String? errorMsg;
    if (!success) {
      errorMsg = serviceApi.lastServiceError();
    }
    return {
      'type': 'ack',
      'cmd': 'restart_service',
      'success': success,
      'errorMessage': errorMsg,
    };
  }

  Future<Map<String, dynamic>> _handleListUsersAsync() async {
    final path = _dllPath!;
    final json = await compute(_listUsersOnce, path);
    final decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic> && decoded['data'] is List) {
      return {'type': 'users', 'data': decoded['data']};
    }
    return {'type': 'users', 'data': []};
  }

  Map<String, dynamic> _handleProperties(Map<String, dynamic> cmd) {
    final pid = cmd['pid'] as int? ?? 0;
    final success = shellApi.openProperties(pid);
    return {'type': 'properties', 'pid': pid, 'success': success};
  }

  Map<String, dynamic> _handleFileLocation(Map<String, dynamic> cmd) {
    final pid = cmd['pid'] as int? ?? 0;
    final success = shellApi.openFileLocation(pid);
    return {
      'type': 'ack',
      'cmd': 'file_location',
      'pid': pid,
      'success': success
    };
  }

  Map<String, dynamic> _handleOpenServices() {
    final success = shellApi.openServices();
    return {'type': 'ack', 'cmd': 'open_services', 'success': success};
  }

  /// Opens a Windows system app like Resource Monitor, Task Manager, or
  /// Services and makes its window topmost over SysPie.
  void openWindowTopmost(String appName) {
    shellApi.openWindowTopmost(appName);
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _servicePollTimer?.cancel();
    _servicePollTimer = null;

    if (_lib != null) {
      try {
        _lib!.plShutdown();
      } catch (_) {}
      _lib!.release();
      _lib = null;
    }

    if (!_eventController.isClosed) {
      _eventController.close();
    }
  }
}
