import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/chat/new_chat_thread.dart';
import 'package:powerboards/meshagent/agent_participants.dart';
import 'package:powerboards/meshagent/desktop_chat_attach_button.dart';
import 'package:powerboards/meshagent/mobile_chat_attach_button.dart';
import 'package:powerboards/meshagent/thread_view.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _NoopProtocolChannel extends ProtocolChannel {
  @override
  void dispose() {}

  @override
  Future<void> sendData(Uint8List data) async {}

  @override
  void start(void Function(Uint8List data) onDataReceived, {void Function()? onDone, void Function(Object? error)? onError}) {}
}

class _ThreadViewHarness extends StatefulWidget {
  const _ThreadViewHarness({required this.room});

  final RoomClient room;

  @override
  State<_ThreadViewHarness> createState() => _ThreadViewHarnessState();
}

class _ThreadViewHarnessState extends State<_ThreadViewHarness> {
  String? _selectedThreadPath;

  @override
  Widget build(BuildContext context) {
    return MeshagentThreadView(
      projectId: 'project',
      client: widget.room,
      joinMeeting: () {},
      agentName: 'assistant',
      threadDisplayMode: ChatThreadDisplayMode.multiThreadComposer,
      selectedThreadPath: _selectedThreadPath,
      onSelectedThreadPathChanged: (path) {
        setState(() {
          _selectedThreadPath = path;
        });
      },
    );
  }
}

ChatThreadSnapshot _emptySnapshot({bool supportsMcp = false, bool agentOnline = false}) {
  return ChatThreadSnapshot(
    messages: const [],
    online: const [],
    offline: const [],
    typing: const [],
    listening: const [],
    agentOnline: agentOnline,
    threadStatus: null,
    threadStatusStartedAt: null,
    threadStatusMode: null,
    supportsAgentMessages: false,
    supportsMcp: supportsMcp,
    toolkits: const <String, AgentToolkitCapabilities>{},
    threadTurnId: null,
    pendingMessages: const [],
    pendingItemId: null,
  );
}

void main() {
  testWidgets('keeps the same new thread view mounted when the created thread becomes selected', (tester) async {
    final room = RoomClient(protocol: Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);

    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(
          body: SizedBox.expand(child: _ThreadViewHarness(room: room)),
        ),
      ),
    );

    final newThreadFinder = find.byType(NewChatThread);
    expect(newThreadFinder, findsOneWidget);

    final stateBefore = tester.state<State<StatefulWidget>>(newThreadFinder);
    final newThread = tester.widget<NewChatThread>(newThreadFinder);
    newThread.onThreadPathChanged?.call('.threads/created.thread');
    await tester.pump();

    expect(newThreadFinder, findsOneWidget);
    final stateAfter = tester.state<State<StatefulWidget>>(newThreadFinder);
    expect(identical(stateAfter, stateBefore), isTrue);
  });

  testWidgets('uses the mobile attach flow dialog entry point only on native mobile layouts', (tester) async {
    final room = RoomClient(protocol: Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);

    final controller = ChatThreadController(room: room);
    addTearDown(controller.dispose);

    Future<void> pumpToolArea(Size size) {
      return tester.pumpWidget(
        ShadApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: Builder(
              builder: (context) => Material(child: buildTools(context, 'project', room, 'assistant', controller, _emptySnapshot())),
            ),
          ),
        ),
      );
    }

    await pumpToolArea(const Size(390, 844));
    expect(find.byType(PowerboardsMobileChatAttachButton), findsOneWidget);
    expect(find.byType(PowerboardsDesktopChatAttachButton), findsNothing);

    await pumpToolArea(const Size(1024, 768));
    expect(find.byType(PowerboardsMobileChatAttachButton), findsNothing);
    expect(find.byType(PowerboardsDesktopChatAttachButton), findsOneWidget);
  });

  testWidgets('mobile attach chooser uses the migrated flow dialog list without MCP', (tester) async {
    final room = RoomClient(protocol: Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);

    final controller = ChatThreadController(room: room);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ShadApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: Center(child: PowerboardsMobileChatAttachButton(controller: controller)),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();

    expect(find.text('Add to thread'), findsOneWidget);
    expect(find.text('Upload a photo...'), findsOneWidget);
    expect(find.text('Upload a file...'), findsOneWidget);
    expect(find.text('Add from room...'), findsOneWidget);
    expect(find.text('MCP'), findsNothing);
  });

  testWidgets('mobile thread empty state keeps descriptive copy when keyboard is down', (tester) async {
    final room = RoomClient(protocol: Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewInsets = FakeViewPadding.zero;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ShadApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: SizedBox.expand(child: _ThreadViewHarness(room: room)),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Start a new thread'), findsOneWidget);
    expect(find.text('Connect with this agent and your team'), findsOneWidget);
  });

  testWidgets('mobile thread empty state uses title-only compact copy when keyboard is up', (tester) async {
    final room = RoomClient(protocol: Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ShadApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: SizedBox.expand(child: _ThreadViewHarness(room: room)),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Start a new thread'), findsOneWidget);
    expect(find.text('Connect with this agent and your team'), findsNothing);
  });
}
