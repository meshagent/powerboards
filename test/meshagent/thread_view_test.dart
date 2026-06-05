import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent/runtime.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/chat/dataset_chat_thread.dart';
import 'package:meshagent_flutter_shadcn/chat/new_chat_thread.dart';
import 'package:powerboards/meshagent/agent_participants.dart';
import 'package:powerboards/meshagent/desktop_chat_attach_button.dart';
import 'package:powerboards/meshagent/mobile_chat_attach_button.dart';
import 'package:powerboards/meshagent/thread_view.dart';
import 'package:powerboards/ui/powerboards_breakpoints.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _ProtocolPair {
  _ProtocolPair() {
    serverProtocol = Protocol(
      channel: StreamProtocolChannel(input: _clientToServer.stream, output: _serverToClient.sink),
    );
  }

  final _clientToServer = StreamController<Uint8List>();
  final _serverToClient = StreamController<Uint8List>();
  Protocol? _clientProtocol;
  late final Protocol serverProtocol;

  Protocol clientProtocolFactory() {
    final existing = _clientProtocol;
    if (existing != null) {
      throw ProtocolReconnectUnsupportedException('protocolFactory was not configured for reconnecting this protocol');
    }
    final protocol = Protocol(
      channel: StreamProtocolChannel(input: _serverToClient.stream, output: _clientToServer.sink),
    );
    _clientProtocol = protocol;
    return protocol;
  }

  Future<void> dispose() async {
    final clientProtocol = _clientProtocol;
    if (clientProtocol != null) {
      try {
        clientProtocol.dispose();
      } catch (_) {}
    }
    try {
      serverProtocol.dispose();
    } catch (_) {}
    unawaited(_clientToServer.close());
    if (!_serverToClient.isClosed) {
      unawaited(_serverToClient.close());
    }
  }
}

class _NoopProtocolChannel extends ProtocolChannel {
  @override
  void dispose() {}

  @override
  Future<void> sendData(Uint8List data) async {}

  @override
  void start(void Function(Uint8List data) onDataReceived, {void Function()? onDone, void Function(Object? error)? onError}) {}
}

Future<void> _sendRoomReady(Protocol protocol) async {
  await protocol.send(
    'room_ready',
    packMessage({'room_name': 'test-room', 'room_url': 'ws://example/rooms/test-room', 'session_id': 'session-1'}),
  );
  await protocol.send(
    'connected',
    packMessage({
      'type': 'init',
      'participantId': 'self',
      'attributes': {'name': 'self'},
    }),
  );
}

Future<void> _sendToolCallResponseChunk({required Protocol protocol, required String toolCallId, required Content chunk}) async {
  final packed = unpackMessage(chunk.pack());
  await protocol.send(
    'room.tool_call_response_chunk',
    packMessage({'tool_call_id': toolCallId, 'chunk': packed.header}, packed.payload.isEmpty ? null : packed.payload),
  );
}

class _FakeDocumentRuntime extends DocumentRuntime {
  _FakeDocumentRuntime() : super.base();

  @override
  void applyBackendChanges({required String documentId, required String base64}) {}

  @override
  void registerDocument(RuntimeDocument document) {}

  @override
  String getState({required String documentId, String? vectorBase64}) {
    return '';
  }

  @override
  String getStateVector({required String documentId}) {
    return '';
  }

  @override
  void sendChanges(Map<String, dynamic> message) {}

  @override
  void unregisterDocument(RuntimeDocument document) {}
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
    threadStatusTotalBytes: null,
    threadStatusLinesAdded: null,
    threadStatusLinesRemoved: null,
    supportsAgentMessages: false,
    supportsMcp: supportsMcp,
    toolkits: const {},
    threadTurnId: null,
    pendingMessages: const [],
    pendingItemId: null,
    usage: null,
  );
}

Widget _buildResponsiveTestApp({required Widget child, MediaQueryData? mediaQueryData}) {
  final responsiveChild = powerboardsResponsiveBreakpoints(child: child);
  return ShadApp(
    home: mediaQueryData == null ? responsiveChild : MediaQuery(data: mediaQueryData, child: responsiveChild),
  );
}

void main() {
  final previousRuntime = DocumentRuntime.instance;

  setUpAll(() {
    DocumentRuntime.instance = _FakeDocumentRuntime();
  });

  tearDownAll(() {
    if (previousRuntime != null) {
      DocumentRuntime.instance = previousRuntime;
    }
  });

  test('composer attachment seed matching normalizes room attachment URLs', () {
    expect(
      powerboardsComposerAttachmentSeedMatchesAttachmentPaths(
        seedPaths: const ['room:///sample-attachments/scratch.md'],
        attachmentPaths: const ['sample-attachments/scratch.md'],
      ),
      isTrue,
    );

    expect(
      powerboardsComposerAttachmentSeedMatchesAttachmentPaths(
        seedPaths: const ['sample-attachments/scratch.md'],
        attachmentPaths: const ['room://sample-attachments/scratch.md'],
      ),
      isTrue,
    );
  });

  test('composer attachment seed matching ignores unrelated and non-attachment paths', () {
    expect(
      powerboardsComposerAttachmentSeedMatchesAttachmentPaths(
        seedPaths: const ['sample-attachments/scratch.md'],
        attachmentPaths: const ['sample-attachments/other.md'],
      ),
      isFalse,
    );

    expect(
      powerboardsComposerAttachmentSeedMatchesAttachmentPaths(
        seedPaths: const ['dataset://agents/assistant/threads/thread-1'],
        attachmentPaths: const ['sample-attachments/scratch.md'],
      ),
      isFalse,
    );
  });

  testWidgets('switches from the new thread view to the selected thread when the parent selection changes', (tester) async {
    final pair = _ProtocolPair();
    final schema = MeshSchema(
      rootTagName: 'thread',
      elements: [ElementType(tagName: 'thread', description: '', properties: [])],
    );
    String? toolCallId;

    pair.serverProtocol.start(
      onMessage: (protocol, messageId, type, data) async {
        if (type == 'room.invoke_tool') {
          final request = unpackMessage(data).header;
          if (request['toolkit'] == 'sync' && request['tool'] == 'open') {
            toolCallId = request['tool_call_id'] as String;
            await protocol.send('__response__', ControlContent(method: 'open').pack(), id: messageId);
          }
          return;
        }

        if (type != 'room.tool_call_request_chunk' || toolCallId == null) {
          return;
        }

        final message = unpackMessage(data);
        final header = message.header;
        final chunkHeader = Map<String, dynamic>.from(header['chunk'] as Map);
        final packedChunk = packMessage(chunkHeader, message.payload.isEmpty ? null : message.payload);
        final chunk = unpackContent(packedChunk);
        await protocol.send('__response__', EmptyContent().pack(), id: messageId);

        if (chunk is BinaryContent && chunk.headers['kind'] == 'start') {
          await _sendToolCallResponseChunk(
            protocol: protocol,
            toolCallId: toolCallId!,
            chunk: BinaryContent(
              data: Uint8List.fromList(utf8.encode('')),
              headers: {'kind': 'state', 'path': chunk.headers['path'], 'schema': schema.toJson()},
            ),
          );
          return;
        }

        if (chunk is ControlContent && chunk.method == 'close') {
          await _sendToolCallResponseChunk(
            protocol: protocol,
            toolCallId: toolCallId!,
            chunk: ControlContent(method: 'close'),
          );
        }
      },
    );

    final room = RoomClient(protocolFactory: pair.clientProtocolFactory);
    final startFuture = room.start();
    await _sendRoomReady(pair.serverProtocol);
    await startFuture;

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();
      room.dispose();
      await pair.dispose();
    });

    await tester.pumpWidget(
      _buildResponsiveTestApp(
        child: Scaffold(
          body: SizedBox.expand(child: _ThreadViewHarness(room: room)),
        ),
      ),
    );

    final newThreadFinder = find.byType(NewChatThread);
    expect(newThreadFinder, findsOneWidget);

    final newThread = tester.widget<NewChatThread>(newThreadFinder);
    newThread.onThreadPathChanged?.call('.threads/created.thread');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final selectedNewThread = tester.widget<NewChatThread>(newThreadFinder);
    expect(selectedNewThread.selectedThreadPath, '.threads/created.thread');
    expect(find.byType(DatasetChatThread), findsOneWidget);
  });

  testWidgets('uses the mobile attach flow dialog entry point only on native mobile layouts', (tester) async {
    final room = RoomClient(protocolFactory: () => Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);

    final controller = ChatThreadController(room: room);
    addTearDown(controller.dispose);

    Future<void> pumpToolArea(Size size) {
      return tester.pumpWidget(
        _buildResponsiveTestApp(
          mediaQueryData: MediaQueryData(size: size),
          child: Builder(
            builder: (context) => Material(child: buildTools(context, 'project', room, 'assistant', controller, _emptySnapshot())),
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
    final room = RoomClient(protocolFactory: () => Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);

    final controller = ChatThreadController(room: room);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildResponsiveTestApp(
        mediaQueryData: const MediaQueryData(size: Size(390, 844)),
        child: Scaffold(
          body: Center(child: PowerboardsMobileChatAttachButton(controller: controller)),
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

  testWidgets('mobile thread empty state shows the mobile action pill row when keyboard is down', (tester) async {
    final room = RoomClient(protocolFactory: () => Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewInsets = FakeViewPadding.zero;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      _buildResponsiveTestApp(
        mediaQueryData: const MediaQueryData(size: Size(390, 844)),
        child: SizedBox.expand(child: _ThreadViewHarness(room: room)),
      ),
    );

    await tester.pump();

    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Start a new thread'), findsNothing);
    expect(find.text('Connect with this agent and your team'), findsNothing);
  });

  testWidgets('mobile thread empty state keeps the mobile action pill row when keyboard is up', (tester) async {
    final room = RoomClient(protocolFactory: () => Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      _buildResponsiveTestApp(
        mediaQueryData: const MediaQueryData(size: Size(390, 844)),
        child: SizedBox.expand(child: _ThreadViewHarness(room: room)),
      ),
    );

    await tester.pump();

    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Start a new thread'), findsNothing);
    expect(find.text('Connect with this agent and your team'), findsNothing);
  });
}
