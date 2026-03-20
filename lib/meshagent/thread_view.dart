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
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
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
  });

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

  @override
  State createState() => _MeshagentThreadViewState();
}

class _MeshagentThreadViewState extends State<MeshagentThreadView> {
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
          inputPlaceholder: Text("Send a message or @developer"),
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
          toolsBuilder: (context, controller, snapshot) => buildTools(context, widget.client, widget.agentName, controller, snapshot),
          agentName: widget.agentName,
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
            controller: _chatController,
            onThreadPathChanged: _onThreadPathChanged,
            toolsBuilder: (context, controller, snapshot) => buildTools(context, widget.client, agentName, controller, snapshot),
            builder: (context, path, loadingBuilder) => _buildThread(path: path, initialMessageText: null, loadingBuilder: loadingBuilder),
          )
        : _buildThread(path: threadPath, initialMessageText: null);

    if (threadPath != null) {
      return threadContent;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideInset = constraints.maxWidth * 0.1;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: sideInset),
          child: threadContent,
        );
      },
    );
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
    this.selectedThreadPath,
    this.newThreadResetVersion = 0,
  });

  final RoomClient client;
  final String? threadListPath;
  final String? selectedThreadPath;
  final int newThreadResetVersion;
  final ValueChanged<String?> onSelectedThreadPathChanged;

  @override
  State<MeshagentThreadListPane> createState() => _MeshagentThreadListPaneState();
}

class _MeshagentThreadListPaneState extends State<MeshagentThreadListPane> {
  static final TextStyle _threadNameStyle = GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: shadForeground);

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
    unawaited(_rebindThreadListDocument());
  }

  @override
  void didUpdateWidget(covariant MeshagentThreadListPane oldWidget) {
    super.didUpdateWidget(oldWidget);

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

    if (entries.isEmpty) {
      return _buildCenteredState(
        icon: LucideIcons.messageSquarePlus,
        title: "No threads yet",
        description: "Create a thread to start a new conversation with this agent.",
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: entries.length + 1,
      separatorBuilder: (_, _) => SizedBox(height: isMobile ? 4 : 4),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _ThreadListCreateItem(selected: widget.selectedThreadPath == null, onOpen: () => widget.onSelectedThreadPathChanged(null));
        }

        final entry = entries[index - 1];
        return _ThreadListItem(
          entry: entry,
          selected: entry.path == widget.selectedThreadPath,
          onOpen: () => widget.onSelectedThreadPathChanged(entry.path),
          onRename: () => _renameThread(entry),
          onDelete: () => _deleteThread(entry),
        );
      },
    );
  }

  Widget _buildCenteredState({required IconData icon, required String title, required String description}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: shadMutedForeground),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: shadForeground),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: shadMutedForeground),
            ),
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

class _ThreadListCreateItem extends StatelessWidget {
  const _ThreadListCreateItem({required this.selected, required this.onOpen});

  final bool selected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final radius = ShadTheme.of(context).radius.resolve(Directionality.of(context));

    return HoverBuilder(
      builder: (context, hovered, focused) {
        final isMobile = ResponsiveBreakpoints.of(context).isMobile;
        final backgroundColor = selected ? ShadTheme.of(context).colorScheme.card : Colors.transparent;
        final borderColor = hovered || focused ? shadBorder : Colors.transparent;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(radius.topLeft.x),
              topRight: Radius.circular(radius.topRight.x),
              bottomLeft: Radius.circular(radius.bottomLeft.x),
              bottomRight: Radius.circular(radius.bottomRight.x),
            ),
            border: Border.all(color: borderColor),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(radius.topLeft.x),
                topRight: Radius.circular(radius.topRight.x),
                bottomLeft: Radius.circular(radius.bottomLeft.x),
                bottomRight: Radius.circular(radius.bottomRight.x),
              ),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              onTap: onOpen,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: isMobile ? 0 : 36),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 12, vertical: isMobile ? 14 : 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: isMobile ? 36 : 16,
                        child: const Center(child: Icon(LucideIcons.messageSquarePlus, size: 16, color: shadForeground)),
                      ),
                      SizedBox(width: isMobile ? 4 : 6),
                      Expanded(
                        child: Text(
                          "New thread",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _MeshagentThreadListPaneState._threadNameStyle.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
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
    return HoverBuilder(
      builder: (context, hovered, focused) {
        final isMobile = ResponsiveBreakpoints.of(context).isMobile;
        final showMenuIcon = hovered || focused || isMobile;
        final selected = widget.selected;
        final rowColor = selected ? ShadTheme.of(context).colorScheme.card : Colors.transparent;
        final borderColor = hovered || focused ? shadBorder : Colors.transparent;
        final radius = ShadTheme.of(context).radius.resolve(Directionality.of(context));

        return DecoratedBox(
          decoration: BoxDecoration(
            color: rowColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(radius.topLeft.x),
              topRight: Radius.circular(radius.topRight.x),
              bottomLeft: Radius.circular(radius.bottomLeft.x),
              bottomRight: Radius.circular(radius.bottomRight.x),
            ),
            border: Border.all(color: borderColor),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(radius.topLeft.x),
                topRight: Radius.circular(radius.topRight.x),
                bottomLeft: Radius.circular(radius.bottomLeft.x),
                bottomRight: Radius.circular(radius.bottomRight.x),
              ),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              onTap: widget.onOpen,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: isMobile ? 0 : 36),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 12, vertical: isMobile ? 14 : 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: isMobile ? 36 : 16,
                        child: Center(
                          child: selected ? const Icon(LucideIcons.dot, size: 22, color: shadForeground) : const SizedBox.shrink(),
                        ),
                      ),
                      SizedBox(width: isMobile ? 4 : 6),
                      Expanded(
                        child: Text(
                          widget.entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _MeshagentThreadListPaneState._threadNameStyle.copyWith(fontWeight: FontWeight.w500),
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
                          onPressed: _menuController.show,
                          hoverBackgroundColor: Colors.transparent,
                          backgroundColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          decoration: ShadDecoration.none,
                          child: SizedBox(
                            width: 40,
                            height: 40,
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

Widget buildTools(BuildContext context, RoomClient room, String? agentName, ChatThreadController controller, ChatThreadSnapshot state) {
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
