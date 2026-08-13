import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syspie/features/shell/widgets/side_menu.dart';

import '../helpers/scaled_material_app.dart';

void main() {
  Future<void> pumpMenu(
      WidgetTester tester, ValueChanged<NavItem> onSelect) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      scaledMaterialApp(
        Scaffold(
          body: SideMenu(
              selectedItem: NavItem.processes, onItemSelected: onSelect),
        ),
      ),
    );
  }

  testWidgets('renders all five navigation labels', (tester) async {
    await pumpMenu(tester, (_) {});

    expect(find.text('Processes'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Services'), findsOneWidget);
    expect(find.text('Charts'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
  });

  testWidgets('tapping Services calls onItemSelected with NavItem.services',
      (tester) async {
    NavItem? captured;
    await pumpMenu(tester, (item) => captured = item);

    await tester.tap(find.text('Services'));
    await tester.pump();

    expect(captured, NavItem.services);
  });
}
