import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syspie/core/widgets/feedback.dart';
import 'package:syspie/features/details/screens/details_screen.dart';
import 'package:syspie/features/processes/process_controller.dart';

import '../helpers/fake_syspie_client.dart';
import '../helpers/scaled_material_app.dart';

void main() {
  testWidgets('details screen renders its table header and a process row',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fake = FakeSysPieClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sysPieClientProvider.overrideWithValue(fake)],
        child: scaledMaterialApp(const DetailsScreen()),
      ),
    );
    await tester.pump();

    fake.emit({
      'type': 'processes',
      'data': [
        {
          'pid': 1,
          'parentPid': 0,
          'name': 'notepad.exe',
          'friendlyName': 'Notepad',
          'status': 'RUNNING',
          'statusType': 0,
        },
      ],
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('notepad.exe'), findsOneWidget);
    expect(find.byType(AppErrorState), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
