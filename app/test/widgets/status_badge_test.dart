import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:syspie/core/widgets/status_badge.dart';

void main() {
  testWidgets('renders the label text for a green badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBadge(label: 'RUNNING', state: StatusBadgeState.green),
        ),
      ),
    );

    expect(find.text('RUNNING'), findsOneWidget);
  });

  testWidgets('all three states render when pumped together', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              StatusBadge(label: 'GREEN', state: StatusBadgeState.green),
              StatusBadge(label: 'YELLOW', state: StatusBadgeState.yellow),
              StatusBadge(label: 'RED', state: StatusBadgeState.red),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(StatusBadge), findsNWidgets(3));
    expect(find.text('GREEN'), findsOneWidget);
    expect(find.text('YELLOW'), findsOneWidget);
    expect(find.text('RED'), findsOneWidget);
  });
}
