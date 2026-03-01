import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:meshagent_flutter_shadcn/viewers/file.dart';
import 'package:path/path.dart' as p;
import 'package:powerboards/meshagent/document_pane.dart';
import 'package:powerboards/nav/delete_room_dialog.dart';
import 'package:powerboards/nav/rename_room_dialog.dart';
import 'package:powerboards/ui/hover_builder.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/chat/outbound_delivery_status.dart';
import 'package:meshagent_flutter_shadcn/meshagent_flutter_shadcn.dart' as ma;

import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/upload_foldername_service.dart';
import 'package:powerboards/theme/theme.dart';
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
    String messageType = "chat",
    void Function(ma.ChatMessage)? onMessageSent,
  }) async {
    if (message.text.trim().isNotEmpty || message.attachments.isNotEmpty) {
      insertMessage(thread: thread, message: message);

      outboundStatus.markSending(message.id);

      bool added = false;
      void waitForAgent() async {
        if (agentName != null && room.messaging.remoteParticipants.where((x) => x.getAttribute("name") == agentName).isEmpty) {
          if (!added) {
            room.messaging.addListener(waitForAgent);
            added = true;
          }
        } else {
          if (added) {
            room.messaging.removeListener(waitForAgent);
          }
          for (final participant in getOnlineParticipants(thread)) {
            sendMessageToParticipant(participant: participant, path: path, message: message, messageType: messageType);
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
    this.threadingMode,
    this.threadListPath,
    this.newThreadResetVersion = 0,

    this.participantNames,

    this.initialMessageID,
    this.initialMessageText,
    this.initialMessageAttachments,
    this.agentName,

    this.emptyState,
    required this.services,
  });

  final String? agentName;
  final String? threadingMode;
  final String? threadListPath;
  final int newThreadResetVersion;
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
  static const double _threadListPanelWidth = 300;
  static const double _minChatAreaWidthWithThreadList = 600;

  late final _agentName = ValueNotifier(widget.agentName);

  late final ChatThreadController _chatController;
  late String _documentPath;
  late String? _initialMessageText;

  OutboundEntry? _currentStatusEntry;
  MeshDocument? _threadListDocument;
  RoomClient? _threadListClient;
  String? _threadListPath;
  Object? _threadListError;
  bool _threadListLoading = false;
  String? _selectedThreadPath;
  String? _activeThreadPath;
  int _inlineNewThreadResetVersion = 0;
  String? _threadListIndexPathOverride;

  String? _threadListIndexPathFromDocumentPath(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final directory = p.posix.dirname(normalized);
    return p.posix.join(directory, "index.threadl");
  }

  String? _normalizedThreadListPath(String? path) {
    if (path == null) {
      return null;
    }

    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  String? _threadListIndexPathFromThreadPath(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return p.posix.join(p.posix.dirname(normalized), "index.threadl");
  }

  String? _resolvedThreadListPath() {
    return _threadListIndexPathOverride ??
        _normalizedThreadListPath(widget.threadListPath) ??
        _threadListIndexPathFromDocumentPath(widget.documentPath);
  }

  DateTime _parseThreadDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return parsed.toUtc();
  }

  DateTime _threadSortDate(_ThreadListEntry entry) {
    if (entry.modifiedAt.trim().isNotEmpty) {
      return _parseThreadDate(entry.modifiedAt);
    }
    if (entry.createdAt.trim().isNotEmpty) {
      return _parseThreadDate(entry.createdAt);
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  String _threadNameFromPath(String path) {
    final filename = p.posix.basename(path);
    if (filename.endsWith(".thread")) {
      return filename.substring(0, filename.length - ".thread".length);
    }
    return filename;
  }

  List<_ThreadListEntry> _threadListEntries() {
    final document = _threadListDocument;
    if (document == null) {
      return const [];
    }

    final entries = <_ThreadListEntry>[];
    for (final node in document.root.getChildren()) {
      if (node is! MeshElement || node.tagName != "thread") {
        continue;
      }

      final rawPath = node.getAttribute("path");
      if (rawPath is! String || rawPath.trim().isEmpty) {
        continue;
      }
      final path = rawPath.trim();

      final rawName = node.getAttribute("name");
      final name = rawName is String && rawName.trim().isNotEmpty ? rawName.trim() : _threadNameFromPath(path);
      final createdAt = node.getAttribute("created_at");
      final modifiedAt = node.getAttribute("modified_at");

      entries.add(
        _ThreadListEntry(
          element: node,
          name: name,
          path: path,
          createdAt: createdAt is String ? createdAt : "",
          modifiedAt: modifiedAt is String ? modifiedAt : "",
        ),
      );
    }

    entries.sort((a, b) => _threadSortDate(b).compareTo(_threadSortDate(a)));
    return entries;
  }

  bool _threadListContainsPath(String path) {
    final document = _threadListDocument;
    if (document == null) {
      return false;
    }

    for (final node in document.root.getChildren()) {
      if (node is! MeshElement || node.tagName != "thread") {
        continue;
      }
      if (node.getAttribute("path") == path) {
        return true;
      }
    }

    return false;
  }

  void _onThreadListChanged() {
    if (!mounted) {
      return;
    }

    final selectedPath = _selectedThreadPath;
    if (selectedPath != null && !_threadListContainsPath(selectedPath)) {
      _selectedThreadPath = null;
      if (_activeThreadPath == selectedPath) {
        _activeThreadPath = null;
      }
      _inlineNewThreadResetVersion++;
    }

    setState(() {});
  }

  Future<void> _closeThreadListDocument() async {
    final document = _threadListDocument;
    final path = _threadListPath;
    final closeClient = _threadListClient ?? widget.client;

    if (document != null) {
      document.removeListener(_onThreadListChanged);
    }

    _threadListDocument = null;
    _threadListClient = null;
    _threadListPath = null;
    _threadListLoading = false;

    if (path != null) {
      try {
        await closeClient.sync.close(path);
      } catch (_) {}
    }
  }

  Future<void> _rebindThreadListDocument() async {
    final nextPath = widget.threadingMode == "default-new" ? _resolvedThreadListPath() : null;
    if (nextPath == _threadListPath && _threadListDocument != null) {
      return;
    }

    await _closeThreadListDocument();

    if (!mounted) {
      return;
    }

    if (nextPath == null) {
      setState(() {
        _threadListError = null;
      });
      return;
    }

    setState(() {
      _threadListLoading = true;
      _threadListError = null;
    });

    try {
      final document = await widget.client.sync.open(nextPath);
      if (!mounted || widget.threadingMode != "default-new") {
        try {
          await widget.client.sync.close(nextPath);
        } catch (_) {}
        return;
      }

      final expectedPath = _resolvedThreadListPath();
      if (expectedPath != nextPath) {
        try {
          await widget.client.sync.close(nextPath);
        } catch (_) {}
        return;
      }

      document.addListener(_onThreadListChanged);
      setState(() {
        _threadListDocument = document;
        _threadListClient = widget.client;
        _threadListPath = nextPath;
        _threadListLoading = false;
        _threadListError = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _threadListDocument = null;
        _threadListClient = null;
        _threadListPath = null;
        _threadListLoading = false;
        _threadListError = e;
      });
    }
  }

  void _onNewThreadPathChanged(String? path) {
    if (!mounted) {
      return;
    }

    final nextIndexPath = path == null ? _threadListIndexPathOverride : _threadListIndexPathFromThreadPath(path);
    final needsRebind = path != null && nextIndexPath != null && nextIndexPath != _threadListIndexPathOverride;
    if (_activeThreadPath == path && !needsRebind) {
      return;
    }

    setState(() {
      _activeThreadPath = path;
      if (path != null && nextIndexPath != null) {
        _threadListIndexPathOverride = nextIndexPath;
      }
    });

    if (needsRebind) {
      unawaited(_rebindThreadListDocument());
    }
  }

  void _openThreadFromList(String path) {
    final nextIndexPath = _threadListIndexPathFromThreadPath(path);
    final needsRebind = nextIndexPath != null && nextIndexPath != _threadListIndexPathOverride;
    if (_selectedThreadPath == path) {
      return;
    }

    setState(() {
      _selectedThreadPath = path;
      _activeThreadPath = path;
      if (nextIndexPath != null) {
        _threadListIndexPathOverride = nextIndexPath;
      }
    });

    if (needsRebind) {
      unawaited(_rebindThreadListDocument());
    }
  }

  Future<void> _renameThread(_ThreadListEntry entry) async {
    final newName = await showRenameRoomDialog(
      context,
      title: "Rename thread",
      description: "Choose a clear name for this conversation.",
      initialValue: entry.name,
      label: "Name",
      placeholder: "e.g. Sprint planning",
    );
    if (newName == null) {
      return;
    }

    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == entry.name) {
      return;
    }

    entry.element.setAttribute("name", trimmed);
  }

  Future<void> _deleteThread(_ThreadListEntry entry) async {
    final confirmed =
        await showDeleteRoomDialog(
          context,
          title: "Delete thread",
          description: "Are you sure you want to delete \"${entry.name}\"? This cannot be undone.",
          confirmText: "Delete",
          destructive: true,
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    final isOpen = _activeThreadPath == entry.path || _selectedThreadPath == entry.path;
    if (isOpen) {
      setState(() {
        _selectedThreadPath = null;
        _activeThreadPath = null;
        _inlineNewThreadResetVersion++;
      });

      await WidgetsBinding.instance.endOfFrame;
    }

    try {
      await widget.client.storage.delete(entry.path);
      entry.element.delete();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ShadToaster.of(context).show(ShadToast.destructive(description: Text("Unable to delete thread: $e")));
    }
  }

  @override
  void didUpdateWidget(covariant MeshagentThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _agentName.value = widget.agentName;

    if (oldWidget.agentName != widget.agentName ||
        oldWidget.threadingMode != widget.threadingMode ||
        oldWidget.documentPath != widget.documentPath ||
        oldWidget.threadListPath != widget.threadListPath) {
      _documentPath = widget.documentPath;
      _initialMessageText = widget.initialMessageText;
      _threadListIndexPathOverride = null;
    } else if (oldWidget.initialMessageText != widget.initialMessageText && widget.threadingMode != "default-new") {
      _initialMessageText = widget.initialMessageText;
    }

    if (widget.threadingMode == "default-new" && oldWidget.newThreadResetVersion != widget.newThreadResetVersion) {
      _selectedThreadPath = null;
      _activeThreadPath = null;
      _inlineNewThreadResetVersion++;
    }

    if (oldWidget.client != widget.client ||
        oldWidget.documentPath != widget.documentPath ||
        oldWidget.threadListPath != widget.threadListPath ||
        oldWidget.threadingMode != widget.threadingMode) {
      unawaited(_rebindThreadListDocument());
    }
  }

  @override
  void initState() {
    super.initState();

    _chatController = MeshagentRoomChatThreadController(room: widget.client, agentName: widget.agentName);
    _documentPath = widget.documentPath;
    _initialMessageText = widget.initialMessageText;

    _chatController.outboundStatus.addListener(_onStatusChange);
    unawaited(_rebindThreadListDocument());
  }

  void _onStatusChange() {
    setState(() {
      _currentStatusEntry = _chatController.outboundStatus.currentEntry();
    });
  }

  @override
  void dispose() {
    unawaited(_closeThreadListDocument());
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

  Widget _buildThread({required String path, required String? initialMessageText, Widget Function(BuildContext)? loadingBuilder}) {
    return IconTheme(
      data: const IconThemeData(size: 14),
      child: ChatThreadLoader(
        key: ValueKey(path),
        room: widget.client,
        loadingBuilder: loadingBuilder ?? (context) => const SizedBox.shrink(),
        path: path,
        builder: (context, document) => ChatThreadSender(
          controller: _chatController,
          document: document,
          documentPath: path,
          initialMessageID: initialMessageText == null ? null : widget.initialMessageID,
          initialMessageText: initialMessageText,
          initialMessageAttachments: widget.initialMessageAttachments,
          onMessageSent: _onMessageSent,
          child: ChatThreadBuilder(
            agentName: widget.agentName,
            path: path,
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
                        path: path,
                        room: widget.client,
                        messages: snapshot.messages,
                        online: snapshot.online,
                        showTyping: (snapshot.threadStatusMode != null) && snapshot.listening.isEmpty,
                        showListening: snapshot.listening.isNotEmpty,
                        threadStatus: snapshot.threadStatus,
                        threadStatusMode: snapshot.threadStatusMode,
                        onCancel: () {
                          _chatController.cancel(path, document);
                        },
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
                                          widget.client.messaging.sendMessage(to: participant, type: "clear", message: {"path": path});
                                        }
                                      },
                                      placeholder: widget.agentName == null ? Text("Message") : Text("Send a message or @$agentName"),
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
                                      trailing: null,
                                      room: widget.client,
                                      onSend: (value, attachments) {
                                        final messageType = snapshot.threadStatusMode == "steerable" ? "steer" : "chat";
                                        final message = ma.ChatMessage(
                                          id: const Uuid().v4(),
                                          text: value,
                                          attachments: attachments.map((x) => x.path).toList(),
                                        );

                                        _chatController.send(
                                          thread: document,
                                          path: path,
                                          message: message,
                                          messageType: messageType,
                                          onMessageSent: _onMessageSent,
                                        );
                                      },
                                      onChanged: (value, attachments) {
                                        for (final part in snapshot.online) {
                                          if (part.id != widget.client.localParticipant?.id) {
                                            widget.client.messaging.sendMessage(to: part, type: "typing", message: {"path": path});
                                          }
                                        }
                                      },
                                      controller: _chatController,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
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

  Widget _buildThreadListPanel(BuildContext context) {
    final entries = _threadListEntries();
    final activePath = _selectedThreadPath ?? _activeThreadPath;
    final cs = ShadTheme.of(context).colorScheme;
    final tt = ShadTheme.of(context).textTheme;

    return SizedBox(
      width: _threadListPanelWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: ShadButton.ghost(
              onPressed: () {
                if (_selectedThreadPath == null && _activeThreadPath == null) {
                  return;
                }
                setState(() {
                  _selectedThreadPath = null;
                  _activeThreadPath = null;
                  _inlineNewThreadResetVersion++;
                });
              },
              mainAxisAlignment: MainAxisAlignment.start,
              expands: true,
              leading: const Icon(LucideIcons.plus, size: 16),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text("New Thread", textAlign: TextAlign.start),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text("Threads", style: tt.small.copyWith(color: cs.foreground.withValues(alpha: .5))),
            ),
          ),
          Expanded(
            child: _threadListLoading
                ? const Center(child: CircularProgressIndicator())
                : _threadListError != null
                ? const Center(child: Text("Unable to load thread list"))
                : entries.isEmpty
                ? const Center(child: Text("No threads yet"))
                : SuperListView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    children: [
                      for (final entry in entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _ThreadListItem(
                            entry: entry,
                            selected: entry.path == activePath,
                            onOpen: () => _openThreadFromList(entry.path),
                            onRename: () => _renameThread(entry),
                            onDelete: () => _deleteThread(entry),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultNewThreadContent(BuildContext context, {required String agentName}) {
    final threadPath = _selectedThreadPath;
    final hasThreadEntries = _threadListEntries().isNotEmpty;
    final threadContent = threadPath == null
        ? ma.NewChatThread(
            key: ValueKey("new-thread-$agentName-${widget.newThreadResetVersion}-$_inlineNewThreadResetVersion"),
            room: widget.client,
            agentName: agentName,
            onThreadPathChanged: _onNewThreadPathChanged,
            toolsBuilder: (context, controller, snapshot) =>
                buildTools(context, widget.client, agentName, controller, snapshot, widget.services),
            builder: (context, path, loadingBuilder) => _buildThread(path: path, initialMessageText: null, loadingBuilder: loadingBuilder),
          )
        : _buildThread(path: threadPath, initialMessageText: null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final showThreadList =
            hasThreadEntries && maxWidth.isFinite && (maxWidth - _threadListPanelWidth) >= _minChatAreaWidthWithThreadList;

        if (!showThreadList) {
          return threadContent;
        }

        return Row(
          children: [
            Expanded(child: threadContent),
            _buildThreadListPanel(context),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.threadingMode == "default-new") {
      final agentName = widget.agentName;
      if (agentName == null) {
        return Center(
          child: ShadAlert.destructive(title: Text("Unable to start a new thread"), description: Text("No chat agent is selected.")),
        );
      }

      return _buildDefaultNewThreadContent(context, agentName: agentName);
    }

    return _buildThread(path: _documentPath, initialMessageText: _initialMessageText);
  }
}

class _ThreadListEntry {
  const _ThreadListEntry({
    required this.element,
    required this.name,
    required this.path,
    required this.createdAt,
    required this.modifiedAt,
  });

  final MeshElement element;
  final String name;
  final String path;
  final String createdAt;
  final String modifiedAt;
}

class _ThreadListItem extends StatefulWidget {
  const _ThreadListItem({
    required this.entry,
    required this.selected,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final _ThreadListEntry entry;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  State<_ThreadListItem> createState() => _ThreadListItemState();
}

class _ThreadListItemState extends State<_ThreadListItem> {
  late final ShadContextMenuController _menuController = ShadContextMenuController();

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;
    final tt = ShadTheme.of(context).textTheme;

    return HoverBuilder(
      builder: (context, hovered, focused) {
        final isMobile = ResponsiveBreakpoints.of(context).isMobile;
        final showMenuIcon = hovered || focused || isMobile;

        return Container(
          decoration: BoxDecoration(color: widget.selected ? cs.secondary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: ShadButton.ghost(
            onPressed: widget.onOpen,
            mainAxisAlignment: MainAxisAlignment.start,
            expands: true,
            trailing: ShadContextMenu(
              controller: _menuController,
              constraints: const BoxConstraints(minWidth: 180),
              items: [
                ShadContextMenuItem(
                  height: 40,
                  leading: const Icon(LucideIcons.pencil, size: 16),
                  onPressed: widget.onRename,
                  child: const Text("Rename"),
                ),
                ShadContextMenuItem(
                  height: 40,
                  leading: const Icon(LucideIcons.trash, size: 16),
                  onPressed: widget.onDelete,
                  child: const Text("Delete"),
                ),
              ],
              child: ShadGestureDetector(
                onTap: _menuController.show,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(child: Icon(LucideIcons.ellipsis, size: 20, color: showMenuIcon ? cs.foreground : Colors.transparent)),
                ),
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.entry.name,
                textAlign: TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: widget.selected ? tt.small.copyWith(fontWeight: FontWeight.w700) : tt.small,
              ),
            ),
          ),
        );
      },
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
  final endpointPath = e.path.startsWith('/') ? e.path : '/${e.path}';
  final port = p.num.value;

  if (s.external == null) {
    if (port == null) {
      return Uri(scheme: 'http', host: 'localhost', path: endpointPath).toString();
    }
    return Uri(scheme: 'http', host: 'localhost', port: port, path: endpointPath).toString();
  }

  final externalUrl = s.external?.url;
  if (externalUrl == null || externalUrl.isEmpty) {
    return null;
  }

  var baseUri = Uri.tryParse(externalUrl);
  if (baseUri == null) {
    return null;
  }
  if (!baseUri.hasScheme) {
    final withDefaultScheme = Uri.tryParse('https://$externalUrl');
    if (withDefaultScheme == null) {
      return null;
    }
    baseUri = withDefaultScheme;
  }
  if (!baseUri.hasAuthority) {
    return null;
  }

  final normalizedBasePath = baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path;
  final joinedPath = normalizedBasePath.isEmpty || normalizedBasePath == '/' ? endpointPath : '$normalizedBasePath$endpointPath';

  final baseWithPath = baseUri.replace(path: joinedPath);
  if (port == null) {
    return baseWithPath.toString();
  }

  return baseWithPath.replace(port: port).toString();
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
        Uri.parse("${MeshagentConfig.current?.appUrl}/oauth2/callback"),
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
