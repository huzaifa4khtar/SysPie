import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syspie/features/processes/process_controller.dart';
import 'package:syspie/features/users/user_controller.dart';

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

  group('userProvider', () {
    test('reading the provider sends list_users', () {
      container.read(userProvider);
      expect(
        fake.sentCommands.map((c) => c['cmd']),
        contains('list_users'),
      );
    });

    test('emit users sets realUsers', () async {
      container.read(userProvider);
      fake.emit({
        'type': 'users',
        'data': ['alice', 'bob'],
      });
      await flushEvents();

      final state = container.read(userProvider);
      expect(state.realUsers, ['alice', 'bob']);
    });

    test('refresh sets isLoading and sends a second list_users', () async {
      container.read(userProvider);
      await container.read(userProvider.notifier).refresh();

      final state = container.read(userProvider);
      expect(state.isLoading, isTrue);
      final listCommands =
          fake.sentCommands.where((c) => c['cmd'] == 'list_users');
      expect(listCommands, hasLength(2));
    });
  });
}
