import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_room_panel.dart';

void main() {
  Widget buildHarness({
    required List<PbAgentListItemData> agents,
    String? selectedAgentId,
    ValueChanged<PbAgentListItemData>? onAgentSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            height: 640,
            child: PbRoomPanel(
              agents: agents,
              selectedAgentId: selectedAgentId,
              onAgentItemSelected: onAgentSelected,
              threads: const ['Planning', 'Implementation'],
              selectedThreadTitle: null,
              onThreadSelected: (_) {},
              onCreateThread: () {},
            ),
          ),
        ),
      ),
    );
  }

  Finder agentCardById(String id) {
    return find.byWidgetPredicate((widget) => widget is PbAgentCard && widget.data.id == id);
  }

  testWidgets('agent list uses ids so duplicate titles stay independently selectable', (tester) async {
    final agents = const [
      PbAgentListItemData(id: 'assistant-primary', title: 'Assistant', status: 'Available', icon: 'bot'),
      PbAgentListItemData(id: 'assistant-secondary', title: 'Assistant', status: 'Available', icon: 'bot'),
    ];

    await tester.pumpWidget(buildHarness(agents: agents, selectedAgentId: 'assistant-secondary'));
    await tester.pump();

    final cards = tester.widgetList<PbAgentCard>(find.byType(PbAgentCard)).toList();
    final primary = cards.singleWhere((card) => card.data.id == 'assistant-primary');
    final secondary = cards.singleWhere((card) => card.data.id == 'assistant-secondary');

    expect(primary.data.selected, isFalse);
    expect(secondary.data.selected, isTrue);
  });

  testWidgets('expanded agent list scrolls through all switchable agents', (tester) async {
    PbAgentListItemData? selected;
    final agents = [
      const PbAgentListItemData(id: 'assistant-primary', title: 'Assistant', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'research', title: 'Research', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'builder', title: 'Builder', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'assistant-secondary', title: 'Assistant', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'coordinator', title: 'Coordinator', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'operator', title: 'Operator', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'reviewer', title: 'Reviewer', status: 'Available', icon: 'bot'),
    ];

    await tester.pumpWidget(
      buildHarness(agents: agents, selectedAgentId: 'assistant-primary', onAgentSelected: (agent) => selected = agent),
    );
    await tester.pump();

    expect(agentCardById('assistant-primary'), findsOneWidget);
    expect(agentCardById('reviewer'), findsNothing);

    await tester.dragUntilVisible(agentCardById('reviewer'), find.byType(Scrollable).first, const Offset(0, -80));
    await tester.tap(agentCardById('reviewer'));
    await tester.pump();

    expect(selected?.id, 'reviewer');
  });

  testWidgets('expanded agent list responds to pointer-wheel scrolling over cards', (tester) async {
    final agents = [
      const PbAgentListItemData(id: 'assistant-primary', title: 'Assistant', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'research', title: 'Research', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'builder', title: 'Builder', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'assistant-secondary', title: 'Assistant', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'coordinator', title: 'Coordinator', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'operator', title: 'Operator', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'reviewer', title: 'Reviewer', status: 'Available', icon: 'bot'),
    ];

    await tester.pumpWidget(buildHarness(agents: agents, selectedAgentId: 'assistant-primary'));
    await tester.pump();

    expect(agentCardById('reviewer'), findsNothing);

    await tester.sendEventToBinding(const PointerScrollEvent(position: Offset(180, 360), scrollDelta: Offset(0, 360)));
    await tester.pumpAndSettle();

    expect(agentCardById('reviewer'), findsOneWidget);
  });

  testWidgets('expanded agent list reveals selected agent when mounted below the viewport', (tester) async {
    final agents = [
      const PbAgentListItemData(id: 'assistant-primary', title: 'Assistant', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'research', title: 'Research', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'builder', title: 'Builder', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'assistant-secondary', title: 'Assistant', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'coordinator', title: 'Coordinator', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'operator', title: 'Operator', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'reviewer', title: 'Reviewer', status: 'Available', icon: 'bot'),
    ];

    await tester.pumpWidget(buildHarness(agents: agents, selectedAgentId: 'reviewer'));
    await tester.pumpAndSettle();

    expect(agentCardById('reviewer'), findsOneWidget);
    final reviewer = tester.widget<PbAgentCard>(agentCardById('reviewer'));
    expect(reviewer.data.selected, isTrue);
  });

  testWidgets('four expanded agents use the scroll viewport instead of a static column', (tester) async {
    final agents = [
      const PbAgentListItemData(id: 'assistant-primary', title: 'Assistant', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'research', title: 'Research', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'builder', title: 'Builder', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'coordinator', title: 'Coordinator', status: 'Available', icon: 'bot'),
    ];

    await tester.pumpWidget(buildHarness(agents: agents, selectedAgentId: 'assistant-primary'));
    await tester.pump();

    expect(find.byType(Scrollable), findsNWidgets(2));
    expect(agentCardById('coordinator'), findsNothing);

    await tester.sendEventToBinding(const PointerScrollEvent(position: Offset(180, 360), scrollDelta: Offset(0, 160)));
    await tester.pumpAndSettle();

    expect(agentCardById('coordinator'), findsOneWidget);
  });
}
