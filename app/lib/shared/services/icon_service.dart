import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/syspie_client.dart';

class IconService {
  static SysPieClient? client;
  static final Map<int, String> _cacheByPid = {};
  static final Map<String, String> _cacheByAumid = {};
  static final Set<int> _loading = {};
  static final Set<String> _loadingAumids = {};
  static final Set<int> _failedPids = {};
  static final Set<String> _failedAumids = {};
  static bool _batchInFlight = false;
  static DateTime _lastFailedPidsClear = DateTime.fromMillisecondsSinceEpoch(0);

  IconService._();

  static String? getCachedIcon(int pid) {
    return _cacheByPid[pid];
  }

  static String? getCachedAumidIcon(String aumid) {
    return _cacheByAumid[aumid];
  }

  static Future<String?> loadIconByAumid(String aumid) async {
    if (aumid.isEmpty) return null;
    if (_cacheByAumid.containsKey(aumid)) return _cacheByAumid[aumid];
    if (_loadingAumids.contains(aumid) || client == null) return null;

    _loadingAumids.add(aumid);
    try {
      final result = await client!
          .sendCommandWithAck({'cmd': 'get_aumid_icon', 'aumid': aumid});
      final icon = result['icon'] as String?;
      if (icon != null && icon.isNotEmpty) {
        _cacheByAumid[aumid] = icon;
        return icon;
      } else {
        _failedAumids.add(aumid);
      }
    } catch (_) {
      _failedAumids.add(aumid);
    } finally {
      _loadingAumids.remove(aumid);
    }
    return null;
  }

  static Future<void> loadIconsForPids(Iterable<int> pids) async {
    final now = DateTime.now();
    if (now.difference(_lastFailedPidsClear).inSeconds >= 30) {
      _failedPids.clear();
      _lastFailedPidsClear = now;
    }

    final toLoad = pids
        .where((pid) =>
            !_cacheByPid.containsKey(pid) &&
            !_loading.contains(pid) &&
            !_failedPids.contains(pid))
        .toList();
    if (toLoad.isEmpty || _batchInFlight || client == null) return;

    _batchInFlight = true;
    for (final pid in toLoad) {
      _loading.add(pid);
    }

    try {
      final result = await client!
          .sendCommandWithAck({'cmd': 'get_icons', 'pids': toLoad});
      final icons = result['icons'] as List<dynamic>?;
      if (icons != null) {
        for (final entry in icons) {
          final pid = entry['pid'] as int;
          final icon = entry['icon'] as String?;
          if (icon != null && icon.isNotEmpty) {
            _cacheByPid[pid] = icon;
            _failedPids.remove(pid);
          } else {
            _failedPids.add(pid);
          }
        }
      }
      for (final pid in toLoad) {
        if (!_cacheByPid.containsKey(pid)) {
          _failedPids.add(pid);
        }
      }
    } catch (_) {
      for (final pid in toLoad) {
        _failedPids.add(pid);
      }
    } finally {
      _loading.clear();
      _batchInFlight = false;
    }
  }

  @visibleForTesting
  static void clearCache() {
    _cacheByPid.clear();
    _cacheByAumid.clear();
    _loading.clear();
    _loadingAumids.clear();
    _failedPids.clear();
    _failedAumids.clear();
  }
}
