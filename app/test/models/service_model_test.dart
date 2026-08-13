import 'package:flutter_test/flutter_test.dart';
import 'package:syspie/features/services/service_model.dart';

void main() {
  group('ServiceModel.fromJson', () {
    test('parses all fields', () {
      final model = ServiceModel.fromJson({
        'serviceName': 'WSearch',
        'displayName': 'Windows Search',
        'pid': 4242,
        'status': 'Running',
        'group': 'Network Service',
        'type': 'Own Process',
      });

      expect(model.serviceName, 'WSearch');
      expect(model.displayName, 'Windows Search');
      expect(model.pid, 4242);
      expect(model.status, 'Running');
      expect(model.group, 'Network Service');
      expect(model.type, 'Own Process');
    });

    test('missing keys fall back to defaults', () {
      final model = ServiceModel.fromJson({});

      expect(model.serviceName, '');
      expect(model.displayName, '');
      expect(model.pid, 0);
      expect(model.status, 'Unknown');
      expect(model.group, '');
      expect(model.type, '');
    });

    test('null keys fall back to defaults', () {
      final model = ServiceModel.fromJson({
        'serviceName': null,
        'displayName': null,
        'pid': null,
        'status': null,
        'group': null,
        'type': null,
      });

      expect(model.serviceName, '');
      expect(model.displayName, '');
      expect(model.pid, 0);
      expect(model.status, 'Unknown');
      expect(model.group, '');
      expect(model.type, '');
    });
  });

  group('ServiceModel status helpers', () {
    test('isRunning is true only when status is Running', () {
      expect(ServiceModel.fromJson({'status': 'Running'}).isRunning, isTrue);
      expect(ServiceModel.fromJson({'status': 'Stopped'}).isRunning, isFalse);
      expect(ServiceModel.fromJson({'status': 'Paused'}).isRunning, isFalse);
    });

    test('isStopped is true only when status is Stopped', () {
      expect(ServiceModel.fromJson({'status': 'Stopped'}).isStopped, isTrue);
      expect(ServiceModel.fromJson({'status': 'Running'}).isStopped, isFalse);
      expect(ServiceModel.fromJson({'status': 'Paused'}).isStopped, isFalse);
    });
  });
}
