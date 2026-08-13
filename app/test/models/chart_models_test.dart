import 'package:flutter_test/flutter_test.dart';
import 'package:syspie/features/charts/chart_controller.dart';
import 'package:syspie/features/charts/chart_models.dart';

void main() {
  ChartDataState stateWith(List<ChartDataPoint> points) =>
      ChartDataState(points: points, isLoading: false);

  ChartDataPoint point({
    double memoryTotalMB = 0,
    double memoryUsedMB = 0,
    double diskReadMBps = 0,
    double diskWriteMBps = 0,
    double networkSendBps = 0,
    double networkRecvBps = 0,
  }) =>
      ChartDataPoint(
        timestamp: DateTime(2026, 1, 1),
        memoryTotalMB: memoryTotalMB,
        memoryUsedMB: memoryUsedMB,
        diskReadMBps: diskReadMBps,
        diskWriteMBps: diskWriteMBps,
        networkSendBps: networkSendBps,
        networkRecvBps: networkRecvBps,
      );

  group('ChartTabData.getMaxY', () {
    test('memory max is pinned to the system total memory', () {
      final state = stateWith([
        point(memoryTotalMB: 16384, memoryUsedMB: 4000),
        point(memoryTotalMB: 16384, memoryUsedMB: 8200),
      ]);

      expect(ChartTabData.getMaxY(ChartTab.memory, state), 16384);
    });

    test('memory max is exact even when used is far below total', () {
      final state = stateWith([
        point(memoryTotalMB: 32768, memoryUsedMB: 1500),
        point(memoryTotalMB: 32768, memoryUsedMB: 900),
      ]);

      expect(ChartTabData.getMaxY(ChartTab.memory, state), 32768);
    });

    test('memory max falls back to 100 when total is unknown', () {
      final state = stateWith([
        point(memoryTotalMB: 0, memoryUsedMB: 1200),
        point(memoryTotalMB: 0, memoryUsedMB: 900),
      ]);

      expect(ChartTabData.getMaxY(ChartTab.memory, state), 100);
    });

    test('memory max returns 100 when there are no points', () {
      expect(ChartTabData.getMaxY(ChartTab.memory, const ChartDataState()),
          100);
    });

    test('disk keeps dynamic scaling', () {
      final state = stateWith([
        point(diskReadMBps: 80, diskWriteMBps: 20),
        point(diskReadMBps: 500, diskWriteMBps: 300),
        point(diskReadMBps: 10, diskWriteMBps: 5),
      ]);

      final maxY = ChartTabData.getMaxY(ChartTab.disk, state);
      expect(maxY, greaterThan(500));
      expect(maxY, lessThanOrEqualTo(1000));
    });

    test('network keeps dynamic scaling', () {
      final state = stateWith([
        point(networkSendBps: 120000000, networkRecvBps: 30000000),
        point(networkSendBps: 40000000, networkRecvBps: 80000000),
      ]);

      final maxY = ChartTabData.getMaxY(ChartTab.network, state);
      expect(maxY, greaterThan(120000000));
    });

    test('cpu and gpu stay fixed at 100', () {
      final state = stateWith([point()]);

      expect(ChartTabData.getMaxY(ChartTab.cpu, state), 100);
      expect(ChartTabData.getMaxY(ChartTab.gpu, state), 100);
    });
  });
}
