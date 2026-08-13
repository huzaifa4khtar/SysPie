import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/syspie_client.dart';

class ServiceService {
  static SysPieClient? _defaultClient;

  static void setDefaultClient(SysPieClient client) {
    _defaultClient = client;
  }

  final SysPieClient _client;

  ServiceService() : _client = _getClient();

  ServiceService.withClient(this._client);

  static SysPieClient _getClient() {
    if (_defaultClient == null) {
      throw StateError(
        'ServiceService.defaultClient not set. Call ServiceService.setDefaultClient() first.',
      );
    }
    return _defaultClient!;
  }

  Future<Map<String, dynamic>> startService(String serviceName) async {
    try {
      return await _client
          .sendCommandWithAck({'cmd': 'start_service', 'name': serviceName});
    } catch (e) {
      debugPrint('[startService] Exception for "$serviceName": $e');
      return {'success': false, 'errorMessage': e.toString()};
    }
  }

  Future<Map<String, dynamic>> stopService(String serviceName) async {
    try {
      return await _client
          .sendCommandWithAck({'cmd': 'stop_service', 'name': serviceName});
    } catch (e) {
      debugPrint('[stopService] Exception for "$serviceName": $e');
      return {'success': false, 'errorMessage': e.toString()};
    }
  }

  Future<Map<String, dynamic>> restartService(String serviceName) async {
    try {
      return await _client
          .sendCommandWithAck({'cmd': 'restart_service', 'name': serviceName});
    } catch (e) {
      debugPrint('[restartService] Exception for "$serviceName": $e');
      return {'success': false, 'errorMessage': e.toString()};
    }
  }
}
