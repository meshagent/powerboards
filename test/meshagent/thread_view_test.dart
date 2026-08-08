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
import 'package:meshagent_flutter_shadcn/markdown_viewer.dart';
import 'package:meshagent_flutter_shadcn/thread_typography.dart';
import 'package:powerboards/meshagent/agent_participants.dart';
import 'package:powerboards/meshagent/desktop_chat_attach_button.dart';
import 'package:powerboards/meshagent/folder_chat_context.dart';
import 'package:powerboards/meshagent/file_reference_registry.dart';
import 'package:powerboards/meshagent/mobile_chat_attach_button.dart';
import 'package:powerboards/meshagent/thread_view.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_file_select_dialog.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_svg_icon.dart';
import 'package:powerboards/powerboards_ui/v1/components/chat/pb_folder_thread_attachment_card.dart';
import 'package:powerboards/powerboards_ui/v1/components/chat/pb_unavailable_thread_attachment.dart';
import 'package:powerboards/settings/ui_mode.dart';
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
  const _ThreadViewHarness({
    required this.room,
    this.composerAttachmentPaths = const [],
    this.composerAttachmentDisplayNamesByPath = const {},
    this.composerAttachmentSeedVersion = 0,
  });

  final RoomClient room;
  final List<String> composerAttachmentPaths;
  final Map<String, String> composerAttachmentDisplayNamesByPath;
  final int composerAttachmentSeedVersion;

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
      composerAttachmentPaths: widget.composerAttachmentPaths,
      composerAttachmentDisplayNamesByPath: widget.composerAttachmentDisplayNamesByPath,
      composerAttachmentSeedVersion: widget.composerAttachmentSeedVersion,
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

  test('composer attachment seed matching preserves nested and root folder identities', () {
    final nestedFolder = powerboardsFolderChatContextDataUrl('content/research');
    final rootFolder = powerboardsFolderChatContextDataUrl('');

    expect(powerboardsComposerAttachmentSeedMatchesAttachmentPaths(seedPaths: [nestedFolder], attachmentPaths: [nestedFolder]), isTrue);
    expect(powerboardsComposerAttachmentSeedMatchesAttachmentPaths(seedPaths: [rootFolder], attachmentPaths: [rootFolder]), isTrue);
    expect(powerboardsComposerAttachmentSeedMatchesAttachmentPaths(seedPaths: [rootFolder], attachmentPaths: [nestedFolder]), isFalse);
  });

  test('V1 active thread session identity survives Files navigation but changes with the active thread', () {
    final beforeFiles = powerboardsV1ActiveThreadSessionKey(
      agentKey: 'assistant',
      documentPath: '.threads/main.thread',
      selectedThreadPath: 'dataset://agents/assistant/threads/launch',
    );
    final afterFiles = powerboardsV1ActiveThreadSessionKey(
      agentKey: 'assistant',
      documentPath: '.threads/main.thread',
      selectedThreadPath: 'dataset://agents/assistant/threads/launch',
    );
    final nextThread = powerboardsV1ActiveThreadSessionKey(
      agentKey: 'assistant',
      documentPath: '.threads/main.thread',
      selectedThreadPath: 'dataset://agents/assistant/threads/follow-up',
    );

    expect(afterFiles, beforeFiles);
    expect(nextThread, isNot(beforeFiles));
  });

  testWidgets('V1 file reference loading waits for the room identity', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final previousMode = powerboardsUiModeSignal.value;
    powerboardsUiModeSignal.value = PowerboardsUiMode.v1;
    addTearDown(() => powerboardsUiModeSignal.value = previousMode);

    final pair = _ProtocolPair();
    var registryDownloadRequested = false;
    pair.serverProtocol.start(
      onMessage: (protocol, messageId, type, data) async {
        if (type != 'room.invoke_tool') {
          return;
        }
        final request = unpackMessage(data).header;
        if (request['toolkit'] != 'storage' || request['tool'] != 'download') {
          return;
        }
        registryDownloadRequested = true;
        await protocol.send('__response__', ErrorContent(text: 'registry not found', code: 404).pack(), id: messageId);
      },
    );

    final room = RoomClient(protocolFactory: pair.clientProtocolFactory);
    final startFuture = room.start();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
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
    await tester.pump();
    expect(registryDownloadRequested, isFalse);

    await _sendRoomReady(pair.serverProtocol);
    await startFuture;
    for (var attempt = 0; attempt < 20 && !registryDownloadRequested; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(registryDownloadRequested, isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  });

  test('folder and file chat links dispatch to Files navigation and file preview', () {
    String? openedFolder;
    String? previewedFile;

    expect(
      powerboardsHandleChatLink(
        url: 'powerboards://files?path=content%2Fresearch',
        onOpenFolder: (path) => openedFolder = path,
        onOpenFilePreview: (path) => previewedFile = path,
      ),
      isTrue,
    );
    expect(openedFolder, 'content/research');
    expect(previewedFile, isNull);

    expect(
      powerboardsHandleChatLink(
        url: 'powerboards://preview?path=content%2Fresearch%2Fnotes.md',
        onOpenFolder: (path) => openedFolder = path,
        onOpenFilePreview: (path) => previewedFile = path,
      ),
      isTrue,
    );
    expect(previewedFile, 'content/research/notes.md');
    expect(
      powerboardsHandleChatLink(
        url: 'powerboards://preview?path=documents%2FScreenshot% 2026-06-02%20at%2010.06.10%20AM.png',
        onOpenFolder: (path) => openedFolder = path,
        onOpenFilePreview: (path) => previewedFile = path,
      ),
      isTrue,
    );
    expect(previewedFile, 'documents/Screenshot 2026-06-02 at 10.06.10 AM.png');
    expect(
      powerboardsHandleChatLink(
        url: 'https://example.com',
        onOpenFolder: (path) => openedFolder = path,
        onOpenFilePreview: (path) => previewedFile = path,
      ),
      isFalse,
    );
  });

  test('Assistant response links resolve moved folder and file identities in the current room', () {
    final references = <PowerboardsFileReference>[
      PowerboardsFileReference(
        sourceRoomName: 'room',
        sourcePath: 'drafts',
        destinationRoomName: 'room',
        destinationPath: 'published',
        operation: PowerboardsFileTransferOperation.move,
        folder: true,
        updatedAt: DateTime.utc(2026, 8, 6),
      ),
    ];

    expect(powerboardsResolveChatLinkCurrentPath(roomName: 'room', path: 'drafts', references: references), 'published');
    expect(
      powerboardsResolveChatLinkCurrentPath(roomName: 'room', path: 'drafts/overview.md', references: references),
      'published/overview.md',
    );
  });

  test('deleted folder attachments retain their captured display name', () {
    final folderAttachment = powerboardsFolderChatContextDataUrl('content/old-name', displayName: 'Project Atlas');

    expect(powerboardsV1ThreadAttachmentDisplayName(folderAttachment, fallback: 'Inline attachment (text/plain)'), 'Project Atlas');
  });

  testWidgets('renamed folder notice uses the V1 dialog and confirms navigation', (tester) async {
    bool? confirmed;
    await tester.pumpWidget(
      _buildResponsiveTestApp(
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                confirmed = await showPbRenamedFolderLinkDialog(context, previousName: 'drafts', currentName: 'published');
              },
              child: const Text('Open folder'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open folder'));
    await tester.pumpAndSettle();

    expect(find.text('Folder renamed'), findsOneWidget);
    expect(find.text('“drafts” is now “published”. Select OK to open the renamed folder.'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets('rendered folder file links preserve spaced filenames for preview dispatch', (tester) async {
    Future<String?> tapRenderedLink(String destination) async {
      String? tappedUrl;
      await tester.pumpWidget(
        _buildResponsiveTestApp(
          child: ThreadTypographyOverride(
            markdownTextTransformer: powerboardsCanonicalizeMalformedPreviewMarkdownLinks,
            markdownLinkHandler: (context, url) {
              tappedUrl = url;
              return true;
            },
            child: Scaffold(
              body: MarkdownViewer(markdown: '[Screenshot 2026-06-02 at 10.06.10 AM.png]($destination)', padding: EdgeInsets.zero),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final link = find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText().contains('Screenshot 2026-06-02 at 10.06.10 AM.png'),
      );
      expect(link, findsOneWidget);
      await tester.tap(link);
      await tester.pump();
      return tappedUrl;
    }

    expect(
      await tapRenderedLink('powerboards://preview?path=stuff%2FScreenshot%202026-06-02%20at%2010.06.10%20AM.png'),
      'powerboards://preview?path=stuff%2FScreenshot%202026-06-02%20at%2010.06.10%20AM.png',
    );
    for (final destination in <String>[
      'powerboards://preview?path=stuff%2FScreenshot% 2026-06-02%20at%2010.06.10%20AM.png',
      'powerboards://preview?path=stuff/Screenshot 2026-06-02 at 10.06.10 AM.md',
      'powerboards://preview?path=stuff%2FScreenshot%202026-06-02%20at%2010.06.10 AM.png',
    ]) {
      final tappedUrl = await tapRenderedLink(destination);
      expect(tappedUrl, isNotNull);
      String? previewedFile;
      expect(powerboardsHandleChatLink(url: tappedUrl!, onOpenFolder: (_) {}, onOpenFilePreview: (path) => previewedFile = path), isTrue);
      expect(
        previewedFile,
        destination.endsWith('.md')
            ? 'stuff/Screenshot 2026-06-02 at 10.06.10 AM.md'
            : destination.contains(' ')
            ? 'stuff/Screenshot 2026-06-02 at 10.06.10 AM.png'
            : 'stuff/Screenshot 2026-06-02 at 10.06.10 AM.png',
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('composer attachment seed appears in the new thread composer', (tester) async {
    final room = RoomClient(protocolFactory: () => Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);

    await tester.pumpWidget(
      _buildResponsiveTestApp(
        child: Scaffold(
          body: SizedBox.expand(
            child: _ThreadViewHarness(
              room: room,
              composerAttachmentPaths: const ['room:///docs/brief.pdf'],
              composerAttachmentSeedVersion: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('brief.pdf'), findsOneWidget);
  });

  test('webserver folder links clear stale preview query parameters', () {
    final nextUri = powerboardsV1ThreadRouteUri(
      currentUri: Uri.parse('/p/project/r/room?pane=chat&webserver_preview=1&thread=abc'),
      pane: 'files',
      rawPath: 'website/',
      removeQueryParameters: const {'webserver_preview'},
    );

    expect(nextUri.queryParameters['pane'], 'files');
    expect(nextUri.queryParameters['p'], 'website/');
    expect(nextUri.queryParameters['thread'], 'abc');
    expect(nextUri.queryParameters.containsKey('webserver_preview'), isFalse);
  });

  test('V1 webserver product links accept only paths inside the website root', () {
    expect(
      powerboardsV1WebServerProductLinkStoragePath(Uri.parse('powerboards://preview/webserver?path=website%2Findex.html')),
      'website/index.html',
    );
    expect(
      powerboardsV1WebServerProductLinkStoragePath(Uri.parse('powerboards://files/webserver?path=website%2Fassets')),
      'website/assets',
    );
    expect(powerboardsV1WebServerProductLinkStoragePath(Uri.parse('powerboards://preview/webserver?path=private.txt')), isNull);
    expect(
      powerboardsV1WebServerProductLinkStoragePath(Uri.parse('powerboards://preview/webserver?path=website%2F..%2Fprivate.txt')),
      isNull,
    );
  });

  testWidgets('composer attachment seed uses the provided display name', (tester) async {
    final room = RoomClient(protocolFactory: () => Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);

    await tester.pumpWidget(
      _buildResponsiveTestApp(
        child: Scaffold(
          body: SizedBox.expand(
            child: _ThreadViewHarness(
              room: room,
              composerAttachmentPaths: const ['room:///website'],
              composerAttachmentDisplayNamesByPath: const {'website': 'hellotimber.meshagent.dev'},
              composerAttachmentSeedVersion: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('hellotimber.meshagent.dev'), findsOneWidget);
  });

  testWidgets('Files root folder context appears in the new thread composer', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final previousMode = powerboardsUiModeSignal.value;
    powerboardsUiModeSignal.value = PowerboardsUiMode.v1;
    addTearDown(() => powerboardsUiModeSignal.value = previousMode);
    final room = RoomClient(protocolFactory: () => Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);

    await tester.pumpWidget(
      _buildResponsiveTestApp(
        child: Scaffold(
          body: SizedBox.expand(
            child: _ThreadViewHarness(
              room: room,
              composerAttachmentPaths: [powerboardsFolderChatContextDataUrl('')],
              composerAttachmentSeedVersion: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Files'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is PbSvgIcon && widget.assetName == 'folder'), findsOneWidget);
  });

  testWidgets('wrapped folder context renders as a folder card in a thread', (tester) async {
    final wrappedContext = 'room:///${powerboardsFolderChatContextDataUrl('')}';

    await tester.pumpWidget(
      ShadApp(
        home: Builder(
          builder: (context) {
            return powerboardsFolderThreadAttachmentBuilder(context, wrappedContext)!;
          },
        ),
      ),
    );

    final card = tester.widget<PbFolderThreadAttachmentCard>(find.byType(PbFolderThreadAttachmentCard));
    expect(card.title, 'Files');
    expect(find.text('Files'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is PbSvgIcon && widget.assetName == 'folder'), findsOneWidget);
    expect(find.textContaining('base64'), findsNothing);
  });

  testWidgets('folder thread renderer leaves ordinary files to the existing file preview renderer', (tester) async {
    Widget? folderAttachment;
    Widget? malformedPercentPngAttachment;

    await tester.pumpWidget(
      ShadApp(
        home: Builder(
          builder: (context) {
            folderAttachment = powerboardsFolderThreadAttachmentBuilder(context, 'scratch.md');
            malformedPercentPngAttachment = powerboardsFolderThreadAttachmentBuilder(context, 'Screenshot% image.png');
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(folderAttachment, isNull);
    expect(malformedPercentPngAttachment, isNull);
    expect(find.byType(PbFolderThreadAttachmentCard), findsNothing);
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

  testWidgets('v1 desktop Add from room opens the migrated file select dialog', (tester) async {
    final room = RoomClient(protocolFactory: () => Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);

    final controller = ChatThreadController(room: room);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildResponsiveTestApp(
        mediaQueryData: const MediaQueryData(size: Size(1024, 768)),
        child: Scaffold(
          body: Center(
            child: PowerboardsDesktopChatAttachButton(
              controller: controller,
              useV1Menu: true,
              triggerBuilder: (context, onPressed) => TextButton(onPressed: onPressed, child: const Text('Open attach menu')),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open attach menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Add from room...'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(PbFileSelectDialog), findsOneWidget);
    expect(find.text('Select files'), findsOneWidget);
    expect(find.text('Attach files from this room'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(PbFileSelectDialog), findsNothing);
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
