import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:powerboards/meshagent/powerboards_v1_thread_composer.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

ChatThreadSnapshot _emptySnapshot() {
  return ChatThreadSnapshot(
    messages: const [],
    online: const [],
    offline: const [],
    typing: const [],
    listening: const [],
    agentOnline: false,
    threadStatus: null,
    threadStatusStartedAt: null,
    threadStatusMode: null,
    threadStatusTotalBytes: null,
    threadStatusLinesAdded: null,
    threadStatusLinesRemoved: null,
    supportsAgentMessages: false,
    supportsMcp: false,
    toolkits: const {},
    threadTurnId: null,
    pendingMessages: const [],
    pendingItemId: null,
    usage: null,
  );
}

RoomClient _roomClientWithAdminGrant({required bool isAdmin}) {
  final token = ParticipantToken(name: 'user', projectId: 'project');
  token.addRoomGrant('room');
  token.addApiGrant(
    ApiScope(developer: DeveloperGrant(logs: true), storage: StorageGrant(), llm: LLMGrant(), admin: isAdmin ? AdminGrant() : null),
  );

  return RoomClient(
    protocolFactory: WebSocketClientProtocol.createFactory(
      url: Uri.parse('ws://localhost:8080/rooms/room'),
      token: token.toJwt(token: 'secret'),
    ),
  );
}

Widget _buildHarness({required RoomClient room, required ChatThreadController controller}) {
  return ShadApp(
    home: Scaffold(
      body: PowerboardsV1ThreadComposer(
        projectId: 'project',
        room: room,
        agentName: null,
        config: ChatThreadInputConfig(
          controller: controller,
          snapshot: _emptySnapshot(),
          placeholder: const Text('Ask Assistant...'),
          sendEnabled: true,
          sendDisabledReason: null,
          readOnly: false,
          onSend: (text, attachments) async {},
        ),
        defaultInput: const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  testWidgets('v1 MCP menu hides Add for non-admin users', (tester) async {
    final room = _roomClientWithAdminGrant(isAdmin: false);
    addTearDown(room.dispose);
    final controller = ChatThreadController(room: room);
    addTearDown(controller.dispose);
    controller.setMcpConnectorSelected(OpenAIConnectors.gmail, true);

    await tester.pumpWidget(_buildHarness(room: room, controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('MCP'));
    await tester.pumpAndSettle();

    expect(find.text('Add...'), findsNothing);
  });

  testWidgets('v1 MCP menu shows Add for admin users', (tester) async {
    final room = _roomClientWithAdminGrant(isAdmin: true);
    addTearDown(room.dispose);
    final controller = ChatThreadController(room: room);
    addTearDown(controller.dispose);
    controller.setMcpConnectorSelected(OpenAIConnectors.gmail, true);

    await tester.pumpWidget(_buildHarness(room: room, controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('MCP'));
    await tester.pumpAndSettle();

    expect(find.text('Add...'), findsOneWidget);
  });
}
