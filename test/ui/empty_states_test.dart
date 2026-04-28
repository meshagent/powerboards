import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/ui/empty_states.dart';
import 'package:powerboards/ui/powerboards_breakpoints.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('mobile low-balance state keeps the admin recovery action', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    var pressed = false;

    await tester.pumpWidget(
      ShadApp(
        home: powerboardsResponsiveBreakpoints(
          child: Scaffold(
            body: BalanceLowWarning(
              role: ProjectRole.admin,
              onAddCredits: () {
                pressed = true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Low balance'), findsOneWidget);
    expect(find.widgetWithText(ShadButton, 'Add Credits'), findsOneWidget);

    await tester.tap(find.text('Add Credits'));
    await tester.pumpAndSettle();

    expect(pressed, isTrue);
  });
}
