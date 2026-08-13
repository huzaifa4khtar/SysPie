import 'package:flutter_test/flutter_test.dart';
import 'package:syspie/shared/models/process_table.dart';

void main() {
  group('ProcessCategory.displayName', () {
    test('returns the correct display names', () {
      expect(ProcessCategory.apps.displayName, 'Apps');
      expect(ProcessCategory.background.displayName, 'Background Processes');
      expect(ProcessCategory.windowsProcesses.displayName, 'Windows Processes');
    });
  });

  group('ProcessTableRow.groupHeader', () {
    test('creates an apps category header', () {
      final row = ProcessTableRow.groupHeader(ProcessCategory.apps, 12);

      expect(row.name, 'Apps (12)');
      expect(row.pid, '');
      expect(row.rowType, ProcessRowType.groupHeader);
      expect(row.category, ProcessCategory.apps);
      expect(row.isExpanded, isTrue);
      expect(row.username, '');
      expect(row.cpu, '');
      expect(row.memory, '');
      expect(row.disk, '');
      expect(row.network, '');
      expect(row.gpu, '');
      expect(row.uacVirtualization, '');
    });
  });

  group('ProcessTableRow.appGroup', () {
    const childA = ProcessTableRow(
        name: 'a',
        pid: '101',
        username: '',
        cpu: '',
        memory: '',
        disk: '',
        network: '',
        gpu: '',
        uacVirtualization: '');
    const childB = ProcessTableRow(
        name: 'b',
        pid: '102',
        username: '',
        cpu: '',
        memory: '',
        disk: '',
        network: '',
        gpu: '',
        uacVirtualization: '');

    test('creates an app group with children', () {
      final row = ProcessTableRow.appGroup(
        name: 'Notepad',
        processCount: 4,
        category: ProcessCategory.apps,
        children: [childA, childB],
        firstChildPid: 123,
      );

      expect(row.name, 'Notepad');
      expect(row.subLabel, '4');
      expect(row.pid, '');
      expect(row.hasExpandArrow, isTrue);
      expect(row.childCount, 2);
      expect(row.firstChildPid, 123);
      expect(row.rowType, ProcessRowType.appGroup);
      expect(row.category, ProcessCategory.apps);
    });

    test('creates an app group with no children', () {
      final row = ProcessTableRow.appGroup(
        name: 'Notepad',
        processCount: 0,
        category: ProcessCategory.apps,
      );

      expect(row.hasExpandArrow, isFalse);
      expect(row.childCount, 0);
    });
  });

  group('ProcessTableRow.expansionKey', () {
    test('appGroup uses category index and name', () {
      final row = ProcessTableRow.appGroup(
        name: 'Notepad',
        processCount: 4,
        category: ProcessCategory.apps,
      );
      expect(row.expansionKey, '0_Notepad');
    });

    test('Service Host appGroup uses firstChildPid', () {
      final row = ProcessTableRow.appGroup(
        name: 'Service Host',
        processCount: 3,
        category: ProcessCategory.apps,
        firstChildPid: 777,
      );
      expect(row.expansionKey, 'svchost_777');
    });

    test('plain process row uses its pid', () {
      const row = ProcessTableRow(
        name: 'notepad.exe',
        pid: '4242',
        username: '',
        cpu: '',
        memory: '',
        disk: '',
        network: '',
        gpu: '',
        uacVirtualization: '',
      );
      expect(row.expansionKey, '4242');
    });

    test('groupHeader row uses its empty pid', () {
      final row = ProcessTableRow.groupHeader(ProcessCategory.background, 5);
      expect(row.expansionKey, '');
    });
  });
}
