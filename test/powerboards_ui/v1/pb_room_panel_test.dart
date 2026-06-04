import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_agents/meshagent_agents.dart' as agent_sessions;
import 'package:powerboards/chat/meshagent_room.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_room_panel.dart';

class _NoopProtocolChannel extends ProtocolChannel {
  @override
  void dispose() {}

  @override
  Future<void> sendData(Uint8List data) async {}

  @override
  void start(void Function(Uint8List data) onDataReceived, {void Function()? onDone, void Function(Object? error)? onError}) {}
}

class _FakeChatClient extends agent_sessions.BaseChatClient {
  @override
  Future<void> sendAgentMessage(agent_sessions.AgentMessage message, {Uint8List? attachment}) async {}
}

class _FakeThreadStorageRepository extends agent_sessions.ThreadStorageRepository {
  _FakeThreadStorageRepository(this._entries);

  List<agent_sessions.ThreadListEntry> _entries;

  void replaceEntries(List<agent_sessions.ThreadListEntry> entries) {
    _entries = entries;
    notifyListeners();
  }

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  List<agent_sessions.ThreadListEntry> entries() => List<agent_sessions.ThreadListEntry>.of(_entries);

  @override
  Future<void> addOrUpdateThread(agent_sessions.ThreadListEntry entry) async {}

  @override
  Future<void> deleteThread(String threadPath) async {}

  @override
  Future<void> renameThread(String threadPath, String name) async {}
}

void main() {
  Widget buildHarness({
    required List<PbAgentListItemData> agents,
    String? selectedAgentId,
    ValueChanged<PbAgentListItemData>? onAgentSelected,
    bool showThreadsSection = true,
    bool showFilesTab = true,
    bool? agentsExpanded,
    ValueChanged<bool>? onAgentsExpandedChanged,
    PbRoomPanelTab? selectedTab,
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
              selectedTab: selectedTab,
              selectedAgentId: selectedAgentId,
              onAgentItemSelected: onAgentSelected,
              agentsExpanded: agentsExpanded,
              onAgentsExpandedChanged: onAgentsExpandedChanged,
              showThreadsSection: showThreadsSection,
              showFilesTab: showFilesTab,
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

  testWidgets('desktop preview threads panel updates when watched storage changes', (tester) async {
    final room = RoomClient(protocolFactory: () => Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);

    final storage = _FakeThreadStorageRepository([
      const agent_sessions.ThreadListEntry(
        path: 'dataset://agents/assistant/threads/greeting',
        name: 'Greeting Chat2',
        createdAt: '2026-05-28T23:00:00.000Z',
        modifiedAt: '2026-05-28T23:00:00.000Z',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              height: 720,
              child: PowerboardsDesktopPreviewThreadListHarness(
                client: room,
                threadListPath: 'dataset://agents/assistant/threads',
                chatClientFactory: (_, _) => _FakeChatClient(),
                threadStorageFactory: (_) => storage,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('Browse threads by selected agent.'), findsOneWidget);
    expect(find.text('Threads'), findsOneWidget);
    expect(find.text('Greeting Chat2'), findsOneWidget);
    expect(find.text('Realtime Thread'), findsNothing);

    storage.replaceEntries([
      const agent_sessions.ThreadListEntry(
        path: 'dataset://agents/assistant/threads/realtime',
        name: 'Realtime Thread',
        createdAt: '2026-05-28T23:10:00.000Z',
        modifiedAt: '2026-05-28T23:10:00.000Z',
      ),
      const agent_sessions.ThreadListEntry(
        path: 'dataset://agents/assistant/threads/greeting',
        name: 'Greeting Chat2',
        createdAt: '2026-05-28T23:00:00.000Z',
        modifiedAt: '2026-05-28T23:00:00.000Z',
      ),
    ]);
    await tester.pump();

    expect(find.text('Realtime Thread'), findsOneWidget);
    expect(find.text('Greeting Chat2'), findsOneWidget);
  });

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

  testWidgets('agent cards capitalize display names while preserving raw selection data', (tester) async {
    PbAgentListItemData? selected;
    final agents = [const PbAgentListItemData(id: 'multi-word', title: 'multi word agent', status: 'Available', icon: 'bot')];

    await tester.pumpWidget(buildHarness(agents: agents, selectedAgentId: 'multi-word', onAgentSelected: (agent) => selected = agent));
    await tester.pump();

    expect(find.text('Multi Word Agent'), findsOneWidget);
    expect(find.text('multi word agent'), findsNothing);

    await tester.tap(agentCardById('multi-word'));
    await tester.pump();

    expect(selected?.title, 'multi word agent');
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

  testWidgets('controlled agent expansion persists when panel is remounted', (tester) async {
    var panelVisible = true;
    var agentsExpanded = true;
    final agents = [
      const PbAgentListItemData(id: 'assistant-primary', title: 'Assistant', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'research', title: 'Research', status: 'Available', icon: 'bot'),
      const PbAgentListItemData(id: 'builder', title: 'Builder', status: 'Available', icon: 'bot'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setHarnessState) {
            return Scaffold(
              body: Column(
                children: [
                  TextButton(onPressed: () => setHarnessState(() => panelVisible = !panelVisible), child: const Text('Toggle panel')),
                  SizedBox(
                    width: 320,
                    height: 520,
                    child: panelVisible
                        ? PbRoomPanel(
                            agents: agents,
                            selectedAgentId: 'assistant-primary',
                            agentsExpanded: agentsExpanded,
                            onAgentsExpandedChanged: (expanded) => setHarnessState(() => agentsExpanded = expanded),
                            threads: const ['Planning', 'Implementation'],
                            selectedThreadTitle: null,
                            onThreadSelected: (_) {},
                            onCreateThread: () {},
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Show less'), findsOneWidget);
    expect(agentCardById('research'), findsOneWidget);

    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();

    expect(find.text('Show more'), findsOneWidget);
    expect(agentCardById('research'), findsNothing);

    await tester.tap(find.text('Toggle panel'));
    await tester.pump();
    await tester.tap(find.text('Toggle panel'));
    await tester.pump();

    expect(find.text('Show more'), findsOneWidget);
    expect(agentCardById('research'), findsNothing);
  });

  testWidgets('agent panel can hide thread section and divider for agents without threads', (tester) async {
    final agents = [
      const PbAgentListItemData(id: 'voice', title: 'Voice', status: 'Available', icon: 'video'),
      const PbAgentListItemData(id: 'assistant-primary', title: 'Assistant', status: 'Available', icon: 'bot'),
    ];

    await tester.pumpWidget(buildHarness(agents: agents, selectedAgentId: 'voice', showThreadsSection: false));
    await tester.pump();

    expect(find.text('Threads'), findsNothing);
    expect(find.text('New Thread...'), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('files tab can be hidden for scoped chat release', (tester) async {
    final agents = [const PbAgentListItemData(id: 'assistant-primary', title: 'Assistant', status: 'Available', icon: 'bot')];

    await tester.pumpWidget(buildHarness(agents: agents, showFilesTab: false));
    await tester.pump();

    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('Files'), findsNothing);
  });

  testWidgets('hidden files tab keeps controlled files selection on agents panel', (tester) async {
    final agents = [const PbAgentListItemData(id: 'assistant-primary', title: 'Assistant', status: 'Available', icon: 'bot')];

    await tester.pumpWidget(buildHarness(agents: agents, showFilesTab: false, selectedTab: PbRoomPanelTab.files));
    await tester.pump();

    expect(find.text('Files'), findsNothing);
    expect(find.text('Browse threads by selected agent.'), findsOneWidget);
    expect(find.text('Browse attachments by selected agent.'), findsNothing);
  });

  testWidgets('empty agent install state stays inside agents tab', (tester) async {
    var manageAgentsPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 640,
            child: PbRoomPanel(
              agents: const [],
              onManageAgents: () => manageAgentsPressed = true,
              threads: const [],
              selectedThreadTitle: null,
              onThreadSelected: (_) {},
              onCreateThread: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Install an agent in this room to get started.'), findsOneWidget);

    await tester.tap(find.text('Install an Agent'));

    expect(manageAgentsPressed, isTrue);
  });
}
