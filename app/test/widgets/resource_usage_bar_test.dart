import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syspie/features/shell/widgets/resource_usage_bar.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, ResourceUsageBar bar) async {
    tester.view.physicalSize = const Size(1600, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: bar)));
  }

  testWidgets('shows CPU, GPU, RAM labels and 0% for defaults', (tester) async {
    await pumpBar(tester, const ResourceUsageBar());

    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('GPU'), findsOneWidget);
    expect(find.text('RAM'), findsOneWidget);
    expect(find.text('0%'), findsNWidgets(3));
  });

  testWidgets('shows rounded percentage values', (tester) async {
    await pumpBar(
      tester,
      const ResourceUsageBar(cpuPercent: 12.6, ramPercent: 99.4),
    );

    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('GPU'), findsOneWidget);
    expect(find.text('RAM'), findsOneWidget);
    expect(find.text('13%'), findsOneWidget);
    expect(find.text('99%'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });
}
