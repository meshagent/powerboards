import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<void> _pumpDialog(WidgetTester tester, Widget dialog) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ShadApp(
      home: Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: dialog),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Finder _flowDialogSurface() {
  return find.byWidgetPredicate((widget) {
    if (widget is! DecoratedBox) {
      return false;
    }

    final decoration = widget.decoration;
    return decoration is BoxDecoration && decoration.borderRadius == const BorderRadius.vertical(top: Radius.circular(28));
  });
}

double _distanceFromCenter(double value, double center) => (value - center).abs();

void main() {
  testWidgets('mobile flow dialog can be dismissed with a downward swipe', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ShadApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ShadButton(
                onPressed: () {
                  showPowerboardsFlowDialog<void>(
                    context: context,
                    builder: (_) => PowerboardsShadDialog.task(
                      title: const Text('Swipe me'),
                      description: const Text('Drag down to dismiss.'),
                      actions: [ShadButton(onPressed: () {}, child: const Text('Done'))],
                      child: const SizedBox(height: 40, child: Text('Body')),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Swipe me'), findsOneWidget);

    await tester.fling(_flowDialogSurface(), const Offset(0, 520), 1800);
    await tester.pumpAndSettle();

    expect(find.text('Swipe me'), findsNothing);
  });

  testWidgets('mobile flow dialog uses a compact floor and actions stay anchored near the bottom', (tester) async {
    const dialogKey = ValueKey('flow-dialog');

    await _pumpDialog(
      tester,
      PowerboardsShadDialog.task(
        key: dialogKey,
        title: const Text('Permissions'),
        description: const Text('Adjust room access.'),
        actions: [
          ShadButton.outline(onPressed: () {}, child: const Text('Cancel')),
          ShadButton(onPressed: () {}, child: const Text('Save')),
        ],
        child: const SizedBox(height: 40, child: Text('Short body')),
      ),
    );

    final dialogFinder = _flowDialogSurface();
    final dialogSize = tester.getSize(dialogFinder);
    final dialogBottom = tester.getBottomLeft(dialogFinder).dy;
    final saveBottom = tester.getBottomLeft(find.widgetWithText(ShadButton, 'Save')).dy;

    expect(dialogSize.height, greaterThan(320));
    expect(dialogSize.height, lessThan(420));
    expect(dialogBottom - saveBottom, lessThan(110));
  });

  testWidgets('mobile flow dialog centers sparse content inside the compact shell', (tester) async {
    await _pumpDialog(
      tester,
      PowerboardsShadDialog.listPicker(
        title: const Text('Agents & Services'),
        description: const Text('No agents installed yet.'),
        actions: [ShadButton(onPressed: () {}, child: const Text('Install'))],
        child: const SizedBox(height: 48, child: Center(child: Text('Empty state'))),
      ),
    );

    final dialogFinder = _flowDialogSurface();
    final dialogRect = tester.getRect(dialogFinder);
    final emptyStateRect = tester.getRect(find.text('Empty state'));
    final contentAreaCenterY = (dialogRect.top + dialogRect.bottom) / 2;
    final emptyStateCenterY = emptyStateRect.center.dy;
    final scrollView = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));

    expect(dialogRect.height, greaterThan(280));
    expect(dialogRect.height, lessThan(390));
    expect(_distanceFromCenter(emptyStateCenterY, contentAreaCenterY), lessThan(80));
    expect(scrollView.physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('mobile compact alert dialog shows the primary action first', (tester) async {
    await _pumpDialog(
      tester,
      PowerboardsShadDialog.compactAlert(
        title: const Text('Secret requested'),
        description: const Text('Provide a secret value.'),
        actions: [
          ShadButton.secondary(onPressed: () {}, child: const Text('Cancel')),
          ShadButton(onPressed: () {}, child: const Text('Provide')),
        ],
        child: const SizedBox(height: 40, child: Text('Body')),
      ),
    );

    final provideRect = tester.getRect(find.widgetWithText(ShadButton, 'Provide'));
    final cancelRect = tester.getRect(find.widgetWithText(ShadButton, 'Cancel'));
    final isPrimaryFirst = provideRect.top < cancelRect.top || (provideRect.top == cancelRect.top && provideRect.left < cancelRect.left);

    expect(isPrimaryFirst, isTrue);
  });

  testWidgets('mobile flow dialog caps growth and scrolls inside the body for long content', (tester) async {
    const dialogKey = ValueKey('scrolling-flow-dialog');

    await _pumpDialog(
      tester,
      PowerboardsShadDialog.task(
        key: dialogKey,
        title: const Text('Long content'),
        description: const Text('A longer flow dialog body should scroll.'),
        actions: [ShadButton(onPressed: () {}, child: const Text('Done'))],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(40, (index) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Item $index'))),
        ),
      ),
    );

    final dialogFinder = _flowDialogSurface();
    final dialogHeight = tester.getSize(dialogFinder).height;
    final dialogBottom = tester.getBottomLeft(dialogFinder).dy;
    final item39Finder = find.text('Item 39');
    final item39TopBeforeScroll = tester.getTopLeft(item39Finder).dy;

    expect(dialogHeight, greaterThan(700));
    expect(dialogHeight, lessThanOrEqualTo(799));
    expect(item39TopBeforeScroll, greaterThan(dialogBottom));

    await tester.drag(find.text('Item 0'), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(item39Finder).dy, lessThan(dialogBottom));
  });
}
