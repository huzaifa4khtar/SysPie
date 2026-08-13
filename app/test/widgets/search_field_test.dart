import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syspie/features/shell/widgets/search_bar.dart';

void main() {
  Future<void> pumpField(WidgetTester tester, SearchField field) async {
    tester.view.physicalSize = const Size(1600, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: field)));
  }

  testWidgets('renders hint text and a TextField', (tester) async {
    await pumpField(
      tester,
      const SearchField(hint: 'Search processes...', availableWidth: 300),
    );

    expect(find.text('Search processes...'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('typing fires onChanged with the entered text', (tester) async {
    String? result;
    await pumpField(
      tester,
      SearchField(availableWidth: 300, onChanged: (v) => result = v),
    );

    await tester.enterText(find.byType(TextField), 'chrome');
    await tester.pump();

    expect(result, 'chrome');
  });

  testWidgets('availableWidth below 180 renders SizedBox.shrink',
      (tester) async {
    await pumpField(
      tester,
      const SearchField(hint: 'Search processes...', availableWidth: 100),
    );

    expect(find.byType(TextField), findsNothing);
  });
}
