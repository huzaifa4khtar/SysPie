import 'dart:async';

import 'package:syspie/core/syspie_client.dart';

/// Test double for SysPieClient.
///
/// Overrides only the parts that controllers and services touch, which are
/// the events stream and command dispatch. Never calls the real FFI init path.
class FakeSysPieClient extends SysPieClient {
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  final List<Map<String, dynamic>> sentCommands = [];

  /// Optional canned responses for sendCommandWithAck. When null, ack calls
  /// return a success response.
  Future<Map<String, dynamic>> Function(Map<String, dynamic> cmd)? ackHandler;

  @override
  Stream<Map<String, dynamic>> get events => _controller.stream;

  @override
  void sendCommand(Map<String, dynamic> cmd) {
    sentCommands.add(cmd);
  }

  @override
  Future<Map<String, dynamic>> sendCommandWithAck(
    Map<String, dynamic> cmd, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (ackHandler != null) return ackHandler!(cmd);
    return {'success': true};
  }

  void emit(Map<String, dynamic> event) => _controller.add(event);

  void close() => _controller.close();
}
