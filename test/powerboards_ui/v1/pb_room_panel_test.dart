import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_agents/meshagent_agents.dart' as agent_sessions;
import 'package:powerboards/chat/meshagent_room.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_file_preview_state_card.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_room_panel.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_room_panel_mount.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_sidepane_item_menu.dart' as sidepane_menu;
import 'package:powerboards/powerboards_ui/v1/components/meet/pb_meet_transcript_panel.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';

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
  Future<void> sendAgentMessage(agent_sessions.AgentMessage message, {Uint8List? attachment, bool ignoreOffline = false}) async {}
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

  testWidgets('controlled side pane keeps shared width while agents tab is active', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    double? committedWidth;
    const roomPanelKey = Key('room-panel');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 640,
            child: PbRoomPanelMount(
              activeTab: PbRoomPanelTab.agents,
              panelWidth: 560,
              onPanelWidthChanged: (width) => committedWidth = width,
              threadPanel: const SizedBox.expand(),
              roomPanel: const SizedBox.expand(key: roomPanelKey),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(committedWidth, isNull);
    expect(tester.getSize(find.byKey(roomPanelKey)).width, 560);
  });

  testWidgets('file preview uses supplied app viewer child before spec fallback content', (tester) async {
    final file = PbAttachmentListItemData.fromFileName(title: 'preview_rules.dart');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(
              file: file,
              fullscreen: false,
              onToggleFullscreen: () {},
              onClose: () {},
              child: const Text('Live document pane'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live document pane'), findsOneWidget);
    expect(find.byKey(const ValueKey('code-preview-surface')), findsNothing);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('file preview fallback renders type-specific code and image surfaces', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(file: PbAttachmentListItemData.fromFileName(title: 'preview_rules.dart'), fullscreen: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('code-preview-surface')), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(file: PbAttachmentListItemData.fromFileName(title: 'launch-poster.png'), fullscreen: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('image-preview-viewport')), findsOneWidget);
    expect(find.byKey(const ValueKey('image-preview-surface')), findsOneWidget);
    expect(find.text('Fit'), findsOneWidget);
  });

  testWidgets('file preview loads editable source text and saves through v1 header action', (tester) async {
    String? savedText;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(
              file: PbAttachmentListItemData.fromFileName(title: 'notes.md'),
              fullscreen: false,
              loadText: () async => '# Draft\n\nInitial note',
              onSaveTextRequested: (text) async {
                savedText = text;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Working draft'), findsNothing);
    expect(find.text('Markdown'), findsNothing);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.enableInteractiveSelection, isTrue);
    final selectionTheme = tester.widget<TextSelectionTheme>(find.byKey(const ValueKey('editable-document-selection-theme')));
    expect(selectionTheme.data.selectionColor, const Color(0x332563EB));

    await tester.enterText(find.byType(TextField), '# Draft\n\nEdited note');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedText, '# Draft\n\nEdited note');
  });

  testWidgets('blank editable document preview shows type here placeholder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(
              file: PbAttachmentListItemData.fromFileName(title: 'new-note.txt'),
              fullscreen: false,
              loadText: () async => '',
              onSaveTextRequested: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.decoration?.hintText, 'Type here');
    expect(find.text('Type here'), findsOneWidget);
    expect(find.text('Working draft'), findsNothing);
    expect(find.text('Text'), findsNothing);
  });

  testWidgets('editable document preview keeps draft when parent rebuilds with fresh loader', (tester) async {
    late StateSetter rebuildParent;
    var loadCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              return SizedBox(
                width: 560,
                height: 480,
                child: PbFilePreviewPane(
                  file: PbAttachmentListItemData.fromFileName(title: 'mobile-test.txt', path: 'docs/mobile-test.txt'),
                  fullscreen: false,
                  sourceKey: 'docs/mobile-test.txt',
                  loadText: () async {
                    loadCount += 1;
                    return 'Loaded text $loadCount';
                  },
                  onSaveTextRequested: (_) async {},
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loadCount, 1);
    await tester.enterText(find.byType(TextField), 'Unsaved draft');
    await tester.pump();

    rebuildParent(() {});
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, 'Unsaved draft');
    expect(loadCount, 1);
  });

  testWidgets('editable document preview keeps draft when fullscreen toggles', (tester) async {
    late StateSetter rebuildParent;
    var fullscreen = false;
    var loadCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              return SizedBox(
                width: 560,
                height: 480,
                child: PbFilePreviewPane(
                  file: PbAttachmentListItemData.fromFileName(title: 'mobile-test.txt', path: 'docs/mobile-test.txt'),
                  fullscreen: fullscreen,
                  sourceKey: 'docs/mobile-test.txt',
                  loadText: () async {
                    loadCount += 1;
                    return 'Loaded text $loadCount';
                  },
                  onSaveTextRequested: (_) async {},
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Fullscreen draft');
    await tester.pump();

    rebuildParent(() => fullscreen = true);
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, 'Fullscreen draft');
    expect(loadCount, 1);
  });

  testWidgets('room panel file preview source owns editable real content instead of legacy child', (tester) async {
    String? savedText;
    final file = PbAttachmentListItemData.fromFileName(title: 'notes.csv', path: 'docs/notes.csv');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 560,
            child: PbRoomPanel(
              selectedTab: PbRoomPanelTab.files,
              initialPreviewFile: file,
              initialFilePreviewOpen: true,
              attachments: [file],
              filePreviewBuilder: (_) => const Text('Legacy document pane'),
              filePreviewSourceBuilder: (_) => PbFilePreviewSource(
                loadText: () async => 'name,status\nLaunch,Ready',
                saveText: (text) async {
                  savedText = text;
                },
              ),
              threads: const ['Planning'],
              selectedThreadTitle: null,
              onThreadSelected: (_) {},
              onCreateThread: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Legacy document pane'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'name,status\nLaunch,Shipped');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedText, 'name,status\nLaunch,Shipped');
  });

  testWidgets('file preview loads editable source code into v1 code surface', (tester) async {
    String? savedText;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(
              file: PbAttachmentListItemData.fromFileName(title: 'preview_rules.dart'),
              fullscreen: false,
              loadText: () async => 'final mode = "media";',
              onSaveTextRequested: (text) async {
                savedText = text;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('code-preview-surface')), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.enableInteractiveSelection, isTrue);
    final selectionTheme = tester.widget<TextSelectionTheme>(find.byKey(const ValueKey('code-editor-selection-theme')));
    expect(selectionTheme.data.selectionColor, const Color(0x665EA2FF));

    await tester.enterText(find.byType(EditableText), 'final mode = "code";');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedText, 'final mode = "code";  ');
  });

  testWidgets('blank editable code preview shows type here placeholder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(
              file: PbAttachmentListItemData.fromFileName(title: 'new-script.dart'),
              fullscreen: false,
              loadText: () async => '',
              onSaveTextRequested: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('code-preview-surface')), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.decoration?.hintText, 'Type here');
    expect(find.text('Type here'), findsOneWidget);
  });

  testWidgets('editable code preview keeps draft when fullscreen toggles', (tester) async {
    late StateSetter rebuildParent;
    var fullscreen = false;
    var loadCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              return SizedBox(
                width: 560,
                height: 480,
                child: PbFilePreviewPane(
                  file: PbAttachmentListItemData.fromFileName(title: 'preview_rules.dart', path: 'docs/preview_rules.dart'),
                  fullscreen: fullscreen,
                  sourceKey: 'docs/preview_rules.dart',
                  loadText: () async {
                    loadCount += 1;
                    return 'final mode = "loaded_$loadCount";';
                  },
                  onSaveTextRequested: (_) async {},
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), 'final mode = "draft";');
    await tester.pump();

    rebuildParent(() => fullscreen = true);
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, 'final mode = "draft";');
    expect(loadCount, 1);
  });

  testWidgets('code preview scrollbars span the file preview frame', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(
              file: PbAttachmentListItemData.fromFileName(title: 'wide.dart'),
              fullscreen: false,
              loadText: () async => 'final value = "${'wide' * 80}";',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final frame = tester.getRect(find.byKey(const ValueKey('file-preview-content-frame')));
    final horizontalScrollbar = tester.getRect(find.byKey(const ValueKey('code-preview-horizontal-scrollbar')));
    final verticalScrollbar = tester.getRect(find.byKey(const ValueKey('code-preview-vertical-scrollbar')));

    expect((horizontalScrollbar.left - frame.left).abs(), lessThanOrEqualTo(1));
    expect((horizontalScrollbar.right - frame.right).abs(), lessThanOrEqualTo(1));
    expect((verticalScrollbar.top - frame.top).abs(), lessThanOrEqualTo(1));
    expect((verticalScrollbar.bottom - frame.bottom).abs(), lessThanOrEqualTo(1));
  });

  testWidgets('file preview hides share action for this scoped release', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 920,
            height: 480,
            child: PbFilePreviewPane(
              file: PbAttachmentListItemData.fromFileName(title: 'brief.pdf'),
              fullscreen: false,
              previewContentChild: const SizedBox.expand(),
              onAskAgent: () {},
              onShare: () {},
              onDownload: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ask agent'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
  });

  testWidgets('responsive ask agent closes file preview and returns to threads panel', (tester) async {
    final file = PbAttachmentListItemData.fromFileName(title: 'brief.pdf', path: 'docs/brief.pdf');
    var selectedTab = PbRoomPanelTab.files;
    var previewOpen = true;
    PbAttachmentListItemData? askedFile;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setHarnessState) {
              return SizedBox(
                width: 560,
                height: 560,
                child: PbRoomPanel(
                  responsiveOverlay: true,
                  selectedTab: selectedTab,
                  initialPreviewFile: file,
                  initialFilePreviewOpen: previewOpen,
                  attachments: [file],
                  agents: const [PbAgentListItemData(id: 'assistant', title: 'Assistant', status: 'Available', icon: 'bot')],
                  selectedAgentId: 'assistant',
                  threads: const ['New Thread...'],
                  selectedThreadTitle: null,
                  onThreadSelected: (_) {},
                  onCreateThread: () {},
                  onAskFileAgent: (file) {
                    askedFile = file;
                    setHarnessState(() {
                      selectedTab = PbRoomPanelTab.agents;
                      previewOpen = false;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('file-preview-content-frame')), findsOneWidget);

    await tester.tap(find.text('Ask agent'));
    await tester.pumpAndSettle();

    expect(askedFile, file);
    expect(find.byKey(const ValueKey('file-preview-content-frame')), findsNothing);
    expect(find.text('Browse threads by selected agent.'), findsOneWidget);
    expect(find.text('Browse attachments by selected agent.'), findsNothing);
  });

  testWidgets('thread preview unavailable state does not expose an inert composer', (tester) async {
    final file = PbAttachmentListItemData.fromFileName(title: 'Sample Thread', fileType: PbAttachmentFileType.thread);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(
              file: file,
              fullscreen: false,
              previewContentChild: Center(
                child: PbFilePreviewStateCard(file: file, state: PbAttachmentPreviewState.unavailable),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No preview available'), findsOneWidget);
    expect(find.text('Unable to load thread'), findsNothing);
    expect(find.text('Type a message…'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('thread preview fallback uses v1 comment rows without a composer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(
              file: PbAttachmentListItemData.fromFileName(title: 'Sample Thread', fileType: PbAttachmentFileType.thread),
              fullscreen: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('thread-preview-surface')), findsOneWidget);
    expect(find.byKey(const ValueKey('thread-preview-user-message-row')), findsNWidgets(2));
    expect(find.byKey(const ValueKey('thread-preview-assistant-message-row')), findsOneWidget);
    expect(find.text('Agent'), findsOneWidget);
    expect(find.text('Unable to load thread'), findsNothing);
    expect(find.text('Type a message…'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('room panel forced fullscreen opens file preview edge to edge on first mount', (tester) async {
    final file = PbAttachmentListItemData.fromFileName(title: 'sample-html-fragment.html', path: 'files/sample-html-fragment.html');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 560,
            child: PbRoomPanel(
              selectedTab: PbRoomPanelTab.files,
              initialPreviewFile: file,
              initialFilePreviewOpen: true,
              openFilePreviewAsFullscreen: true,
              attachments: [file],
              filePreviewSourceBuilder: (_) => PbFilePreviewSource(loadText: () async => '<!doctype html>'),
              threads: const ['Planning'],
              selectedThreadTitle: null,
              onThreadSelected: (_) {},
              onCreateThread: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final previewFrame = tester.getRect(find.byKey(const ValueKey('file-preview-content-frame')));

    expect(previewFrame.left, 0);
    expect(previewFrame.width, 560);
    expect(find.byKey(const ValueKey('code-preview-surface')), findsOneWidget);
  });

  testWidgets('file preview uses real native document child instead of editable sample fallback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(
              file: PbAttachmentListItemData.fromFileName(title: 'meshwidget.widget'),
              fullscreen: false,
              previewContentChild: const Center(child: Text('No preview available')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No preview available'), findsOneWidget);
    expect(find.text('Working draft'), findsNothing);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('file preview unavailable and unsupported states stay centered in the preview frame', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(
              file: PbAttachmentListItemData.fromFileName(title: 'archive.zip', previewState: PbAttachmentPreviewState.unsupported),
              fullscreen: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final frameCenter = tester.getCenter(find.byKey(const ValueKey('file-preview-content-frame')));
    final cardCenter = tester.getCenter(find.byType(PbFilePreviewStateCard));

    expect(find.text('File preview not supported'), findsOneWidget);
    expect((frameCenter.dx - cardCenter.dx).abs(), lessThan(1));
    expect((frameCenter.dy - cardCenter.dy).abs(), lessThan(1));
  });

  testWidgets('file preview state card supports contextual empty labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PbFilePreviewStateCard(
              file: PbAttachmentListItemData.fromFileName(title: 'New Chat', fileType: PbAttachmentFileType.thread),
              state: PbAttachmentPreviewState.unavailable,
              label: 'No messages yet',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.text('No preview available'), findsNothing);
  });

  testWidgets('unavailable image previews do not render image zoom controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(
              file: PbAttachmentListItemData.fromFileName(
                title: 'sample-image-preview.tiff',
                previewState: PbAttachmentPreviewState.unavailable,
              ),
              fullscreen: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No preview available'), findsOneWidget);
    expect(find.text('Fit'), findsNothing);
    expect(find.byKey(const ValueKey('image-preview-viewport')), findsNothing);
    expect(find.byKey(const ValueKey('image-preview-surface')), findsNothing);
  });

  testWidgets('pdf preview child sits flush inside the v1 frame', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(
              file: PbAttachmentListItemData.fromFileName(title: 'brief.pdf'),
              fullscreen: false,
              previewContentChild: const SizedBox.expand(key: ValueKey('pdf-child')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final frame = tester.getRect(find.byKey(const ValueKey('file-preview-content-frame')));
    final child = tester.getRect(find.byKey(const ValueKey('pdf-child')));

    expect((child.left - frame.left).abs(), lessThanOrEqualTo(1));
    expect((child.top - frame.top).abs(), lessThanOrEqualTo(1));
    expect((frame.right - child.right).abs(), lessThanOrEqualTo(1));
    expect((frame.bottom - child.bottom).abs(), lessThanOrEqualTo(1));
  });

  testWidgets('transcript preview child renders real transcript content through v1 typography surface', (tester) async {
    const data = PbTranscriptPreviewData(
      dateLabel: 'June 2, 2026',
      detailLabel: 'Transcript   3:55p - 8 secs',
      participants: [PbTranscriptPreviewParticipant(label: 'dinesh.daewar@timu.com', initials: 'DD')],
      turns: [PbTranscriptPreviewTurn(timestamp: '00:00:00', speaker: 'dinesh.daewar@timu.com', text: 'Real transcript text.')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(
              file: PbAttachmentListItemData.fromFileName(title: '2026-06-02.transcript'),
              fullscreen: false,
              previewContentChild: const PbTranscriptPreviewContent(data: data, fullscreen: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('June 2, 2026'), findsOneWidget);
    expect(find.text('Real transcript text.'), findsOneWidget);
    expect(find.text("Hi, I'm checking to see if the transcription works. I turned it on. Can you hear me?"), findsNothing);
  });

  testWidgets('empty transcript preview uses the shared preview state card', (tester) async {
    const data = PbTranscriptPreviewData(dateLabel: 'June 2, 2026', detailLabel: 'Transcript', participants: [], turns: []);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 480,
            child: PbFilePreviewPane(
              file: PbAttachmentListItemData.fromFileName(title: 'empty.transcript'),
              fullscreen: false,
              previewContentChild: const PbTranscriptPreviewContent(data: data, fullscreen: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PbFilePreviewStateCard), findsOneWidget);
    expect(find.text('No transcript available'), findsOneWidget);
  });

  testWidgets('meet transcript panel uses source transcript content instead of fallback child', (tester) async {
    const data = PbTranscriptPreviewData(
      dateLabel: 'June 2, 2026',
      detailLabel: 'Transcript   1 min',
      participants: [PbTranscriptPreviewParticipant(label: 'Jesse Park', initials: 'JP')],
      turns: [PbTranscriptPreviewTurn(timestamp: '00:00:00', speaker: 'Jesse Park', text: 'Source transcript content.')],
    );
    final file = PbAttachmentListItemData.fromFileName(title: 'daily.transcript', path: 'transcripts/daily.transcript');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 560,
            child: PbMeetTranscriptPanel(
              transcripts: [file],
              initialPreviewFile: file,
              initialFilePreviewOpen: true,
              filePreviewBuilder: (_) => const Text('Legacy transcript pane'),
              filePreviewSourceBuilder: (_) => const PbFilePreviewSource(child: PbTranscriptPreviewContent(data: data, fullscreen: false)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Legacy transcript pane'), findsNothing);
    expect(find.text('Source transcript content.'), findsOneWidget);
    expect(find.text("Hi, I'm checking to see if the transcription works. I turned it on. Can you hear me?"), findsNothing);
  });

  testWidgets('meet transcript panel describes recent meetings without a hard time limit', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 560, height: 560, child: PbMeetTranscriptPanel(transcripts: [])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Browse transcripts from recent meetings.'), findsOneWidget);
    expect(find.text('Browse transcripts from the last seven days.'), findsNothing);
  });

  testWidgets('meet transcript row menu exposes ask agent and download actions', (tester) async {
    final file = PbAttachmentListItemData.fromFileName(title: 'daily.transcript', path: 'transcripts/daily.transcript');
    PbAttachmentListItemData? askedFile;
    PbAttachmentListItemData? downloadedFile;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            height: 560,
            child: PbMeetTranscriptPanel(
              transcripts: [file],
              onAskFileAgent: (file) => askedFile = file,
              onDownloadFile: (file) => downloadedFile = file,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.text('daily')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(sidepane_menu.PbSidepaneItemMenu));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Ask agent'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);

    await tester.tap(find.text('Ask agent'));
    await tester.pumpAndSettle();
    expect(askedFile, file);

    await mouse.moveTo(tester.getCenter(find.text('daily')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(sidepane_menu.PbSidepaneItemMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(downloadedFile, file);
  });
}
