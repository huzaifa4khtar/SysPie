import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syspie/features/charts/screens/charts_screen.dart';
import 'package:syspie/features/processes/process_controller.dart';

import '../helpers/fake_syspie_client.dart';

void main() {
  testWidgets('charts screen renders its tab bar labels', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fake = FakeSysPieClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sysPieClientProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: ChartsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('CPU'), findsWidgets);
    expect(find.text('GPU'), findsWidgets);
    expect(find.text('MEMORY'), findsWidgets);
    expect(find.text('DISK'), findsWidgets);
    expect(find.text('NETWORK'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });
}
