import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syspie/features/processes/process_controller.dart';

import '../helpers/fake_syspie_client.dart';

Map<String, dynamic> makeProcessJson({
  required int pid,
  int parentPid = 1,
  String name = 'app.exe',
  double cpuUsage = 5.0,
  double memoryMB = 12.5,
}) {
  return {
    'pid': pid,
    'parentPid': parentPid,
    'name': name,
    'cpuUsage': cpuUsage,
    'memoryMB': memoryMB,
  };
}

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

  group('processProvider', () {
    setUp(() {
      fake = FakeSysPieClient();
      container = buildContainer();
    });

    test('initial state is empty and not loading', () {
      final state = container.read(processProvider);
      expect(state.processes, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('emit processes populates processes with correct pids', () async {
      container.read(processProvider);
      fake.emit({
        'type': 'processes',
        'data': [
          makeProcessJson(pid: 100),
          makeProcessJson(pid: 200),
        ],
      });
      await flushEvents();

      final state = container.read(processProvider);
      expect(state.processes, hasLength(2));
      expect(state.processes.map((p) => p.pid), [100, 200]);
    });

    test('a second processes event replaces the full snapshot', () async {
      container.read(processProvider);
      fake.emit({
        'type': 'processes',
        'data': [
          makeProcessJson(pid: 100),
          makeProcessJson(pid: 200),
        ],
      });
      await flushEvents();
      fake.emit({
        'type': 'processes',
        'data': [makeProcessJson(pid: 300)],
      });
      await flushEvents();

      final state = container.read(processProvider);
      expect(state.processes, hasLength(1));
      expect(state.processes.single.pid, 300);
    });

    test('processes_diff applies added/updated/removed', () async {
      container.read(processProvider);
      fake.emit({
        'type': 'processes',
        'data': [
          makeProcessJson(pid: 100),
          makeProcessJson(pid: 200),
        ],
      });
      await flushEvents();
      fake.emit({
        'type': 'processes_diff',
        'added': [makeProcessJson(pid: 300)],
        'updated': [makeProcessJson(pid: 100, name: 'app.exe')],
        'removed': [200],
      });
      await flushEvents();

      final state = container.read(processProvider);
      final pids = state.processes.map((p) => p.pid).toList();
      expect(pids, containsAll([100, 300]));
      expect(pids, isNot(contains(200)));
      expect(state.processes, hasLength(2));
    });

    test('processes_diff with no changes leaves processes untouched', () async {
      container.read(processProvider);
      fake.emit({
        'type': 'processes',
        'data': [
          makeProcessJson(pid: 100),
          makeProcessJson(pid: 200),
        ],
      });
      await flushEvents();
      fake.emit({'type': 'processes_diff'});
      await flushEvents();

      final state = container.read(processProvider);
      expect(state.processes, hasLength(2));
      expect(state.processes.map((p) => p.pid), [100, 200]);
    });

    test('stats event is ignored and processes stay unchanged', () async {
      container.read(processProvider);
      fake.emit({
        'type': 'processes',
        'data': [makeProcessJson(pid: 100)],
      });
      await flushEvents();
      fake.emit({
        'type': 'stats',
        'data': {'cpuUsagePercent': 42.0},
      });
      await flushEvents();

      final state = container.read(processProvider);
      expect(state.processes, hasLength(1));
      expect(state.processes.single.pid, 100);
    });
  });
}
