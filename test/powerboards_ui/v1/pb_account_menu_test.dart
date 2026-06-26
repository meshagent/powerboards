import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_account_menu.dart';

void main() {
  testWidgets('account menu shows Switch profile action when supplied', (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PbAccountMenu(
            onSwitchProfilePressed: () {
              pressed = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Switch profile'), findsOneWidget);

    await tester.tap(find.text('Switch profile'));
    expect(pressed, isTrue);
  });

  testWidgets('account menu hides Switch profile action by default', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PbAccountMenu())));

    expect(find.text('Switch profile'), findsNothing);
  });
}
