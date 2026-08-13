import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syspie/core/widgets/data_table.dart';
import 'package:syspie/shared/models/process_table.dart';

import '../helpers/scaled_material_app.dart';

const List<ProcessTableColumn> _columns = [
  ProcessTableColumn(label: 'Name', width: 500),
  ProcessTableColumn(label: 'PID', width: 60),
  ProcessTableColumn(label: 'CPU', width: 60),
  ProcessTableColumn(label: 'Status', width: 100),
];

ProcessTableRow _processRow(
  String name,
  String pid, {
  String? statusLabel,
  int? statusType,
}) {
  return ProcessTableRow(
    name: name,
    pid: pid,
    username: 'me',
    cpu: '5.0%',
    memory: '12.5 MB',
    disk: '0 MB/s',
    network: '0 Kbps',
    gpu: '0%',
    uacVirtualization: 'Disabled',
    statusLabel: statusLabel,
    statusType: statusType,
  );
}

ProcessTableRow _appGroup() {
  return ProcessTableRow.appGroup(
    name: 'Notepad',
    processCount: 4,
    category: ProcessCategory.apps,
    children: [_processRow('n1.exe', '1'), _processRow('n2.exe', '2')],
    firstChildPid: 123,
    childPids: [1, 2, 3, 4],
  );
}

Future<void> _pumpTable(
  WidgetTester tester, {
  required List<ProcessTableRow> rows,
  ValueChanged<int>? onRowSelected,
  ValueChanged<int>? onRowExpanded,
  Set<String> expandedParentPids = const {},
  int? selectedIndex,
}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    scaledMaterialApp(
      Scaffold(
        body: SizedBox(
          width: 1200,
          height: 800,
          child: ProcessDataTable(
            columns: _columns,
            rows: rows,
            selectedIndex: selectedIndex,
            expandedParentPids: expandedParentPids,
            hScrollController: ScrollController(),
            vScrollController: ScrollController(),
            onRowSelected: onRowSelected,
            onRowExpanded: onRowExpanded,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders header labels and row names/pid', (tester) async {
    await _pumpTable(tester, rows: [
      ProcessTableRow.groupHeader(ProcessCategory.apps, 12),
      _appGroup(),
      _processRow('app.exe', '4242', statusLabel: 'RUNNING', statusType: 0),
    ]);

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('PID'), findsOneWidget);
    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);

    expect(find.text('Apps (12)'), findsOneWidget);
    expect(find.text('Notepad'), findsOneWidget);
    expect(find.text('app.exe'), findsOneWidget);
    expect(find.text('4242'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a process row with a statusLabel renders a StatusBadge',
      (tester) async {
    await _pumpTable(tester, rows: [
      _processRow('app.exe', '4242', statusLabel: 'RUNNING', statusType: 0),
    ]);

    expect(find.text('RUNNING'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping an appGroup row fires onRowExpanded with its index',
      (tester) async {
    final indexes = <int>[];
    await _pumpTable(
      tester,
      rows: [_appGroup(), _processRow('app.exe', '4242')],
      onRowExpanded: (i) => indexes.add(i),
    );

    await tester.tap(find.text('Notepad'));
    await tester.pump();

    expect(indexes, [0]);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping a process row fires onRowSelected with its index',
      (tester) async {
    final indexes = <int>[];
    await _pumpTable(
      tester,
      rows: [_appGroup(), _processRow('app.exe', '4242')],
      onRowSelected: (i) => indexes.add(i),
    );

    await tester.tap(find.text('app.exe'));
    await tester.pump();

    expect(indexes, [1]);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('expandedParentPids shows keyboard_arrow_down on the app group',
      (tester) async {
    await _pumpTable(
      tester,
      rows: [_appGroup()],
      expandedParentPids: {'0_Notepad'},
    );

    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_right), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('collapsed app group shows keyboard_arrow_right', (tester) async {
    await _pumpTable(tester, rows: [_appGroup()]);

    expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'selectedIndex highlights without crashing and rows stay tappable',
      (tester) async {
    final indexes = <int>[];
    await _pumpTable(
      tester,
      rows: [_appGroup(), _processRow('app.exe', '4242')],
      selectedIndex: 1,
      onRowSelected: (i) => indexes.add(i),
    );

    expect(find.text('app.exe'), findsOneWidget);

    await tester.tap(find.text('app.exe'));
    await tester.pump();

    expect(indexes, [1]);

    await tester.pumpWidget(const SizedBox());
  });
}
