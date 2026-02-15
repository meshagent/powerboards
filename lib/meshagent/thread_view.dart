import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:meshagent_flutter_shadcn/viewers/file.dart';
import 'package:powerboards/meshagent/document_pane.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/chat/outbound_delivery_status.dart';
import 'package:meshagent_flutter_shadcn/meshagent_flutter_shadcn.dart' as ma;

import 'package:powerboards/meshagent/upload_foldername_service.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/meshagent/wait_for_agent_participant_builder.dart';
import 'package:powerboards/web_context_menu_manager/enable_web_context_menu.dart';

class MeshagentRoomChatThreadController extends ChatThreadController {
  MeshagentRoomChatThreadController({required super.room, required this.agentName});

  final String? agentName;

  final folderNameService = MeshagentUploadFoldernameService();

  @override
  Future<FileAttachment> uploadFile(String path, Stream<Uint8List> dataStream, int size) async {
    final uploader = (await super.uploadFileDeferred(path, dataStream, size)) as MeshagentFileUpload;

    // Josef: Removing folder name suggestion for now
    // final folder = await folderNameService.generateFoldername(room, path);

    uploader
      ..path = path
      ..startUpload();

    return uploader;
  }

  @override
  Future<void> send({
    required MeshDocument thread,
    required String path,
    required ma.ChatMessage message,
    void Function(ma.ChatMessage)? onMessageSent,
  }) async {
    if (message.text.trim().isNotEmpty || message.attachments.isNotEmpty) {
      insertMessage(thread: thread, message: message);

      outboundStatus.markSending(message.id);

      bool added = false;
      void waitForAgent() async {
        if (agentName != null && getOfflineParticipants(thread).where((x) => x == agentName).isNotEmpty) {
          if (!added) {
            room.messaging.addListener(waitForAgent);
            added = true;
          }
        } else {
          if (added) {
            room.messaging.removeListener(waitForAgent);
          }
          if (notifyOnSend) {
            for (final participant in getOnlineParticipants(thread)) {
              sendMessageToParticipant(participant: participant, path: path, message: message);
            }
          }
          outboundStatus.markDelivered(message.id);
        }
      }

      waitForAgent();

      clear();
    }
  }
}

class ChatThreadSender extends StatefulWidget {
  const ChatThreadSender({
    super.key,
    required this.child,
    this.initialMessageID,
    this.initialMessageText,
    this.initialMessageAttachments,
    this.onMessageSent,
    required this.controller,
    required this.document,
    required this.documentPath,
  });

  final Widget child;
  final String? initialMessageID;
  final String? initialMessageText;
  final List<FileAttachment>? initialMessageAttachments;
  final void Function(ma.ChatMessage)? onMessageSent;
  final ChatThreadController controller;
  final MeshDocument document;
  final String documentPath;

  @override
  State createState() => _ChatThreadSender();
}

class _ChatThreadSender extends State<ChatThreadSender> {
  late final ChatThreadController controller;

  @override
  void initState() {
    super.initState();

    final initialMessage = (widget.initialMessageText != null)
        ? ma.ChatMessage(
            id: widget.initialMessageID!,
            text: widget.initialMessageText!,
            attachments: (widget.initialMessageAttachments?.map((a) => a.path).toList() ?? []),
          )
        : null;

    if (initialMessage != null) {
      widget.controller.send(
        thread: widget.document,
        path: widget.documentPath,
        message: initialMessage,
        onMessageSent: widget.onMessageSent,
      );
    }
  }

  @override
  Widget build(context) => widget.child;
}

class MeshagentThreadView extends StatefulWidget {
  const MeshagentThreadView({
    super.key,
    required this.client,
    required this.joinMeeting,
    this.documentPath = ".threads/main.thread",

    this.participantNames,

    this.initialMessageID,
    this.initialMessageText,
    this.initialMessageAttachments,
    this.agentName,

    this.emptyState,
    required this.services,
  });

  final String? agentName;
  final RoomClient client;
  final String documentPath;
  final void Function() joinMeeting;
  final List<String>? participantNames;

  final String? initialMessageID;
  final String? initialMessageText;
  final List<FileAttachment>? initialMessageAttachments;
  final Resource<List<ServiceSpec>> services;

  final Widget? emptyState;

  @override
  State createState() => _MeshagentThreadViewState();
}

class _MeshagentThreadViewState extends State<MeshagentThreadView> {
  late final _agentName = ValueNotifier(widget.agentName);

  late final ChatThreadController _chatController;
  late String _documentPath;
  late String? _initialMessageText;

  OutboundEntry? _currentStatusEntry;

  @override
  void didUpdateWidget(covariant MeshagentThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _agentName.value = widget.agentName;
  }

  @override
  void initState() {
    super.initState();

    _chatController = MeshagentRoomChatThreadController(room: widget.client, agentName: widget.agentName);
    _documentPath = widget.documentPath;
    _initialMessageText = widget.initialMessageText;

    _chatController.outboundStatus.addListener(_onStatusChange);
  }

  void _onStatusChange() {
    setState(() {
      _currentStatusEntry = _chatController.outboundStatus.currentEntry();
    });
  }

  @override
  void dispose() {
    _chatController.outboundStatus.removeListener(_onStatusChange);
    _chatController.dispose();

    super.dispose();
  }

  void _onMessageSent(ma.ChatMessage message) {}

  Widget _fileInThreadBuilder(BuildContext context, String path, List<MeshElement> messages) {
    if (path.endsWith('.meeting')) {
      return MeetingCard(onJoin: () => widget.joinMeeting());
    }

    return ShadGestureDetector(
      cursor: SystemMouseCursors.click,
      onTap: () => _openFileDialog(context, path, messages),
      child: ChatThreadPreview(room: widget.client, path: path),
    );
  }

  void _openFileDialog(BuildContext context, String startPath, List<MeshElement> messages) {
    final files = _collectFilePaths(messages);
    final start = files.indexOf(startPath);
    if (start == -1) return;

    showShadDialog(
      context: context,
      barrierColor: Colors.white,
      builder: (context) {
        return SafeArea(
          bottom: false,
          child: _FileViewer(room: widget.client, files: files, initialIndex: start, onClose: () => Navigator.of(context).maybePop()),
        );
      },
    );
  }

  List<String> _collectFilePaths(List<MeshElement> messages) {
    final paths = <String>[];
    for (final m in messages) {
      for (final attachment in m.getChildren()) {
        final path = (attachment as MeshElement).getAttribute("path");
        if (path != null && !path.endsWith('.meeting')) {
          paths.add(path);
        }
      }
    }
    return paths.toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: const IconThemeData(size: 14),
      child: ChatThreadLoader(
        key: ValueKey(_documentPath),
        room: widget.client,
        loadingBuilder: (context) => const SizedBox.shrink(),
        path: _documentPath,
        builder: (context, document) => ChatThreadSender(
          controller: _chatController,
          document: document,
          documentPath: _documentPath,
          initialMessageID: widget.initialMessageID,
          initialMessageText: _initialMessageText,
          initialMessageAttachments: widget.initialMessageAttachments,
          onMessageSent: _onMessageSent,
          child: ChatThreadBuilder(
            agentName: widget.agentName,
            path: _documentPath,
            document: document,
            room: widget.client,
            controller: _chatController,
            builder: (context, snapshot) {
              return FileDropArea(
                onFileDrop: (name, dataStream, size) async {
                  _chatController.uploadFile(name, dataStream, size ?? 0);
                },

                child: ValueListenableBuilder(
                  valueListenable: _agentName,
                  builder: (context, agentName, _) => Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ChatThreadMessages(
                        path: widget.documentPath,
                        room: widget.client,
                        messages: snapshot.messages,
                        online: snapshot.online,
                        showTyping: (snapshot.typing.isNotEmpty || snapshot.thinking.isNotEmpty) && snapshot.listening.isEmpty,
                        showListening: snapshot.listening.isNotEmpty,
                        fileInThreadBuilder: (context, path) => _fileInThreadBuilder(context, path, snapshot.messages),
                        currentStatusEntry: _currentStatusEntry,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 15, left: 8, right: 8),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 912),
                            child: Column(
                              children: [
                                ListenableBuilder(
                                  listenable: _chatController,
                                  builder: (context, _) => EnableWebContextMenu(
                                    child: ChatThreadInput(
                                      onClear: () {
                                        final participant = widget.client.messaging.remoteParticipants.firstWhereOrNull(
                                          (x) => x.getAttribute("name") == widget.agentName,
                                        );
                                        if (participant != null) {
                                          widget.client.messaging.sendMessage(
                                            to: participant,
                                            type: "clear",
                                            message: {"path": _documentPath},
                                          );
                                        }
                                      },
                                      placeholder: widget.agentName == null
                                          ? Text("Message")
                                          : _chatController.notifyOnSend
                                          ? Text("Send a message or @$agentName")
                                          : Text("Send a message to everyone except the $agentName"),
                                      leading: _chatController.toolkits.isEmpty
                                          ? buildTools(context, widget.client, agentName, _chatController, snapshot, widget.services)
                                          : null,
                                      footer: _chatController.toolkits.isEmpty
                                          ? null
                                          : Padding(
                                              padding: EdgeInsets.only(top: 8),
                                              child: buildTools(
                                                context,
                                                widget.client,
                                                agentName,
                                                _chatController,
                                                snapshot,
                                                widget.services,
                                              ),
                                            ),
                                      trailing: snapshot.thinking.isNotEmpty
                                          ? ShadGestureDetector(
                                              cursor: SystemMouseCursors.click,
                                              onTapDown: (_) {
                                                _chatController.cancel(_documentPath, document);
                                              },
                                              child: ShadTooltip(
                                                builder: (context) => Text("Stop"),
                                                child: Container(
                                                  width: 22,
                                                  height: 22,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: ShadTheme.of(context).colorScheme.foreground,
                                                  ),
                                                  child: Icon(LucideIcons.x, color: ShadTheme.of(context).colorScheme.background),
                                                ),
                                              ),
                                            )
                                          : null,
                                      room: widget.client,
                                      onSend: (value, attachments) {
                                        final message = ma.ChatMessage(
                                          id: const Uuid().v4(),
                                          text: value,
                                          attachments: attachments.map((x) => x.path).toList(),
                                        );

                                        _chatController.send(
                                          thread: document,
                                          path: _documentPath,
                                          message: message,
                                          onMessageSent: _onMessageSent,
                                        );
                                      },
                                      onChanged: (value, attachments) {
                                        for (final part in snapshot.online) {
                                          if (part.id != widget.client.localParticipant?.id) {
                                            widget.client.messaging.sendMessage(to: part, type: "typing", message: {"path": _documentPath});
                                          }
                                        }
                                      },
                                      controller: _chatController,
                                    ),
                                  ),
                                ),
                                if (agentName != null)
                                  WaitForAgentParticipantBuilder(
                                    room: widget.client,
                                    agentName: widget.agentName!,
                                    builder: (context, agent) => Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        spacing: 8,
                                        children: [
                                          ListenableBuilder(
                                            listenable: _chatController,
                                            builder: (context, _) => ShadSwitch(
                                              height: 20,
                                              width: 32,
                                              value: _chatController.notifyOnSend,
                                              onChanged: (value) => _chatController.notifyOnSend = value,
                                            ),
                                          ),
                                          ListenableBuilder(
                                            listenable: _chatController,
                                            builder: (context, _) => Text("include $agentName in replies"),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      if (agentName == null) SizedBox(height: 10),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        participantNames: widget.participantNames,
      ),
    );
  }
}

class MeetingCard extends StatelessWidget {
  const MeetingCard({super.key, required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onJoin,
      child: ShadAlert(icon: Icon(LucideIcons.video), title: Text('Meeting'), description: Text('Join meeting to start')),
    );
  }
}

class _FileViewer extends StatefulWidget {
  const _FileViewer({required this.room, required this.files, required this.initialIndex, required this.onClose});

  final RoomClient room;
  final List<String> files;
  final int initialIndex;
  final VoidCallback onClose;

  @override
  State<_FileViewer> createState() => _FileViewerState();
}

class _FileViewerState extends State<_FileViewer> {
  late int _index;

  String get _currentPath => widget.files[_index];
  String get _fileTitle => _currentPath.split('/').last;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  void _cycle(int d) => setState(() => _index = (_index + d + widget.files.length) % widget.files.length);
  void _prev() => _cycle(-1);
  void _next() => _cycle(1);

  Future<void> _download() async {
    final url = await widget.room.storage.downloadUrl(_currentPath);
    launchUrl(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _prev,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
      },
      child: Focus(
        autofocus: true,
        child: SizedBox.expand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: headerHeight,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    Row(
                      children: [
                        Tooltip(
                          message: "Close file",
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: ShadIconButton.ghost(icon: const Icon(LucideIcons.x), onPressed: widget.onClose),
                          ),
                        ),
                        Tooltip(
                          message: "Previous file",
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: ShadIconButton.outline(icon: const Icon(LucideIcons.chevronLeft), onPressed: _prev),
                          ),
                        ),
                        Tooltip(
                          message: "Next file",
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: ShadIconButton.outline(icon: const Icon(LucideIcons.chevronRight), onPressed: _next),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          _fileTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: "Download",
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: ShadIconButton.outline(icon: const Icon(LucideIcons.download), onPressed: _download),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1600),
                    child: fileViewer(widget.room, _currentPath) ?? DocumentPane(path: _currentPath, room: widget.room),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final webSearch = StaticToolkitBuilderOption(
  icon: LucideIcons.search,
  config: WebSearchConfig(),
  text: "Web search",
  selectedText: "Search",
);
final imageGen = StaticToolkitBuilderOption(
  icon: LucideIcons.image,
  config: ImageGenerationConfig(),
  text: "Image generation",
  selectedText: "Images",
);
final mcp = ConnectorToolkitBuilderOption(icon: LucideIcons.plug, connectors: [], text: "MCP", selectedText: "MCP");
final storage = StaticToolkitBuilderOption(
  icon: LucideIcons.file,
  config: StorageConfig(),
  text: "Allow file access",
  selectedText: "Files",
);

String? getBaseUrl(ServiceSpec s, PortSpec p, EndpointSpec e) {
  if (s.external != null) {
    if (s.external?.url == null) {
      return null;
    }
    return "${s.external!.url}:${p.num}${e.path}";
  } else {
    return "http://localhost:${p.num}${e.path}";
  }
}

Widget buildTools(
  BuildContext context,
  RoomClient room,
  String? agentName,
  ChatThreadController controller,
  ChatThreadSnapshot state,
  Resource<List<ServiceSpec>> services,
) {
  return ChatThreadAttachButton(
    agentName: agentName,
    alwaysShowAttachFiles: true, // agentName == null ? true : null,
    controller: controller,
    onConnectorSetup: (connector) async {
      await connector.authenticate(
        room,
        room.messaging.remoteParticipants.firstWhereOrNull((agent) {
              return agent.getAttribute('name') == agentName;
            })
            as RemoteParticipant,
        Uri.parse("${const String.fromEnvironment('STUDIO_URL')}/oauth2/callback"),
      );
    },
    availableConnectors: [
      if (services.state.isReady)
        for (final s in services.state.value!)
          for (final p in s.ports)
            for (final e in p.endpoints)
              if (e.mcp != null)
                Connector(
                  name: e.mcp!.label,
                  server: MCPServer(serverLabel: e.mcp!.label, serverUrl: getBaseUrl(s, p, e), openaiConnectorId: e.mcp!.openaiConnectorId),
                  oauth: e.mcp!.oauth,
                ),
    ],
    toolkits: [
      for (final tool in state.availableTools) ...[
        if (tool.name == "storage") storage,
        if (tool.name == "web_search") webSearch,
        if (tool.name == "image_generation") imageGen,
        if (tool.name == "mcp") mcp,
      ],
    ],
  );
}
