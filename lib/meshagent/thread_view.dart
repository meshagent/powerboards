import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:powerboards/nav/delete_room_dialog.dart';
import 'package:powerboards/nav/rename_room_dialog.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:powerboards/ui/hover_builder.dart';
import 'package:powerboards/ui/pane_header_action_scope.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/chat_bubble_markdown_config.dart';
import 'package:meshagent_flutter_shadcn/meshagent_flutter_shadcn.dart' as ma;

import 'package:powerboards/meshagent/agent_participants.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/upload_foldername_service.dart';
import 'package:powerboards/web_context_menu_manager/enable_web_context_menu.dart';

class MeshagentRoomChatThreadController extends ChatThreadController {
  MeshagentRoomChatThreadController({required super.room});

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
}

class MeshagentThreadView extends StatefulWidget {
  const MeshagentThreadView({
    super.key,
    required this.projectId,
    required this.client,
    required this.joinMeeting,
    this.documentPath = ".threads/main.thread",
    this.threadDisplayMode = ChatThreadDisplayMode.singleThread,
    this.threadListPath,
    this.newThreadResetVersion = 0,

    this.participantNames,

    this.initialMessageID,
    this.initialMessageText,
    this.initialMessageAttachments,
    this.agentName,
    this.selectedThreadPath,
    this.onSelectedThreadPathChanged,
    this.emptyState,
    this.newThreadEmptyStateVerticalOffset = 0,
  });

  final String projectId;
  final String? agentName;
  final ChatThreadDisplayMode threadDisplayMode;
  final String? threadListPath;
  final int newThreadResetVersion;
  final RoomClient client;
  final String documentPath;
  final void Function() joinMeeting;
  final List<String>? participantNames;

  final String? initialMessageID;
  final String? initialMessageText;
  final List<FileAttachment>? initialMessageAttachments;
  final String? selectedThreadPath;
  final ValueChanged<String?>? onSelectedThreadPathChanged;
  final Widget? emptyState;
  final double newThreadEmptyStateVerticalOffset;

  @override
  State createState() => _MeshagentThreadViewState();
}

class _MeshagentThreadViewState extends State<MeshagentThreadView> {
  static const String _threadEmptyDescription = "Connect with this agent and your team";
  final Set<String> _emptyThreadCleanupPaths = <String>{};

  String _chatPlaceholderText(String? agentName) {
    final normalizedAgentName = agentName?.trim();
    if (normalizedAgentName == null || normalizedAgentName.isEmpty) {
      return "Type a message";
    }

    return "Type a message or @$normalizedAgentName";
  }

  Widget _buildThreadEmptyState(BuildContext context, {required String title, required String description}) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: ChatThreadEmptyStateContent(title: title, description: description),
    );

    final verticalOffset = widget.newThreadEmptyStateVerticalOffset;
    if (verticalOffset == 0) {
      return content;
    }

    return Transform.translate(offset: Offset(0, verticalOffset), child: content);
  }

  late final ChatThreadController _chatController;
  late String _documentPath;
  late String? _initialMessageText;
  @override
  void didUpdateWidget(covariant MeshagentThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.agentName != widget.agentName ||
        oldWidget.threadDisplayMode != widget.threadDisplayMode ||
        oldWidget.documentPath != widget.documentPath ||
        oldWidget.threadListPath != widget.threadListPath) {
      _documentPath = widget.documentPath;
      _initialMessageText = widget.initialMessageText;
    } else if (oldWidget.initialMessageText != widget.initialMessageText &&
        widget.threadDisplayMode != ChatThreadDisplayMode.multiThreadComposer) {
      _initialMessageText = widget.initialMessageText;
    }
  }

  @override
  void initState() {
    super.initState();

    _chatController = MeshagentRoomChatThreadController(room: widget.client);
    _documentPath = widget.documentPath;
    _initialMessageText = widget.initialMessageText;
  }

  @override
  void dispose() {
    _chatController.dispose();

    super.dispose();
  }

  void _onMessageSent(ma.ChatMessage message) {}

  Widget _fileInThreadBuilder(BuildContext context, String path) {
    if (path.endsWith('.meeting')) {
      return MeetingCard(onJoin: () => widget.joinMeeting());
    }

    return ShadGestureDetector(
      cursor: SystemMouseCursors.click,
      onTap: () => _open(path),
      child: ChatThreadPreview(room: widget.client, path: path),
    );
  }

  void _open(String path) {
    final state = PathRouteMatch.of(context);
    final currentUri = state.uri;

    final updatedQueryParameters = Map<String, String>.from(currentUri.queryParameters);
    updatedQueryParameters['p'] = path;

    final newUri = currentUri.replace(queryParameters: updatedQueryParameters);

    context.go(newUri.toString());
  }

  void _onThreadPathChanged(String? path) {
    final onSelectedThreadPathChanged = widget.onSelectedThreadPathChanged;
    if (onSelectedThreadPathChanged != null) {
      onSelectedThreadPathChanged(path);
    }
  }

  Future<void> _onVisibleMessagesEmpty(String path) async {
    if (widget.threadDisplayMode != ChatThreadDisplayMode.multiThreadComposer || widget.selectedThreadPath != path) {
      return;
    }
    if (!_emptyThreadCleanupPaths.add(path)) {
      return;
    }

    try {
      widget.onSelectedThreadPathChanged?.call(null);

      final threadListPath = widget.threadListPath?.trim();
      if (threadListPath != null && threadListPath.isNotEmpty) {
        MeshDocument? threadListDocument;
        try {
          threadListDocument = await widget.client.sync.open(threadListPath);
          final threadEntry = threadListDocument.root.getChildren().whereType<MeshElement>().firstWhereOrNull(
            (node) => node.tagName == "thread" && node.getAttribute("path") == path,
          );
          threadEntry?.delete();
        } finally {
          try {
            await widget.client.sync.close(threadListPath);
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(ShadToast.destructive(description: Text("Unable to remove empty thread: $e")));
      }
    } finally {
      _emptyThreadCleanupPaths.remove(path);
    }
  }

  Widget _buildThread({required String path, required String? initialMessageText, Widget Function(BuildContext)? loadingBuilder}) {
    return IconTheme(
      data: const IconThemeData(size: 14),
      child: ChatThreadLoader(
        key: ValueKey(path),
        room: widget.client,
        loadingBuilder: loadingBuilder ?? (context) => const SizedBox.shrink(),
        path: path,
        builder: (context, document) => ChatThread(
          path: path,
          document: document,
          room: widget.client,
          controller: _chatController,
          inputPlaceholder: Text(_chatPlaceholderText(widget.agentName)),
          initialMessage: initialMessageText == null
              ? null
              : ma.ChatMessage(
                  id: widget.initialMessageID ?? const Uuid().v4(),
                  text: initialMessageText,
                  attachments: widget.initialMessageAttachments?.map((attachment) => attachment.path).toList() ?? const [],
                ),
          onMessageSent: _onMessageSent,
          fileInThreadBuilder: _fileInThreadBuilder,
          openFile: _open,
          toolsBuilder: (context, controller, snapshot) =>
              buildTools(context, widget.projectId, widget.client, widget.agentName, controller, snapshot),
          agentName: widget.agentName,
          emptyStateTitle: "Chat to get started",
          emptyStateDescription: _threadEmptyDescription,
          emptyState: widget.emptyState,
          onVisibleMessagesEmpty: widget.threadDisplayMode == ChatThreadDisplayMode.multiThreadComposer
              ? () => _onVisibleMessagesEmpty(path)
              : null,
          chatInputBoxBuilder: (context, inputBox) => EnableWebContextMenu(child: inputBox),
        ),
        participantNames: widget.participantNames,
      ),
    );
  }

  Widget _buildDefaultNewThreadContent(BuildContext context, {required String agentName}) {
    final threadPath = widget.selectedThreadPath;
    final threadContent = threadPath == null
        ? ma.NewChatThread(
            key: ValueKey("new-thread-$agentName-${widget.newThreadResetVersion}"),
            room: widget.client,
            agentName: agentName,
            centerComposer: false,
            emptyState:
                widget.emptyState ??
                Builder(
                  builder: (context) => _buildThreadEmptyState(context, title: "Start a new thread", description: _threadEmptyDescription),
                ),
            controller: _chatController,
            onThreadPathChanged: _onThreadPathChanged,
            toolsBuilder: (context, controller, snapshot) =>
                buildTools(context, widget.projectId, widget.client, agentName, controller, snapshot),
            builder: (context, path, loadingBuilder) => _buildThread(path: path, initialMessageText: null, loadingBuilder: loadingBuilder),
          )
        : _buildThread(path: threadPath, initialMessageText: null);

    return threadContent;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.threadDisplayMode == ChatThreadDisplayMode.multiThreadComposer) {
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

class MeshagentThreadListPane extends StatefulWidget {
  const MeshagentThreadListPane({
    super.key,
    required this.client,
    required this.onSelectedThreadPathChanged,
    this.threadListPath,
    this.agentName,
    this.selectedThreadPath,
    this.newThreadResetVersion = 0,
    this.createItemTopPadding = 0,
    this.mobileListTopPadding = 0,
    this.mobileListBottomPadding = 8,
    this.mobileRowVerticalPadding = 14,
    this.mobileUseDialogListStyle = false,
    this.showCreateItem = true,
  });

  final RoomClient client;
  final String? threadListPath;
  final String? agentName;
  final String? selectedThreadPath;
  final int newThreadResetVersion;
  final double createItemTopPadding;
  final double mobileListTopPadding;
  final double mobileListBottomPadding;
  final double mobileRowVerticalPadding;
  final bool mobileUseDialogListStyle;
  final bool showCreateItem;
  final ValueChanged<String?> onSelectedThreadPathChanged;

  @override
  State<MeshagentThreadListPane> createState() => _MeshagentThreadListPaneState();
}

class MeshagentInlineThreadCreatePrompt extends StatelessWidget {
  const MeshagentInlineThreadCreatePrompt({
    super.key,
    required this.onOpen,
    required this.onViewAllThreads,
    this.createItemTopPadding = 0,
    this.isSelected = false,
  });

  final VoidCallback onOpen;
  final VoidCallback onViewAllThreads;
  final double createItemTopPadding;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final foreground = theme.colorScheme.foreground;
    const desktopActionButtonPadding = EdgeInsets.symmetric(horizontal: 16);

    Widget desktopActionButton({
      required VoidCallback onPressed,
      required Widget child,
      Widget? leading,
      EdgeInsetsGeometry padding = desktopActionButtonPadding,
      MainAxisAlignment? mainAxisAlignment,
      bool selected = false,
    }) {
      return ShadButton.ghost(
        height: desktopPaneSecondaryControlHeight,
        padding: padding,
        hoverBackgroundColor: theme.colorScheme.accent,
        pressedBackgroundColor: theme.colorScheme.accent,
        leading: leading,
        gap: 12,
        mainAxisAlignment: mainAxisAlignment,
        onPressed: onPressed,
        child: child,
      );
    }

    return ColoredBox(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.only(top: createItemTopPadding),
          child: SizedBox(
            width: double.infinity,
            height: desktopPaneSecondaryControlHeight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                desktopActionButton(
                  onPressed: onOpen,
                  selected: isSelected,
                  leading: _newThreadActionIcon(isSelected, color: foreground),
                  child: Text(
                    "New thread",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _MeshagentThreadListPaneState.createActionStyle(context),
                  ),
                ),
                const SizedBox(width: desktopPaneHeaderButtonGap),
                desktopActionButton(
                  onPressed: onViewAllThreads,
                  padding: desktopActionButtonPadding,
                  child: Text(
                    "View all threads",
                    maxLines: 1,
                    softWrap: false,
                    style: _MeshagentThreadListPaneState.threadNameStyle(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MeshagentThreadListPaneState extends State<MeshagentThreadListPane> {
  static TextStyle threadNameStyle(BuildContext context, {FontWeight fontWeight = FontWeight.w400, Color? color}) {
    final theme = ShadTheme.of(context);
    return GoogleFonts.inter(fontSize: 13, fontWeight: fontWeight, color: color ?? theme.colorScheme.mutedForeground);
  }

  static TextStyle createActionStyle(BuildContext context, {FontWeight fontWeight = FontWeight.w700}) {
    final theme = ShadTheme.of(context);
    return GoogleFonts.inter(
      fontSize: chatBubbleMarkdownBaseFontSize(context),
      fontWeight: fontWeight,
      color: theme.colorScheme.foreground,
    );
  }

  MeshDocument? _threadListDocument;
  RoomClient? _threadListClient;
  String? _threadListPath;
  Object? _threadListError;
  bool _threadListLoading = true;

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

    final selectedPath = widget.selectedThreadPath;
    if (selectedPath != null && !_threadListContainsPath(selectedPath)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSelectedThreadPathChanged(null);
      });
    }

    setState(() {});
  }

  void _onThreadStatusChanged() {
    if (!mounted) {
      return;
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
    final nextPath = _normalizedThreadListPath(widget.threadListPath);
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
      if (!mounted || _normalizedThreadListPath(widget.threadListPath) != nextPath) {
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

    if (widget.selectedThreadPath == entry.path) {
      widget.onSelectedThreadPathChanged(null);
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
  void initState() {
    super.initState();
    widget.client.messaging.addListener(_onThreadStatusChanged);
    unawaited(_rebindThreadListDocument());
  }

  @override
  void didUpdateWidget(covariant MeshagentThreadListPane oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.client != widget.client) {
      oldWidget.client.messaging.removeListener(_onThreadStatusChanged);
      widget.client.messaging.addListener(_onThreadStatusChanged);
    }

    if (oldWidget.client != widget.client || oldWidget.threadListPath != widget.threadListPath) {
      unawaited(_rebindThreadListDocument());
    }

    if (oldWidget.newThreadResetVersion != widget.newThreadResetVersion && widget.selectedThreadPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSelectedThreadPathChanged(null);
      });
    }
  }

  @override
  void dispose() {
    widget.client.messaging.removeListener(_onThreadStatusChanged);
    unawaited(_closeThreadListDocument());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _threadListEntries();

    return ColoredBox(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Expanded(child: _buildThreadListSurface(entries))],
      ),
    );
  }

  Widget _buildThreadListSurface(List<_ThreadListEntry> entries) {
    return _buildThreadListBody(entries);
  }

  Widget _buildThreadListBody(List<_ThreadListEntry> entries) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final showCreateItem = widget.showCreateItem;
    final showDraftThreadEntry = isMobile && widget.selectedThreadPath == null && entries.isNotEmpty;

    if (_threadListLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_threadListError != null) {
      return _buildCenteredState(
        icon: LucideIcons.triangleAlert,
        title: "Unable to load threads",
        description: "Check the room connection and try again.",
      );
    }

    if (entries.isEmpty && isMobile && !showCreateItem) {
      return _buildCenteredState(title: "No threads yet");
    }

    final createItemCount = showCreateItem ? 1 : 0;
    final contentItemCount = entries.isEmpty ? 1 : entries.length + (showDraftThreadEntry ? 1 : 0);

    return ListView.separated(
      shrinkWrap: isMobile && widget.mobileUseDialogListStyle,
      padding: EdgeInsets.only(top: isMobile ? widget.mobileListTopPadding : 0, bottom: isMobile ? widget.mobileListBottomPadding : 8),
      itemCount: createItemCount + contentItemCount,
      separatorBuilder: (_, _) => SizedBox(height: isMobile && widget.mobileUseDialogListStyle ? 0 : 4),
      itemBuilder: (context, index) {
        if (showCreateItem && index == 0) {
          return _ThreadListCreateItem(
            topPadding: widget.createItemTopPadding,
            selected: widget.selectedThreadPath == null,
            onOpen: () => widget.onSelectedThreadPathChanged(null),
          );
        }

        final contentIndex = index - createItemCount;

        if (entries.isEmpty) {
          return const _ThreadListEmptyHint();
        }

        if (showDraftThreadEntry && contentIndex == 0) {
          return _DraftThreadListItem(
            showUnderline: contentItemCount > 1,
            mobileRowVerticalPadding: widget.mobileRowVerticalPadding,
            mobileUseDialogListStyle: widget.mobileUseDialogListStyle,
            onOpen: () => widget.onSelectedThreadPathChanged(null),
          );
        }

        final entry = entries[contentIndex - (showDraftThreadEntry ? 1 : 0)];
        return _ThreadListItem(
          entry: entry,
          threadStatus: ma.resolveChatThreadStatus(room: widget.client, path: entry.path, agentName: widget.agentName),
          showUnderline: contentIndex != contentItemCount - 1,
          selected: entry.path == widget.selectedThreadPath,
          mobileRowVerticalPadding: widget.mobileRowVerticalPadding,
          mobileUseDialogListStyle: widget.mobileUseDialogListStyle,
          onOpen: () => widget.onSelectedThreadPathChanged(entry.path),
          onRename: () => _renameThread(entry),
          onDelete: () => _deleteThread(entry),
        );
      },
    );
  }

  Widget _buildCenteredState({IconData? icon, required String title, String? description}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 44, color: shadMutedForeground), const SizedBox(height: 16)],
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: shadForeground),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: shadMutedForeground),
              ),
            ],
          ],
        ),
      ),
    );
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
    required this.threadStatus,
    required this.showUnderline,
    required this.selected,
    required this.mobileRowVerticalPadding,
    required this.mobileUseDialogListStyle,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final _ThreadListEntry entry;
  final ma.ChatThreadStatusState threadStatus;
  final bool showUnderline;
  final bool selected;
  final double mobileRowVerticalPadding;
  final bool mobileUseDialogListStyle;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  State<_ThreadListItem> createState() => _ThreadListItemState();
}

class _ThreadListCreateItem extends StatelessWidget {
  const _ThreadListCreateItem({required this.onOpen, this.topPadding = 0, this.selected = false});

  final VoidCallback onOpen;
  final double topPadding;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final theme = ShadTheme.of(context);
    final foreground = theme.colorScheme.foreground;

    if (!isMobile) {
      return Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: ShadButton.ghost(
          width: double.infinity,
          height: desktopPaneSecondaryControlHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          hoverBackgroundColor: theme.colorScheme.accent,
          pressedBackgroundColor: theme.colorScheme.accent,
          leading: _newThreadActionIcon(selected, color: foreground),
          gap: 12,
          mainAxisAlignment: MainAxisAlignment.start,
          onPressed: onOpen,
          child: Text(
            "New thread",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _MeshagentThreadListPaneState.createActionStyle(context),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          onTap: onOpen,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: isMobile ? 0 : desktopPaneSecondaryControlHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 0, vertical: isMobile ? 14 : 0),
              child: Row(
                children: [
                  SizedBox(
                    width: isMobile ? 36 : 20,
                    child: Center(child: Icon(LucideIcons.messageSquarePlus, size: 16, color: foreground)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "New thread",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _MeshagentThreadListPaneState.createActionStyle(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadListEmptyHint extends StatelessWidget {
  const _ThreadListEmptyHint();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final leadingInset =
        (isMobile ? 12.0 : _desktopThreadListHorizontalPadding) + _threadListLeadingWidth(isMobile) + _threadListGap(isMobile);

    return Padding(
      padding: EdgeInsets.fromLTRB(leadingInset, isMobile ? 4 : 8, 0, 0),
      child: Text(
        "Add and manage multiple threads.",
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: shadMutedForeground, height: 1.4),
      ),
    );
  }
}

Widget _newThreadActionIcon(bool selected, {required Color color}) {
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 180),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(animation), child: child),
    ),
    child: Icon(selected ? LucideIcons.check : LucideIcons.messageSquarePlus, key: ValueKey(selected), size: 16, color: color),
  );
}

class _ThreadListItemState extends State<_ThreadListItem> {
  late final ShadContextMenuController _menuController = ShadContextMenuController();

  EdgeInsets _rowPadding(bool isMobile) {
    if (isMobile && widget.mobileUseDialogListStyle) {
      return EdgeInsets.symmetric(horizontal: 12, vertical: widget.mobileRowVerticalPadding);
    }

    if (isMobile) {
      return EdgeInsets.symmetric(vertical: widget.mobileRowVerticalPadding);
    }

    return const EdgeInsets.only(left: _desktopThreadListHorizontalPadding);
  }

  double _leadingWidth(bool isMobile) {
    if (isMobile && widget.mobileUseDialogListStyle) {
      return 24;
    }

    return _threadListLeadingWidth(isMobile);
  }

  EdgeInsets _contentPadding(bool isMobile) {
    if (isMobile) {
      return EdgeInsets.zero;
    }

    return const EdgeInsets.symmetric(vertical: 8);
  }

  double _trailingButtonHeight(bool isMobile) {
    if (isMobile && widget.mobileUseDialogListStyle) {
      return 24;
    }

    return 40;
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovered, focused) {
        final isMobile = ResponsiveBreakpoints.of(context).isMobile;
        final showMenuIcon = widget.selected || hovered || focused || isMobile || _menuController.isOpen;
        final selected = widget.selected;
        final textStyle = isMobile && widget.mobileUseDialogListStyle
            ? TextStyle(inherit: true, fontWeight: selected ? FontWeight.w700 : FontWeight.w400, color: shadForeground)
            : _MeshagentThreadListPaneState.threadNameStyle(
                context,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected || widget.threadStatus.hasStatus ? shadForeground : shadMutedForeground,
              );

        return DecoratedBox(
          decoration: BoxDecoration(
            border: widget.showUnderline ? Border(bottom: BorderSide(color: shadBorder.withValues(alpha: 0.5))) : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: isMobile ? 0 : 36),
              child: Padding(
                padding: _rowPadding(isMobile),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        onTap: widget.onOpen,
                        child: Padding(
                          padding: _contentPadding(isMobile),
                          child: Row(
                            children: [
                              SizedBox(
                                width: _leadingWidth(isMobile),
                                child: Center(
                                  child: selected && !widget.threadStatus.hasStatus
                                      ? const Icon(LucideIcons.check, size: 16, color: shadForeground)
                                      : ma.ChatThreadStatusIndicator(
                                          statusText: widget.threadStatus.text,
                                          startedAt: widget.threadStatus.startedAt,
                                          reserveSpace: true,
                                          size: 14,
                                          strokeWidth: 2,
                                        ),
                                ),
                              ),
                              SizedBox(width: _threadListGap(isMobile)),
                              Expanded(
                                child: isMobile && widget.mobileUseDialogListStyle
                                    ? Text(
                                        widget.entry.name,
                                        style: textStyle,
                                        textAlign: TextAlign.start,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                      )
                                    : ma.ChatThreadProcessingSweepText(
                                        text: widget.entry.name,
                                        style: textStyle,
                                        animate: widget.threadStatus.hasStatus,
                                        textAlign: TextAlign.start,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AdaptiveShadContextMenu(
                      controller: _menuController,
                      constraints: const BoxConstraints(minWidth: 180),
                      estimatedMenuWidth: 180,
                      estimatedMenuHeight: 2 * 40.0 + 8.0,
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
                      child: ShadButton.ghost(
                        onPressed: _menuController.toggle,
                        width: 40,
                        height: _trailingButtonHeight(isMobile),
                        hoverBackgroundColor: Colors.transparent,
                        backgroundColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        decoration: ShadDecoration.none,
                        child: SizedBox(
                          width: 40,
                          height: _trailingButtonHeight(isMobile),
                          child: Center(
                            child: Icon(LucideIcons.ellipsis, size: 20, color: showMenuIcon ? shadForeground : Colors.transparent),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

double _threadListLeadingWidth(bool isMobile) => isMobile ? 36 : 16;

double _threadListGap(bool isMobile) => isMobile ? 10 : 12;

const double _desktopThreadListHorizontalPadding = 16;

class _DraftThreadListItem extends StatelessWidget {
  const _DraftThreadListItem({
    required this.showUnderline,
    required this.mobileRowVerticalPadding,
    required this.mobileUseDialogListStyle,
    required this.onOpen,
  });

  final bool showUnderline;
  final double mobileRowVerticalPadding;
  final bool mobileUseDialogListStyle;
  final VoidCallback onOpen;

  EdgeInsets _rowPadding(bool isMobile) {
    if (isMobile && mobileUseDialogListStyle) {
      return EdgeInsets.symmetric(horizontal: 12, vertical: mobileRowVerticalPadding);
    }

    if (isMobile) {
      return EdgeInsets.symmetric(vertical: mobileRowVerticalPadding);
    }

    return const EdgeInsets.only(left: _desktopThreadListHorizontalPadding);
  }

  double _leadingWidth(bool isMobile) {
    if (isMobile && mobileUseDialogListStyle) {
      return 24;
    }

    return _threadListLeadingWidth(isMobile);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final textStyle = mobileUseDialogListStyle
        ? TextStyle(inherit: true, fontWeight: FontWeight.w700, color: shadForeground)
        : _MeshagentThreadListPaneState.threadNameStyle(context, fontWeight: FontWeight.w700, color: shadForeground);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showUnderline ? Border(bottom: BorderSide(color: shadBorder.withValues(alpha: 0.5))) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          onTap: onOpen,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: isMobile ? 0 : 36),
            child: Padding(
              padding: _rowPadding(isMobile),
              child: Row(
                children: [
                  SizedBox(
                    width: _leadingWidth(isMobile),
                    child: const Center(child: Icon(LucideIcons.check, size: 16, color: shadForeground)),
                  ),
                  SizedBox(width: _threadListGap(isMobile)),
                  Expanded(
                    child: Text("My new thread", maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: textStyle),
                  ),
                  const SizedBox(width: 52),
                ],
              ),
            ),
          ),
        ),
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

final webSearch = StaticToolkitBuilderOption(
  icon: LucideIcons.search,
  config: WebSearchConfig(),
  text: "Web search",
  selectedText: "Search",
);

final shell = StaticToolkitBuilderOption(icon: LucideIcons.terminal, config: ShellConfig(), text: "Shell", selectedText: "Shell");

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
  final rawPath = e.path.trim();
  final endpointPath = rawPath.isEmpty ? "" : (rawPath.startsWith('/') ? rawPath : '/$rawPath');
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
  String projectId,
  RoomClient room,
  String? agentName,
  ChatThreadController controller,
  ChatThreadSnapshot state,
) {
  Future<RoomClient> connectRoomClient(String roomName) async {
    final client = getMeshagentClient();
    final conn = await client.connectRoom(projectId: projectId, roomName: roomName);
    final roomClient = RoomClient(
      protocol: WebSocketClientProtocol(url: conn.roomUrl, token: conn.jwt),
    );
    await roomClient.start();
    await roomClient.ready;
    return roomClient;
  }

  return ChatThreadAttachButton(
    agentName: agentName,
    alwaysShowAttachFiles: true, // agentName == null ? true : null,
    controller: controller,
    availableRooms: () => listMeshagentRooms(projectId),
    connectRoomClient: connectRoomClient,
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
    availableConnectors: () async {
      final services = await room.services.list();
      return [
        for (final s in services)
          if (s.metadata.annotations["meshagent.service.filter.agent"] == null ||
              s.metadata.annotations["meshagent.service.filter.agent"] == agentName)
            for (final p in s.ports)
              for (final e in p.endpoints)
                if (e.mcp != null)
                  Connector(
                    name: e.mcp!.label,
                    server: MCPServer(
                      serverLabel: e.mcp!.label,
                      serverUrl: getBaseUrl(s, p, e),
                      headers: e.mcp!.headers == null
                          ? null
                          : [for (final header in e.mcp!.headers!.entries) MCPHeader(name: header.key, value: header.value)],
                      openaiConnectorId: e.mcp!.openaiConnectorId,
                    ),
                    oauth: e.mcp!.oauth,
                  ),
      ];
    },
    toolkits: [
      for (final tool in state.availableTools) ...[
        if (tool.name == "storage") storage,
        if (tool.name == "web_search") webSearch,
        if (tool.name == "shell") shell,
        if (tool.name == "image_generation") imageGen,
        if (tool.name == "mcp") mcp,
      ],
    ],
  );
}
