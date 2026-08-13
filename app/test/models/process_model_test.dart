import 'package:flutter_test/flutter_test.dart';
import 'package:syspie/shared/models/process_model.dart';

void main() {
  group('ProcessModel.fromJson', () {
    test('parses a full JSON map with every field set', () {
      final model = ProcessModel.fromJson({
        'pid': 4242,
        'parentPid': 1,
        'name': 'notepad.exe',
        'exePath': r'C:\Windows\notepad.exe',
        'friendlyName': 'Notepad',
        'detailName': 'Windows 10 Notepad',
        'aumid': 'Microsoft.Windows.Notepad',
        'userName': 'Huzaifa',
        'status': 'Running',
        'statusType': 4,
        'threadCount': 7,
        'handleCount': 128,
        'cpuUsage': 12.5,
        'memoryMB': 256.0,
        'memoryAccessDenied': true,
        'diskReadMB': 10.0,
        'diskWriteMB': 3.5,
        'networkBps': 2048.0,
        'gpuPercent': 5.0,
        'gpuEngine': '3D',
        'powerUsage': 'VeryLow',
        'diskPermission': 'Full',
        'uacVirtualization': 'Enabled',
        'isSystemProcess': false,
        'hasVisibleWindow': true,
        'hasIdeMatch': false,
        'windowTitles': ['Untitled - Notepad'],
        'serviceDisplayNames': ['Test Service'],
      });

      expect(model.pid, 4242);
      expect(model.parentPid, 1);
      expect(model.name, 'notepad.exe');
      expect(model.exePath, r'C:\Windows\notepad.exe');
      expect(model.friendlyName, 'Notepad');
      expect(model.detailName, 'Windows 10 Notepad');
      expect(model.aumid, 'Microsoft.Windows.Notepad');
      expect(model.userName, 'Huzaifa');
      expect(model.status, 'Running');
      expect(model.statusType, 4);
      expect(model.threadCount, 7);
      expect(model.handleCount, 128);
      expect(model.cpuUsage, 12.5);
      expect(model.memoryMB, 256.0);
      expect(model.memoryAccessDenied, isTrue);
      expect(model.diskReadMB, 10.0);
      expect(model.diskWriteMB, 3.5);
      expect(model.networkBps, 2048.0);
      expect(model.gpuPercent, 5.0);
      expect(model.gpuEngine, '3D');
      expect(model.powerUsage, 'VeryLow');
      expect(model.diskPermission, 'Full');
      expect(model.uacVirtualization, 'Enabled');
      expect(model.isSystemProcess, isFalse);
      expect(model.hasVisibleWindow, isTrue);
      expect(model.hasIdeMatch, isFalse);
      expect(model.windowTitles, ['Untitled - Notepad']);
      expect(model.serviceDisplayNames, ['Test Service']);
    });

    test('missing and null keys fall back to defaults', () {
      final model = ProcessModel.fromJson({});

      expect(model.pid, 0);
      expect(model.parentPid, 0);
      expect(model.name, '');
      expect(model.exePath, '');
      expect(model.friendlyName, '');
      expect(model.detailName, '');
      expect(model.aumid, '');
      expect(model.userName, '');
      expect(model.status, 'UNKNOWN');
      expect(model.statusType, 0);
      expect(model.threadCount, 0);
      expect(model.handleCount, 0);
      expect(model.cpuUsage, 0.0);
      expect(model.memoryMB, 0.0);
      expect(model.memoryAccessDenied, isFalse);
      expect(model.diskReadMB, 0.0);
      expect(model.diskWriteMB, 0.0);
      expect(model.networkBps, 0.0);
      expect(model.gpuPercent, 0.0);
      expect(model.gpuEngine, '');
      expect(model.powerUsage, '');
      expect(model.diskPermission, 'Read');
      expect(model.uacVirtualization, 'Disabled');
      expect(model.isSystemProcess, isFalse);
      expect(model.hasVisibleWindow, isFalse);
      expect(model.hasIdeMatch, isFalse);
      expect(model.windowTitles, isEmpty);
      expect(model.serviceDisplayNames, isEmpty);
      expect(model.windowInfos, isEmpty);
    });

    test('null keys fall back to defaults', () {
      final model = ProcessModel.fromJson({
        'pid': null,
        'name': null,
        'status': null,
        'cpuUsage': null,
        'diskPermission': null,
        'uacVirtualization': null,
        'windowTitles': null,
        'serviceDisplayNames': null,
      });

      expect(model.pid, 0);
      expect(model.name, '');
      expect(model.status, 'UNKNOWN');
      expect(model.cpuUsage, 0.0);
      expect(model.diskPermission, 'Read');
      expect(model.uacVirtualization, 'Disabled');
      expect(model.windowTitles, isEmpty);
      expect(model.serviceDisplayNames, isEmpty);
    });

    test('windowTitles as a list of Maps builds windowInfos', () {
      final model = ProcessModel.fromJson({
        'windowTitles': [
          {'title': 'Untitled - Notepad', 'hwnd': 1001, 'pid': 4242},
          {'title': 'Document - Word', 'hwnd': 1002, 'pid': 4242},
        ],
      });

      expect(model.windowTitles, ['Untitled - Notepad', 'Document - Word']);
      expect(model.windowInfos, hasLength(2));
      expect(model.windowInfos[0].title, 'Untitled - Notepad');
      expect(model.windowInfos[0].hwnd, 1001);
      expect(model.windowInfos[0].pid, 4242);
      expect(model.windowInfos[1].title, 'Document - Word');
      expect(model.windowInfos[1].hwnd, 1002);
      expect(model.windowInfos[1].pid, 4242);
    });

    test('windowTitles as plain strings falls back to WindowModel defaults',
        () {
      final model = ProcessModel.fromJson({
        'windowTitles': ['Untitled - Notepad', 'Second Window'],
      });

      expect(model.windowTitles, ['Untitled - Notepad', 'Second Window']);
      expect(model.windowInfos, hasLength(2));
      expect(model.windowInfos[0].title, 'Untitled - Notepad');
      expect(model.windowInfos[0].hwnd, 0);
      expect(model.windowInfos[0].pid, 0);
      expect(model.windowInfos[1].title, 'Second Window');
      expect(model.windowInfos[1].hwnd, 0);
      expect(model.windowInfos[1].pid, 0);
    });
  });

  group('SystemStatsModel.fromJson', () {
    test('parses a full JSON map', () {
      final model = SystemStatsModel.fromJson({
        'cpuUsagePercent': 23.5,
        'totalProcesses': 311,
        'totalThreads': 2048,
        'totalHandles': 120000,
        'totalPhysicalMB': 16384.0,
        'usedPhysicalMB': 9216.0,
        'availablePhysicalMB': 7168.0,
        'commitChargeMB': 12000.0,
        'commitLimitMB': 20000.0,
        'diskReadMBps': 12.0,
        'diskWriteMBps': 8.5,
        'gpuUsagePercent': 6.0,
      });

      expect(model.cpuUsagePercent, 23.5);
      expect(model.totalProcesses, 311);
      expect(model.totalThreads, 2048);
      expect(model.totalHandles, 120000);
      expect(model.totalPhysicalMB, 16384.0);
      expect(model.usedPhysicalMB, 9216.0);
      expect(model.availablePhysicalMB, 7168.0);
      expect(model.commitChargeMB, 12000.0);
      expect(model.commitLimitMB, 20000.0);
      expect(model.diskReadMBps, 12.0);
      expect(model.diskWriteMBps, 8.5);
      expect(model.gpuUsagePercent, 6.0);
    });

    test('missing keys fall back to defaults', () {
      final model = SystemStatsModel.fromJson({});

      expect(model.cpuUsagePercent, 0.0);
      expect(model.totalProcesses, 0);
      expect(model.totalThreads, 0);
      expect(model.totalHandles, 0);
      expect(model.totalPhysicalMB, 0.0);
      expect(model.usedPhysicalMB, 0.0);
      expect(model.availablePhysicalMB, 0.0);
      expect(model.commitChargeMB, 0.0);
      expect(model.commitLimitMB, 0.0);
      expect(model.diskReadMBps, 0.0);
      expect(model.diskWriteMBps, 0.0);
      expect(model.gpuUsagePercent, 0.0);
    });
  });

  group('WindowModel', () {
    test('default pid is 0', () {
      const window = WindowModel(title: 'Untitled - Notepad', hwnd: 1001);
      expect(window.pid, 0);
    });
  });
}
