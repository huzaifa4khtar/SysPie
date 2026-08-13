import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syspie/core/widgets/feedback.dart';
import 'package:syspie/features/processes/process_controller.dart';
import 'package:syspie/features/users/screens/users_screen.dart';

import '../helpers/fake_syspie_client.dart';

void main() {
  testWidgets('users screen renders its table header and a user group row',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fake = FakeSysPieClient();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sysPieClientProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: UsersScreen()),
      ),
    );
    await tester.pump();

    fake.emit({
      'type': 'users',
      'data': ['User1']
    });
    await tester.pump();

    fake.emit({
      'type': 'processes',
      'data': [
        {
          'pid': 1,
          'parentPid': 0,
          'name': 'notepad.exe',
          'friendlyName': 'Notepad',
          'userName': 'User1',
          'hasVisibleWindow': true,
        },
      ],
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('User1 (1)'), findsOneWidget);
    expect(find.byType(AppErrorState), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
