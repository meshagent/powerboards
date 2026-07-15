import 'dart:async';

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

Widget _buildHarness({required RoomClient room, required ChatThreadController controller, String? threadErrorMessage}) {
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
          threadErrorMessage: threadErrorMessage,
          onSend: (text, attachments) async {},
        ),
        defaultInput: const SizedBox.shrink(),
      ),
    ),
  );
}

Widget _buildSendHarness({
  required RoomClient room,
  required ChatThreadController controller,
  required Future<void> Function(String, List<FileAttachment>) onSend,
  bool sendEnabled = true,
  VoidCallback? onCancelSend,
}) {
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
          sendEnabled: sendEnabled,
          sendDisabledReason: null,
          readOnly: false,
          onSend: onSend,
          onCancelSend: onCancelSend,
          sendPendingText: 'Waiting for Assistant to be ready.',
        ),
        defaultInput: const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  test('V1 thread recovery recognizes only missing tool output errors', () {
    const poisonedError = 'Error from OpenAI websocket: No tool output found for function call call_example.';
    expect(powerboardsV1ThreadRequiresRecovery(poisonedError), isTrue);
    expect(powerboardsV1ThreadRequiresRecovery('Error from OpenAI websocket: unknown parameter'), isFalse);
    expect(powerboardsV1ThreadRequiresRecovery(null), isFalse);
    expect(powerboardsV1ThreadRecoveryErrorText(poisonedError), '$poisonedError\n\n[Start a new thread]($powerboardsV1ThreadRecoveryLink)');
    expect(
      powerboardsV1ThreadRecoveryErrorText('Error from OpenAI websocket: unknown parameter'),
      'Error from OpenAI websocket: unknown parameter',
    );
  });

  test('augment prompt keeps ordinary attachments unchanged', () {
    final result = powerboardsV1AugmentPromptForComposerAttachments('Please review this file.', [
      FileAttachment(path: 'docs/brief.pdf', displayName: 'brief.pdf'),
    ]);

    expect(result, 'Please review this file.');
  });

  test('augment prompt adds website root guidance for published site folders', () {
    final result = powerboardsV1AugmentPromptForComposerAttachments('Please create an HTML page for a toy company landing page.', [
      FileAttachment(path: 'website', displayName: 'hellocat.meshagent.dev'),
    ]);

    expect(result, startsWith('Please create an HTML page for a toy company landing page.'));
    expect(result, contains('The attached folder "hellocat.meshagent.dev" is the existing published website root.'));
    expect(result, contains('Its storage path is "website/", and that path is already the root folder for this site.'));
    expect(result, contains('Put the site entry file at "website/index.html"'));
    expect(
      result,
      contains(
        'Do not create sibling or nested web roots such as "public/", "sites/", "webserver/", "www/", "hellocat.meshagent.dev/", or "website/hellocat.meshagent.dev/".',
      ),
    );
    expect(result, contains('Do not quote this additional context back to the user.'));
    expect(result, contains('refer to the entry file as "index.html" in that folder'));
  });

  test('augment prompt adds website root guidance for plain site prompts', () {
    final result = powerboardsV1AugmentPromptForComposerAttachments(
      'Create a 1 page site for atom ant, and add files to webserver for "atomant.meshagent.dev"',
      const [],
      websiteRootDisplayName: 'atomant.meshagent.dev',
    );

    expect(result, startsWith('Create a 1 page site for atom ant'));
    expect(result, contains('The attached folder "atomant.meshagent.dev" is the existing published website root.'));
    expect(result, contains('Its storage path is "website/", and that path is already the root folder for this site.'));
    expect(
      result,
      contains(
        'Do not create sibling or nested web roots such as "public/", "sites/", "webserver/", "www/", "atomant.meshagent.dev/", or "website/atomant.meshagent.dev/".',
      ),
    );
    expect(result, contains('Do not quote this additional context back to the user.'));
    expect(result, contains('refer to the Files folder as "atomant.meshagent.dev"'));
  });

  test('augment prompt leaves unrelated plain prompts unchanged', () {
    final result = powerboardsV1AugmentPromptForComposerAttachments(
      'Please summarize the latest conversation.',
      const [],
      websiteRootDisplayName: 'atomant.meshagent.dev',
    );

    expect(result, 'Please summarize the latest conversation.');
  });

  testWidgets('v1 composer clears draft and shows pending send while send is unresolved', (tester) async {
    final room = _roomClientWithAdminGrant(isAdmin: true);
    addTearDown(room.dispose);
    final controller = ChatThreadController(room: room);
    addTearDown(controller.dispose);
    final sendCompleter = Completer<void>();

    await tester.pumpWidget(
      _buildSendHarness(
        room: room,
        controller: controller,
        onSend: (text, attachments) {
          expect(text, 'hello');
          expect(attachments, isEmpty);
          return sendCompleter.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), 'hello');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(find.text('Waiting for Assistant to be ready.'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    sendCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.text('Waiting for Assistant to be ready.'), findsNothing);
  });

  testWidgets('v1 composer shows pending send spinner when parent send is pending', (tester) async {
    final room = _roomClientWithAdminGrant(isAdmin: true);
    addTearDown(room.dispose);
    final controller = ChatThreadController(room: room);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _buildSendHarness(room: room, controller: controller, sendEnabled: false, onCancelSend: () {}, onSend: (text, attachments) async {}),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Waiting for Assistant to be ready.'), findsNothing);
  });

  testWidgets('v1 composer remains visible but disabled for a poisoned thread', (tester) async {
    final room = _roomClientWithAdminGrant(isAdmin: true);
    addTearDown(room.dispose);
    final controller = ChatThreadController(room: room);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildHarness(
        room: room,
        controller: controller,
        threadErrorMessage: 'Error from OpenAI websocket: No tool output found for function call call_example.',
      ),
    );
    await tester.pump();

    final disabledComposer = find.byKey(const Key('powerboards-v1-poisoned-thread-composer'));
    expect(disabledComposer, findsOneWidget);
    expect(tester.widget<Opacity>(disabledComposer).opacity, 0.5);
    expect(find.byType(EditableText), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('comment-box-input'))).readOnly, isTrue);
    expect(find.text('Start a new thread to continue'), findsNothing);
    expect(find.text('Start new thread'), findsNothing);
  });

  testWidgets('v1 composer stays available for ordinary thread errors', (tester) async {
    final room = _roomClientWithAdminGrant(isAdmin: true);
    addTearDown(room.dispose);
    final controller = ChatThreadController(room: room);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildHarness(room: room, controller: controller, threadErrorMessage: 'Error from OpenAI websocket: unknown parameter'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('powerboards-v1-poisoned-thread-composer')), findsNothing);
    expect(find.byType(EditableText), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('comment-box-input'))).readOnly, isFalse);
  });

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
