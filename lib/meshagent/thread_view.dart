import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:powerboards/nav/delete_room_dialog.dart';
import 'package:powerboards/nav/rename_room_dialog.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/settings/ui_mode.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:powerboards/ui/adaptive_text_selection_toolbar.dart';
import 'package:powerboards/ui/hover_builder.dart';
import 'package:powerboards/ui/pane_header_action_scope.dart';
import 'package:powerboards/ui/powerboards_breakpoints.dart';
import 'package:powerboards/ui/powerboards_mobile_action_pills.dart';
import 'package:powerboards/ui/powerboards_mobile_overlay_header.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_agents/meshagent_agents.dart' as agent_sessions;
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/chat/chat_bot_view.dart';
import 'package:meshagent_flutter_shadcn/chat_bubble_markdown_config.dart';
import 'package:meshagent_flutter_shadcn/meshagent_flutter_shadcn.dart' as ma;

import 'package:powerboards/meshagent/agent_participants.dart';
import 'package:powerboards/meshagent/desktop_chat_attach_button.dart';
import 'package:powerboards/meshagent/file_attachment_index.dart';
import 'package:powerboards/meshagent/file_list_primitives.dart';
import 'package:powerboards/meshagent/file_preview_origin.dart';
import 'package:powerboards/meshagent/install_agent.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/mobile_chat_attach_button.dart';
import 'package:powerboards/meshagent/thread_display_name.dart';
import 'package:powerboards/meshagent/thread_storage_save_surface.dart';
import 'package:powerboards/meshagent/upload_foldername_service.dart';

typedef PowerboardsThreadAttachmentsChanged =
    void Function({
      required String threadPath,
      required String threadName,
      required String createdBy,
      required Iterable<String> attachmentPaths,
    });

class MeshagentRoomChatThreadController extends ChatThreadController {
  MeshagentRoomChatThreadController({required super.room});

  final folderNameService = MeshagentUploadFoldernameService();

  @override
  Future<FileAttachment> uploadFile(String path, Stream<Uint8List> dataStream, int size, {String? mimeType}) async {
    final uploader = (await super.uploadFileDeferred(path, dataStream, size, mimeType: mimeType)) as MeshagentFileUpload;

    // Josef: Removing folder name suggestion for now
    // final folder = await folderNameService.generateFoldername(room, path);

    uploader
      ..path = path
      ..startUpload();

    return uploader;
  }
}

String? _agentThreadListPath(String? path) {
  final normalized = path?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return "agent://threads";
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
    this.chatClient,
    this.selectedThreadPath,
    this.selectedThreadDisplayName,
    this.onSelectedThreadPathChanged,
    this.onSelectedThreadResolved,
    this.emptyState,
    this.newThreadEmptyStateVerticalOffset = 0,
    this.hideChatInput = false,
    this.onConnectAgents,
    this.onInvite,
    this.onOpenFiles,
    this.onOpenMeet,
    this.onThreadAttachmentsChanged,
    this.composerAttachmentSeedVersion = 0,
    this.composerAttachmentPaths = const [],
    this.onComposerAttachmentSeedApplied,
    this.onComposerAttachmentOpen,
    this.onComposerAttachmentRemoved,
    this.onThreadAttachmentOpen,
    this.fileDropOverlayBuilder,
  });

  final String projectId;
  final String? agentName;
  final agent_sessions.BaseChatClient? chatClient;
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
  final String? selectedThreadDisplayName;
  final ValueChanged<String?>? onSelectedThreadPathChanged;
  final void Function(String? path, String? displayName)? onSelectedThreadResolved;
  final Widget? emptyState;
  final double newThreadEmptyStateVerticalOffset;
  final bool hideChatInput;
  final VoidCallback? onConnectAgents;
  final VoidCallback? onInvite;
  final VoidCallback? onOpenFiles;
  final VoidCallback? onOpenMeet;
  final PowerboardsThreadAttachmentsChanged? onThreadAttachmentsChanged;
  final int composerAttachmentSeedVersion;
  final List<String> composerAttachmentPaths;
  final VoidCallback? onComposerAttachmentSeedApplied;
  final ValueChanged<String>? onComposerAttachmentOpen;
  final ValueChanged<String>? onComposerAttachmentRemoved;
  final ValueChanged<String>? onThreadAttachmentOpen;
  final FileDropOverlayBuilder? fileDropOverlayBuilder;

  @override
  State createState() => _MeshagentThreadViewState();
}

class _MeshagentThreadViewState extends State<MeshagentThreadView> {
  static const String _threadEmptyDescription = "Connect with this agent and your team";
  static const double _mobileThreadEmptyStateWidthMax = 600;

  late final ChatThreadController _chatController;
  String? _lastRestoredThreadScrollOffsetValue;
  final Set<String> _reportedAttachmentKeys = <String>{};
  int _lastAppliedComposerAttachmentSeedVersion = 0;

  bool _usesCompactMobileThreadEmptyState(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final view = View.of(context);
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
    return mediaQuery.size.width < _mobileThreadEmptyStateWidthMax && bottomInset > 0;
  }

  bool _usesMobileThreadLayout(BuildContext context) {
    if (powerboardsUsesDesktopUiPreview(context)) {
      return false;
    }

    return ResponsiveBreakpoints.of(context).isMobile || powerboardsIsLandscapePhoneViewport(context);
  }

  String _chatPlaceholderText(String? agentName) {
    final normalizedAgentName = agentName?.trim();
    if (normalizedAgentName == null || normalizedAgentName.isEmpty) {
      return "Message...";
    }

    return "Message $normalizedAgentName...";
  }

  Widget _buildThreadEmptyState(BuildContext context, {required String title, required String description, required bool compact}) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: compact
          ? ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(title, textAlign: TextAlign.center, style: powerboardsSectionTitleStyle()),
            )
          : ChatThreadEmptyStateContent(title: title, description: description),
    );

    final verticalOffset = widget.newThreadEmptyStateVerticalOffset;
    if (verticalOffset == 0) {
      return content;
    }

    return Transform.translate(offset: Offset(0, verticalOffset), child: content);
  }

  Widget _buildMobileNewThreadEmptyState(BuildContext context) {
    const horizontalInset = powerboardsMobileShellHorizontalInset;
    final theme = ShadTheme.of(context);
    final inactivePillColor = theme.colorScheme.foreground;
    final pillTextStyle = powerboardsInterTextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.0);
    final items = <PowerboardsMobileActionPillItem>[
      const PowerboardsMobileActionPillItem(label: "Chat", selected: true),
      if (widget.onOpenFiles != null) PowerboardsMobileActionPillItem(label: "Share files", onPressed: widget.onOpenFiles),
      if (widget.onOpenMeet != null) PowerboardsMobileActionPillItem(label: "Meet", onPressed: widget.onOpenMeet),
    ];

    Widget content = Align(
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: powerboardsMobileOverlaySecondaryRowLift),
              child: SizedBox(
                height: powerboardsMobileSecondaryRowHeight,
                width: double.infinity,
                child: PowerboardsMobileActionPillStrip(
                  items: items,
                  viewportPadding: const EdgeInsets.symmetric(horizontal: horizontalInset),
                  textStyle: pillTextStyle,
                  unselectedForegroundColor: inactivePillColor,
                  itemGap: 10,
                  pillPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
                ),
              ),
            ),
        ],
      ),
    );

    final verticalOffset = widget.newThreadEmptyStateVerticalOffset;
    if (verticalOffset != 0) {
      content = Transform.translate(offset: Offset(0, verticalOffset), child: content);
    }

    return content;
  }

  Widget _buildAdaptiveMobileChatInputBox(BuildContext context, Widget chatBox) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: KeyedSubtree(key: const ValueKey('mobile-chat-input'), child: chatBox),
    );
  }

  @override
  void initState() {
    super.initState();
    _chatController = MeshagentRoomChatThreadController(room: widget.client);
    _chatController.addListener(_onChatControllerChanged);
    _scheduleComposerAttachmentSeed();
  }

  @override
  void didUpdateWidget(covariant MeshagentThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleComposerAttachmentSeed();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restoreThreadScrollOffsetFromRoute();
  }

  @override
  void dispose() {
    _chatController.removeListener(_onChatControllerChanged);
    _chatController.dispose();
    super.dispose();
  }

  String _currentParticipantDisplayName() {
    final name = widget.client.localParticipant?.getAttribute("name");
    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }
    return 'Unknown';
  }

  String _currentThreadPathForAttachmentIndex() {
    final selectedThreadPath = widget.selectedThreadPath?.trim();
    if (selectedThreadPath != null && selectedThreadPath.isNotEmpty) {
      return selectedThreadPath;
    }
    return widget.documentPath.trim();
  }

  String _currentThreadNameForAttachmentIndex(String threadPath) {
    final selectedDisplayName = widget.selectedThreadDisplayName?.trim();
    if (selectedDisplayName != null && selectedDisplayName.isNotEmpty) {
      return selectedDisplayName;
    }
    return defaultThreadDisplayNameFromPath(threadPath);
  }

  void _notifyThreadAttachments({required String threadPath, required String threadName, required Iterable<String> attachmentPaths}) {
    final normalizedThreadPath = normalizePowerboardsAttachmentPath(threadPath);
    if (normalizedThreadPath.isEmpty) {
      return;
    }

    final normalizedAttachmentPaths = attachmentPaths
        .where(isPowerboardsStorageAttachmentPath)
        .map(normalizePowerboardsAttachmentPath)
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    if (normalizedAttachmentPaths.isEmpty) {
      return;
    }

    final freshAttachmentPaths = <String>[];
    for (final attachmentPath in normalizedAttachmentPaths) {
      if (_reportedAttachmentKeys.add('$normalizedThreadPath\n$attachmentPath')) {
        freshAttachmentPaths.add(attachmentPath);
      }
    }
    if (freshAttachmentPaths.isEmpty) {
      return;
    }

    widget.onThreadAttachmentsChanged?.call(
      threadPath: normalizedThreadPath,
      threadName: threadName,
      createdBy: _currentParticipantDisplayName(),
      attachmentPaths: freshAttachmentPaths,
    );
  }

  void _onChatControllerChanged() {
    for (final message in _chatController.pendingAgentMessages) {
      _notifyThreadAttachments(
        threadPath: message.threadPath,
        threadName: _currentThreadNameForAttachmentIndex(message.threadPath),
        attachmentPaths: message.attachments.map((attachment) => attachment.url),
      );
    }
  }

  String _composerAttachmentDisplayName(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return normalized;
    }

    final segments = normalized.split('/').where((segment) => segment.trim().isNotEmpty).toList(growable: false);
    return segments.isEmpty ? normalized : segments.last;
  }

  void _scheduleComposerAttachmentSeed() {
    final version = widget.composerAttachmentSeedVersion;
    if (version <= 0 || version == _lastAppliedComposerAttachmentSeedVersion) {
      return;
    }

    _lastAppliedComposerAttachmentSeedVersion = version;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.composerAttachmentSeedVersion != version) {
        return;
      }

      final seen = <String>{};
      final paths = <String>[];
      for (final path in widget.composerAttachmentPaths) {
        final normalizedPath = normalizePowerboardsAttachmentPath(path);
        if (normalizedPath.isNotEmpty && seen.add(normalizedPath)) {
          paths.add(normalizedPath);
        }
      }
      if (paths.isEmpty) {
        return;
      }

      _chatController.clear();
      for (final path in paths) {
        _chatController.attachFile(path, displayName: _composerAttachmentDisplayName(path));
      }
      widget.onComposerAttachmentSeedApplied?.call();
    });
  }

  void _onMessageSent(ma.ChatMessage message) {
    final attachmentPaths = message.attachments;
    if (attachmentPaths.isEmpty) {
      return;
    }

    final threadPath = _currentThreadPathForAttachmentIndex();
    _notifyThreadAttachments(
      threadPath: threadPath,
      threadName: _currentThreadNameForAttachmentIndex(threadPath),
      attachmentPaths: attachmentPaths,
    );
    unawaited(
      recordPowerboardsFileAttachmentLinks(
        room: widget.client,
        threadPath: threadPath,
        threadName: _currentThreadNameForAttachmentIndex(threadPath),
        createdBy: _currentParticipantDisplayName(),
        attachmentPaths: attachmentPaths,
      ).catchError((Object error, StackTrace stackTrace) {
        debugPrint('Failed to record file attachment index: $error');
      }),
    );
  }

  Uri? _currentRouteUriOrNull() {
    try {
      return PathRouteMatch.of(context).uri;
    } catch (_) {
      return null;
    }
  }

  void _openThreadAttachment(String path) {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty || normalizedPath.startsWith('data:')) {
      return;
    }

    final callback = widget.onThreadAttachmentOpen;
    if (callback != null) {
      callback(normalizedPath);
      return;
    }

    _open(normalizedPath);
  }

  Widget _fileInThreadBuilder(BuildContext context, String path) {
    if (path.endsWith('.meeting')) {
      return MeetingCard(onJoin: () => widget.joinMeeting());
    }

    return ChatThreadPreview(room: widget.client, path: path);
  }

  void _open(String path) {
    final currentUri = _currentRouteUriOrNull();
    if (currentUri == null) {
      return;
    }

    final updatedQueryParameters = Map<String, String>.from(currentUri.queryParameters);
    final previewOriginQueryParameters = Map<String, String>.from(currentUri.queryParameters);
    previewOriginQueryParameters.putIfAbsent('pane', () => 'chat');
    if (_chatController.threadScrollController.hasClients) {
      previewOriginQueryParameters[filePreviewThreadScrollOffsetQueryParameter] = _chatController.threadScrollController.position.pixels
          .toString();
    }

    updatedQueryParameters['p'] = path;
    updatedQueryParameters[filePreviewOriginQueryParameter] = currentUri.replace(queryParameters: previewOriginQueryParameters).toString();
    updatedQueryParameters.remove('pane');

    final newUri = currentUri.replace(queryParameters: updatedQueryParameters);

    context.go(newUri.toString());
  }

  void _openComposerAttachment(FileAttachment attachment) {
    final path = attachment.path.trim();
    if (path.isEmpty || path.startsWith('data:')) {
      return;
    }

    final callback = widget.onComposerAttachmentOpen;
    if (callback != null) {
      callback(path);
      return;
    }

    _open(path);
  }

  void _restoreThreadScrollOffsetFromRoute() {
    final currentUri = _currentRouteUriOrNull();
    if (currentUri == null) {
      return;
    }

    final rawOffset = currentUri.queryParameters[filePreviewThreadScrollOffsetQueryParameter];
    if (rawOffset == null || rawOffset.isEmpty || rawOffset == _lastRestoredThreadScrollOffsetValue) {
      return;
    }

    final parsedOffset = double.tryParse(rawOffset);
    if (parsedOffset == null || !parsedOffset.isFinite) {
      return;
    }

    _lastRestoredThreadScrollOffsetValue = rawOffset;

    void restore() {
      if (!mounted) {
        return;
      }

      final scrollController = _chatController.threadScrollController;
      if (!scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) => restore());
        return;
      }

      final position = scrollController.position;
      final clampedOffset = parsedOffset.clamp(position.minScrollExtent, position.maxScrollExtent);
      scrollController.jumpTo(clampedOffset);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => restore());
  }

  @override
  Widget build(BuildContext context) {
    final usesDesktopUiPreview = powerboardsUsesDesktopUiPreview(context);
    final usesMobileLayout = _usesMobileThreadLayout(context);
    final usesMobileEmptyState = _usesCompactMobileThreadEmptyState(context);
    final overlayHeaderScope = PowerboardsMobileOverlayHeaderScope.maybeOf(context);
    final mobileUnderHeaderContentPadding = usesMobileLayout
        ? 40.0 * Curves.easeOutCubic.transform(overlayHeaderScope?.collapseProgress ?? 0)
        : null;
    final usesCompactNewThreadPrompt = usesMobileLayout && widget.threadDisplayMode == ChatThreadDisplayMode.multiThreadComposer;
    final resolvedEmptyState =
        widget.emptyState ??
        (widget.threadDisplayMode == ChatThreadDisplayMode.multiThreadComposer
            ? Builder(
                builder: (context) => usesCompactNewThreadPrompt
                    ? _buildMobileNewThreadEmptyState(context)
                    : _buildThreadEmptyState(
                        context,
                        title: "Start a new thread",
                        description: _threadEmptyDescription,
                        compact: usesMobileEmptyState,
                      ),
              )
            : null);

    final chatBotView = ChatBotView(
      room: widget.client,
      chatClient: widget.chatClient,
      agentName: widget.agentName,
      threadDisplayMode: widget.threadDisplayMode,
      threadListPath: widget.threadListPath,
      documentPath: widget.documentPath,
      controller: _chatController,
      onAttachmentOpen: _openComposerAttachment,
      onAttachmentRemoved: (attachment) => widget.onComposerAttachmentRemoved?.call(attachment.path),
      selectedThreadPath: widget.selectedThreadPath,
      selectedThreadDisplayName: widget.selectedThreadDisplayName,
      onSelectedThreadPathChanged: widget.onSelectedThreadPathChanged,
      onSelectedThreadResolved: widget.onSelectedThreadResolved,
      newThreadResetVersion: widget.newThreadResetVersion,
      participantNames: widget.participantNames,
      initialMessage: widget.initialMessageText == null
          ? null
          : ChatMessage(
              id: widget.initialMessageID ?? widget.documentPath,
              text: widget.initialMessageText!,
              attachments: widget.initialMessageAttachments?.map((attachment) => attachment.path).toList() ?? const [],
            ),
      onMessageSent: _onMessageSent,
      fileInThreadBuilder: _fileInThreadBuilder,
      openFile: _openThreadAttachment,
      fileDropOverlayBuilder: widget.fileDropOverlayBuilder,
      chatInputBoxBuilder: usesMobileLayout ? (context, chatBox) => _buildAdaptiveMobileChatInputBox(context, chatBox) : null,
      toolsBuilder: (context, controller, snapshot) =>
          buildTools(context, widget.projectId, widget.client, widget.agentName, controller, snapshot),
      inputPlaceholder: Text(_chatPlaceholderText(widget.agentName)),
      emptyStateTitle: null,
      emptyStateDescription: usesMobileEmptyState ? null : _threadEmptyDescription,
      emptyState: resolvedEmptyState,
      inputContextMenuBuilder: powerboardsUsesSystemAdaptiveTextSelectionToolbar()
          ? powerboardsThreadMobileAttachmentContextMenuBuilder(
              onPasteFile: (name, dataStream, size) => _chatController.uploadFile(name, dataStream, size),
            )
          : powerboardsAdaptiveInputContextMenuBuilder,
      inputOnPressedOutside: powerboardsAdaptiveInputOnPressedOutside(),
      mobileStorageSaveSurfacePresenter: usesMobileLayout ? showPowerboardsThreadStorageSaveSurface : null,
      mobileUnderHeaderContentPadding: mobileUnderHeaderContentPadding,
      centerComposer: false,
      hideChatInput: widget.hideChatInput,
      showThreadList: false,
    );

    return IconTheme(
      data: const IconThemeData(size: 14),
      child: usesDesktopUiPreview ? ChatContextLayoutOverride(useMobileLayout: false, child: chatBotView) : chatBotView,
    );
  }
}

class MeshagentThreadListPane extends StatefulWidget {
  const MeshagentThreadListPane({
    super.key,
    required this.client,
    required this.onSelectedThreadPathChanged,
    this.onSelectedThreadResolved,
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
    this.mobileHideEmptyStateWhenNoEntries = false,
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
  final bool mobileHideEmptyStateWhenNoEntries;
  final ValueChanged<String?> onSelectedThreadPathChanged;
  final void Function(String? path, String? displayName)? onSelectedThreadResolved;

  @override
  State<MeshagentThreadListPane> createState() => _MeshagentThreadListPaneState();
}

class MeshagentInlineThreadCreatePrompt extends StatelessWidget {
  const MeshagentInlineThreadCreatePrompt({
    super.key,
    required this.onOpen,
    required this.onViewAllThreads,
    required this.currentThreadLabel,
    this.createItemTopPadding = 0,
    this.isSelected = false,
  });

  final VoidCallback onOpen;
  final VoidCallback onViewAllThreads;
  final String currentThreadLabel;
  final double createItemTopPadding;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final foreground = theme.colorScheme.foreground;
    const desktopActionButtonPadding = EdgeInsets.symmetric(horizontal: _desktopThreadListHorizontalPadding, vertical: 8);
    final threadIcon = AnimatedSwitcher(
      duration: powerboardsAdaptiveTransitionDuration(context),
      switchInCurve: powerboardsAdaptiveTransitionInCurve(context),
      switchOutCurve: powerboardsAdaptiveTransitionOutCurve(context),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(animation), child: child),
      ),
      child: Icon(
        isSelected ? LucideIcons.check : LucideIcons.messageSquare,
        key: ValueKey("${isSelected}_$currentThreadLabel"),
        size: 16,
        color: foreground,
      ),
    );

    return ColoredBox(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(top: createItemTopPadding),
        child: SizedBox(
          width: double.infinity,
          height: desktopPaneSecondaryControlHeight,
          child: Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: theme.colorScheme.accent,
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    onTap: onOpen,
                    child: Padding(
                      padding: desktopActionButtonPadding,
                      child: Row(
                        children: [
                          const SizedBox(width: _desktopThreadContentAlignmentOffset),
                          threadIcon,
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              currentThreadLabel,
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
              const SizedBox(width: desktopPaneHeaderButtonGap),
              IntrinsicWidth(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: theme.colorScheme.accent,
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    onTap: onViewAllThreads,
                    child: Padding(
                      padding: desktopActionButtonPadding,
                      child: Text(
                        "View all threads",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: _MeshagentThreadListPaneState.threadNameStyle(context),
                      ),
                    ),
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

class _MeshagentThreadListPaneState extends State<MeshagentThreadListPane> {
  static TextStyle threadNameStyle(BuildContext context, {FontWeight fontWeight = FontWeight.w400, Color? color}) {
    final theme = ShadTheme.of(context);
    return powerboardsMetaTextStyle(color: color ?? theme.colorScheme.mutedForeground, fontWeight: fontWeight);
  }

  static TextStyle createActionStyle(BuildContext context, {FontWeight fontWeight = FontWeight.w700}) {
    final theme = ShadTheme.of(context);
    return powerboardsInterTextStyle(
      fontSize: chatBubbleMarkdownBaseFontSize(context),
      fontWeight: fontWeight,
      color: theme.colorScheme.foreground,
    );
  }

  agent_sessions.MessagingChatClient? _threadListChatClient;
  agent_sessions.AgentThreadStorageRepository? _threadListStorage;
  String? _threadListPath;
  String? _threadListAgentName;
  Object? _threadListError;
  bool _threadListLoading = true;
  StreamSubscription<RoomEvent>? _roomSubscription;

  String? _normalizedThreadListPath(String? path) {
    return _agentThreadListPath(path);
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

  DateTime _threadCreatedSortDate(_ThreadListEntry entry) {
    if (entry.createdAt.trim().isNotEmpty) {
      return _parseThreadDate(entry.createdAt);
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  String _threadNameFromPath(String path) {
    return defaultThreadDisplayNameFromPath(path);
  }

  List<_ThreadListEntry> _threadListEntries() {
    final storage = _threadListStorage;
    if (storage == null) {
      return const [];
    }

    final entries = storage.entries().map((entry) {
      final displayName = entry.name.trim().isEmpty ? null : entry.name.trim();
      return _ThreadListEntry(
        displayName: displayName,
        name: displayName ?? _threadNameFromPath(entry.path),
        path: entry.path,
        createdAt: entry.createdAt,
        modifiedAt: entry.modifiedAt,
      );
    }).toList();

    entries.sort((a, b) {
      final dateComparison = _threadSortDate(b).compareTo(_threadSortDate(a));
      if (dateComparison != 0) {
        return dateComparison;
      }

      final createdDateComparison = _threadCreatedSortDate(b).compareTo(_threadCreatedSortDate(a));
      if (createdDateComparison != 0) {
        return createdDateComparison;
      }

      return a.path.compareTo(b.path);
    });
    return entries;
  }

  void _onThreadListChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _onThreadStatusChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _onRoomEvent(RoomEvent event) {
    if (!mounted || event is! RoomMessageEvent || event.message.type != "agent-message") {
      return;
    }

    final message = event.message.message;
    final payload = message["type"] is String ? message : message["payload"];
    final normalizedPayload = payload is Map<String, dynamic>
        ? payload
        : payload is Map
        ? Map<String, dynamic>.from(payload)
        : null;
    if (normalizedPayload == null) {
      return;
    }

    if (trackAgentThreadStatusPayload(room: widget.client, payload: normalizedPayload) && mounted) {
      setState(() {});
    }
  }

  Future<void> _closeThreadListDocument() async {
    final storage = _threadListStorage;
    final chatClient = _threadListChatClient;

    if (storage != null) {
      storage.removeListener(_onThreadListChanged);
    }

    _threadListStorage = null;
    _threadListChatClient = null;
    _threadListPath = null;
    _threadListAgentName = null;
    _threadListLoading = false;

    await storage?.close();
    await chatClient?.stop();
  }

  Future<void> _rebindThreadListDocument() async {
    final nextPath = _normalizedThreadListPath(widget.threadListPath);
    final nextAgentName = widget.agentName?.trim();
    if (nextPath == _threadListPath && nextAgentName == _threadListAgentName && _threadListStorage != null) {
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
      final chatClient = agent_sessions.MessagingChatClient(room: widget.client, agentName: nextAgentName);
      final storage = agent_sessions.AgentThreadStorageRepository(chatClient: chatClient);
      storage.addListener(_onThreadListChanged);
      await chatClient.start();
      await storage.open();
      if (!mounted || _normalizedThreadListPath(widget.threadListPath) != nextPath) {
        storage.removeListener(_onThreadListChanged);
        await storage.close();
        await chatClient.stop();
        return;
      }

      setState(() {
        _threadListStorage = storage;
        _threadListChatClient = chatClient;
        _threadListPath = nextPath;
        _threadListAgentName = nextAgentName;
        _threadListLoading = false;
        _threadListError = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _threadListStorage = null;
        _threadListChatClient = null;
        _threadListPath = null;
        _threadListAgentName = null;
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

    try {
      await _threadListStorage?.renameThread(entry.path, trimmed);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ShadToaster.of(context).show(ShadToast.destructive(description: Text("Unable to rename thread: $e")));
    }
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
      await _threadListStorage?.deleteThread(entry.path);
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
    _roomSubscription = widget.client.listen(_onRoomEvent);
    widget.client.messaging.addListener(_onThreadStatusChanged);
    unawaited(_rebindThreadListDocument());
  }

  @override
  void didUpdateWidget(covariant MeshagentThreadListPane oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.client != widget.client) {
      _roomSubscription?.cancel();
      oldWidget.client.messaging.removeListener(_onThreadStatusChanged);
      _roomSubscription = widget.client.listen(_onRoomEvent);
      widget.client.messaging.addListener(_onThreadStatusChanged);
    }

    if (oldWidget.client != widget.client || oldWidget.threadListPath != widget.threadListPath || oldWidget.agentName != widget.agentName) {
      unawaited(_rebindThreadListDocument());
    }

    if (oldWidget.newThreadResetVersion != widget.newThreadResetVersion && widget.selectedThreadPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSelectedThreadPathChanged(null);
        widget.onSelectedThreadResolved?.call(null, null);
      });
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    widget.client.messaging.removeListener(_onThreadStatusChanged);
    unawaited(_closeThreadListDocument());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _threadListEntries();
    final isMobileDialogList = ResponsiveBreakpoints.of(context).isMobile && widget.mobileUseDialogListStyle;
    final surface = _buildThreadListSurface(entries);

    if (isMobileDialogList) {
      return ColoredBox(color: Colors.transparent, child: surface);
    }

    return ColoredBox(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Expanded(child: surface)],
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
      if (widget.mobileHideEmptyStateWhenNoEntries) {
        return const SizedBox.expand();
      }

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
            onOpen: () {
              widget.onSelectedThreadPathChanged(null);
              widget.onSelectedThreadResolved?.call(null, null);
            },
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
            onOpen: () {
              widget.onSelectedThreadPathChanged(null);
              widget.onSelectedThreadResolved?.call(null, null);
            },
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
          onOpen: () {
            widget.onSelectedThreadPathChanged(entry.path);
            widget.onSelectedThreadResolved?.call(entry.path, entry.name);
          },
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
              style: powerboardsInterTextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: shadForeground),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: powerboardsSecondaryTextStyle(color: shadMutedForeground),
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
    required this.displayName,
    required this.name,
    required this.path,
    required this.createdAt,
    required this.modifiedAt,
  });

  final String? displayName;
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
          padding: const EdgeInsets.symmetric(horizontal: _desktopThreadListHorizontalPadding),
          hoverBackgroundColor: theme.colorScheme.accent,
          pressedBackgroundColor: theme.colorScheme.accent,
          leading: Padding(
            padding: const EdgeInsets.only(left: _desktopThreadContentAlignmentOffset),
            child: _newThreadActionIcon(context, selected, color: foreground),
          ),
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
        (isMobile ? 12.0 : _desktopThreadListHorizontalPadding + _desktopThreadContentAlignmentOffset) +
        _threadListLeadingWidth(isMobile) +
        _threadListGap(isMobile);

    return Padding(
      padding: EdgeInsets.fromLTRB(leadingInset, isMobile ? 4 : 8, 0, 0),
      child: Text("Add and manage multiple threads.", style: powerboardsMetaTextStyle(color: shadMutedForeground, height: 1.4)),
    );
  }
}

Widget _newThreadActionIcon(BuildContext context, bool selected, {required Color color}) {
  return AnimatedSwitcher(
    duration: powerboardsAdaptiveTransitionDuration(context),
    switchInCurve: powerboardsAdaptiveTransitionInCurve(context),
    switchOutCurve: powerboardsAdaptiveTransitionOutCurve(context),
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
      return 0;
    }

    return _threadListLeadingWidth(isMobile);
  }

  EdgeInsets _contentPadding(bool isMobile) {
    if (isMobile) {
      return EdgeInsets.zero;
    }

    return const EdgeInsets.fromLTRB(_desktopThreadContentAlignmentOffset, 8, 0, 8);
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
        final leadingWidth = _leadingWidth(isMobile);
        final textStyle = isMobile && widget.mobileUseDialogListStyle
            ? powerboardsFileListTitleStyle().copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w400)
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
                              if (leadingWidth > 0) ...[
                                SizedBox(
                                  width: leadingWidth,
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
                              ],
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
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
                                    if (selected && isMobile && widget.mobileUseDialogListStyle) ...[
                                      const SizedBox(width: 12),
                                      buildPowerboardsCurrentPill(),
                                    ],
                                  ],
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
const double _desktopThreadContentAlignmentOffset = 10;

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
      return 0;
    }

    return _threadListLeadingWidth(isMobile);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final leadingWidth = _leadingWidth(isMobile);
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
                  if (!isMobile) const SizedBox(width: _desktopThreadContentAlignmentOffset),
                  if (leadingWidth > 0) ...[
                    SizedBox(
                      width: leadingWidth,
                      child: const Center(child: Icon(LucideIcons.check, size: 16, color: shadForeground)),
                    ),
                    SizedBox(width: _threadListGap(isMobile)),
                  ],
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

Widget buildTools(
  BuildContext context,
  String projectId,
  RoomClient room,
  String? agentName,
  ChatThreadController controller,
  ChatThreadSnapshot state,
) {
  final usesNativeMobileAttachMenu = powerboardsUsesNativeMobileDialogLayout(context);

  Future<RoomClient> connectRoomClient(String roomName) async {
    final client = getMeshagentClient();
    final conn = await client.connectRoom(projectId: projectId, roomName: roomName);
    final roomClient = RoomClient(
      protocolFactory: WebSocketClientProtocol.createFactory(url: conn.roomUrl, token: conn.jwt),
    );
    await roomClient.start();
    await roomClient.ready;
    return roomClient;
  }

  final normalizedAgentName = agentName?.trim();
  RemoteParticipant? agent;
  if (normalizedAgentName != null && normalizedAgentName.isNotEmpty) {
    for (final participant in room.messaging.remoteParticipants) {
      if (participant.getAttribute("name") == normalizedAgentName) {
        agent = participant;
        break;
      }
    }
  }

  final oauth2CallbackUrl = MeshagentConfig.current?.oauth2CallbackUrl;
  final showMcpConnectors = state.agentOnline && state.supportsMcp && agent != null && oauth2CallbackUrl != null;
  final canAddMcpServices = showMcpConnectors && room.apiGrant?.admin != null;
  final availableConnectors = !showMcpConnectors
      ? null
      : () async {
          return mcpConnectorsFromRoomServices(services: await room.services.list(), agentName: normalizedAgentName);
        };
  final onConnectorSetup = !showMcpConnectors
      ? null
      : (Connector connector) async {
          await connector.authenticate(room, agent!, oauth2CallbackUrl);
        };
  final onAddMcpConnector = !canAddMcpServices
      ? null
      : () async {
          await showShadDialog<bool?>(
            context: context,
            builder: (context) => InstallServiceDialog(
              type: ServiceType.mcp,
              projectId: projectId,
              roomName: room.roomName,
              onInstalled: (ctx, projectId, roomName, serviceId) {
                Navigator.of(ctx).pop(true);
              },
            ),
          );
        };

  return ChatThreadToolArea(
    leading: usesNativeMobileAttachMenu
        ? PowerboardsMobileChatAttachButton(
            alwaysShowAttachFiles: true,
            controller: controller,
            availableRooms: () => listMeshagentRooms(projectId),
            connectRoomClient: connectRoomClient,
          )
        : PowerboardsDesktopChatAttachButton(
            alwaysShowAttachFiles: true,
            controller: controller,
            availableRooms: () => listMeshagentRooms(projectId),
            connectRoomClient: connectRoomClient,
            agentName: normalizedAgentName,
            showMcpConnectors: showMcpConnectors,
          ),
    footer: !usesNativeMobileAttachMenu && showMcpConnectors && controller.isToolkitEnabled("mcp")
        ? ChatThreadMcpFooter(
            controller: controller,
            agentName: normalizedAgentName,
            showMcpConnectors: showMcpConnectors,
            availableConnectors: availableConnectors,
            onConnectorSetup: onConnectorSetup,
            onAddMcpConnector: onAddMcpConnector,
          )
        : null,
  );
}
