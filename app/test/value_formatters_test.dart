import 'package:flutter_test/flutter_test.dart';
import 'package:syspie/shared/value_formatters.dart';

void main() {
  group('formatCpuPercent', () {
    test('returns 0% for zero', () {
      expect(formatCpuPercent(0), '0%');
    });

    test('returns 0% for negative values', () {
      expect(formatCpuPercent(-5.0), '0%');
    });

    test('returns <0.1% for values below 0.1', () {
      expect(formatCpuPercent(0.05), '<0.1%');
    });

    test('formats to one decimal place', () {
      expect(formatCpuPercent(5.0), '5.0%');
      expect(formatCpuPercent(23.46), '23.5%');
    });
  });

  group('formatMemoryMB', () {
    test('returns 0 MB for zero', () {
      expect(formatMemoryMB(0), '0 MB');
    });

    test('returns 0 MB for negative values', () {
      expect(formatMemoryMB(-100.0), '0 MB');
    });

    test('stays in MB below 1024', () {
      expect(formatMemoryMB(512.0), '512.0 MB');
    });

    test('converts to GB at or above 1024', () {
      expect(formatMemoryMB(1024.0), '1.0 GB');
      expect(formatMemoryMB(1536.0), '1.5 GB');
    });
  });

  group('formatDiskMBps', () {
    test('returns 0 KB/s for zero', () {
      expect(formatDiskMBps(0), '0 KB/s');
    });

    test('returns 0 KB/s for negative values', () {
      expect(formatDiskMBps(-3.0), '0 KB/s');
    });

    test('converts MB/s to KB/s below 1024 kBps', () {
      expect(formatDiskMBps(0.5), '512.0 KB/s');
    });

    test('converts to MB/s at or above 1024 kBps', () {
      expect(formatDiskMBps(1.0), '1.0 MB/s');
      expect(formatDiskMBps(2.0), '2.0 MB/s');
    });
  });

  group('formatNetworkBps', () {
    test('returns 0 Kbps for zero', () {
      expect(formatNetworkBps(0), '0 Kbps');
    });

    test('returns 0 Kbps for negative values', () {
      expect(formatNetworkBps(-500.0), '0 Kbps');
    });

    test('stays in Kbps below 1000', () {
      expect(formatNetworkBps(1000.0), '8.0 Kbps');
    });

    test('converts to Mbps at or above 1000 Kbps', () {
      expect(formatNetworkBps(125000.0), '1.0 Mbps');
      expect(formatNetworkBps(250000.0), '2.0 Mbps');
    });
  });

  group('formatGpuPercent', () {
    test('returns 0.0% for zero', () {
      expect(formatGpuPercent(0), '0.0%');
    });

    test('returns 0.0% for negative values', () {
      expect(formatGpuPercent(-1.0), '0.0%');
    });

    test('formats to one decimal place', () {
      expect(formatGpuPercent(45.67), '45.7%');
    });
  });
}
