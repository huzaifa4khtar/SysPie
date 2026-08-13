import '../../core/syspie_client.dart';

class ProcessService {
  static SysPieClient? _defaultClient;

  static void setDefaultClient(SysPieClient client) {
    _defaultClient = client;
  }

  final SysPieClient _client;

  ProcessService() : _client = _getClient();

  ProcessService.withClient(this._client);

  static SysPieClient _getClient() {
    if (_defaultClient == null) {
      throw StateError(
        'ProcessService.defaultClient not set. Call ProcessService.setDefaultClient() first.',
      );
    }
    return _defaultClient!;
  }

  Future<bool> terminateProcess(int pid, {int hwnd = 0}) async {
    final cmd = <String, dynamic>{
      'cmd': hwnd > 0 ? 'close_window' : 'terminate',
      'pid': pid
    };
    if (hwnd > 0) cmd['hwnd'] = hwnd;
    try {
      final result = await _client.sendCommandWithAck(cmd);
      return result['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> terminateProcessTree(int pid) async {
    try {
      final result = await _client
          .sendCommandWithAck({'cmd': 'terminate_tree', 'pid': pid});
      return result['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> checkDangerous(int pid) async {
    try {
      final result = await _client
          .sendCommandWithAck({'cmd': 'check_dangerous', 'pid': pid});
      return result['dangerous'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<int> terminateProcesses(List<int> pids) async {
    try {
      final result = await _client
          .sendCommandWithAck({'cmd': 'terminate_batch', 'pids': pids});
      return result['terminated'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> openProperties(int pid) async {
    try {
      final result =
          await _client.sendCommandWithAck({'cmd': 'properties', 'pid': pid});
      return result['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openFileLocation(int pid) async {
    try {
      final result = await _client
          .sendCommandWithAck({'cmd': 'file_location', 'pid': pid});
      return result['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openServices() async {
    try {
      final result = await _client.sendCommandWithAck({'cmd': 'open_services'});
      return result['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
