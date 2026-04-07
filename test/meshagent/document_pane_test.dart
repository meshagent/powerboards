import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent/runtime.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:powerboards/meshagent/document_pane.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _ProtocolPair {
  _ProtocolPair() {
    clientProtocol = Protocol(
      channel: StreamProtocolChannel(input: _serverToClient.stream, output: _clientToServer.sink),
    );
    serverProtocol = Protocol(
      channel: StreamProtocolChannel(input: _clientToServer.stream, output: _serverToClient.sink),
    );
  }

  final _clientToServer = StreamController<Uint8List>();
  final _serverToClient = StreamController<Uint8List>();
  late final Protocol clientProtocol;
  late final Protocol serverProtocol;

  Future<void> dispose() async {
    try {
      clientProtocol.dispose();
    } catch (_) {}
    try {
      serverProtocol.dispose();
    } catch (_) {}
    unawaited(_clientToServer.close());
    if (!_serverToClient.isClosed) {
      unawaited(_serverToClient.close());
    }
  }
}

class _FakeDocumentRuntime extends DocumentRuntime {
  _FakeDocumentRuntime() : super.base();

  @override
  void applyBackendChanges({required String documentId, required String base64}) {}

  @override
  void registerDocument(RuntimeDocument document) {}

  @override
  void sendChanges(Map<String, dynamic> message) {}

  @override
  void unregisterDocument(RuntimeDocument document) {}
}

final MeshSchema _threadSchema = MeshSchema(
  rootTagName: 'thread',
  elements: [
    ElementType(
      tagName: 'thread',
      description: '',
      properties: [
        ChildProperty(name: 'children', description: '', childTagNames: ['messages', 'members']),
      ],
    ),
    ElementType(
      tagName: 'messages',
      description: '',
      properties: [
        ChildProperty(name: 'children', description: '', childTagNames: ['message', 'reasoning', 'event']),
      ],
    ),
    ElementType(
      tagName: 'members',
      description: '',
      properties: [
        ChildProperty(name: 'children', description: '', childTagNames: ['member']),
      ],
    ),
    ElementType(
      tagName: 'member',
      description: '',
      properties: [ValueProperty(name: 'name', description: '', type: SimpleValue.string)],
    ),
    ElementType(
      tagName: 'message',
      description: '',
      properties: [
        ValueProperty(name: 'text', description: '', type: SimpleValue.string),
        ValueProperty(name: 'author_name', description: '', type: SimpleValue.string),
      ],
    ),
    ElementType(
      tagName: 'reasoning',
      description: '',
      properties: [ValueProperty(name: 'summary', description: '', type: SimpleValue.string)],
    ),
    ElementType(
      tagName: 'event',
      description: '',
      properties: [ValueProperty(name: 'kind', description: '', type: SimpleValue.string)],
    ),
  ],
);

Future<void> _sendRoomReady(Protocol protocol) async {
  await protocol.send(
    'room_ready',
    packMessage({'room_name': 'test-room', 'room_url': 'ws://example/rooms/test-room', 'session_id': 'session-1'}),
  );
}

Future<void> _sendToolCallResponseChunk({required Protocol protocol, required String toolCallId, required Content chunk}) async {
  final packed = unpackMessage(chunk.pack());
  await protocol.send(
    'room.tool_call_response_chunk',
    packMessage({'tool_call_id': toolCallId, 'chunk': packed.header}, packed.payload.isEmpty ? null : packed.payload),
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition, {Duration timeout = const Duration(seconds: 1)}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('condition was not met before timeout');
    }
    await tester.pump(const Duration(milliseconds: 10));
  }
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

  testWidgets('renders the thread viewer for an empty thread document', (tester) async {
    final pair = _ProtocolPair();
    final closeReceived = Completer<void>();
    String? toolCallId;

    pair.serverProtocol.start(
      onMessage: (protocol, messageId, type, data) async {
        if (type == 'room.invoke_tool') {
          final request = Map<String, dynamic>.from(unpackMessage(data).header);
          if (request['toolkit'] != 'sync' || request['tool'] != 'open') {
            return;
          }
          toolCallId = request['tool_call_id'] as String;
          await protocol.send('__response__', ControlContent(method: 'open').pack(), id: messageId);
          return;
        }

        if (type != 'room.tool_call_request_chunk') {
          return;
        }

        final message = unpackMessage(data);
        final header = message.header;
        final chunkHeader = Map<String, dynamic>.from(header['chunk'] as Map);
        final packedChunk = packMessage(chunkHeader, message.payload.isEmpty ? null : message.payload);
        final chunk = unpackContent(packedChunk);

        await protocol.send('__response__', EmptyContent().pack(), id: messageId);

        final activeToolCallId = toolCallId;
        if (activeToolCallId == null) {
          return;
        }

        if (chunk is BinaryContent && chunk.headers['kind'] == 'start') {
          await _sendToolCallResponseChunk(
            protocol: protocol,
            toolCallId: activeToolCallId,
            chunk: BinaryContent(data: Uint8List(0), headers: {'kind': 'state', 'path': 'thread.thread', 'schema': _threadSchema.toJson()}),
          );
          return;
        }

        if (chunk is ControlContent && chunk.method == 'close') {
          await _sendToolCallResponseChunk(
            protocol: protocol,
            toolCallId: activeToolCallId,
            chunk: ControlContent(method: 'close'),
          );
          if (!closeReceived.isCompleted) {
            closeReceived.complete();
          }
        }
      },
    );

    final room = RoomClient(protocol: pair.clientProtocol);
    final startFuture = room.start();
    await _sendRoomReady(pair.serverProtocol);
    await startFuture;

    try {
      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: DocumentPane(path: 'thread.thread', room: room),
            ),
          ),
        ),
      );

      await _pumpUntil(tester, () => find.byType(ChatThread).evaluate().isNotEmpty);

      expect(find.byType(ChatThread), findsOneWidget);
      expect(find.byType(ChatThreadInput), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await closeReceived.future.timeout(const Duration(seconds: 1));
    } finally {
      room.dispose();
      await pair.dispose();
    }
  });
}
