import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syspie/core/widgets/feedback.dart';
import 'package:syspie/features/processes/process_controller.dart';
import 'package:syspie/features/services/screens/services_screen.dart';

import '../helpers/fake_syspie_client.dart';
import '../helpers/scaled_material_app.dart';

void main() {
  testWidgets('services screen renders its table header and a service row',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fake = FakeSysPieClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sysPieClientProvider.overrideWithValue(fake)],
        child: scaledMaterialApp(const ServicesScreen()),
      ),
    );
    await tester.pump();

    fake.emit({
      'type': 'services',
      'data': [
        {
          'serviceName': 'TestSvc',
          'displayName': 'Test Service',
          'pid': 123,
          'status': 'Running',
          'group': '',
          'type': 'Own process',
        },
      ],
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('TestSvc'), findsOneWidget);
    expect(find.byType(AppErrorState), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
