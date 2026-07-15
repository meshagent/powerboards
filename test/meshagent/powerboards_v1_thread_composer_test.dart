import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/chat/dataset_chat_thread.dart';
import 'package:powerboards/meshagent/powerboards_v1_model_controller_scope.dart';
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

Widget _buildHarness({required RoomClient room, required ChatThreadController controller, DatasetChatModelController? modelController}) {
  final composer = PowerboardsV1ThreadComposer(
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
  );

  return ShadApp(
    home: Scaffold(
      body: modelController == null ? composer : PowerboardsV1ModelControllerScope(controller: modelController, child: composer),
    ),
  );
}

DatasetChatModelController _modelController({required bool includeCodex}) {
  final controller = DatasetChatModelController();
  controller.applyModelsResponse({
    'providers': <Object?>[
      {
        'name': 'openai-work',
        'friendly_name': 'ChatGPT Work',
        'models': <Object?>[
          {'name': 'gpt-4.1', 'friendly_name': 'GPT-4.1', 'active': true},
        ],
      },
      if (includeCodex)
        {
          'name': 'openai-codex',
          'friendly_name': 'ChatGPT Codex',
          'models': <Object?>[
            {'name': 'codex', 'friendly_name': 'Codex'},
          ],
        },
    ],
  });
  return controller;
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

  testWidgets('v1 MCP menu hides Add for non-admin users', (tester) async {
    final room = _roomClientWithAdminGrant(isAdmin: false);
    addTearDown(room.dispose);
    final controller = ChatThreadController(room: room);
    addTearDown(controller.dispose);
    controller.setMcpConnectorSelected(OpenAIConnectors.gmail, true);

    await tester.pumpWidget(_buildHarness(room: room, controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Attach files'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect MCPs'));
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

    await tester.tap(find.byTooltip('Attach files'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect MCPs'));
    await tester.pumpAndSettle();

    expect(find.text('Add...'), findsOneWidget);
  });

  testWidgets('v1 MCP submenu stacks without overflow at narrow widths', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final room = _roomClientWithAdminGrant(isAdmin: false);
    addTearDown(room.dispose);
    final controller = ChatThreadController(room: room);
    addTearDown(controller.dispose);
    controller.setMcpConnectorSelected(OpenAIConnectors.gmail, true);

    await tester.pumpWidget(_buildHarness(room: room, controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Attach files'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect MCPs'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Connect MCPs'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(1000, 760));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Connect MCPs'), findsOneWidget);
  });

  testWidgets('v1 model selector appears only when the assistant has multiple models', (tester) async {
    final room = _roomClientWithAdminGrant(isAdmin: false);
    addTearDown(room.dispose);
    final controller = ChatThreadController(room: room);
    addTearDown(controller.dispose);
    final oneModelController = _modelController(includeCodex: false);
    addTearDown(oneModelController.dispose);

    await tester.pumpWidget(_buildHarness(room: room, controller: controller, modelController: oneModelController));
    await tester.pumpAndSettle();

    expect(find.text('ChatGPT Work'), findsNothing);

    final multiModelController = _modelController(includeCodex: true);
    addTearDown(multiModelController.dispose);
    await tester.pumpWidget(_buildHarness(room: room, controller: controller, modelController: multiModelController));
    await tester.pumpAndSettle();

    expect(find.text('ChatGPT Work'), findsOneWidget);
  });

  testWidgets('v1 model selector changes through the typed model controller', (tester) async {
    final room = _roomClientWithAdminGrant(isAdmin: false);
    addTearDown(room.dispose);
    final controller = ChatThreadController(room: room);
    addTearDown(controller.dispose);
    final modelController = _modelController(includeCodex: true);
    addTearDown(modelController.dispose);
    DatasetChatModelOption? changedTo;
    modelController.bindChangeHandler((option) async {
      changedTo = option;
      modelController.applyModelChanged({
        'provider': option.provider,
        'model': option.model,
        'provider_friendly_name': option.providerFriendlyName,
        'model_friendly_name': option.modelFriendlyName,
      });
    });

    await tester.pumpWidget(_buildHarness(room: room, controller: controller, modelController: modelController));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ChatGPT Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ChatGPT Codex'));
    await tester.pumpAndSettle();

    expect(changedTo?.provider, 'openai-codex');
    expect(modelController.activeModel?.key, changedTo?.key);
    expect(find.text('ChatGPT Codex'), findsOneWidget);
  });

  test('v1 model labels disambiguate multiple models from the same provider', () {
    const first = DatasetChatModelOption(
      provider: 'anthropic',
      providerFriendlyName: 'Claude',
      model: 'sonnet',
      modelFriendlyName: 'Sonnet',
    );
    const second = DatasetChatModelOption(provider: 'anthropic', providerFriendlyName: 'Claude', model: 'opus', modelFriendlyName: 'Opus');

    expect(powerboardsV1ModelLabel(first, const [first, second]), 'Claude / Sonnet');
    expect(powerboardsV1ModelLabel(second, const [first, second]), 'Claude / Opus');
  });
}
