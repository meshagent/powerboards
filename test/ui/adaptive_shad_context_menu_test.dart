import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent_flutter_shadcn/ui/coordinated_context_menu.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Widget _buildMenuHarness({required ShadContextMenuController firstController, required ShadContextMenuController secondController}) {
  return ShadApp(
    home: Scaffold(
      body: Row(
        children: [
          AdaptiveShadContextMenu(
            controller: firstController,
            items: const [ShadContextMenuItem(height: 40, child: Text('First menu'))],
            child: const SizedBox(width: 80, height: 40, child: Text('First trigger')),
          ),
          AdaptiveShadContextMenu(
            controller: secondController,
            items: const [ShadContextMenuItem(height: 40, child: Text('Second menu'))],
            child: const SizedBox(width: 80, height: 40, child: Text('Second trigger')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('opening one adaptive menu closes another open sibling menu', (tester) async {
    final firstController = ShadContextMenuController();
    final secondController = ShadContextMenuController();

    await tester.pumpWidget(_buildMenuHarness(firstController: firstController, secondController: secondController));

    firstController.show();
    await tester.pump();
    expect(firstController.isOpen, isTrue);
    expect(secondController.isOpen, isFalse);

    secondController.show();
    await tester.pump();

    expect(firstController.isOpen, isFalse);
    expect(secondController.isOpen, isTrue);
  });

  testWidgets('opening an adaptive menu closes an open coordinated menu from meshagent_flutter_shadcn', (tester) async {
    final coordinatedController = ShadContextMenuController();
    final adaptiveController = ShadContextMenuController();
    addTearDown(coordinatedController.dispose);
    addTearDown(adaptiveController.dispose);

    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(
          body: Row(
            children: [
              CoordinatedShadContextMenu(
                controller: coordinatedController,
                items: const [ShadContextMenuItem(height: 40, child: Text('Coordinated menu'))],
                child: const SizedBox(width: 80, height: 40, child: Text('Coordinated trigger')),
              ),
              AdaptiveShadContextMenu(
                controller: adaptiveController,
                items: const [ShadContextMenuItem(height: 40, child: Text('Adaptive menu'))],
                child: const SizedBox(width: 80, height: 40, child: Text('Adaptive trigger')),
              ),
            ],
          ),
        ),
      ),
    );

    coordinatedController.show();
    await tester.pump();
    expect(coordinatedController.isOpen, isTrue);
    expect(adaptiveController.isOpen, isFalse);

    adaptiveController.show();
    await tester.pump();

    expect(coordinatedController.isOpen, isFalse);
    expect(adaptiveController.isOpen, isTrue);
  });
}
