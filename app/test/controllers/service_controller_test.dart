import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syspie/features/processes/process_controller.dart';
import 'package:syspie/features/services/service_controller.dart';

import '../helpers/fake_syspie_client.dart';

void main() {
  late FakeSysPieClient fake;
  late ProviderContainer container;

  ProviderContainer buildContainer() {
    final c = ProviderContainer(
      overrides: [
        sysPieClientProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> flushEvents() => Future<void>.delayed(Duration.zero);

  setUp(() {
    fake = FakeSysPieClient();
    container = buildContainer();
  });

  group('serviceProvider', () {
    test('reading the provider sends list_services', () {
      container.read(serviceProvider);
      expect(
        fake.sentCommands.map((c) => c['cmd']),
        contains('list_services'),
      );
    });

    test('emit services populates state', () async {
      container.read(serviceProvider);
      fake.emit({
        'type': 'services',
        'data': [
          {'serviceName': 'X', 'status': 'Running', 'pid': 10},
        ],
      });
      await flushEvents();

      final state = container.read(serviceProvider);
      expect(state.services, hasLength(1));
      expect(state.services.single.serviceName, 'X');
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('refresh sets isLoading and sends a second list_services', () async {
      container.read(serviceProvider);
      await container.read(serviceProvider.notifier).refresh();

      final state = container.read(serviceProvider);
      expect(state.isLoading, isTrue);
      final listCommands =
          fake.sentCommands.where((c) => c['cmd'] == 'list_services');
      expect(listCommands, hasLength(2));
    });
  });
}
