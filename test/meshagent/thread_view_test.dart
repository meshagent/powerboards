import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/chat/new_chat_thread.dart';
import 'package:powerboards/meshagent/agent_participants.dart';
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
}
