import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/ui/resizable_split_view.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Widget _buildTestApp({
  required double width,
  required bool split,
  required bool allowCollapse,
  required ResizableSplitViewController controller,
  ValueChanged<bool>? onCollapsedChanged,
  double minArea1Width = 58,
  double minArea2Width = 440,
  double? preferredArea2Fraction = 0.75,
  double? minArea2Fraction = 0.5,
  double? collapseArea1Width = 300,
  Widget area1 = const ColoredBox(color: Colors.red),
  Widget area2 = const ColoredBox(color: Colors.blue),
}) {
  return ShadApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          height: 320,
          child: ResizableSplitView(
            key: const ValueKey('split-view'),
            split: split,
            allowCollapse: allowCollapse,
            controller: controller,
            minArea1Width: minArea1Width,
            minArea2Width: minArea2Width,
            preferredArea2Fraction: preferredArea2Fraction,
            minArea2Fraction: minArea2Fraction,
            collapseArea1Width: collapseArea1Width,
            onCollapsedChanged: onCollapsedChanged,
            area1: area1,
            area2: area2,
          ),
        ),
      ),
    ),
  );
}

class _StatefulTextArea extends StatefulWidget {
  const _StatefulTextArea();

  @override
  State<_StatefulTextArea> createState() => _StatefulTextAreaState();
}

class _StatefulTextAreaState extends State<_StatefulTextArea> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          child: TextField(key: const ValueKey('area1-input'), controller: _controller),
        ),
      ),
    );
  }
}

void main() {
  group('ResizableSplitView', () {
    testWidgets('preserves area1 state across split and collapse changes', (tester) async {
      final controller = ResizableSplitViewController();

      await tester.pumpWidget(
        _buildTestApp(width: 960, split: true, allowCollapse: true, controller: controller, area1: const _StatefulTextArea()),
      );

      await tester.enterText(find.byKey(const ValueKey('area1-input')), 'draft comment');
      expect(find.text('draft comment'), findsOneWidget);

      await tester.pumpWidget(
        _buildTestApp(width: 960, split: false, allowCollapse: true, controller: controller, area1: const _StatefulTextArea()),
      );
      await tester.pump();
      expect(find.text('draft comment'), findsOneWidget);

      await tester.pumpWidget(
        _buildTestApp(width: 960, split: true, allowCollapse: true, controller: controller, area1: const _StatefulTextArea()),
      );
      await tester.pump();
      expect(find.text('draft comment'), findsOneWidget);

      controller.collapse();
      await tester.pump();
      await tester.pump();

      controller.expand();
      await tester.pump();
      await tester.pump();
      expect(find.text('draft comment'), findsOneWidget);
    });

    testWidgets('reports an automatic uncollapse when collapse becomes unavailable', (tester) async {
      final controller = ResizableSplitViewController();
      final collapsedStates = <bool>[];

      await tester.pumpWidget(
        _buildTestApp(width: 900, split: true, allowCollapse: true, controller: controller, onCollapsedChanged: collapsedStates.add),
      );

      controller.collapse();
      await tester.pump();

      expect(controller.collapsed, isTrue);
      expect(collapsedStates, [true]);

      await tester.pumpWidget(
        _buildTestApp(
          width: 520,
          split: true,
          allowCollapse: false,
          controller: controller,
          onCollapsedChanged: collapsedStates.add,
          minArea1Width: 360,
          preferredArea2Fraction: null,
          minArea2Fraction: null,
          collapseArea1Width: null,
        ),
      );
      await tester.pump();

      expect(controller.collapsed, isFalse);
      expect(collapsedStates, [true, false]);
    });

    testWidgets('keeps panel defaults in range across resize and meeting-end transitions', (tester) async {
      final controller = ResizableSplitViewController();

      await tester.pumpWidget(_buildTestApp(width: 960, split: true, allowCollapse: true, controller: controller));
      await tester.pump(const Duration(milliseconds: 40));

      controller.collapse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(controller.collapsed, isTrue);

      await tester.pumpWidget(_buildTestApp(width: 620, split: true, allowCollapse: true, controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      await tester.pumpWidget(
        _buildTestApp(
          width: 380,
          split: true,
          allowCollapse: false,
          controller: controller,
          minArea1Width: 360,
          preferredArea2Fraction: null,
          minArea2Fraction: null,
          collapseArea1Width: null,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      await tester.pumpWidget(
        _buildTestApp(
          width: 1400,
          split: true,
          allowCollapse: false,
          controller: controller,
          minArea1Width: 360,
          preferredArea2Fraction: null,
          minArea2Fraction: null,
          collapseArea1Width: null,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      expect(controller.collapsed, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not throw when resized while a divider drag is in progress', (tester) async {
      final controller = ResizableSplitViewController();

      await tester.pumpWidget(_buildTestApp(width: 960, split: true, allowCollapse: true, controller: controller));
      await tester.pump(const Duration(milliseconds: 40));

      final splitRect = tester.getRect(find.byKey(const ValueKey('split-view')));
      final dragStart = splitRect.topLeft + Offset(240, splitRect.height / 2);

      final gesture = await tester.startGesture(dragStart);
      await tester.pump();
      await gesture.moveBy(const Offset(-32, 0));
      await tester.pump();

      await tester.pumpWidget(_buildTestApp(width: 620, split: true, allowCollapse: true, controller: controller));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      await gesture.moveBy(const Offset(24, 0));
      await tester.pump();

      await tester.pumpWidget(
        _buildTestApp(
          width: 380,
          split: true,
          allowCollapse: false,
          controller: controller,
          minArea1Width: 360,
          preferredArea2Fraction: null,
          minArea2Fraction: null,
          collapseArea1Width: null,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      await gesture.moveBy(const Offset(24, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('stops dragging when collapse happens during an active drag', (tester) async {
      final controller = ResizableSplitViewController();

      await tester.pumpWidget(_buildTestApp(width: 960, split: true, allowCollapse: true, controller: controller));
      await tester.pump(const Duration(milliseconds: 40));

      final dragStart = tester.getCenter(find.byIcon(LucideIcons.gripVertical));

      final gesture = await tester.startGesture(dragStart);
      await tester.pump();

      await gesture.moveBy(const Offset(-32, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      controller.collapse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      expect(controller.collapsed, isTrue);

      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      expect(controller.collapsed, isTrue);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('can resize after switching into meeting split config', (tester) async {
      final controller = ResizableSplitViewController();

      await tester.pumpWidget(
        _buildTestApp(
          width: 960,
          split: true,
          allowCollapse: false,
          controller: controller,
          minArea1Width: 360,
          preferredArea2Fraction: null,
          minArea2Fraction: null,
          collapseArea1Width: null,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      await tester.pumpWidget(
        _buildTestApp(
          width: 1400,
          split: true,
          allowCollapse: true,
          controller: controller,
          minArea1Width: 58,
          preferredArea2Fraction: 0.75,
          minArea2Fraction: 0.5,
          collapseArea1Width: 300,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      expect(controller.collapsed, isFalse);
      final dragStart = tester.getCenter(find.byIcon(LucideIcons.gripVertical));
      final gesture = await tester.startGesture(dragStart);
      await tester.pump();

      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      expect(controller.collapsed, isFalse);
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
