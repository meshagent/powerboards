import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:http/http.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/shell/shell_agent.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:powerboards/ui/powerboards_toasts.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_agents/meshagent_agents.dart' as agent_sessions;
import 'package:meshagent_flutter/meshagent_flutter.dart';
import 'package:meshagent_flutter_auth/meshagent_flutter_auth.dart';
import 'package:meshagent_flutter_dev/developer_console.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/chat/conversation_descriptor.dart' as ma;
import 'package:meshagent_flutter_shadcn/chat/file_prompt_actions.dart';
import 'package:meshagent_flutter_shadcn/meetings/audio_visualization.dart';
import 'package:meshagent_flutter_shadcn/meetings/meetings.dart';
import 'package:meshagent_flutter_shadcn/markdown_viewer.dart';
import 'package:meshagent_flutter_shadcn/secrets/keychain_dialog.dart';
import 'package:meshagent_flutter_shadcn/storage/transcript_file_name.dart';
import 'package:meshagent_flutter_shadcn/theme/colors.dart';
import 'package:meshagent_flutter_shadcn/viewers/builder.dart';
import 'package:meshagent_flutter_shadcn/voice/voice.dart';

import 'package:powerboards/chat/hangup_button.dart';
import 'package:powerboards/meshagent/archive_extract.dart';
import 'package:powerboards/meshagent/archive_extract_toast.dart';
import 'package:powerboards/livekit/room.dart' as room;
import 'package:powerboards/livekit/voice_meeting_controls.dart';
import 'package:powerboards/meshagent/agent_participants.dart';
import 'package:powerboards/meshagent/agent_option.dart';
import 'package:powerboards/meshagent/agents_dropdown.dart';
import 'package:powerboards/meshagent/file_attachment_index.dart';
import 'package:powerboards/meshagent/file_preview_origin.dart';
import 'package:powerboards/meshagent/file_preview_state.dart';
import 'package:powerboards/meshagent/file_list_primitives.dart';
import 'package:powerboards/meshagent/file_table_view.dart';
import 'package:powerboards/meshagent/thread_display_name.dart';
import 'package:powerboards/meshagent/grant.dart' as grant;
import 'package:powerboards/meshagent/loader.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/options_menu.dart';
import 'package:powerboards/meshagent/path.dart';
import 'package:powerboards/meshagent/room_lifecycle_errors.dart';
import 'package:powerboards/meshagent/share_remote_file.dart';
import 'package:powerboards/meshagent/thread_view.dart';
import 'package:powerboards/meshagent/tool_connection_scope.dart';
import 'package:powerboards/meshagent/tools/ui_toolkit.dart';
import 'package:powerboards/meshagent/v1_file_preview_source.dart';
import 'package:powerboards/meshagent/wait_for_agent_participant_builder.dart';
import 'package:powerboards/nav/leave_meeting.dart';
import 'package:powerboards/nav/nav.dart';
import 'package:powerboards/nav/nav_rooms.dart';
import 'package:powerboards/nav/delete_room_dialog.dart';
import 'package:powerboards/nav/rename_room_dialog.dart';
import 'package:powerboards/nav/update_room_perms_dialog.dart';
import 'package:powerboards/powerboards_controller/powerboards_controller.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/powerboards_ui/v1/components/chat/pb_voice_session_empty_state.dart';
import 'package:powerboards/powerboards_ui/v1/components/dialogs/pb_dialog_shell.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_drop_target.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_archive_extract.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_layout_values.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_sidepane_file_list.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_room_panel.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_room_panel_mount.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_thread_header.dart';
import 'package:powerboards/powerboards_ui/v1/components/meet/pb_meet_header.dart';
import 'package:powerboards/powerboards_ui/v1/components/meet/pb_meet_transcript_panel.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_menu_anchor.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_switcher_menu.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_button.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_empty_state.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_svg_icon.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';
import 'package:powerboards/powerboards_ui/v1/preview/preview_room_rail_menu.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_tokens.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_typography.dart';
import 'package:powerboards/settings/selected_room.dart';
import 'package:powerboards/settings/ui_mode.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:powerboards/ui/app_context_menu.dart';
import 'package:powerboards/ui/avatar_menu_button.dart';
import 'package:powerboards/ui/desktop_sidetray_toggle.dart';
import 'package:powerboards/ui/keyboard_safe.dart';
import 'package:powerboards/ui/meeting_view.dart';
import 'package:powerboards/ui/pane_empty_state.dart';
import 'package:powerboards/ui/powerboards_back_icon_button.dart';
import 'package:powerboards/ui/powerboards_breakpoints.dart';
import 'package:powerboards/ui/powerboards_mobile_overlay_header.dart';
import 'package:powerboards/ui/pane_header_action_scope.dart';
import 'package:powerboards/ui/resizable_split_view.dart';
import 'package:powerboards/ui/sweep_status_text.dart';
import 'package:url_launcher/url_launcher.dart';

const defaultDebugSize = 0.4;
final meetingHeaderTitleStyle = powerboardsSectionTitleStyle();
const double _meetingToolbarCompactThreshold = 620;
const double _desktopPreviewMeetingToolbarCompactThreshold = 720;
const double _meetingToolbarPreferredExpandedWidth = 640;
const double _meetingToolbarPreferredCompactWidth = _meetingToolbarCompactThreshold;
const double _mobileRoomHeaderGap = 8;
const String _roomPaneQueryParameter = 'pane';
const String _transcriptRootFolder = 'transcripts';
const String _meetingTranscriptFolder = '$_transcriptRootFolder/meetings';

enum _MobileRoomPane { chat, files, meeting }

class _MobileFilesLocation {
  const _MobileFilesLocation({required this.folder, required this.openedFile});

  final String folder;
  final String? openedFile;

  String get title {
    final path = openedFile ?? folder;
    if (path.isEmpty) {
      return "Files";
    }

    final fileName = path.split('/').where((segment) => segment.isNotEmpty).lastOrNull;
    if (fileName == null) {
      return "Files";
    }

    if (openedFile == null) {
      return fileName;
    }
    if (isThreadPath(path)) {
      return threadFileDisplayNameFromPath(path);
    }
    return formatTranscriptFileNameForDisplay(fileName);
  }

  String? get backFolderPath {
    if (openedFile != null) {
      return folder;
    }

    if (folder.isNotEmpty) {
      return parentPath(folder);
    }

    return null;
  }

  String get backTooltip {
    if (openedFile != null) {
      return "Back to folder";
    }

    if (folder.isNotEmpty) {
      return "Back to parent folder";
    }

    return "Back to chat";
  }

  factory _MobileFilesLocation.fromUri(Uri uri) {
    final raw = uri.queryParameters['p'] ?? '';

    if (raw.isEmpty) {
      return const _MobileFilesLocation(folder: "", openedFile: null);
    }

    final isFolder = raw.endsWith('/');
    final normalizedPath = joinPaths(raw, '');

    if (isFolder) {
      return _MobileFilesLocation(folder: normalizedPath, openedFile: null);
    }

    return _MobileFilesLocation(folder: parentPath(normalizedPath), openedFile: normalizedPath);
  }
}

class _MobileFilesBackDestination {
  const _MobileFilesBackDestination({required this.label, required this.path});

  final String label;
  final String path;
}

class _MobileMeetingOrigin {
  const _MobileMeetingOrigin({required this.pane, required this.rawPath});

  final _MobileRoomPane pane;
  final String? rawPath;
}

class _MobileChatHeaderContext {
  const _MobileChatHeaderContext({
    required this.agentName,
    required this.agentKey,
    required this.currentThreadLabel,
    required this.selectedThreadPath,
    required this.threadListPath,
    required this.isVoiceOnly,
  });

  final String agentName;
  final String? agentKey;
  final String currentThreadLabel;
  final String? selectedThreadPath;
  final String? threadListPath;
  final bool isVoiceOnly;

  bool get canOpenContextSwitcher => threadListPath != null || agentKey != null;

  _MobileChatHeaderContext withThreadSelection({required String currentThreadLabel, required String? selectedThreadPath}) {
    return _MobileChatHeaderContext(
      agentName: agentName,
      agentKey: agentKey,
      currentThreadLabel: currentThreadLabel,
      selectedThreadPath: selectedThreadPath,
      threadListPath: threadListPath,
      isVoiceOnly: isVoiceOnly,
    );
  }
}

enum _MobileRoomContextSwitcherState { threads, agents }

class _MobileRoomContextAgentOption {
  const _MobileRoomContextAgentOption({
    required this.routeId,
    required this.name,
    required this.description,
    required this.threadListPath,
    required this.leadingIcon,
    required this.supportsThreads,
    required this.isVoiceOnly,
  });

  final String routeId;
  final String name;
  final String description;
  final String? threadListPath;
  final IconData leadingIcon;
  final bool supportsThreads;
  final bool isVoiceOnly;
}

class _MobileSelectedThreadLabelResolver extends StatefulWidget {
  const _MobileSelectedThreadLabelResolver({
    super.key,
    required this.client,
    required this.agentName,
    required this.threadListPath,
    required this.selectedThreadPath,
    required this.onResolved,
  });

  final RoomClient client;
  final String? agentName;
  final String threadListPath;
  final String selectedThreadPath;
  final ValueChanged<String?> onResolved;

  @override
  State<_MobileSelectedThreadLabelResolver> createState() => _MobileSelectedThreadLabelResolverState();
}

class _MobileSelectedThreadLabelResolverState extends State<_MobileSelectedThreadLabelResolver> {
  agent_sessions.MessagingChatClient? _chatClient;
  agent_sessions.AgentThreadStorageRepository? _storage;
  String? _openedThreadListPath;
  String? _openedAgentName;
  String? _lastResolvedDisplayName;

  String _normalizedSelectedThreadPath() => widget.selectedThreadPath.trim();

  String? _displayNameForSelectedThread() {
    final storage = _storage;
    final selectedThreadPath = _normalizedSelectedThreadPath();
    if (storage == null) {
      return defaultThreadDisplayNameFromPath(selectedThreadPath);
    }
    for (final entry in storage.entries()) {
      if (entry.path.trim() != selectedThreadPath) {
        continue;
      }
      final trimmedName = entry.name.trim();
      return trimmedName.isEmpty ? defaultThreadDisplayNameFromPath(selectedThreadPath) : trimmedName;
    }

    return defaultThreadDisplayNameFromPath(selectedThreadPath);
  }

  void _emitResolved() {
    final displayName = _displayNameForSelectedThread();
    if (displayName == _lastResolvedDisplayName) {
      return;
    }

    _lastResolvedDisplayName = displayName;
    widget.onResolved(displayName);
  }

  void _onThreadListChanged() {
    if (!mounted) {
      return;
    }

    _emitResolved();
  }

  Future<void> _closeDocument() async {
    final storage = _storage;
    final chatClient = _chatClient;

    storage?.removeListener(_onThreadListChanged);
    _storage = null;
    _chatClient = null;
    _openedThreadListPath = null;
    _openedAgentName = null;

    await storage?.close();
    await chatClient?.stop();
  }

  Future<void> _rebindDocument() async {
    final nextThreadListPath = _agentThreadListPath(widget.threadListPath);
    if (nextThreadListPath == null) {
      _emitResolved();
      return;
    }
    final nextAgentName = widget.agentName?.trim();
    if (_openedThreadListPath == nextThreadListPath && _openedAgentName == nextAgentName && _storage != null) {
      _emitResolved();
      return;
    }

    await _closeDocument();

    try {
      final chatClient = agent_sessions.MessagingChatClient(room: widget.client, agentName: nextAgentName);
      final storage = agent_sessions.AgentThreadStorageRepository(chatClient: chatClient);
      storage.addListener(_onThreadListChanged);
      await chatClient.start();
      await storage.open();
      if (!mounted || _agentThreadListPath(widget.threadListPath) != nextThreadListPath) {
        storage.removeListener(_onThreadListChanged);
        await storage.close();
        await chatClient.stop();
        return;
      }

      _storage = storage;
      _chatClient = chatClient;
      _openedThreadListPath = nextThreadListPath;
      _openedAgentName = nextAgentName;
      _emitResolved();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _emitResolved();
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_rebindDocument());
  }

  @override
  void didUpdateWidget(covariant _MobileSelectedThreadLabelResolver oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.client != widget.client || oldWidget.threadListPath != widget.threadListPath || oldWidget.agentName != widget.agentName) {
      unawaited(_rebindDocument());
      return;
    }

    if (oldWidget.selectedThreadPath != widget.selectedThreadPath) {
      _emitResolved();
    }
  }

  @override
  void dispose() {
    unawaited(_closeDocument());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

@visibleForTesting
typedef PowerboardsDesktopPreviewChatClientFactory = agent_sessions.BaseChatClient Function(RoomClient client, String? agentName);

@visibleForTesting
typedef PowerboardsDesktopPreviewThreadStorageFactory =
    agent_sessions.ThreadStorageRepository Function(agent_sessions.BaseChatClient chatClient);

class _DesktopPreviewThreadEntry {
  const _DesktopPreviewThreadEntry({
    required this.storage,
    required this.path,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
  });

  final agent_sessions.ThreadStorageRepository storage;
  final String path;
  final String name;
  final String createdAt;
  final String modifiedAt;
}

class _DesktopPreviewTranscriptRecord {
  const _DesktopPreviewTranscriptRecord({required this.data, required this.sortDate});

  final PbAttachmentListItemData data;
  final DateTime? sortDate;
}

class _DesktopPreviewMeetPaneData {
  const _DesktopPreviewMeetPaneData({required this.transcripts, required this.roomHasStoredFiles});

  final List<PbAttachmentListItemData> transcripts;
  final bool roomHasStoredFiles;
}

class _FilePromptAgentChoice {
  const _FilePromptAgentChoice({required this.routeId, required this.agentName, required this.action});

  final String routeId;
  final String agentName;
  final ChatFilePromptAction action;
}

@visibleForTesting
T? powerboardsPreferScopedValue<T>({T? scopedValue, T? fallbackValue}) {
  return scopedValue ?? fallbackValue;
}

@visibleForTesting
bool powerboardsShouldDisconnectVoiceSessionForAgentSwitch({
  required bool voiceSessionConnected,
  required String? currentRouteId,
  required String? nextRouteId,
}) {
  return voiceSessionConnected && nextRouteId != null && nextRouteId != currentRouteId;
}

@visibleForTesting
bool powerboardsResolvePreviewRailVoiceSessionActive({
  required bool actualVoiceSessionActive,
  required bool pendingVoiceSessionDisconnect,
}) {
  if (pendingVoiceSessionDisconnect && actualVoiceSessionActive) {
    return false;
  }
  return actualVoiceSessionActive;
}

DateTime? _desktopPreviewTranscriptSortDate(StorageEntry entry) {
  return entry.updatedAt ?? entry.createdAt;
}

PbAttachmentListItemData _desktopPreviewTranscriptItem({required String path, required String fileName}) {
  final displayTitle = formatTranscriptFileNameForDisplay(fileName).trim();

  return PbAttachmentListItemData.fromFileName(
    title: displayTitle.isEmpty ? fileName : displayTitle,
    subtitle: 'Transcript',
    path: path,
    fileType: PbAttachmentFileType.transcript,
  );
}

List<PbAttachmentListItemData> _selectDesktopPreviewRecentTranscripts(Iterable<_DesktopPreviewTranscriptRecord> records) {
  final sorted = records.toList(growable: false)
    ..sort((left, right) {
      final leftDate = left.sortDate;
      final rightDate = right.sortDate;
      if (leftDate == null && rightDate == null) {
        return left.data.title.compareTo(right.data.title);
      }
      if (leftDate == null) {
        return 1;
      }
      if (rightDate == null) {
        return -1;
      }
      return rightDate.compareTo(leftDate);
    });

  final now = DateTime.now();
  final recentCutoff = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
  final recent = sorted
      .where((record) {
        final sortDate = record.sortDate;
        return sortDate != null && !sortDate.isBefore(recentCutoff);
      })
      .toList(growable: false);
  final selected = recent.isNotEmpty ? recent : sorted.take(7);

  return [for (final record in selected) record.data];
}

bool _isTranscriptFileName(String fileName) {
  return fileName.toLowerCase().endsWith(transcriptFileExtension);
}

String? _agentThreadListPath(String? path) {
  final normalized = path?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return "agent://threads";
}

@visibleForTesting
String? powerboardsDesktopPreviewSelectedThreadPathForVisibleThreads({
  required String? selectedThreadPath,
  required Iterable<String> threadPaths,
  required bool threadListLoaded,
}) {
  final normalizedSelectedThreadPath = selectedThreadPath?.trim();
  if (normalizedSelectedThreadPath == null || normalizedSelectedThreadPath.isEmpty) {
    return null;
  }

  if (!threadListLoaded) {
    return normalizedSelectedThreadPath;
  }

  for (final threadPath in threadPaths) {
    if (threadPath.trim() == normalizedSelectedThreadPath) {
      return normalizedSelectedThreadPath;
    }
  }

  return null;
}

@visibleForTesting
String? powerboardsDesktopPreviewVerifiedThreadPathForLoadedThreads({
  required String? selectedThreadPath,
  required Iterable<String> threadPaths,
  required bool threadListLoaded,
}) {
  if (!threadListLoaded) {
    return null;
  }

  return powerboardsDesktopPreviewSelectedThreadPathForVisibleThreads(
    selectedThreadPath: selectedThreadPath,
    threadPaths: threadPaths,
    threadListLoaded: true,
  );
}

@visibleForTesting
bool powerboardsDesktopPreviewThreadTitleIsGenericFallback(String? title) {
  final normalized = title?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return true;
  }

  return normalized == 'new chat' || normalized == 'new thread';
}

@visibleForTesting
List<MeshElement> powerboardsDesktopPreviewThreadMessageElements(RuntimeDocument document) {
  final rootChildren = document.root.getChildren().whereType<MeshElement>().toList(growable: false);
  for (final child in rootChildren) {
    if (child.tagName == 'messages') {
      return child.getChildren().whereType<MeshElement>().toList(growable: false);
    }
  }

  return rootChildren.where(powerboardsDesktopPreviewIsThreadMessageElement).toList(growable: false);
}

@visibleForTesting
bool powerboardsDesktopPreviewIsThreadMessageElement(MeshElement element) {
  return switch (element.tagName) {
    'message' || 'reasoning' || 'exec' || 'event' => true,
    _ => false,
  };
}

@visibleForTesting
String powerboardsDesktopPreviewThreadAttachmentPath(MeshElement attachment) {
  if (attachment.tagName != 'file' && attachment.tagName != 'image') {
    return '';
  }

  for (final attributeName in const ['path', 'url', 'src', 'title', 'name', 'alt']) {
    final rawPath = attachment.getAttribute(attributeName);
    if (rawPath is! String) {
      continue;
    }

    final filePath = powerboardsStorageAttachmentPathFromUrl(rawPath);
    if (filePath.isNotEmpty) {
      return filePath;
    }
  }

  return '';
}

@visibleForTesting
List<String> powerboardsDesktopPreviewAgentMessageAttachmentPaths(agent_sessions.AgentMessage message) {
  Iterable<Object?> content = const <Object?>[];
  if (message is agent_sessions.StartThread) {
    content = message.content ?? const <Object?>[];
  } else if (message is agent_sessions.TurnStart) {
    content = message.content;
  } else if (message is agent_sessions.TurnSteer) {
    content = message.content;
  } else if (message is agent_sessions.TurnStartAccepted) {
    content = message.content;
  }

  final paths = <String>[];
  final seen = <String>{};
  for (final attachment in content.whereType<agent_sessions.AgentFileContent>()) {
    final path = powerboardsStorageAttachmentPathFromUrl(attachment.url);
    if (path.isNotEmpty && seen.add(path)) {
      paths.add(path);
    }
  }
  return paths;
}

@visibleForTesting
List<String> powerboardsDesktopPreviewAttachmentThreadPathsForSelectedThread(String? selectedThreadPath) {
  final normalizedPath = normalizePowerboardsThreadAttachmentPath(selectedThreadPath ?? '');
  if (normalizedPath.isEmpty || powerboardsThreadAttachmentMatchKey(normalizedPath).isEmpty) {
    return const <String>[];
  }

  return <String>[normalizedPath];
}

@visibleForTesting
String powerboardsDesktopPreviewAttachmentThreadScopeSignature({required String? selectedThreadPath, required String? selectedThreadName}) {
  final paths = powerboardsDesktopPreviewAttachmentThreadPathsForSelectedThread(selectedThreadPath);
  if (paths.isEmpty) {
    return '';
  }

  return '${paths.single}\u{1d}${selectedThreadName?.trim() ?? ''}';
}

@visibleForTesting
bool powerboardsDesktopPreviewShouldLoadThreadAttachments({required PbRoomPanelTab selectedTab, required bool filePreviewOpen}) {
  return selectedTab == PbRoomPanelTab.files || filePreviewOpen;
}

@visibleForTesting
String powerboardsDesktopPreviewSelectedThreadTitleForVisibleThreads({
  required String? selectedThreadPath,
  required String? currentThreadLabel,
  required bool currentThreadLabelTrusted,
  required Map<String, String> threadNamesByPath,
  required bool threadListLoaded,
}) {
  final normalizedSelectedThreadPath = selectedThreadPath?.trim();
  if (normalizedSelectedThreadPath == null || normalizedSelectedThreadPath.isEmpty) {
    final normalizedCurrentThreadLabel = currentThreadLabel?.trim();
    return normalizedCurrentThreadLabel == null || normalizedCurrentThreadLabel.isEmpty ? 'New thread' : normalizedCurrentThreadLabel;
  }

  for (final entry in threadNamesByPath.entries) {
    if (entry.key.trim() != normalizedSelectedThreadPath) {
      continue;
    }
    final normalizedThreadName = entry.value.trim();
    return normalizedThreadName.isEmpty ? defaultThreadDisplayNameFromPath(normalizedSelectedThreadPath) : normalizedThreadName;
  }

  final normalizedCurrentThreadLabel = currentThreadLabel?.trim();
  if (currentThreadLabelTrusted &&
      normalizedCurrentThreadLabel != null &&
      normalizedCurrentThreadLabel.isNotEmpty &&
      !powerboardsDesktopPreviewThreadTitleIsGenericFallback(normalizedCurrentThreadLabel) &&
      !shouldBackfillThreadDisplayName(normalizedCurrentThreadLabel)) {
    return normalizedCurrentThreadLabel;
  }

  final fallbackThreadLabel = defaultThreadDisplayNameFromPath(normalizedSelectedThreadPath);
  return fallbackThreadLabel;
}

@visibleForTesting
List<PbThreadListItemData> powerboardsDesktopPreviewThreadItemsForVisibleThreads({
  required String? selectedThreadPath,
  required String? selectedThreadTitle,
  required Iterable<PbThreadListItemData> threadItems,
  required bool threadListLoaded,
}) {
  final items = threadItems.toList(growable: true);
  if (threadListLoaded) {
    return items;
  }

  final normalizedSelectedThreadPath = selectedThreadPath?.trim();
  if (normalizedSelectedThreadPath == null || normalizedSelectedThreadPath.isEmpty) {
    return items;
  }

  if (items.any((thread) => thread.id.trim() == normalizedSelectedThreadPath)) {
    return items;
  }

  final trimmedTitle = selectedThreadTitle?.trim();
  final fallbackTitle = defaultThreadDisplayNameFromPath(normalizedSelectedThreadPath);
  final title = trimmedTitle == null || trimmedTitle.isEmpty ? fallbackTitle : trimmedTitle;

  return <PbThreadListItemData>[PbThreadListItemData(id: normalizedSelectedThreadPath, title: title, actionsEnabled: false), ...items];
}

class _DesktopPreviewThreadList extends StatefulWidget {
  const _DesktopPreviewThreadList({
    required this.client,
    required this.agentName,
    required this.threadListPath,
    required this.builder,
    this.chatClientFactory,
    this.threadStorageFactory,
    this.disposeChatClient = true,
  });

  final RoomClient client;
  final String? agentName;
  final String? threadListPath;
  final Widget Function(BuildContext context, List<_DesktopPreviewThreadEntry> threads, bool threadListLoaded) builder;
  final PowerboardsDesktopPreviewChatClientFactory? chatClientFactory;
  final PowerboardsDesktopPreviewThreadStorageFactory? threadStorageFactory;
  final bool disposeChatClient;

  @override
  State<_DesktopPreviewThreadList> createState() => _DesktopPreviewThreadListState();
}

class _DesktopPreviewThreadListState extends State<_DesktopPreviewThreadList> {
  agent_sessions.BaseChatClient? _chatClient;
  agent_sessions.ThreadStorageRepository? _storage;
  String? _openedThreadListPath;
  String? _openedAgentName;

  String? _normalizedThreadListPath() {
    return _agentThreadListPath(widget.threadListPath);
  }

  DateTime _parseThreadDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return parsed.toUtc();
  }

  DateTime _threadSortDate(_DesktopPreviewThreadEntry entry) {
    if (entry.modifiedAt.trim().isNotEmpty) {
      return _parseThreadDate(entry.modifiedAt);
    }
    if (entry.createdAt.trim().isNotEmpty) {
      return _parseThreadDate(entry.createdAt);
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  List<_DesktopPreviewThreadEntry> _entries() {
    final storage = _storage;
    if (storage == null) {
      return const <_DesktopPreviewThreadEntry>[];
    }

    final entries = storage.entries().map((entry) {
      return _DesktopPreviewThreadEntry(
        storage: storage,
        path: entry.path,
        name: entry.name.trim().isNotEmpty ? entry.name.trim() : defaultThreadDisplayNameFromPath(entry.path),
        createdAt: entry.createdAt,
        modifiedAt: entry.modifiedAt,
      );
    }).toList();

    entries.sort((a, b) {
      final dateComparison = _threadSortDate(b).compareTo(_threadSortDate(a));
      if (dateComparison != 0) {
        return dateComparison;
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

  Future<void> _closeDocument() async {
    final storage = _storage;
    final chatClient = _chatClient;

    storage?.removeListener(_onThreadListChanged);
    _storage = null;
    _chatClient = null;
    _openedThreadListPath = null;
    _openedAgentName = null;

    await storage?.close();
    if (widget.disposeChatClient) {
      await chatClient?.stop();
    }
  }

  Future<void> _rebindDocument() async {
    final nextThreadListPath = _normalizedThreadListPath();
    final nextAgentName = widget.agentName?.trim();
    if (nextThreadListPath == _openedThreadListPath && nextAgentName == _openedAgentName && _storage != null) {
      return;
    }

    await _closeDocument();

    if (nextThreadListPath == null) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    try {
      final chatClient =
          widget.chatClientFactory?.call(widget.client, nextAgentName) ??
          agent_sessions.MessagingChatClient(room: widget.client, agentName: nextAgentName);
      final storage = widget.threadStorageFactory?.call(chatClient) ?? agent_sessions.AgentThreadStorageRepository(chatClient: chatClient);
      storage.addListener(_onThreadListChanged);
      await chatClient.start();
      if (chatClient.agentParticipant() == null && chatClient is agent_sessions.MessagingChatClient) {
        await chatClient.waitForAgentParticipant(waitKey: 'desktop-preview-thread-list:$nextThreadListPath:$nextAgentName');
      }
      if (!mounted || _normalizedThreadListPath() != nextThreadListPath) {
        storage.removeListener(_onThreadListChanged);
        await storage.close();
        if (widget.disposeChatClient) {
          await chatClient.stop();
        }
        return;
      }
      await storage.open();
      if (!mounted || _normalizedThreadListPath() != nextThreadListPath) {
        storage.removeListener(_onThreadListChanged);
        await storage.close();
        if (widget.disposeChatClient) {
          await chatClient.stop();
        }
        return;
      }

      setState(() {
        _storage = storage;
        _chatClient = chatClient;
        _openedThreadListPath = nextThreadListPath;
        _openedAgentName = nextAgentName;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_rebindDocument());
  }

  @override
  void didUpdateWidget(covariant _DesktopPreviewThreadList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.client != widget.client || oldWidget.threadListPath != widget.threadListPath || oldWidget.agentName != widget.agentName) {
      unawaited(_rebindDocument());
    }
  }

  @override
  void dispose() {
    unawaited(_closeDocument());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _entries(), _storage != null || _normalizedThreadListPath() == null);
}

class _DesktopPreviewThreadAttachments extends StatefulWidget {
  const _DesktopPreviewThreadAttachments({
    required this.client,
    required this.enabled,
    required this.threads,
    required this.selectedThreadPath,
    required this.selectedThreadName,
    required this.chatClient,
    required this.localLinks,
    required this.builder,
  });

  final RoomClient client;
  final bool enabled;
  final List<_DesktopPreviewThreadEntry> threads;
  final String? selectedThreadPath;
  final String? selectedThreadName;
  final agent_sessions.BaseChatClient? chatClient;
  final List<PowerboardsFileAttachmentLink> localLinks;
  final Widget Function(BuildContext context, List<PbAttachmentListItemData> attachments) builder;

  @override
  State<_DesktopPreviewThreadAttachments> createState() => _DesktopPreviewThreadAttachmentsState();
}

class _DesktopPreviewAttachmentThreadRef {
  const _DesktopPreviewAttachmentThreadRef({required this.path, required this.name});

  final String path;
  final String name;
}

class _DesktopPreviewThreadAttachmentRecord {
  const _DesktopPreviewThreadAttachmentRecord({required this.filePath, required this.threadPath, required this.threadName});

  final String filePath;
  final String threadPath;
  final String threadName;
}

class _DesktopPreviewThreadAttachmentsState extends State<_DesktopPreviewThreadAttachments> {
  StreamSubscription<RoomEvent>? _roomSubscription;
  final Map<String, MeshDocument> _threadDocuments = <String, MeshDocument>{};
  final Map<String, agent_sessions.ChatThreadSession> _agentThreadSessions = <String, agent_sessions.ChatThreadSession>{};
  final Map<String, StorageEntry> _attachmentEntriesByPath = <String, StorageEntry>{};
  List<PowerboardsFileAttachmentLink> _links = const <PowerboardsFileAttachmentLink>[];
  List<_DesktopPreviewThreadAttachmentRecord> _threadAttachments = const <_DesktopPreviewThreadAttachmentRecord>[];
  List<_DesktopPreviewThreadAttachmentRecord> _agentThreadAttachments = const <_DesktopPreviewThreadAttachmentRecord>[];
  int _loadGeneration = 0;
  int _attachmentEntryGeneration = 0;
  Future<void> _pendingThreadDocumentClose = Future<void>.value();
  bool _agentThreadAttachmentUpdateQueued = false;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      return;
    }
    _bindRoom();
    _bindAgentChatClient();
    unawaited(_loadAttachments());
  }

  @override
  void didUpdateWidget(covariant _DesktopPreviewThreadAttachments oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) {
      _bindRoom();
      _bindAgentChatClient();
      unawaited(_loadAttachments());
      return;
    }

    if (oldWidget.enabled && !widget.enabled) {
      _deactivateAttachmentLoading(oldWidget: oldWidget);
      return;
    }

    if (!widget.enabled) {
      return;
    }

    if (oldWidget.client != widget.client) {
      if (oldWidget.chatClient != widget.chatClient) {
        _unbindAgentChatClient(oldWidget: oldWidget);
        _unbindAgentThreadSessions();
        _bindAgentChatClient();
      }
      unawaited(_closeThreadDocuments(client: oldWidget.client));
      _bindRoom();
      unawaited(_loadAttachments());
      return;
    }

    if (oldWidget.chatClient != widget.chatClient) {
      _unbindAgentChatClient(oldWidget: oldWidget);
      _unbindAgentThreadSessions();
      _bindAgentChatClient();
      unawaited(_loadAttachments());
      return;
    }

    if (_threadSignature(oldWidget) != _threadSignature(widget)) {
      unawaited(_loadAttachments());
      return;
    }

    if (_localLinksSignature(oldWidget.localLinks) != _localLinksSignature(widget.localLinks)) {
      unawaited(_syncAttachmentEntries());
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _roomSubscription = null;
    _unbindAgentThreadSessions();
    _unbindAgentChatClient(oldWidget: widget);
    unawaited(_closeThreadDocuments(client: widget.client));
    super.dispose();
  }

  void _deactivateAttachmentLoading({required _DesktopPreviewThreadAttachments oldWidget}) {
    _loadGeneration++;
    _attachmentEntryGeneration++;
    _roomSubscription?.cancel();
    _roomSubscription = null;
    _unbindAgentChatClient(oldWidget: oldWidget);
    _unbindAgentThreadSessions();
    _pendingThreadDocumentClose = _closeThreadDocuments(client: oldWidget.client);
    _attachmentEntriesByPath.clear();
    _links = const <PowerboardsFileAttachmentLink>[];
    _threadAttachments = const <_DesktopPreviewThreadAttachmentRecord>[];
    _agentThreadAttachments = const <_DesktopPreviewThreadAttachmentRecord>[];
  }

  void _bindRoom() {
    _roomSubscription?.cancel();
    _roomSubscription = widget.client.listen(_onRoomEvent);
  }

  void _bindAgentChatClient() {
    widget.chatClient?.addListener(_onAgentChatClientChanged);
  }

  void _unbindAgentChatClient({required _DesktopPreviewThreadAttachments oldWidget}) {
    oldWidget.chatClient?.removeListener(_onAgentChatClientChanged);
  }

  void _onAgentChatClientChanged() {
    _scheduleAgentThreadAttachmentUpdate();
  }

  void _onRoomEvent(RoomEvent event) {
    final path = switch (event) {
      FileUpdatedEvent() => normalizePowerboardsAttachmentPath(event.path),
      FileDeletedEvent() => normalizePowerboardsAttachmentPath(event.path),
      _ => null,
    };

    if (path == null) {
      return;
    }

    if (path == powerboardsFileAttachmentIndexPath) {
      unawaited(_loadAttachments());
      return;
    }

    if (!_scopedAttachmentPaths().contains(path)) {
      return;
    }

    if (event is FileDeletedEvent) {
      setState(() {
        _attachmentEntriesByPath.remove(path);
      });
      return;
    }

    if (event is FileUpdatedEvent) {
      unawaited(_refreshAttachmentEntry(path));
    }
  }

  String _threadSignature(_DesktopPreviewThreadAttachments widget) {
    return powerboardsDesktopPreviewAttachmentThreadScopeSignature(
      selectedThreadPath: widget.selectedThreadPath,
      selectedThreadName: widget.selectedThreadName,
    );
  }

  String _localLinksSignature(List<PowerboardsFileAttachmentLink> links) {
    return links.map((link) => '${link.threadPath}\u{1f}${link.filePath}\u{1f}${link.createdAt?.toIso8601String() ?? ''}').join('\u{1e}');
  }

  List<_DesktopPreviewAttachmentThreadRef> _threadRefs() {
    final seen = <String>{};
    final refs = <_DesktopPreviewAttachmentThreadRef>[];

    void addRef(String path, String name) {
      final normalizedPath = normalizePowerboardsThreadAttachmentPath(path);
      final matchKey = powerboardsThreadAttachmentMatchKey(normalizedPath);
      if (normalizedPath.isEmpty || matchKey.isEmpty || !seen.add(matchKey)) {
        return;
      }

      final trimmedName = name.trim();
      refs.add(
        _DesktopPreviewAttachmentThreadRef(
          path: normalizedPath,
          name: trimmedName.isNotEmpty ? trimmedName : defaultThreadDisplayNameFromPath(normalizedPath),
        ),
      );
    }

    for (final threadPath in powerboardsDesktopPreviewAttachmentThreadPathsForSelectedThread(widget.selectedThreadPath)) {
      addRef(threadPath, widget.selectedThreadName ?? defaultThreadDisplayNameFromPath(threadPath));
    }

    return refs;
  }

  Future<void> _loadAttachments() async {
    final generation = ++_loadGeneration;
    final threadRefs = _threadRefs();
    _syncAgentThreadSessions(threadRefs);
    final links = await loadPowerboardsFileAttachmentLinks(widget.client);
    await _pendingThreadDocumentClose;
    if (!mounted || generation != _loadGeneration) {
      return;
    }
    await _syncThreadDocuments(threadRefs, generation: generation);
    if (!mounted || generation != _loadGeneration) {
      return;
    }

    final threadAttachments = _collectThreadAttachments(threadRefs);
    final agentThreadAttachments = _collectAgentThreadAttachments(threadRefs);
    setState(() {
      _links = links;
      _threadAttachments = threadAttachments;
      _agentThreadAttachments = agentThreadAttachments;
    });
    unawaited(_syncAttachmentEntries());
  }

  void _syncAgentThreadSessions(List<_DesktopPreviewAttachmentThreadRef> threads) {
    final chatClient = widget.chatClient;
    final desiredPaths = threads.map((thread) => thread.path).toSet();

    for (final path in _agentThreadSessions.keys.toList()) {
      if (desiredPaths.contains(path)) {
        continue;
      }
      final session = _agentThreadSessions.remove(path);
      session?.removeListener(_onAgentThreadSessionChanged);
    }

    if (chatClient == null) {
      for (final session in _agentThreadSessions.values) {
        session.removeListener(_onAgentThreadSessionChanged);
      }
      _agentThreadSessions.clear();
      _agentThreadAttachments = const <_DesktopPreviewThreadAttachmentRecord>[];
      return;
    }

    for (final thread in threads) {
      if (_agentThreadSessions.containsKey(thread.path)) {
        continue;
      }

      final session = chatClient.openThread(thread.path);
      session.addListener(_onAgentThreadSessionChanged);
      _agentThreadSessions[thread.path] = session;
    }
  }

  void _unbindAgentThreadSessions() {
    for (final session in _agentThreadSessions.values) {
      session.removeListener(_onAgentThreadSessionChanged);
    }
    _agentThreadSessions.clear();
    _agentThreadAttachments = const <_DesktopPreviewThreadAttachmentRecord>[];
  }

  void _onAgentThreadSessionChanged() {
    _scheduleAgentThreadAttachmentUpdate();
  }

  void _scheduleAgentThreadAttachmentUpdate() {
    if (!mounted || !widget.enabled || _agentThreadAttachmentUpdateQueued) {
      return;
    }

    void applyUpdate() {
      _agentThreadAttachmentUpdateQueued = false;
      if (!mounted || !widget.enabled) {
        return;
      }

      final agentThreadAttachments = _collectAgentThreadAttachments(_threadRefs());
      setState(() {
        _agentThreadAttachments = agentThreadAttachments;
      });
      unawaited(_syncAttachmentEntries());
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      applyUpdate();
      return;
    }

    _agentThreadAttachmentUpdateQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyUpdate();
    });
  }

  Future<void> _syncThreadDocuments(List<_DesktopPreviewAttachmentThreadRef> threads, {required int generation}) async {
    final desiredPaths = threads.map((thread) => thread.path).toSet();
    final currentPaths = _threadDocuments.keys.toSet();

    for (final path in currentPaths.difference(desiredPaths)) {
      final document = _threadDocuments.remove(path);
      if (document != null) {
        document.removeListener(_onThreadDocumentChanged);
      }
      try {
        await widget.client.sync.close(path);
      } catch (_) {}
    }

    for (final thread in threads) {
      if (_threadDocuments.containsKey(thread.path)) {
        continue;
      }

      MeshDocument? document;
      try {
        document = await widget.client.sync.open(thread.path, create: false);
        if (!mounted || generation != _loadGeneration || !_threadRefs().any((candidate) => candidate.path == thread.path)) {
          try {
            await widget.client.sync.close(thread.path);
          } catch (_) {}
          continue;
        }

        document.addListener(_onThreadDocumentChanged);
        _threadDocuments[thread.path] = document;
      } catch (_) {
        if (document != null) {
          try {
            await widget.client.sync.close(thread.path);
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _closeThreadDocuments({required RoomClient client}) async {
    final documents = Map<String, MeshDocument>.of(_threadDocuments);
    _threadDocuments.clear();

    for (final entry in documents.entries) {
      entry.value.removeListener(_onThreadDocumentChanged);
      try {
        await client.sync.close(entry.key);
      } catch (_) {}
    }
  }

  void _onThreadDocumentChanged() {
    if (!mounted) {
      return;
    }

    final threadAttachments = _collectThreadAttachments(_threadRefs());
    setState(() {
      _threadAttachments = threadAttachments;
    });
    unawaited(_syncAttachmentEntries());
  }

  List<_DesktopPreviewThreadAttachmentRecord> _collectThreadAttachments(List<_DesktopPreviewAttachmentThreadRef> threads) {
    final attachments = <_DesktopPreviewThreadAttachmentRecord>[];
    final threadNamesByPath = {for (final thread in threads) thread.path: thread.name};

    for (final entry in _threadDocuments.entries) {
      final threadName = threadNamesByPath[entry.key];
      if (threadName == null) {
        continue;
      }

      final messageElements = powerboardsDesktopPreviewThreadMessageElements(entry.value);
      final seenAttachments = <String>{};

      for (final message in messageElements) {
        for (final attachment in message.getChildren().whereType<MeshElement>()) {
          final filePath = powerboardsDesktopPreviewThreadAttachmentPath(attachment);
          if (filePath.isEmpty) {
            continue;
          }
          if (!seenAttachments.add('$filePath\n${entry.key}')) {
            continue;
          }

          attachments.add(_DesktopPreviewThreadAttachmentRecord(filePath: filePath, threadPath: entry.key, threadName: threadName));
        }
      }
    }

    return attachments;
  }

  List<_DesktopPreviewThreadAttachmentRecord> _collectAgentThreadAttachments(List<_DesktopPreviewAttachmentThreadRef> threads) {
    final attachments = <_DesktopPreviewThreadAttachmentRecord>[];
    final threadNamesByPath = {for (final thread in threads) thread.path: thread.name};

    for (final entry in _agentThreadSessions.entries) {
      final threadName = threadNamesByPath[entry.key];
      if (threadName == null) {
        continue;
      }

      final seenAttachments = <String>{};
      void addFromMessage(agent_sessions.AgentMessage message) {
        for (final filePath in powerboardsDesktopPreviewAgentMessageAttachmentPaths(message)) {
          if (!seenAttachments.add('$filePath\n${entry.key}')) {
            continue;
          }
          attachments.add(_DesktopPreviewThreadAttachmentRecord(filePath: filePath, threadPath: entry.key, threadName: threadName));
        }
      }

      for (final event in entry.value.messages) {
        addFromMessage(event.message);
      }
      for (final input in entry.value.pendingInputs) {
        addFromMessage(input.payload);
      }
    }

    return attachments;
  }

  String _attachmentTitle(String path) {
    final storageName = _attachmentEntriesByPath[path]?.name.trim();
    if (storageName != null && storageName.isNotEmpty) {
      return storageName;
    }

    return path.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? path;
  }

  String _attachmentSizeLabel(String path) {
    final size = _attachmentEntriesByPath[path]?.size;
    return size == null ? '' : pbFormatBytes(size);
  }

  Set<String> _scopedAttachmentPaths() {
    final threadPathKeys = _threadRefs().map((thread) => powerboardsThreadAttachmentMatchKey(thread.path)).toSet();
    final paths = <String>{};

    for (final link in widget.localLinks) {
      if (threadPathKeys.contains(powerboardsThreadAttachmentMatchKey(link.threadPath)) && link.filePath.isNotEmpty) {
        final filePath = powerboardsStorageAttachmentPathFromUrl(link.filePath);
        if (filePath.isNotEmpty) {
          paths.add(filePath);
        }
      }
    }

    for (final attachment in _threadAttachments) {
      if (threadPathKeys.contains(powerboardsThreadAttachmentMatchKey(attachment.threadPath)) && attachment.filePath.isNotEmpty) {
        final filePath = powerboardsStorageAttachmentPathFromUrl(attachment.filePath);
        if (filePath.isNotEmpty) {
          paths.add(filePath);
        }
      }
    }

    for (final attachment in _agentThreadAttachments) {
      if (threadPathKeys.contains(powerboardsThreadAttachmentMatchKey(attachment.threadPath)) && attachment.filePath.isNotEmpty) {
        final filePath = powerboardsStorageAttachmentPathFromUrl(attachment.filePath);
        if (filePath.isNotEmpty) {
          paths.add(filePath);
        }
      }
    }

    for (final link in _links) {
      if (threadPathKeys.contains(powerboardsThreadAttachmentMatchKey(link.threadPath)) && link.filePath.isNotEmpty) {
        final filePath = powerboardsStorageAttachmentPathFromUrl(link.filePath);
        if (filePath.isNotEmpty) {
          paths.add(filePath);
        }
      }
    }

    return paths;
  }

  Future<void> _syncAttachmentEntries() async {
    final generation = ++_attachmentEntryGeneration;
    final paths = _scopedAttachmentPaths();
    final retained = Map<String, StorageEntry>.of(_attachmentEntriesByPath)..removeWhere((path, _) => !paths.contains(path));

    final missingPaths = paths.where((path) => !retained.containsKey(path)).toList(growable: false);
    final loaded = <String, StorageEntry>{};
    for (final path in missingPaths) {
      try {
        final entry = await widget.client.storage.stat(path);
        if (entry != null && !entry.isFolder) {
          loaded[path] = entry;
        }
      } catch (_) {}
    }

    if (!mounted || generation != _attachmentEntryGeneration) {
      return;
    }

    setState(() {
      _attachmentEntriesByPath
        ..clear()
        ..addAll(retained)
        ..addAll(loaded);
    });
  }

  Future<void> _refreshAttachmentEntry(String path) async {
    final generation = ++_attachmentEntryGeneration;
    StorageEntry? entry;
    try {
      entry = await widget.client.storage.stat(path);
    } catch (_) {}

    if (!mounted || generation != _attachmentEntryGeneration) {
      return;
    }

    final loadedEntry = entry;
    setState(() {
      if (loadedEntry == null || loadedEntry.isFolder) {
        _attachmentEntriesByPath.remove(path);
      } else {
        _attachmentEntriesByPath[path] = loadedEntry;
      }
    });
  }

  List<PbAttachmentListItemData> _attachments() {
    final threadRefs = _threadRefs();
    final threadNamesByMatchKey = {for (final thread in threadRefs) powerboardsThreadAttachmentMatchKey(thread.path): thread.name};
    final seenAttachments = <String>{};
    final attachments = <PbAttachmentListItemData>[];

    void addAttachment({required String filePath, required String threadPath, required String threadName}) {
      final normalizedFilePath = powerboardsStorageAttachmentPathFromUrl(filePath);
      final normalizedThreadPath = normalizePowerboardsThreadAttachmentPath(threadPath);
      if (normalizedFilePath.isEmpty || normalizedThreadPath.isEmpty) {
        return;
      }

      final key = normalizedFilePath;
      if (!seenAttachments.add(key)) {
        return;
      }

      final title = _attachmentTitle(normalizedFilePath);
      final metadata = PbResolvedAttachmentMetadata.resolve(title: title);
      final displayThreadName = threadName.trim().isNotEmpty ? threadName.trim() : defaultThreadDisplayNameFromPath(normalizedThreadPath);
      attachments.add(
        PbAttachmentListItemData(
          title: metadata.displayTitle,
          subtitle: displayThreadName.isEmpty ? metadata.displayType : '${metadata.displayType} / $displayThreadName',
          fileType: metadata.fileType,
          path: normalizedFilePath,
          previewState: powerboardsV1PreviewStateForPath(normalizedFilePath),
          sizeLabel: _attachmentSizeLabel(normalizedFilePath),
        ),
      );
    }

    for (final link in widget.localLinks) {
      final threadName = threadNamesByMatchKey[powerboardsThreadAttachmentMatchKey(link.threadPath)];
      if (threadName == null) {
        continue;
      }

      addAttachment(
        filePath: link.filePath,
        threadPath: link.threadPath,
        threadName: threadName.isNotEmpty ? threadName : link.threadDisplayName,
      );
    }

    for (final attachment in _threadAttachments) {
      if (!threadNamesByMatchKey.containsKey(powerboardsThreadAttachmentMatchKey(attachment.threadPath))) {
        continue;
      }

      addAttachment(filePath: attachment.filePath, threadPath: attachment.threadPath, threadName: attachment.threadName);
    }

    for (final attachment in _agentThreadAttachments) {
      if (!threadNamesByMatchKey.containsKey(powerboardsThreadAttachmentMatchKey(attachment.threadPath))) {
        continue;
      }

      addAttachment(filePath: attachment.filePath, threadPath: attachment.threadPath, threadName: attachment.threadName);
    }

    for (final link in _links) {
      final threadName = threadNamesByMatchKey[powerboardsThreadAttachmentMatchKey(link.threadPath)];
      if (threadName == null) {
        continue;
      }

      addAttachment(
        filePath: link.filePath,
        threadPath: link.threadPath,
        threadName: threadName.isNotEmpty ? threadName : link.threadDisplayName,
      );
    }

    return attachments;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.builder(context, const <PbAttachmentListItemData>[]);
    }

    return widget.builder(context, _attachments());
  }
}

class _DesktopPreviewVoiceSessionTranscripts extends StatefulWidget {
  const _DesktopPreviewVoiceSessionTranscripts({required this.client, required this.agentName, required this.builder});

  final RoomClient client;
  final String agentName;
  final Widget Function(BuildContext context, List<PbAttachmentListItemData> transcripts) builder;

  @override
  State<_DesktopPreviewVoiceSessionTranscripts> createState() => _DesktopPreviewVoiceSessionTranscriptsState();
}

class _DesktopPreviewVoiceSessionTranscriptsState extends State<_DesktopPreviewVoiceSessionTranscripts> {
  StreamSubscription<RoomEvent>? _roomSubscription;
  List<PbAttachmentListItemData> _transcripts = const <PbAttachmentListItemData>[];
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _bindRoom();
    unawaited(_loadTranscripts());
  }

  @override
  void didUpdateWidget(covariant _DesktopPreviewVoiceSessionTranscripts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client) {
      _bindRoom();
      unawaited(_loadTranscripts());
      return;
    }

    if (oldWidget.agentName != widget.agentName) {
      unawaited(_loadTranscripts());
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _roomSubscription = null;
    super.dispose();
  }

  void _bindRoom() {
    _roomSubscription?.cancel();
    _roomSubscription = widget.client.listen(_onRoomEvent);
  }

  void _onRoomEvent(RoomEvent event) {
    final path = switch (event) {
      FileUpdatedEvent() => normalizePowerboardsAttachmentPath(event.path),
      FileDeletedEvent() => normalizePowerboardsAttachmentPath(event.path),
      _ => null,
    };

    final agentFolder = _agentTranscriptFolder;
    if (path == null || agentFolder.isEmpty) {
      return;
    }

    if (path == agentFolder || path.startsWith('$agentFolder/')) {
      unawaited(_loadTranscripts());
    }
  }

  String get _agentTranscriptFolder {
    return normalizePowerboardsAttachmentPath(joinPaths(_transcriptRootFolder, widget.agentName.trim()));
  }

  Future<void> _loadTranscripts() async {
    final generation = ++_loadGeneration;
    final agentFolder = _agentTranscriptFolder;
    final records = agentFolder.isEmpty ? const <_DesktopPreviewTranscriptRecord>[] : await _collectTranscriptRecords(agentFolder);

    if (!mounted || generation != _loadGeneration) {
      return;
    }

    setState(() {
      _transcripts = _selectDesktopPreviewRecentTranscripts(records);
    });
  }

  Future<List<_DesktopPreviewTranscriptRecord>> _collectTranscriptRecords(String folderPath) async {
    List<StorageEntry> entries;
    try {
      entries = await widget.client.storage.list(folderPath);
    } catch (_) {
      return const <_DesktopPreviewTranscriptRecord>[];
    }

    final records = <_DesktopPreviewTranscriptRecord>[];
    for (final entry in entries) {
      if (entry.name.startsWith('.')) {
        continue;
      }

      final fullPath = joinPaths(folderPath, entry.name);
      if (entry.isFolder) {
        records.addAll(await _collectTranscriptRecords(fullPath));
        continue;
      }

      if (!_isTranscriptFileName(entry.name)) {
        continue;
      }

      records.add(
        _DesktopPreviewTranscriptRecord(
          data: _desktopPreviewTranscriptItem(path: fullPath, fileName: entry.name),
          sortDate: _desktopPreviewTranscriptSortDate(entry),
        ),
      );
    }

    return records;
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _transcripts);
  }
}

class _AskAgentSwitchDialog extends StatefulWidget {
  const _AskAgentSwitchDialog({required this.currentAgentName, required this.choices, required this.initialChoice});

  final String currentAgentName;
  final List<_FilePromptAgentChoice> choices;
  final _FilePromptAgentChoice initialChoice;

  @override
  State<_AskAgentSwitchDialog> createState() => _AskAgentSwitchDialogState();
}

class _AskAgentSwitchDialogState extends State<_AskAgentSwitchDialog> {
  late _FilePromptAgentChoice _selectedChoice = widget.initialChoice;
  bool _agentMenuOpen = false;

  String get _currentAgentLabel {
    final trimmed = widget.currentAgentName.trim();
    return trimmed.isEmpty ? 'the current agent' : trimmed;
  }

  String get _description {
    if (_currentAgentLabel.toLowerCase() == 'voice') {
      return 'This will switch you from your current voice agent to the selected chat-based agent to start a new thread.';
    }

    return 'This will switch you from $_currentAgentLabel to the selected chat-based agent to start a new thread.';
  }

  String _displayAgentName(String agentName) {
    final trimmed = agentName.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  List<PbSwitcherMenuItem> get _agentItems {
    return widget.choices
        .map(
          (choice) => PbSwitcherMenuItem(title: _displayAgentName(choice.agentName), selected: choice.routeId == _selectedChoice.routeId),
        )
        .toList(growable: false);
  }

  void _selectChoice(String agentName) {
    final nextChoice = widget.choices.firstWhereOrNull((choice) => _displayAgentName(choice.agentName) == agentName);
    if (nextChoice == null) {
      return;
    }

    setState(() {
      _selectedChoice = nextChoice;
      _agentMenuOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const messageTextStyle = PowerboardsTypography.p;

    return PbDialogShell(
      title: 'Switch to a chat agent',
      description: 'Ask an agent about this file.',
      onClose: () => Navigator.of(context).pop(),
      actions: [
        PbButton(label: 'Cancel', variant: PbButtonVariant.secondary, onPressed: () => Navigator.of(context).pop()),
        PbButton(label: 'Continue', variant: PbButtonVariant.primary, onPressed: () => Navigator.of(context).pop(_selectedChoice)),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.choices.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
              child: _DialogDropdownField(
                value: _displayAgentName(_selectedChoice.agentName),
                menuOpen: _agentMenuOpen,
                items: _agentItems,
                emptyLabel: 'No agents found',
                onMenuOpenChanged: (open) => setState(() => _agentMenuOpen = open),
                onItemPressed: _selectChoice,
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: PbColors.surfaceAccentSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PbColors.borderStateSelected),
            ),
            child: Text(_description, style: messageTextStyle),
          ),
        ],
      ),
    );
  }
}

class _DialogDropdownField extends StatefulWidget {
  const _DialogDropdownField({
    required this.value,
    required this.menuOpen,
    required this.items,
    required this.onMenuOpenChanged,
    required this.onItemPressed,
    required this.emptyLabel,
  });

  final String value;
  final bool menuOpen;
  final List<PbSwitcherMenuItem> items;
  final ValueChanged<bool> onMenuOpenChanged;
  final ValueChanged<String> onItemPressed;
  final String emptyLabel;

  @override
  State<_DialogDropdownField> createState() => _DialogDropdownFieldState();
}

class _DialogDropdownFieldState extends State<_DialogDropdownField> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selectedSurface = _pressed || widget.menuOpen;

    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWidth = constraints.hasBoundedWidth ? constraints.maxWidth : 320.0;

        return PbMenuAnchor(
          placement: PbMenuAnchorPlacement.bottomLeft,
          gap: 8,
          onDismiss: () => widget.onMenuOpenChanged(false),
          panel: widget.menuOpen
              ? PbSwitcherMenu(
                  width: menuWidth,
                  showFilter: false,
                  items: widget.items,
                  emptyLabel: widget.emptyLabel,
                  onItemPressed: widget.onItemPressed,
                )
              : null,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() {
              _hovered = false;
              _pressed = false;
            }),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) {
                setState(() => _pressed = false);
                widget.onMenuOpenChanged(!widget.menuOpen);
              },
              onTapCancel: () => setState(() => _pressed = false),
              child: Transform.translate(
                offset: Offset(0, _hovered && !_pressed && !widget.menuOpen ? -1 : 0),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PbRadii.small),
                    border: Border.all(color: selectedSurface ? PbColors.borderStateSelected : PbColors.borderSoft),
                    color: selectedSurface ? PbColors.surfaceStateSelected : PbColors.surfacePanel,
                    boxShadow: _hovered && !_pressed && !widget.menuOpen ? PbShadows.stateHover : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PowerboardsTypography.button.copyWith(color: PbColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedRotation(
                        turns: widget.menuOpen ? -0.5 : 0,
                        duration: PbMotion.chevron,
                        curve: Curves.easeOutCubic,
                        child: const PbSvgIcon(assetName: 'chevron-down', size: 16, color: PbColors.customBrandInk),
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

@visibleForTesting
class PowerboardsDesktopPreviewThreadListHarness extends StatelessWidget {
  const PowerboardsDesktopPreviewThreadListHarness({
    super.key,
    required this.client,
    required this.threadListPath,
    this.chatClientFactory,
    this.threadStorageFactory,
    this.disposeChatClient,
    this.agentName = 'assistant',
    this.selectedThreadPath,
    this.selectedThreadName,
  });

  final RoomClient client;
  final String? threadListPath;
  final String? agentName;
  final PowerboardsDesktopPreviewChatClientFactory? chatClientFactory;
  final PowerboardsDesktopPreviewThreadStorageFactory? threadStorageFactory;
  final bool? disposeChatClient;
  final String? selectedThreadPath;
  final String? selectedThreadName;

  @override
  Widget build(BuildContext context) {
    return _DesktopPreviewThreadList(
      client: client,
      agentName: agentName,
      threadListPath: threadListPath,
      chatClientFactory: chatClientFactory,
      threadStorageFactory: threadStorageFactory,
      disposeChatClient: disposeChatClient ?? chatClientFactory == null,
      builder: (context, threads, threadListLoaded) {
        final visibleSelectedThreadPath = powerboardsDesktopPreviewSelectedThreadPathForVisibleThreads(
          selectedThreadPath: selectedThreadPath,
          threadPaths: threads.map((thread) => thread.path),
          threadListLoaded: threadListLoaded,
        );
        final selectedThread = visibleSelectedThreadPath == null
            ? null
            : threads.firstWhereOrNull((thread) => thread.path.trim() == visibleSelectedThreadPath);
        final selectedThreadTitle = visibleSelectedThreadPath == null ? null : selectedThread?.name ?? selectedThreadName;
        final threadItems = powerboardsDesktopPreviewThreadItemsForVisibleThreads(
          selectedThreadPath: visibleSelectedThreadPath,
          selectedThreadTitle: selectedThreadTitle,
          threadItems: [for (final thread in threads) PbThreadListItemData(id: thread.path, title: thread.name)],
          threadListLoaded: threadListLoaded,
        );
        return PbRoomPanel(
          agents: const [PbAgentListItemData(id: 'assistant', title: 'Assistant', status: 'Available', icon: 'bot', selected: true)],
          selectedAgentId: 'assistant',
          selectedAgentTitle: 'Assistant',
          showFilesTab: false,
          threads: [for (final thread in threads) thread.name],
          threadItems: threadItems,
          selectedThreadId: visibleSelectedThreadPath,
          selectedThreadTitle: selectedThreadTitle,
          onThreadSelected: (_) {},
          onCreateThread: () {},
        );
      },
    );
  }
}

EdgeInsetsGeometry _paneHeaderButtonPadding({required bool compact}) {
  if (compact) {
    return const EdgeInsets.symmetric(horizontal: 0);
  }

  return const EdgeInsets.symmetric(horizontal: 10);
}

Widget _buildPaneHeaderIconButton({
  required BuildContext context,
  required String tooltip,
  required IconData icon,
  required VoidCallback? onPressed,
  ShadButtonVariant variant = ShadButtonVariant.outline,
  Color? iconColor,
  Color? backgroundColor,
  Color? foregroundColor,
}) {
  final iconWidget = Icon(icon, size: paneHeaderIconButtonIconSize, color: iconColor);

  final button = backgroundColor != null || foregroundColor != null
      ? ShadIconButton(
          icon: iconWidget,
          decoration: powerboardsAdaptiveIconButtonDecoration(context),
          onPressed: onPressed,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
        )
      : switch (variant) {
          ShadButtonVariant.primary => ShadIconButton(
            icon: iconWidget,
            decoration: powerboardsAdaptiveIconButtonDecoration(context),
            onPressed: onPressed,
          ),
          ShadButtonVariant.destructive => ShadIconButton.destructive(
            icon: iconWidget,
            decoration: powerboardsAdaptiveIconButtonDecoration(context),
            onPressed: onPressed,
          ),
          ShadButtonVariant.secondary => ShadIconButton.secondary(
            icon: iconWidget,
            decoration: powerboardsAdaptiveIconButtonDecoration(context),
            onPressed: onPressed,
          ),
          ShadButtonVariant.ghost => ShadIconButton.ghost(
            icon: iconWidget,
            decoration: powerboardsAdaptiveIconButtonDecoration(context),
            onPressed: onPressed,
          ),
          _ => ShadIconButton.outline(icon: iconWidget, decoration: powerboardsAdaptiveIconButtonDecoration(context), onPressed: onPressed),
        };

  return Tooltip(message: tooltip, child: button);
}

Color _mobileRoomSurfaceColor(BuildContext context) {
  return ShadTheme.of(context).colorScheme.card;
}

class _BlankDesktopPreviewRoomWorkspace extends StatelessWidget {
  const _BlankDesktopPreviewRoomWorkspace({this.onInstallAgent});

  final VoidCallback? onInstallAgent;

  @override
  Widget build(BuildContext context) {
    const sourceTopFactor = 0.334;
    const sourceThreadHeaderHeight = 76.0;

    return ColoredBox(
      color: const Color(0x73FFFFFF),
      child: Column(
        children: [
          const PbThreadHeader(blankRoom: true),
          Expanded(
            child: PbEmptyState(
              iconAssetName: 'messages-square',
              title: 'Start with an agent',
              subtitle: 'Add an agent to help keep conversations, files, and follow-ups moving.',
              topFactor: sourceTopFactor,
              topOffset: -sourceThreadHeaderHeight * (1 - sourceTopFactor),
              actionTopGap: 30,
              action: onInstallAgent == null
                  ? null
                  : PbButton(label: 'Install an Agent', variant: PbButtonVariant.primary, height: 42, onPressed: onInstallAgent),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileRoomCreateActionRow extends StatelessWidget {
  const _MobileRoomCreateActionRow({required this.title, required this.icon, required this.onPressed});

  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final foreground = theme.colorScheme.foreground;
    final titleStyle = powerboardsInterTextStyle(color: foreground, fontWeight: FontWeight.w600);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: powerboardsMobileSecondaryRowHeight,
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Center(child: Icon(icon, size: 20, color: foreground)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ParticipantsButton extends StatefulWidget {
  const ParticipantsButton({super.key, required this.participants, required this.localParticipant});

  final List<RemoteParticipant> participants;
  final LocalParticipant? localParticipant;

  @override
  State createState() => _ParticipantsButtonState();
}

class _ParticipantsButtonState extends State<ParticipantsButton> {
  late final popoverController = ShadContextMenuController();
  final statesController = ShadStatesController();
  static const double _menuWidth = 320;
  static const double _menuHeaderHeight = 53;
  static const double _menuRowHeight = 40;

  String _initialFromText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return "U";

    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  String _initialsFromName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return "U";

    final localPart = trimmed.split("@").first;
    final parts = localPart.split(RegExp(r"[-._ ]+")).where((part) => part.isNotEmpty).toList();

    if (parts.length >= 2) {
      return "${_initialFromText(parts[0])}${_initialFromText(parts[1])}";
    }

    if (parts.length == 1) {
      return _initialFromText(parts[0]);
    }

    return _initialFromText(trimmed);
  }

  Widget _buildOverlapAvatars(List<String> names, Set<ShadState> states) {
    const avatarSize = userAvatarStandardDiameter;
    const overlapOffset = 24.0;
    final width = avatarSize + (names.length - 1) * overlapOffset;
    final hovered = states.contains(ShadState.hovered);

    return SizedBox(
      width: width,
      height: avatarSize,
      child: Stack(
        children: List.generate(names.length, (index) {
          final name = names[index];
          return Positioned(
            left: index * overlapOffset,
            child: Tooltip(
              message: name,
              child: UserAvatarCircle(initials: _initialsFromName(name), variant: UserAvatarVariant.standard, hovered: hovered),
            ),
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    popoverController.dispose();
    statesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final tt = theme.textTheme;
    final nameSet = <String>{};
    final myName = (widget.localParticipant?.getAttribute("name") as String?)?.trim().toLowerCase();

    for (final participant in widget.participants) {
      final name = participant.getAttribute("name") as String?;

      if (participant.role != 'agent' && name != null && name.isNotEmpty && (myName == null || name.trim().toLowerCase() != myName)) {
        nameSet.add(name);
      }
    }

    if (nameSet.isEmpty) {
      return SizedBox.shrink();
    }

    final sortedNames = nameSet.sorted((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final trigger = sortedNames.length <= 3
        ? ValueListenableBuilder(
            valueListenable: statesController,
            builder: (BuildContext context, Set<ShadState> states, Widget? child) {
              return ShadButton.ghost(
                statesController: statesController,
                backgroundColor: Colors.transparent,
                hoverBackgroundColor: Colors.transparent,
                padding: .zero,
                onPressed: popoverController.toggle,
                decoration: ShadDecoration.none,
                child: _buildOverlapAvatars(sortedNames, states),
              );
            },
          )
        : ShadButton.outline(leading: Icon(LucideIcons.users), onPressed: popoverController.toggle, child: Text("+${nameSet.length}"));

    return AdaptiveShadContextMenu(
      controller: popoverController,
      constraints: const BoxConstraints(minWidth: _menuWidth, maxWidth: _menuWidth),
      estimatedMenuWidth: _menuWidth,
      estimatedMenuHeight: _menuHeaderHeight + sortedNames.length * _menuRowHeight,
      items: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Text(
                "People here right now",
                style: tt.large.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.foreground, fontSize: tt.p.fontSize),
              ),
            ),
            for (final name in sortedNames)
              ShadContextMenuItem(
                height: _menuRowHeight,
                leading: UserAvatarCircle(initials: _initialsFromName(name), variant: UserAvatarVariant.menu),
                onPressed: popoverController.hide,
                child: Text(name, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ],
      child: trigger,
    );
  }
}

class InviteUserButton extends StatelessWidget {
  const InviteUserButton({super.key, required this.projectId, required this.roomName});

  final String projectId;
  final String roomName;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final compact = CompactHeaderActions.compactOf(context);

    if (isMobile || compact) {
      return _buildPaneHeaderIconButton(
        context: context,
        tooltip: "Invite user",
        icon: LucideIcons.userPlus,
        onPressed: () async {
          final room = await getMeshagentClient().getRoom(name: roomName, projectId: projectId);

          if (context.mounted) {
            await showUpdateRoomPermsDialog(context, projectId: projectId, room: room);
          }
        },
      );
    }

    return Tooltip(
      message: "Invite user",
      child: SizedBox(
        width: desktopPaneHeaderInviteButtonWidth,
        child: ShadButton.outline(
          padding: _paneHeaderButtonPadding(compact: false),
          leading: Icon(LucideIcons.userPlus),
          onPressed: () async {
            final room = await getMeshagentClient().getRoom(name: roomName, projectId: projectId);

            if (context.mounted) {
              await showUpdateRoomPermsDialog(context, projectId: projectId, room: room);
            }
          },
          child: isMobile || compact ? null : Text("Invite"),
        ),
      ),
    );
  }
}

class MeetButton extends StatelessWidget {
  const MeetButton({super.key, required this.controller, required this.meetingSessionActive, this.onPressed});

  final MeshagentRoomController controller;
  final bool meetingSessionActive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final compact = CompactHeaderActions.compactOf(context);
    final theme = ShadTheme.of(context);

    Widget buildMeetButton() {
      final activeMeetingColor = theme.colorScheme.greenCustom;
      final activeMeetingForeground = theme.colorScheme.greenCustomForeground;
      final buttonVariant = controller.inMeeting
          ? ShadButtonVariant.primary
          : meetingSessionActive
          ? ShadButtonVariant.primary
          : ShadButtonVariant.outline;
      final iconData = meetingSessionActive ? LucideIcons.circleDot : LucideIcons.video;
      final iconColor = controller.inMeeting && meetingSessionActive ? activeMeetingColor : null;
      final customBackgroundColor = !controller.inMeeting && meetingSessionActive ? activeMeetingColor : null;
      final customForegroundColor = !controller.inMeeting && meetingSessionActive ? activeMeetingForeground : null;

      if (isMobile || compact) {
        return _buildPaneHeaderIconButton(
          context: context,
          tooltip: "Meet",
          icon: iconData,
          iconColor: iconColor,
          backgroundColor: customBackgroundColor,
          foregroundColor: customForegroundColor,
          onPressed: onPressed ?? () => controller.selectMeetingTab(isMobile: isMobile),
          variant: buttonVariant,
        );
      }

      return Tooltip(
        message: "Meet",
        child: SizedBox(
          width: desktopPaneHeaderMeetButtonWidth,
          child: ShadButton.raw(
            variant: buttonVariant,
            padding: _paneHeaderButtonPadding(compact: false),
            backgroundColor: customBackgroundColor,
            foregroundColor: customForegroundColor,
            hoverBackgroundColor: customBackgroundColor,
            hoverForegroundColor: customForegroundColor,
            pressedBackgroundColor: customBackgroundColor,
            pressedForegroundColor: customForegroundColor,
            leading: Icon(iconData, color: iconColor),
            onPressed: onPressed ?? () => controller.selectMeetingTab(isMobile: isMobile),
            child: Text("Meet"),
          ),
        ),
      );
    }

    return buildMeetButton();
  }
}

class FilesButton extends StatelessWidget {
  const FilesButton({super.key, required this.controller, this.onPressed});

  final MeshagentRoomController controller;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final compact = CompactHeaderActions.compactOf(context);
    final isIconOnly = isMobile || compact;

    return controller.isFilesShown
        ? Tooltip(
            message: "Hide files",
            child: isIconOnly
                ? _buildPaneHeaderIconButton(
                    context: context,
                    tooltip: "Hide files",
                    icon: LucideIcons.files,
                    onPressed: onPressed ?? () => controller.selectFilesTab(isMobile: isMobile),
                    variant: ShadButtonVariant.primary,
                  )
                : SizedBox(
                    width: desktopPaneHeaderFilesButtonWidth,
                    child: ShadButton(
                      padding: _paneHeaderButtonPadding(compact: false),
                      leading: Icon(LucideIcons.files),
                      onPressed: onPressed ?? () => controller.selectFilesTab(isMobile: isMobile),
                      child: Text("Files"),
                    ),
                  ),
          )
        : Tooltip(
            message: "Show files",
            child: isIconOnly
                ? _buildPaneHeaderIconButton(
                    context: context,
                    tooltip: "Show files",
                    icon: LucideIcons.files,
                    onPressed: onPressed ?? () => controller.selectFilesTab(isMobile: isMobile),
                  )
                : SizedBox(
                    width: desktopPaneHeaderFilesButtonWidth,
                    child: ShadButton.outline(
                      padding: _paneHeaderButtonPadding(compact: false),
                      leading: Icon(LucideIcons.files),
                      onPressed: onPressed ?? () => controller.selectFilesTab(isMobile: isMobile),
                      child: Text("Files"),
                    ),
                  ),
          );
  }
}

class BackButton extends StatelessWidget {
  const BackButton({super.key, required this.projectId});

  final String projectId;

  void _goBack(BuildContext context) {
    final pid = fromUUID(projectId);

    context.go("/p/$pid");
  }

  void _goToRoomChat(BuildContext context) {
    final currentUri = PathRouteMatch.of(context).uri;
    final updatedQueryParameters = Map<String, String>.from(currentUri.queryParameters);
    updatedQueryParameters[_roomPaneQueryParameter] = 'chat';
    context.go(currentUri.replace(queryParameters: updatedQueryParameters).toString());
  }

  @override
  Widget build(BuildContext context) {
    return PowerboardsBackIconButton(
      onPressed: () async {
        final videoRoom = room.VideoRoomModel.maybeOf(context)?.room;
        final meetingViewController = Controller.ofType<MeetingViewController>(context);
        final roomController = Controller.ofType<MeshagentRoomController>(context);
        final navController = Controller.ofType<NavController>(context);
        final isMobile = ResponsiveBreakpoints.of(context).isMobile;
        final meetingSessionActive = meetingViewController.state == MeetingViewState.joined && videoRoom != null;

        if (meetingSessionActive) {
          final leave = await showLeaveMeeting(context);

          if (leave) {
            if (context.mounted) {
              context.findAncestorStateOfType<room.VideoChatConnectionState>()?.hangup();
              meetingViewController.resetToLobby();
              roomController.showChat();
              navController.showNav();
              if (isMobile) {
                _goToRoomChat(context);
              } else {
                _goBack(context);
              }
            }
          }
        } else {
          _goBack(context);
        }
      },
    );
  }
}

class MeshagentRoomController extends Controller {
  bool _isFilesShown = false;
  bool _isDebugShown = false;
  bool _inMeeting = false;

  bool get isFilesShown => _isFilesShown;
  bool get isDebugShown => _isDebugShown;
  bool get inMeeting => _inMeeting;

  void showFiles() {
    if (_isFilesShown && !_inMeeting) {
      return;
    }
    _isFilesShown = true;
    _inMeeting = false;
    notifyListeners();
  }

  void hideFiles() {
    if (!_isFilesShown) {
      return;
    }
    _isFilesShown = false;
    notifyListeners();
  }

  void selectFilesTab({required bool isMobile}) {
    if (_isFilesShown) {
      if (isMobile) {
        return;
      }

      hideFiles();
      return;
    }

    showFiles();
  }

  void showChat() {
    if (!_isFilesShown && !_inMeeting) {
      return;
    }
    _isFilesShown = false;
    _inMeeting = false;
    notifyListeners();
  }

  void showDebug() {
    _isDebugShown = true;
    notifyListeners();
  }

  void hideDebug() {
    _isDebugShown = false;
    notifyListeners();
  }

  void enterMeeting() {
    if (_inMeeting && !_isFilesShown) {
      return;
    }
    _inMeeting = true;
    _isFilesShown = false;
    notifyListeners();
  }

  void exitMeeting() {
    if (!_inMeeting) {
      return;
    }
    _inMeeting = false;
    notifyListeners();
  }

  void selectMeetingTab({required bool isMobile}) {
    if (_inMeeting) {
      if (isMobile) {
        return;
      }

      exitMeeting();
      return;
    }

    enterMeeting();
  }
}

class ActionsRow extends StatelessWidget {
  const ActionsRow({super.key, required this.actions});

  final List<Widget> actions;

  List<Widget> _desktopLeadingChildren(List<Widget> leadingActions) {
    final children = <Widget>[];
    for (var i = 0; i < leadingActions.length; i++) {
      final action = leadingActions[i];
      if (action is AgentsDropdown) {
        children.add(
          Flexible(
            fit: FlexFit.loose,
            child: Align(alignment: Alignment.centerLeft, child: action),
          ),
        );
      } else {
        children.add(action);
      }
      if (i < leadingActions.length - 1) {
        children.add(const SizedBox(width: 8));
      }
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final sidetrayScope = DesktopSidetrayToggleScope.maybeOf(context);
    final showDesktopSidetrayOpenAction = !isMobile && sidetrayScope?.enabled == true && sidetrayScope?.collapsed == true;
    final act = [...actions];
    final breadcrumbOwnsSidetrayOpenAction = act.any(
      (action) => action is AgentsDropdown && action.showRoomBreadcrumb && action.roomBreadcrumbEllipsisOnly,
    );

    if (showDesktopSidetrayOpenAction && !breadcrumbOwnsSidetrayOpenAction) {
      act.insert(0, DesktopSidetrayToggleButton(collapsed: true, onPressed: sidetrayScope!.onExpand));
    }

    if (act.isEmpty) {
      return SizedBox.shrink();
    }

    bool found = false;

    for (var i = 0; i < act.length; i++) {
      if (act[i] is Spacer) {
        found = true;
        break;
      }
    }

    if (!found) {
      for (var i = 0; i < act.length; i++) {
        if (act[i] is ParticipantsButton) {
          act.insert(i + 1, Spacer());
          found = true;
          break;
        }
      }
    }

    if (!found) {
      for (var i = 0; i < act.length; i++) {
        if (act[i] is AgentsDropdown) {
          act.insert(i + 1, Spacer());
          found = true;
          break;
        }
      }
    }

    if (!found) {
      if (showDesktopSidetrayOpenAction && !breadcrumbOwnsSidetrayOpenAction) {
        act.insert(1, Spacer());
      } else {
        act.insert(0, Spacer());
      }
    }

    final spacerIndex = act.indexWhere((widget) => widget is Spacer);
    final leadingActions = spacerIndex == -1 ? const <Widget>[] : act.take(spacerIndex).toList(growable: false);
    final trailingActions = spacerIndex == -1 ? act : act.skip(spacerIndex + 1).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidetrayLeadingWidth = showDesktopSidetrayOpenAction && !breadcrumbOwnsSidetrayOpenAction
            ? (desktopPaneHeaderCompactButtonWidth + desktopPaneHeaderButtonGap)
            : 0.0;
        final state = resolvePaneHeaderActionState(
          constraints,
          leadingWidth: 320 + sidetrayLeadingWidth,
          minimumLeadingWidth: 220 + sidetrayLeadingWidth,
          actions: trailingActions,
        );
        final visibleTrailingActions = visiblePaneHeaderActions(trailingActions, overflowCollapsed: state.overflowCollapsed);

        return CompactHeaderActions(
          state: state,
          child: SizedBox(
            height: headerHeight,
            child: Center(
              child: SizedBox(
                height: desktopPaneHeaderContentHeight,
                child: Padding(
                  padding: isMobile ? powerboardsMobileHorizontalPadding : const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (leadingActions.isNotEmpty)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: isMobile
                                ? SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: leadingActions),
                                  )
                                : Row(mainAxisSize: MainAxisSize.max, children: _desktopLeadingChildren(leadingActions)),
                          ),
                        ),
                      if (leadingActions.isEmpty && visibleTrailingActions.isNotEmpty) const Spacer(),
                      if (visibleTrailingActions.isNotEmpty)
                        Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: visibleTrailingActions),
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

class MeshagentRoom extends StatefulWidget {
  const MeshagentRoom({super.key, required this.projectId, required this.projects, required this.room, this.service});

  final String projectId;
  final Resource<List<Project>> projects;
  final RoomClient room;
  final String? service;

  @override
  State createState() => MeshagentRoomState();
}

class _ResolvedAgentSelection {
  const _ResolvedAgentSelection({required this.routeId, required this.service, required this.developmentParticipant});

  final String? routeId;
  final ServiceSpec? service;
  final RemoteParticipant? developmentParticipant;
}

class MeshagentRoomState extends State<MeshagentRoom> {
  static const Duration _voiceSessionInstructionToastDuration = Duration(seconds: 5);

  final ResizableSplitViewController _meetingSplitViewController = ResizableSplitViewController();
  final FileManagerViewController _filesHeaderController = FileManagerViewController();
  final PreviewRoomRailMenuBridge _previewRoomRailMenuBridge = PreviewRoomRailMenuBridge();

  final videoChatKey = GlobalKey<room.VideoChatConnectionState>();
  final meetingViewKey = GlobalKey();

  final Map<String, String> _selectedThreadPathByAgentKey = <String, String>{};
  final Map<String, String> _selectedThreadLabelByAgentKey = <String, String>{};
  final Map<String, List<String>> _composerAttachmentPathsByAgentKey = <String, List<String>>{};
  final Map<String, int> _composerAttachmentSeedVersionByAgentKey = <String, int>{};
  final Map<String, PowerboardsFileAttachmentLink> _localThreadAttachmentLinksByKey = <String, PowerboardsFileAttachmentLink>{};
  final Map<String, agent_sessions.MessagingChatClient> _agentChatClients = <String, agent_sessions.MessagingChatClient>{};
  static const Duration _roomResourceTimeout = Duration(seconds: 30);

  final MeshagentRoomController controller = MeshagentRoomController();
  MeetingController? _roomMeetingController;
  int _newThreadResetVersion = 0;
  int _composerAttachmentSeedRevision = 0;
  String _lastRoomStatusText = "Connecting to room";
  String? _resolvedRoomDisplayName;
  String? _lastPersistedMobileAgentRouteId;
  String? _lastSyncedRoutePath;
  _MobileRoomPane? _lastSyncedRoutePane;
  PbRoomPanelTab _desktopPreviewRoomPanelTab = PbRoomPanelTab.agents;
  final OverlayPortalController _desktopPreviewRoomPanelOverlayController = OverlayPortalController();
  bool _desktopPreviewRoomPanelCollapsed = false;
  bool _desktopPreviewRoomPanelOverlayOpen = false;
  double? _desktopPreviewRoomPanelWidth;
  bool _desktopPreviewFilePreviewOpen = false;
  bool _desktopPreviewFilePreviewFullscreen = false;
  PbAttachmentListItemData? _desktopPreviewFilePreviewFile;
  String? _desktopPreviewComposerAttachmentPreviewPath;
  bool _desktopPreviewMeetTranscriptPreviewOpen = false;
  bool _desktopPreviewMeetTranscriptPreviewFullscreen = false;
  bool _desktopPreviewRestoreTranscriptOverlayOnPreviewClose = false;
  PbAttachmentListItemData? _desktopPreviewMeetTranscriptPreviewFile;
  bool _desktopPreviewMeetingFullscreen = false;
  bool _desktopPreviewAgentsExpanded = true;
  bool _didNormalizeInitialDesktopPane = false;
  bool _pendingPreviewRailVoiceSessionDisconnect = false;
  _MobileMeetingOrigin? _mobileMeetingOrigin;
  StreamSubscription<RoomStatusEvent>? _roomStatusSubscription;

  final List<RoomEvent> events = [];

  late final isOwner = Resource(
    () => grant
        .amIOwnerOfRoom(room: widget.room)
        .timeout(_roomResourceTimeout, onTimeout: () => throw TimeoutException("Timed out while checking room ownership.")),
  );
  late final canViewDeveloperLogs = Resource(
    () => grant
        .canViewDeveloperLogs(room: widget.room)
        .timeout(_roomResourceTimeout, onTimeout: () => throw TimeoutException("Timed out while loading developer log permissions.")),
  );
  late final canViewStorage = Resource(
    () => grant
        .canViewStorage(room: widget.room)
        .timeout(_roomResourceTimeout, onTimeout: () => throw TimeoutException("Timed out while loading storage permissions.")),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadRoomDisplayName());

    _roomStatusSubscription = widget.room.events.where((event) => event is RoomStatusEvent).cast<RoomStatusEvent>().listen((event) {
      final status = event.description.trim();
      if (status.isEmpty || !mounted) {
        return;
      }
      setState(() {
        _lastRoomStatusText = status;
      });
    });
  }

  @override
  void didUpdateWidget(covariant MeshagentRoom oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId || oldWidget.room.roomName != widget.room.roomName) {
      _resolvedRoomDisplayName = null;
      _clearRoomScopedThreadSelectionState();
      unawaited(_loadRoomDisplayName());
    }
    if (oldWidget.room != widget.room) {
      for (final chatClient in _agentChatClients.values) {
        unawaited(chatClient.stop());
      }
      _agentChatClients.clear();
    }
  }

  void _clearRoomScopedThreadSelectionState() {
    _selectedThreadPathByAgentKey.clear();
    _selectedThreadLabelByAgentKey.clear();
    _composerAttachmentPathsByAgentKey.clear();
    _composerAttachmentSeedVersionByAgentKey.clear();
    _newThreadResetVersion++;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncViewWithRoute();
  }

  void _syncViewWithRoute() {
    final state = PathRouteMatch.of(context);
    final currentUri = state.uri;
    final path = currentUri.queryParameters['p'];
    final pane = _roomPaneFromUri(currentUri);
    final usesMobileRoomLayout = _usesMobileRoomLayout(context);

    if (!usesMobileRoomLayout && !_didNormalizeInitialDesktopPane) {
      _didNormalizeInitialDesktopPane = true;

      final hasExplicitPane = pane != null;
      final hasResidualPath = path != null && path.isNotEmpty;
      final hasPreviewOrigin = currentUri.queryParameters.containsKey(filePreviewOriginQueryParameter);
      final shouldResetToChat = !hasExplicitPane && (hasResidualPath || hasPreviewOrigin);

      if (shouldResetToChat) {
        controller.showChat();

        final updatedQueryParameters = Map<String, String>.from(currentUri.queryParameters)
          ..[_roomPaneQueryParameter] = _roomPaneQueryValue(_MobileRoomPane.chat)
          ..remove('p')
          ..remove(filePreviewOriginQueryParameter);
        final normalizedUri = currentUri.replace(queryParameters: updatedQueryParameters);

        _lastSyncedRoutePath = null;
        _lastSyncedRoutePane = _MobileRoomPane.chat;

        if (normalizedUri.toString() != currentUri.toString()) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !context.mounted) {
              return;
            }

            context.go(normalizedUri.toString());
          });
        }
        return;
      }
    }

    if (path == _lastSyncedRoutePath && pane == _lastSyncedRoutePane) {
      return;
    }
    _lastSyncedRoutePath = path;
    _lastSyncedRoutePane = pane;

    switch (pane) {
      case _MobileRoomPane.chat:
        controller.showChat();
        return;
      case _MobileRoomPane.files:
        controller.showFiles();
        return;
      case _MobileRoomPane.meeting:
        controller.enterMeeting();
        return;
      case null:
        if (path != null && path.isNotEmpty && usesMobileRoomLayout) {
          controller.showFiles();
          return;
        }

        controller.showChat();
    }
  }

  late final services = Resource<List<ServiceSpec>>(() async {
    final services = (await widget.room.services.list().timeout(
      _roomResourceTimeout,
      onTimeout: () => throw TimeoutException("Timed out while loading room services."),
    )).where(hasAgentMetadata).toList();
    services.sort(_compareServices);
    return services;
  });

  @override
  void dispose() {
    if (identical(previewRoomRailMenuBridgeListenable.value, _previewRoomRailMenuBridge)) {
      exposePreviewRoomRailMenuBridge(null);
    }
    if (previewFilePreviewFullscreenListenable.value) {
      setPreviewFilePreviewFullscreen(false);
    }
    for (final chatClient in _agentChatClients.values) {
      unawaited(chatClient.stop());
    }
    _agentChatClients.clear();
    _meetingSplitViewController.dispose();
    _roomStatusSubscription?.cancel();
    _roomStatusSubscription = null;
    super.dispose();
  }

  List<ServiceSpec> _supportedServices(List<ServiceSpec> all) {
    final supported = all.where(isSupportedServiceType).toList();
    supported.sort(_compareServices);
    return supported;
  }

  String _serviceSortKey(ServiceSpec s) => s.agents.firstOrNull?.name ?? s.metadata.name;
  int _compareServices(ServiceSpec a, ServiceSpec b) => _serviceSortKey(a).compareTo(_serviceSortKey(b));

  agent_sessions.BaseChatClient? _agentChatClientFor(String? agentName) {
    final normalized = agentName?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return _agentChatClients.putIfAbsent(normalized, () {
      final chatClient = agent_sessions.MessagingChatClient(room: widget.room, agentName: normalized);
      unawaited(chatClient.start());
      return chatClient;
    });
  }

  String _serviceId(ServiceSpec s) => s.metadata.annotations["meshagent.service.id"] ?? "";
  String _serviceType(ServiceSpec s) => s.agents.firstOrNull?.annotations["meshagent.agent.type"] ?? "[Unspecified]";
  String? _serviceAgentName(ServiceSpec service) {
    final name = service.agents.firstOrNull?.name;
    if (name == null) {
      return null;
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  bool _isBaseRouteId(String id) => id.isEmpty || id == "chat";

  void _navigateToAgentRoute(BuildContext context, String routeId) {
    final pid = fromUUID(widget.projectId);
    final currentUri = PathRouteMatch.of(context).uri;
    final nextPath = _isBaseRouteId(routeId) ? '/p/$pid/r/${widget.room.roomName}' : '/p/$pid/r/${widget.room.roomName}/a/$routeId';
    final nextUri = currentUri.replace(path: nextPath);
    context.go(nextUri.toString());
  }

  void _showDesktopPreviewChatPane(BuildContext context, {String? agentKey}) {
    controller.showChat();

    final currentUri = PathRouteMatch.of(context).uri;
    final updatedQueryParameters = Map<String, String>.from(currentUri.queryParameters)
      ..[_roomPaneQueryParameter] = _roomPaneQueryValue(_MobileRoomPane.chat)
      ..remove('p')
      ..remove(filePreviewOriginQueryParameter);
    var nextPath = currentUri.path;
    if (agentKey != null) {
      _persistSelectedRoomAgentRouteId(agentKey);
      final pid = fromUUID(widget.projectId);
      nextPath = _isBaseRouteId(agentKey) ? '/p/$pid/r/${widget.room.roomName}' : '/p/$pid/r/${widget.room.roomName}/a/$agentKey';
    }

    final nextUri = currentUri.replace(path: nextPath, queryParameters: updatedQueryParameters);
    if (nextUri.toString() == currentUri.toString()) {
      return;
    }

    context.go(nextUri.toString());
  }

  String? _agentRouteIdForFilePromptAction(ChatFilePromptAction action) {
    final agentName = action.agentName.trim();
    if (agentName.isEmpty) {
      return null;
    }

    if (services.state.isReady) {
      final supported = _supportedServices(services.state.value!);
      for (final service in supported) {
        final serviceName = service.metadata.name.trim();
        if (serviceName == agentName) {
          return _serviceId(service);
        }

        for (final agent in service.agents) {
          if (agent.name.trim() == agentName) {
            return _serviceId(service);
          }
        }
      }

      for (final participant in _developmentParticipants(supported)) {
        if (participantDisplayName(participant) == agentName) {
          return developmentAgentRouteId(agentName);
        }
      }
    }

    final developmentParticipant = widget.room.messaging.remoteParticipants.firstWhereOrNull(
      (participant) => isChatOrVoiceBotParticipant(participant) && participantDisplayName(participant) == agentName,
    );
    return developmentParticipant == null ? null : developmentAgentRouteId(agentName);
  }

  String? _chatCapableDevelopmentAgentNameForRoute(String routeId, List<ServiceSpec> supported) {
    final developmentAgentName = developmentAgentNameFromRoute(routeId);
    if (developmentAgentName == null) {
      return null;
    }

    final participant = _developmentParticipants(
      supported,
    ).firstWhereOrNull((candidate) => participantDisplayName(candidate) == developmentAgentName);
    if (participant == null || participantConversationDescriptor(participant)?.isChat != true) {
      return null;
    }

    return developmentAgentName;
  }

  List<_FilePromptAgentChoice> _filePromptAgentChoices(String path, {String? preferredAgentKey}) {
    if (!services.state.isReady) {
      return const <_FilePromptAgentChoice>[];
    }

    final supported = _supportedServices(services.state.value!);
    final resolvedActions = resolveChatFilePromptActions(services: services.state.value!, filePath: path);
    final actionsByAgentName = <String, ChatFilePromptAction>{};
    for (final action in resolvedActions) {
      final agentName = action.agentName.trim();
      if (agentName.isEmpty || actionsByAgentName.containsKey(agentName)) {
        continue;
      }
      actionsByAgentName[agentName] = action;
    }

    final choices = <_FilePromptAgentChoice>[];
    final seenRouteIds = <String>{};

    void addChoice(String routeId, String agentName) {
      final normalizedRouteId = routeId.trim();
      final normalizedAgentName = agentName.trim();
      if (normalizedRouteId.isEmpty || normalizedAgentName.isEmpty || !seenRouteIds.add(normalizedRouteId)) {
        return;
      }

      choices.add(
        _FilePromptAgentChoice(
          routeId: normalizedRouteId,
          agentName: normalizedAgentName,
          action: actionsByAgentName[normalizedAgentName] ?? defaultChatFilePromptAction(agentName: normalizedAgentName),
        ),
      );
    }

    if (preferredAgentKey != null) {
      final preferredDevelopmentAgentName = _chatCapableDevelopmentAgentNameForRoute(preferredAgentKey, supported);
      if (preferredDevelopmentAgentName != null) {
        addChoice(preferredAgentKey, preferredDevelopmentAgentName);
      }

      for (final service in supported) {
        if (_serviceId(service) != preferredAgentKey) {
          continue;
        }

        final agentName = _chatAgentNameForService(service);
        if (agentName != null) {
          addChoice(preferredAgentKey, agentName);
        }
      }
    }

    for (final service in supported) {
      final agentName = _chatAgentNameForService(service);
      if (agentName != null) {
        addChoice(_serviceId(service), agentName);
      }
    }

    for (final participant in _developmentParticipants(supported)) {
      if (participantConversationDescriptor(participant)?.isChat != true) {
        continue;
      }

      final agentName = participantDisplayName(participant);
      if (agentName != null) {
        addChoice(developmentAgentRouteId(agentName), agentName);
      }
    }

    return choices;
  }

  Future<_FilePromptAgentChoice?> _showAskAgentSwitchDialog({
    required _MobileChatHeaderContext currentAgent,
    required List<_FilePromptAgentChoice> choices,
    required _FilePromptAgentChoice initialChoice,
  }) {
    return showGeneralDialog<_FilePromptAgentChoice?>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Switch agent to ask',
      barrierColor: Colors.transparent,
      pageBuilder: (_, _, _) =>
          _AskAgentSwitchDialog(currentAgentName: currentAgent.agentName, choices: choices, initialChoice: initialChoice),
    );
  }

  Future<ChatFilePromptAction?> _resolveAttachmentPromptAction(
    ChatFilePromptAction action, {
    required String filePath,
    String? preferredAgentKey,
  }) async {
    if (!services.state.isReady) {
      return action;
    }

    final supported = _supportedServices(services.state.value!);
    final selected = _resolveSelectedAgent(supported);
    final currentAgent = _resolveMobileChatHeaderContext(supported, selected);
    if (currentAgent == null || currentAgent.threadListPath != null) {
      return action;
    }

    final choices = _filePromptAgentChoices(filePath, preferredAgentKey: preferredAgentKey);
    if (choices.isEmpty) {
      return action;
    }

    final resolvedTargetRouteId = _agentRouteIdForFilePromptAction(action) ?? preferredAgentKey;
    final currentRouteId = currentAgent.agentKey;
    final initialChoice =
        choices.firstWhereOrNull((choice) => choice.routeId == resolvedTargetRouteId) ??
        choices.firstWhereOrNull((choice) => choice.routeId != currentRouteId) ??
        choices.first;

    if (currentRouteId != null && initialChoice.routeId == currentRouteId) {
      return action;
    }

    final selectedChoice = await _showAskAgentSwitchDialog(currentAgent: currentAgent, choices: choices, initialChoice: initialChoice);
    if (selectedChoice == null) {
      return null;
    }

    final didDisconnect = await _disconnectVoiceSessionForAgentSwitch(currentRouteId: currentRouteId, nextRouteId: selectedChoice.routeId);
    if (!didDisconnect) {
      return null;
    }

    return selectedChoice.action;
  }

  MeetingController? _voiceSessionControllerForAgentSwitch({BuildContext? sourceContext}) {
    final scopedController = sourceContext != null && sourceContext.mounted ? MeetingController.maybeOf(sourceContext) : null;
    return powerboardsPreferScopedValue(scopedValue: scopedController, fallbackValue: _roomMeetingController);
  }

  Future<bool> _disconnectVoiceSessionForAgentSwitch({
    BuildContext? sourceContext,
    required String? currentRouteId,
    required String? nextRouteId,
  }) async {
    final voiceSessionController = _voiceSessionControllerForAgentSwitch(sourceContext: sourceContext);
    final shouldDisconnect = powerboardsShouldDisconnectVoiceSessionForAgentSwitch(
      voiceSessionConnected: voiceSessionController?.isConnected == true,
      currentRouteId: currentRouteId,
      nextRouteId: nextRouteId,
    );
    if (!shouldDisconnect) {
      return true;
    }

    final toaster = sourceContext != null && sourceContext.mounted ? ShadToaster.maybeOf(sourceContext) : ShadToaster.maybeOf(context);
    try {
      await voiceSessionController!.disconnect();
      _pendingPreviewRailVoiceSessionDisconnect = true;
      final syncContext = sourceContext != null && sourceContext.mounted ? sourceContext : context;
      if (mounted && syncContext.mounted) {
        _syncPreviewRoomRailMenuBridge(syncContext, meetingSessionActive: _isMeetingSessionActive(syncContext), voiceSessionActive: false);
      }
      return true;
    } catch (_) {
      toaster?.show(
        powerboardsToast(
          title: 'Unable to switch agents',
          description: 'End the active voice session before switching agents.',
          destructive: true,
        ),
      );
      return false;
    }
  }

  IconData _developmentAgentIcon(RemoteParticipant participant) {
    if (participantSupportsVoice(participant)) {
      return LucideIcons.audioWaveform;
    }
    if (!participantSupportsChat(participant)) {
      return LucideIcons.badgeQuestionMark;
    }
    return LucideIcons.bot;
  }

  List<RemoteParticipant> _developmentParticipants(List<ServiceSpec> supported) {
    final serviceAgentNames = <String>{};
    for (final service in supported) {
      final name = _serviceAgentName(service);
      if (name != null) {
        serviceAgentNames.add(name);
      }
    }

    final seenNames = <String>{};
    final participants = <RemoteParticipant>[];
    for (final participant in widget.room.messaging.remoteParticipants) {
      if (!isChatOrVoiceBotParticipant(participant)) {
        continue;
      }

      final name = participantDisplayName(participant);
      if (name == null || serviceAgentNames.contains(name) || !seenNames.add(name)) {
        continue;
      }

      participants.add(participant);
    }

    participants.sort((a, b) {
      final left = participantDisplayName(a) ?? "";
      final right = participantDisplayName(b) ?? "";
      return left.toLowerCase().compareTo(right.toLowerCase());
    });

    return participants;
  }

  bool _hasVisibleAgents(List<ServiceSpec> supported) {
    if (supported.isNotEmpty) {
      return true;
    }

    return _developmentParticipants(supported).isNotEmpty;
  }

  bool get _canPersistRoomContextSelection {
    final roomName = widget.room.roomName;
    return roomName != null && roomName.trim().isNotEmpty;
  }

  String? get _roomNameForSelectionPersistence {
    final roomName = widget.room.roomName;
    if (roomName == null) {
      return null;
    }

    final trimmed = roomName.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _persistedSelectedRoomAgentRouteId() {
    final roomName = _roomNameForSelectionPersistence;
    if (roomName == null) {
      return null;
    }

    final stored = getLastSelectedRoomAgent(widget.projectId, roomName);
    if (stored == null) {
      return null;
    }

    final trimmed = stored.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _persistSelectedRoomAgentRouteId(String? routeId) {
    if (!_canPersistRoomContextSelection || routeId == _lastPersistedMobileAgentRouteId) {
      return;
    }

    final roomName = _roomNameForSelectionPersistence;
    if (roomName == null) {
      return;
    }

    if (routeId == null || routeId.trim().isEmpty) {
      clearLastSelectedRoomAgent(widget.projectId, roomName);
      _lastPersistedMobileAgentRouteId = null;
      return;
    }

    setLastSelectedRoomAgent(widget.projectId, roomName, routeId);
    _lastPersistedMobileAgentRouteId = routeId;
  }

  _ResolvedAgentSelection _resolveSelectedAgent(List<ServiceSpec> supported, {String? requestedRouteId}) {
    final resolvedRouteId = requestedRouteId ?? widget.service;
    if (resolvedRouteId != null) {
      final service = supported.firstWhereOrNull((candidate) => _serviceId(candidate) == resolvedRouteId);
      if (service != null) {
        return _ResolvedAgentSelection(routeId: resolvedRouteId, service: service, developmentParticipant: null);
      }

      final participantName = developmentAgentNameFromRoute(resolvedRouteId);
      if (participantName != null) {
        final participant = _developmentParticipants(
          supported,
        ).firstWhereOrNull((candidate) => participantDisplayName(candidate) == participantName);
        return _ResolvedAgentSelection(
          routeId: developmentAgentRouteId(participantName),
          service: null,
          developmentParticipant: participant,
        );
      }

      final legacyParticipantId = legacyDevelopmentAgentParticipantIdFromRoute(resolvedRouteId);
      if (legacyParticipantId != null) {
        final participant = widget.room.messaging.remoteParticipants.firstWhereOrNull(
          (candidate) => candidate.id == legacyParticipantId && isChatOrVoiceBotParticipant(candidate),
        );
        final participantName = participant == null ? null : participantDisplayName(participant);
        return _ResolvedAgentSelection(
          routeId: participantName == null ? resolvedRouteId : developmentAgentRouteId(participantName),
          service: null,
          developmentParticipant: participant,
        );
      }

      return _ResolvedAgentSelection(routeId: resolvedRouteId, service: null, developmentParticipant: null);
    }

    final defaultService =
        supported.firstWhereOrNull((candidate) => serviceConversationDescriptor(candidate)?.isChat == true) ?? supported.firstOrNull;
    if (defaultService != null) {
      return _ResolvedAgentSelection(routeId: _serviceId(defaultService), service: defaultService, developmentParticipant: null);
    }

    final participant = _developmentParticipants(supported).firstOrNull;
    if (participant != null) {
      final participantName = participantDisplayName(participant);
      if (participantName != null) {
        return _ResolvedAgentSelection(
          routeId: developmentAgentRouteId(participantName),
          service: null,
          developmentParticipant: participant,
        );
      }
    }

    return const _ResolvedAgentSelection(routeId: null, service: null, developmentParticipant: null);
  }

  String? _selectedThreadPathForAgentKey(String? agentKey) {
    if (agentKey == null) {
      return null;
    }

    final inMemory = _selectedThreadPathByAgentKey[agentKey];
    if (inMemory != null) {
      return inMemory;
    }

    return null;
  }

  // ignore: unused_element
  String? _selectedThreadLabelForAgentKey(String? agentKey) {
    if (agentKey == null) {
      return null;
    }

    final stored = _selectedThreadLabelByAgentKey[agentKey];
    if (stored != null && stored.trim().isNotEmpty) {
      return stored;
    }

    return null;
  }

  void _setSelectedThreadPath(String? agentKey, String? path, {String? displayName}) {
    if (agentKey == null) {
      return;
    }

    final normalizedPath = path?.trim();
    final resolvedPath = normalizedPath == null || normalizedPath.isEmpty ? null : normalizedPath;
    final normalizedName = displayName?.trim();
    final resolvedDisplayName = normalizedName == null || normalizedName.isEmpty ? null : normalizedName;
    final previousPath = _selectedThreadPathByAgentKey[agentKey];
    final previousDisplayName = _selectedThreadLabelByAgentKey[agentKey];
    final effectiveDisplayName = resolvedDisplayName ?? (resolvedPath == previousPath ? previousDisplayName : null);

    if (resolvedPath == previousPath && effectiveDisplayName == previousDisplayName) {
      return;
    }

    setState(() {
      if (resolvedPath == null) {
        _selectedThreadPathByAgentKey.remove(agentKey);
        _selectedThreadLabelByAgentKey.remove(agentKey);
        _newThreadResetVersion++;
      } else {
        _selectedThreadPathByAgentKey[agentKey] = resolvedPath;
        if (effectiveDisplayName == null) {
          _selectedThreadLabelByAgentKey.remove(agentKey);
        } else {
          _selectedThreadLabelByAgentKey[agentKey] = effectiveDisplayName;
        }
      }
    });
  }

  void _setComposerAttachmentSeed(String agentKey, Iterable<String> paths) {
    final normalizedPaths = paths.map(powerboardsStorageAttachmentPathFromUrl).where((path) => path.isNotEmpty).toList(growable: false);
    if (normalizedPaths.isEmpty) {
      return;
    }

    setState(() {
      _composerAttachmentPathsByAgentKey[agentKey] = normalizedPaths;
      _composerAttachmentSeedVersionByAgentKey[agentKey] = ++_composerAttachmentSeedRevision;
    });
  }

  void _clearComposerAttachmentSeed(String agentKey) {
    if (!_composerAttachmentPathsByAgentKey.containsKey(agentKey) && !_composerAttachmentSeedVersionByAgentKey.containsKey(agentKey)) {
      return;
    }

    setState(() {
      _composerAttachmentPathsByAgentKey.remove(agentKey);
      _composerAttachmentSeedVersionByAgentKey.remove(agentKey);
    });
  }

  void updatePath(BuildContext context, String? path) {
    controller.showFiles();
    _replaceRoomRouteState(context, pane: _MobileRoomPane.files, rawPath: path);
  }

  String? _normalizedThreadDocumentDir(String? threadDir) {
    if (threadDir == null) {
      return null;
    }

    final trimmed = threadDir.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed.endsWith("/") ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  String? _defaultThreadDocumentDir(String? agentName) {
    if (agentName == null) {
      return null;
    }

    final trimmed = agentName.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return '.threads/$trimmed';
  }

  String? _resolvedThreadListPath(String? threadListPath, {String? threadDir, String? agentName}) {
    return ma.resolvedThreadListPath(threadListPath, threadDir: threadDir, agentName: agentName);
  }

  String getDocumentPath(String? agent, {String? threadDir}) {
    final normalizedThreadDir = _normalizedThreadDocumentDir(threadDir);
    if (normalizedThreadDir != null) {
      if (normalizedThreadDir.startsWith('dataset://') || normalizedThreadDir.startsWith('tmp://')) {
        return "$normalizedThreadDir/main";
      }
      return "$normalizedThreadDir/main.thread";
    }

    final defaultThreadDir = _defaultThreadDocumentDir(agent);
    if (defaultThreadDir != null) {
      return "$defaultThreadDir/main.thread";
    }

    return '.threads/main.thread';
  }

  String? _preferredMobileAgentRouteId(BuildContext context) {
    final explicitRouteId = widget.service;
    if (explicitRouteId != null) {
      return explicitRouteId;
    }

    if (_usesMobileRoomLayout(context) || powerboardsUsesDesktopUiPreview(context)) {
      return _persistedSelectedRoomAgentRouteId();
    }

    return null;
  }

  List<_MobileRoomContextAgentOption> _mobileRoomContextAgentOptions(List<ServiceSpec> supported) {
    final options = <_MobileRoomContextAgentOption>[];

    for (final service in supported) {
      final descriptor = serviceConversationDescriptor(service, remoteParticipants: widget.room.messaging.remoteParticipants);
      final supportsVoice = descriptor?.isVoiceOnly == true;
      final supportsChat = descriptor?.isChat == true;
      if (!supportsChat && !supportsVoice) {
        continue;
      }

      final serviceName = service.agents.firstOrNull?.name ?? service.metadata.name;
      final isVoiceOnly = supportsVoice && !supportsChat;
      final threadListPath = isVoiceOnly
          ? null
          : _resolvedThreadListPath(descriptor?.threadListPath, threadDir: descriptor?.threadDir, agentName: serviceName);
      final supportsThreads = threadListPath != null;
      final rawServiceDescription = service.metadata.description;
      final serviceDescription = rawServiceDescription == null || rawServiceDescription.trim().isEmpty
          ? (isVoiceOnly ? "Voice agent" : "Chat agent")
          : rawServiceDescription;
      options.add(
        _MobileRoomContextAgentOption(
          routeId: _serviceId(service),
          name: serviceName,
          description: serviceDescription,
          threadListPath: threadListPath,
          leadingIcon: supportsVoice ? LucideIcons.audioWaveform : LucideIcons.bot,
          supportsThreads: supportsThreads,
          isVoiceOnly: isVoiceOnly,
        ),
      );
    }

    for (final participant in _developmentParticipants(supported)) {
      final descriptor = participantConversationDescriptor(participant);
      final supportsVoice = descriptor?.isVoiceOnly == true;
      final supportsChat = descriptor?.isChat == true;
      if (!supportsChat && !supportsVoice) {
        continue;
      }

      final participantName = participantDisplayName(participant);
      if (participantName == null) {
        continue;
      }
      final isVoiceOnly = supportsVoice && !supportsChat;
      final threadListPath = isVoiceOnly
          ? null
          : _resolvedThreadListPath(descriptor?.threadListPath, threadDir: descriptor?.threadDir, agentName: participantName);
      final supportsThreads = threadListPath != null;

      options.add(
        _MobileRoomContextAgentOption(
          routeId: developmentAgentRouteId(participantName),
          name: participantName,
          description: isVoiceOnly ? "Development mode voice agent" : "Development mode agent",
          threadListPath: threadListPath,
          leadingIcon: _developmentAgentIcon(participant),
          supportsThreads: supportsThreads,
          isVoiceOnly: isVoiceOnly,
        ),
      );
    }

    return options;
  }

  void _applyMobileRoomContextSelection({
    required _MobileChatHeaderContext currentChatContext,
    required _MobileRoomContextAgentOption agentOption,
    required String? threadPath,
    String? displayName,
  }) {
    _setSelectedThreadPath(agentOption.routeId, threadPath, displayName: displayName);
    _persistSelectedRoomAgentRouteId(agentOption.routeId);

    if (agentOption.routeId != currentChatContext.agentKey) {
      _navigateToAgentRoute(context, agentOption.routeId);
    }
  }

  Future<void> _commitMobileRoomContextSelection(
    BuildContext dialogContext, {
    required _MobileChatHeaderContext currentChatContext,
    required _MobileRoomContextAgentOption agentOption,
    required String? threadPath,
    String? displayName,
  }) async {
    Navigator.of(dialogContext).pop();
    _applyMobileRoomContextSelection(
      currentChatContext: currentChatContext,
      agentOption: agentOption,
      threadPath: threadPath,
      displayName: displayName,
    );
  }

  _MobileChatHeaderContext? _resolveMobileChatHeaderContext(List<ServiceSpec> supported, _ResolvedAgentSelection selection) {
    String? agentName;
    String? threadListPath;
    var currentThreadLabel = "New thread";
    var supportsThreads = false;
    var isVoiceOnly = false;

    final developmentParticipant = selection.developmentParticipant;
    if (developmentParticipant != null) {
      final descriptor = participantConversationDescriptor(developmentParticipant);
      if (descriptor == null || (descriptor.isChat != true && descriptor.isVoiceOnly != true)) {
        return null;
      }

      agentName = participantDisplayName(developmentParticipant);
      if (agentName == null) {
        return null;
      }
      isVoiceOnly = descriptor.isVoiceOnly == true && descriptor.isChat != true;
      threadListPath = isVoiceOnly
          ? null
          : _resolvedThreadListPath(descriptor.threadListPath, threadDir: descriptor.threadDir, agentName: agentName);
      supportsThreads = threadListPath != null;
      currentThreadLabel = isVoiceOnly ? "Audio session" : "New thread";
    } else if (selection.service != null) {
      final service = selection.service!;
      final descriptor = serviceConversationDescriptor(service, remoteParticipants: widget.room.messaging.remoteParticipants);
      if (descriptor == null || (descriptor.isChat != true && descriptor.isVoiceOnly != true)) {
        return null;
      }

      agentName = service.agents.firstOrNull?.name ?? service.metadata.name;
      isVoiceOnly = descriptor.isVoiceOnly == true && descriptor.isChat != true;
      threadListPath = isVoiceOnly
          ? null
          : _resolvedThreadListPath(descriptor.threadListPath, threadDir: descriptor.threadDir, agentName: agentName);
      supportsThreads = threadListPath != null;
      currentThreadLabel = isVoiceOnly ? "Audio session" : "New thread";
    }

    if (agentName == null) {
      return null;
    }

    final agentKey = selection.routeId;
    final selectedThreadPath = supportsThreads ? _selectedThreadPathForAgentKey(agentKey) : null;
    if (supportsThreads && selectedThreadPath != null) {
      currentThreadLabel = _selectedThreadLabelForAgentKey(agentKey) ?? defaultThreadDisplayNameFromPath(selectedThreadPath);
    }

    return _MobileChatHeaderContext(
      agentName: agentName,
      agentKey: agentKey,
      currentThreadLabel: currentThreadLabel,
      selectedThreadPath: selectedThreadPath,
      threadListPath: threadListPath,
      isVoiceOnly: isVoiceOnly,
    );
  }

  List<Widget> _meetingHeaderPrimaryControls(BuildContext context) {
    final model = room.VideoRoomModel.maybeOf(context);
    if (model?.room == null) {
      return [];
    }
    final usesMobileRoomLayout = _usesMobileRoomLayout(context);
    final meetingSessionActive = _isMeetingSessionActive(context);
    final showExpandSplitButton = !usesMobileRoomLayout && meetingSessionActive && _meetingSplitViewController.collapsed;
    final useDesktopV1ActiveControls = !usesMobileRoomLayout && meetingSessionActive && powerboardsUsesDesktopUiPreview(context);

    return [
      if (showExpandSplitButton)
        Tooltip(
          message: "Expand chat",
          child: ShadIconButton.ghost(
            icon: const Icon(LucideIcons.panelLeftOpen),
            decoration: powerboardsAdaptiveIconButtonDecoration(context),
            onPressed: () {
              _meetingSplitViewController.expand();
              setState(() {});
            },
          ),
        ),
      HangupButton(onPressed: _endMeeting, desktopV1Style: useDesktopV1ActiveControls),
      room.MicToggle(desktopV1Style: useDesktopV1ActiveControls),
      room.CameraToggle(desktopV1Style: useDesktopV1ActiveControls),
      room.ChangeSettings(desktopV1Style: useDesktopV1ActiveControls),
    ];
  }

  List<Widget> _meetingToolbarControls(BuildContext context, {bool compact = false}) {
    final primaryControls = _meetingHeaderPrimaryControls(context);
    if (primaryControls.isEmpty) {
      return [];
    }

    final usesMobileRoomLayout = _usesMobileRoomLayout(context);
    final isLandscapePhone = _isLandscapePhoneViewport(context);
    final useDesktopV1ActiveControls =
        !usesMobileRoomLayout && _isMeetingSessionActive(context) && powerboardsUsesDesktopUiPreview(context);
    final compactTranscriptionControl = compact && !isLandscapePhone;

    return [
      ...primaryControls,
      if (!usesMobileRoomLayout) room.ShareScreen(compact: compact, desktopV1Style: useDesktopV1ActiveControls),
      MeetingToolkits(room: widget.room, compact: compactTranscriptionControl, desktopV1Style: useDesktopV1ActiveControls),
    ];
  }

  List<Widget> meetingActions(BuildContext context) {
    final controls = _meetingToolbarControls(context);
    if (controls.isEmpty) {
      return controls;
    }

    return [...controls, Spacer()];
  }

  bool _isMeetingSessionActive(BuildContext context) {
    final meetingViewController = Controller.ofType<MeetingViewController>(context);
    final videoRoom = room.VideoRoomModel.maybeOf(context)?.room;
    return meetingViewController.state == MeetingViewState.joined && videoRoom != null;
  }

  bool _isVoiceSessionActive(BuildContext context) {
    final voiceSessionController = MeetingController.maybeOf(context);
    return voiceSessionController?.isConnected == true && !_isMeetingSessionActive(context);
  }

  bool _previewRailVoiceSessionActive(BuildContext context, {bool? actualVoiceSessionActive}) {
    final resolvedActualVoiceSessionActive = actualVoiceSessionActive ?? _isVoiceSessionActive(context);
    final resolvedPreviewRailVoiceSessionActive = powerboardsResolvePreviewRailVoiceSessionActive(
      actualVoiceSessionActive: resolvedActualVoiceSessionActive,
      pendingVoiceSessionDisconnect: _pendingPreviewRailVoiceSessionDisconnect,
    );
    if (_pendingPreviewRailVoiceSessionDisconnect && !resolvedActualVoiceSessionActive) {
      _pendingPreviewRailVoiceSessionDisconnect = false;
    }
    return resolvedPreviewRailVoiceSessionActive;
  }

  Widget _buildAudioAgentEmptyState({
    required String title,
    required String description,
    Widget? action,
    double verticalOffset = AudioAgentEmptyState.defaultVerticalOffset,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: AudioAgentEmptyState(
          title: title,
          description: description,
          availableWidth: constraints.maxWidth,
          action: action,
          verticalOffset: verticalOffset,
        ),
      ),
    );
  }

  Widget _buildMeetingSingleThreadChatEmptyState(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: ChatThreadEmptyStateContent(title: title),
    );
  }

  Widget _buildMeetingTranscriberTitleOnlyEmptyState(String title) {
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: AudioAgentEmptyState(
          title: title,
          description: "",
          availableWidth: constraints.maxWidth,
          verticalOffset: AudioAgentEmptyState.defaultVerticalOffset - 20,
        ),
      ),
    );
  }

  Widget _buildMeetingTranscriberPreMeetingChatEmptyState() {
    return _buildAudioAgentEmptyState(
      title: "Transcribe your meeting",
      description: "Meet with this agent and include your team.",
      verticalOffset: AudioAgentEmptyState.defaultVerticalOffset - 20,
    );
  }

  List<Widget> _meetingPaneActions(BuildContext context, {required bool canViewStorageAllowed}) {
    final meetingSessionActive = _isMeetingSessionActive(context);
    final activeMeetingPane = meetingSessionActive && controller.inMeeting;
    final useDesktopUiPreview = powerboardsUsesDesktopUiPreview(context);
    return [
      if (canViewStorageAllowed)
        PaneHeaderActionItem(
          expandedWidth: desktopPaneHeaderFilesButtonWidth,
          compactWidth: desktopPaneHeaderCompactButtonWidth,
          overflowOnCompact: activeMeetingPane,
          child: FilesButton(controller: controller, onPressed: () => _toggleFilesPane(context)),
        ),
      PaneHeaderActionItem(
        expandedWidth: desktopPaneHeaderMeetButtonWidth,
        compactWidth: desktopPaneHeaderCompactButtonWidth,
        overflowOnCompact: activeMeetingPane,
        child: MeetButton(controller: controller, meetingSessionActive: meetingSessionActive, onPressed: () => _toggleMeetingPane(context)),
      ),
      if (activeMeetingPane)
        PaneHeaderActionItem(
          expandedWidth: desktopPaneHeaderInviteButtonWidth,
          compactWidth: desktopPaneHeaderCompactButtonWidth,
          overflowOnCompact: false,
          child: InviteUserButton(projectId: widget.projectId, roomName: widget.room.roomName!),
        ),
      PaneHeaderActionItem(
        expandedWidth: desktopPaneHeaderOptionsButtonWidth,
        compactWidth: desktopPaneHeaderOptionsButtonWidth,
        child: RoomOptionsMenu(
          projectId: widget.projectId,
          room: widget.room,
          roomController: controller,
          isOwner: isOwner,
          canViewDeveloperLogs: canViewDeveloperLogs,
          boundaryContext: context,
          showMeetingPaneEntriesInOverflow: activeMeetingPane,
          showFilesAction: canViewStorageAllowed,
          showMeetAction: true,
          onShowChat: () => _showChatPane(context),
          onShowFiles: () => _toggleFilesPane(context),
          onShowMeet: () => _toggleMeetingPane(context),
        ),
      ),
      if (!useDesktopUiPreview)
        PaneHeaderActionItem(
          expandedWidth: desktopPaneHeaderAvatarButtonWidth,
          compactWidth: desktopPaneHeaderAvatarButtonWidth,
          child: UserAvatarMenuButton(projectId: widget.projectId, projects: widget.projects, boundaryContext: context),
        ),
    ];
  }

  Future<void> showManageAgents() async {
    await showManageAgentsSurface(context: context, projectId: widget.projectId, room: widget.room);
    if (!mounted) return;
    services.refresh();
  }

  Future<void> _renameCurrentRoomFromPreviewRail() async {
    final currentName = _roomDisplayName;
    final newName = await showRenameRoomDialog(context, initialValue: currentName);
    if (!mounted || newName == null || newName == currentName) {
      return;
    }

    final room = await getMeshagentClient().getRoom(name: widget.room.roomName!, projectId: widget.projectId);
    if (!mounted) {
      return;
    }

    await getMeshagentClient().updateRoom(
      projectId: widget.projectId,
      roomId: room.id,
      name: room.name,
      metadata: {"displayName": newName},
    );
    if (!mounted) {
      return;
    }

    overridePreviewRoomDisplayName(projectId: widget.projectId, roomName: room.name, displayName: newName);
    refreshPreviewRoomList();
    setState(() {
      _resolvedRoomDisplayName = newName;
    });
  }

  Future<void> _openCurrentRoomPermissionsFromPreviewRail() async {
    final room = await getMeshagentClient().getRoom(name: widget.room.roomName!, projectId: widget.projectId);
    if (!mounted) {
      return;
    }

    await showUpdateRoomPermsDialog(context, projectId: widget.projectId, room: room);
  }

  Future<void> _deleteCurrentRoomFromPreviewRail() async {
    final confirmed =
        await showDeleteRoomDialog(
          context,
          title: 'Delete room',
          description: 'Are you sure you want to delete the room "$_roomDisplayName"? This action cannot be undone.',
          confirmText: 'Delete',
          destructive: true,
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }

    final room = await getMeshagentClient().getRoom(name: widget.room.roomName!, projectId: widget.projectId);
    if (!mounted) {
      return;
    }

    await getMeshagentClient().deleteRoom(projectId: widget.projectId, roomId: room.id);
    if (!mounted) {
      return;
    }

    refreshPreviewRoomList();
    clearLastSelectedRoom(widget.projectId);
    context.go('/p/${fromUUID(widget.projectId)}');
  }

  void _openRoomKeychainFromPreviewRail() {
    showShadDialog<void>(
      context: context,
      builder: (dialogContext) => KeychainDialog(client: getMeshagentClient(), projectId: widget.projectId),
    );
  }

  Future<void> _shutdownRoomFromPreviewRail() async {
    final toaster = ShadToaster.of(context);
    final sessionId = widget.room.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      toaster.show(powerboardsToast(title: "Unable to shut down room", description: "Session id is not available yet.", destructive: true));
      return;
    }

    final confirmed = await showDeleteRoomDialog(
      context,
      title: "Shutdown room?",
      description: "This will stop the current room session for everyone connected.",
      confirmText: "Shutdown",
      destructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      toaster.show(powerboardsToast(title: "Room shutdown", description: "Requested."));
      widget.room.dispose();
      await getMeshagentClient().terminate(projectId: widget.projectId, sessionId: sessionId);
    } catch (error) {
      if (!mounted) {
        return;
      }

      toaster.show(powerboardsToast(title: "Unable to shut down room", description: "$error", destructive: true));
    }
  }

  void _syncPreviewRoomRailMenuBridge(BuildContext context, {bool? meetingSessionActive, bool? voiceSessionActive}) {
    final shouldExpose = powerboardsUsesDesktopUiPreview(context);
    if (!shouldExpose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (identical(previewRoomRailMenuBridgeListenable.value, _previewRoomRailMenuBridge)) {
          exposePreviewRoomRailMenuBridge(null);
        }
      });
      return;
    }

    final resolvedMeetActive = meetingSessionActive ?? _isMeetingSessionActive(context);
    final resolvedChatActive = _previewRailVoiceSessionActive(context, actualVoiceSessionActive: voiceSessionActive);
    final canShowManageAgents = isOwner.state.value == true;
    final showConsoleToggle = canViewDeveloperLogs.state.value == true;
    final showShutdown = isOwner.state.value == true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _previewRoomRailMenuBridge.configure(
        chatActive: resolvedChatActive,
        showDestinations: true,
        showMore: true,
        showRename: true,
        showPermissions: true,
        showManageAgents: canShowManageAgents,
        showDeleteRoom: true,
        showKeychain: true,
        showConsoleToggle: showConsoleToggle,
        showShutdown: showShutdown,
        meetActive: resolvedMeetActive,
        consoleLabel: 'Developer console',
        whoIsHereNames: const [],
        onRenamePressed: () => unawaited(_renameCurrentRoomFromPreviewRail()),
        onPermissionsPressed: () => unawaited(_openCurrentRoomPermissionsFromPreviewRail()),
        onManageAgentsPressed: () => unawaited(showManageAgents()),
        onDeleteRoomPressed: () => unawaited(_deleteCurrentRoomFromPreviewRail()),
        onKeychainPressed: _openRoomKeychainFromPreviewRail,
        onToggleConsolePressed: () {
          if (controller.isDebugShown) {
            controller.hideDebug();
          } else {
            controller.showDebug();
          }
          _syncPreviewRoomRailMenuBridge(context, meetingSessionActive: resolvedMeetActive);
        },
        onShutdownPressed: () => unawaited(_shutdownRoomFromPreviewRail()),
      );
      exposePreviewRoomRailMenuBridge(_previewRoomRailMenuBridge);
    });
  }

  Widget _buildAgentsActionRow(BuildContext context) {
    final isMobile = _usesMobileRoomLayout(context);
    if (!isMobile) return const SizedBox.shrink();
    return const SizedBox.shrink();
  }

  // ignore: unused_element
  _MobileRoomPane _mobileActivePane({required bool filesVisible}) {
    if (controller.inMeeting) {
      return _MobileRoomPane.meeting;
    }
    if (filesVisible) {
      return _MobileRoomPane.files;
    }
    return _MobileRoomPane.chat;
  }

  _MobileRoomPane? _roomPaneFromUri(Uri uri) {
    final value = uri.queryParameters[_roomPaneQueryParameter];
    return switch (value) {
      'chat' => _MobileRoomPane.chat,
      'files' => _MobileRoomPane.files,
      'meeting' => _MobileRoomPane.meeting,
      _ => null,
    };
  }

  String _roomPaneQueryValue(_MobileRoomPane pane) {
    return switch (pane) {
      _MobileRoomPane.chat => 'chat',
      _MobileRoomPane.files => 'files',
      _MobileRoomPane.meeting => 'meeting',
    };
  }

  void _replaceRoomRouteState(
    BuildContext context, {
    required _MobileRoomPane pane,
    String? rawPath,
    bool clearRawPath = false,
    bool clearPreviewOrigin = false,
  }) {
    final state = PathRouteMatch.of(context);
    final currentUri = state.uri;
    final updatedQueryParameters = Map<String, String>.from(currentUri.queryParameters);

    updatedQueryParameters[_roomPaneQueryParameter] = _roomPaneQueryValue(pane);

    if (clearRawPath) {
      updatedQueryParameters.remove('p');
    } else if (rawPath != null) {
      updatedQueryParameters['p'] = rawPath;
    }
    if (clearPreviewOrigin) {
      updatedQueryParameters.remove(filePreviewOriginQueryParameter);
    }

    final newUri = currentUri.replace(queryParameters: updatedQueryParameters);
    if (newUri.toString() == currentUri.toString()) {
      return;
    }

    context.go(newUri.toString());
  }

  void _showChatPane(BuildContext context) {
    controller.showChat();
    _replaceRoomRouteState(context, pane: _MobileRoomPane.chat, clearRawPath: true, clearPreviewOrigin: true);
  }

  void _showFilesPane(BuildContext context) {
    controller.showFiles();
    _replaceRoomRouteState(context, pane: _MobileRoomPane.files);
  }

  void _rememberMobileMeetingOrigin(BuildContext context) {
    final currentPane = _mobileActivePane(filesVisible: controller.isFilesShown);
    if (currentPane == _MobileRoomPane.meeting) {
      return;
    }

    final currentUri = PathRouteMatch.of(context).uri;
    _mobileMeetingOrigin = _MobileMeetingOrigin(pane: currentPane, rawPath: currentUri.queryParameters['p']);
  }

  void _showMeetingPane(BuildContext context) {
    if (ResponsiveBreakpoints.of(context).isMobile) {
      _rememberMobileMeetingOrigin(context);
    }
    controller.enterMeeting();
    _replaceRoomRouteState(context, pane: _MobileRoomPane.meeting);
  }

  void _closeMobileMeetingLobby(BuildContext context) {
    final origin = _mobileMeetingOrigin;
    _mobileMeetingOrigin = null;

    if (origin?.pane == _MobileRoomPane.files) {
      controller.showFiles();
      _replaceRoomRouteState(context, pane: _MobileRoomPane.files, rawPath: origin?.rawPath ?? '');
      return;
    }

    _showChatPane(context);
  }

  void _toggleFilesPane(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (controller.isFilesShown) {
      if (isMobile) {
        _showFilesPane(context);
        return;
      }

      _showChatPane(context);
      return;
    }

    _showFilesPane(context);
  }

  void _toggleMeetingPane(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (controller.inMeeting) {
      if (isMobile) {
        _showMeetingPane(context);
        return;
      }

      _showChatPane(context);
      return;
    }

    _showMeetingPane(context);
  }

  _MobileFilesLocation _mobileFilesLocation(BuildContext context) {
    return _MobileFilesLocation.fromUri(PathRouteMatch.of(context).uri);
  }

  void _openMobileFilesEntry(BuildContext context, String path, {required bool isFolder}) {
    _replaceRoomRouteState(context, pane: _MobileRoomPane.files, rawPath: path.isEmpty ? '' : (isFolder ? '$path/' : path));
  }

  void _navigateBackFromMobileFiles(BuildContext context) {
    final currentUri = PathRouteMatch.of(context).uri;
    final previewOrigin = currentUri.queryParameters[filePreviewOriginQueryParameter];
    if (previewOrigin != null && previewOrigin.isNotEmpty && previewOrigin != currentUri.toString()) {
      context.go(previewOrigin);
      return;
    }

    final filesLocation = _mobileFilesLocation(context);
    final backFolderPath = filesLocation.backFolderPath;

    if (backFolderPath != null) {
      _openMobileFilesEntry(context, backFolderPath, isFolder: true);
      return;
    }

    _showChatPane(context);
  }

  List<AppMenuEntry> _mobileFilesBackMenuEntries(BuildContext context) {
    final filesLocation = _mobileFilesLocation(context);
    final folderSegments = filesLocation.folder.split('/').where((segment) => segment.isNotEmpty).toList(growable: false);
    final destinations = <_MobileFilesBackDestination>[];

    var accumulatedPath = "";
    for (final segment in folderSegments) {
      accumulatedPath = accumulatedPath.isEmpty ? segment : "$accumulatedPath/$segment";
      destinations.add(_MobileFilesBackDestination(label: segment, path: accumulatedPath));
    }

    final ancestorDestinations = filesLocation.openedFile != null
        ? destinations.reversed.toList(growable: false)
        : destinations.reversed.skip(1).toList(growable: false);

    final isFilesLanding = filesLocation.folder.isEmpty && filesLocation.openedFile == null;
    if (isFilesLanding) {
      return const [];
    }

    return [
      ...ancestorDestinations.map(
        (destination) => AppMenuEntry(
          title: destination.label,
          icon: LucideIcons.folder,
          onPressed: () => _openMobileFilesEntry(context, destination.path, isFolder: true),
        ),
      ),
      AppMenuEntry(title: "Files", icon: LucideIcons.files, onPressed: () => _openMobileFilesEntry(context, "", isFolder: true)),
      AppMenuEntry(title: "Chat", icon: LucideIcons.messageSquareText, separatorBefore: true, onPressed: () => _showChatPane(context)),
    ];
  }

  Widget _buildMobileRoomLeadingAction(BuildContext context, {required bool filesVisible}) {
    final pane = _mobileActivePane(filesVisible: filesVisible);

    if (pane == _MobileRoomPane.chat) {
      final navController = Controller.ofType<NavController>(context);
      return PowerboardsBackIconButton(onPressed: navController.openMobileRoomList, tooltip: "Open rooms", icon: LucideIcons.menu);
    }

    if (pane == _MobileRoomPane.meeting) {
      return PowerboardsBackIconButton(onPressed: () => _closeMobileMeetingLobby(context), tooltip: "Close meet", icon: LucideIcons.x);
    }

    final filesLocation = _mobileFilesLocation(context);
    if (filesLocation.openedFile != null) {
      return Tooltip(
        message: "Close file",
        child: PowerboardsBackIconButton(
          onPressed: () => _navigateBackFromMobileFiles(context),
          tooltip: "Close file",
          icon: LucideIcons.x,
        ),
      );
    }

    final backMenuEntries = _mobileFilesBackMenuEntries(context);

    if (backMenuEntries.isEmpty) {
      return Tooltip(
        message: filesLocation.backTooltip,
        child: PowerboardsBackIconButton(onPressed: () => _navigateBackFromMobileFiles(context), tooltip: filesLocation.backTooltip),
      );
    }

    return AppContextMenuButton(
      compact: true,
      boundaryContext: context,
      entries: backMenuEntries,
      constraints: const BoxConstraints(minWidth: 220),
      childBuilder: (context, controller) => Tooltip(
        message: "${filesLocation.backTooltip}. Press and hold to browse ancestors.",
        child: PowerboardsBackIconButton(
          onPressed: () => _navigateBackFromMobileFiles(context),
          onLongPress: controller.toggle,
          tooltip: filesLocation.backTooltip,
        ),
      ),
    );
  }

  Widget _buildMobileRoomHeader(
    BuildContext context, {
    required Widget leadingAction,
    required Widget title,
    required List<Widget> trailingActions,
    Alignment titleAlignment = Alignment.centerLeft,
  }) {
    return ColoredBox(
      color: _mobileRoomSurfaceColor(context),
      child: SizedBox(
        height: headerHeight,
        child: Padding(
          padding: powerboardsMobileHorizontalPadding,
          child: Row(
            spacing: _mobileRoomHeaderGap,
            children: [
              leadingAction,
              Expanded(
                child: Align(
                  alignment: titleAlignment,
                  child: DefaultTextStyle.merge(overflow: TextOverflow.ellipsis, maxLines: 1, child: title),
                ),
              ),
              ...trailingActions,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileMeetingHeaderTitle(BuildContext context) {
    final controls = _meetingToolbarControls(context, compact: true);
    if (controls.isEmpty) {
      final theme = ShadTheme.of(context);
      return Text("Get ready to meet", style: powerboardsMobileHeaderPrimaryTextStyle(color: theme.colorScheme.foreground));
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, spacing: desktopPaneHeaderButtonGap, children: controls),
      ),
    );
  }

  Widget _buildMobileRoomContextHeaderTitle(
    BuildContext context, {
    required List<ServiceSpec> supported,
    required _MobileChatHeaderContext chatContext,
    required double collapseProgress,
  }) {
    final overlayHeaderScope = PowerboardsMobileOverlayHeaderScope.maybeOf(context);
    final isMinimized = collapseProgress > 0.01;
    final canOpenContextSwitcher = chatContext.canOpenContextSwitcher && !isMinimized;
    VoidCallback? onPressed;
    if (isMinimized) {
      onPressed = overlayHeaderScope?.onRestoreChrome;
    } else if (chatContext.canOpenContextSwitcher) {
      onPressed = () => _showMobileRoomContextSwitcher(context: context, supported: supported, chatContext: chatContext);
    }

    return PowerboardsMobileHeaderTrigger(
      primaryText: chatContext.currentThreadLabel,
      secondaryText: _mobileRoomHeaderName,
      collapseProgress: collapseProgress,
      showChevron: canOpenContextSwitcher,
      textAlign: TextAlign.left,
      onPressed: onPressed,
    );
  }

  Widget _buildMobileFilesContextHeaderTitle(
    BuildContext context, {
    required _MobileFilesLocation filesLocation,
    required double collapseProgress,
  }) {
    final menuEntries = _mobileFilesBackMenuEntries(context);
    final title = PowerboardsMobileHeaderTrigger(
      primaryText: filesLocation.title,
      secondaryText: null,
      collapseProgress: collapseProgress,
      showChevron: menuEntries.isNotEmpty,
      textAlign: TextAlign.left,
    );

    if (menuEntries.isEmpty) {
      return title;
    }

    return AppContextMenuButton(
      compact: true,
      boundaryContext: context,
      entries: menuEntries,
      constraints: const BoxConstraints(minWidth: 220),
      childBuilder: (context, controller) => PowerboardsMobileHeaderTrigger(
        primaryText: filesLocation.title,
        secondaryText: null,
        collapseProgress: collapseProgress,
        showChevron: true,
        textAlign: TextAlign.left,
        onPressed: controller.toggle,
      ),
    );
  }

  List<Widget> _buildMobileEmptyRoomHeaderActions(BuildContext context, {required bool canViewStorageAllowed}) {
    return [
      InviteUserButton(projectId: widget.projectId, roomName: widget.room.roomName!),
      if (isOwner.state.value == true)
        _buildPaneHeaderIconButton(
          context: context,
          tooltip: "Manage agents",
          icon: LucideIcons.blocks,
          onPressed: () async {
            await showManageAgentsSurface(
              context: context,
              room: widget.room,
              projectId: widget.projectId,
              onServiceChanged: () {
                services.refresh();
              },
            );
          },
        )
      else
        RoomOptionsMenu(
          projectId: widget.projectId,
          room: widget.room,
          roomController: controller,
          isOwner: isOwner,
          canViewDeveloperLogs: canViewDeveloperLogs,
          boundaryContext: context,
          showMeetingPaneEntriesInOverflow: true,
          showFilesAction: canViewStorageAllowed,
          showMeetAction: true,
          onShowChat: () => _showChatPane(context),
          onShowFiles: () => _showFilesPane(context),
          onShowMeet: () => _showMeetingPane(context),
        ),
    ];
  }

  List<Widget> _buildMobileRoomHeaderActions(
    BuildContext context, {
    required _MobileRoomPane activePane,
    required bool canViewStorageAllowed,
    _MobileChatHeaderContext? chatContext,
    _MobileFilesLocation? filesLocation,
  }) {
    final hidePrimaryHeaderAction = activePane == _MobileRoomPane.chat && chatContext?.isVoiceOnly == true;
    final useDirectNewThreadAction = activePane == _MobileRoomPane.chat && chatContext != null && !hidePrimaryHeaderAction;
    final useDirectFileShareAction = activePane == _MobileRoomPane.files && filesLocation?.openedFile != null;

    return [
      if (!hidePrimaryHeaderAction)
        _buildPaneHeaderIconButton(
          context: context,
          tooltip: useDirectFileShareAction ? "Share" : (useDirectNewThreadAction ? "New thread" : "Create"),
          icon: useDirectFileShareAction ? LucideIcons.share : (useDirectNewThreadAction ? LucideIcons.squarePen : LucideIcons.plus),
          onPressed: useDirectFileShareAction
              ? () => _filesHeaderController.shareOpenedFileInCurrentLocation()
              : useDirectNewThreadAction
              ? () {
                  _showChatPane(context);
                  _setSelectedThreadPath(chatContext.agentKey, null);
                }
              : () => _showMobileRoomCreateMenu(
                  context: context,
                  activePane: activePane,
                  canViewStorageAllowed: canViewStorageAllowed,
                  chatContext: chatContext,
                ),
        ),
      RoomOptionsMenu(
        projectId: widget.projectId,
        room: widget.room,
        roomController: controller,
        isOwner: isOwner,
        canViewDeveloperLogs: canViewDeveloperLogs,
        boundaryContext: context,
        showMeetingPaneEntriesInOverflow: true,
        showFilesAction: canViewStorageAllowed,
        showMeetAction: true,
        onShowChat: () => _showChatPane(context),
        onShowFiles: () => _showFilesPane(context),
        onShowMeet: () => _showMeetingPane(context),
      ),
    ];
  }

  List<Widget> _buildLegacyMobileMeetingHeaderActions(BuildContext context, {required bool canViewStorageAllowed}) {
    final showMeetingInviteAction = _isMeetingSessionActive(context);

    return [
      if (showMeetingInviteAction) InviteUserButton(projectId: widget.projectId, roomName: widget.room.roomName!),
      RoomOptionsMenu(
        projectId: widget.projectId,
        room: widget.room,
        roomController: controller,
        isOwner: isOwner,
        canViewDeveloperLogs: canViewDeveloperLogs,
        boundaryContext: context,
        showMeetingPaneEntriesInOverflow: true,
        showFilesAction: canViewStorageAllowed,
        showMeetAction: true,
        onShowChat: () => _showChatPane(context),
        onShowFiles: () => _showFilesPane(context),
        onShowMeet: () => _showMeetingPane(context),
      ),
    ];
  }

  Widget _buildMobileRoomScaffold(
    BuildContext context, {
    required Widget leadingAction,
    required Widget title,
    required List<Widget> trailingActions,
    required Widget body,
    List<Widget> bottomActions = const [],
    Alignment titleAlignment = Alignment.centerLeft,
  }) {
    return KeyboardSafe(
      child: ColoredBox(
        color: _mobileRoomSurfaceColor(context),
        child: SafeArea(
          minimum: powerboardsMobileScreenSafeAreaMinimum,
          child: Column(
            children: [
              _buildMobileRoomHeader(
                context,
                leadingAction: leadingAction,
                title: title,
                trailingActions: trailingActions,
                titleAlignment: titleAlignment,
              ),
              Expanded(child: body),
              if (bottomActions.isNotEmpty) ActionsRow(actions: bottomActions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorArea(BuildContext context, String error, List<Widget> actions, {bool embedMobileChrome = true}) {
    final isMobile = _usesMobileRoomLayout(context);

    return Column(
      children: [
        if (!isMobile || embedMobileChrome) ActionsRow(actions: actions),
        if (!isMobile || embedMobileChrome) _buildAgentsActionRow(context),
        Expanded(
          child: Center(child: ShadAlert.destructive(title: Text(error))),
        ),
      ],
    );
  }

  Widget _buildRoomLoading(BuildContext context, {required String title}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            spacing: 10,
            mainAxisSize: MainAxisSize.min,
            children: [
              SweepStatusText(
                text: title,
                style: ShadTheme.of(context).textTheme.p.copyWith(fontWeight: FontWeight.w700),
              ),
              SweepStatusText(text: _lastRoomStatusText, style: ShadTheme.of(context).textTheme.muted),
              SizedBox(height: 2),
              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(key: loadingKey)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadRoomDisplayName() async {
    final roomName = widget.room.roomName?.trim();
    if (roomName == null || roomName.isEmpty) {
      return;
    }

    try {
      final room = await getMeshagentClient().getRoom(name: roomName, projectId: widget.projectId);
      if (!mounted) {
        return;
      }

      final displayName = roomDisplayName(room);
      if (displayName.isEmpty || displayName == _resolvedRoomDisplayName) {
        return;
      }

      setState(() {
        _resolvedRoomDisplayName = displayName;
      });
    } catch (_) {}
  }

  String get _roomDisplayName {
    final displayName = _resolvedRoomDisplayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final roomName = widget.room.roomName?.trim();
    if (roomName == null || roomName.isEmpty) {
      return "Room";
    }

    return roomName;
  }

  String get _mobileRoomHeaderName {
    final roomName = widget.room.roomName?.trim();
    if (roomName == null || roomName.isEmpty) {
      return "Room";
    }

    return roomName;
  }

  Widget _buildEmptyRoomNameDisplay(BuildContext context) {
    final sidetrayScope = DesktopSidetrayToggleScope.maybeOf(context);

    return ShadButton.ghost(
      onPressed: () {
        if (sidetrayScope?.enabled == true && sidetrayScope?.collapsed == true) {
          sidetrayScope!.onExpand();
        }
      },
      child: Text(
        _roomDisplayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
        style: powerboardsSectionTitleStyle(),
      ),
    );
  }

  Widget _buildMobileRoomNameHeaderTitle(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Text(
        _mobileRoomHeaderName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
        style: powerboardsMobileHeaderSecondaryTextStyle(color: theme.colorScheme.mutedForeground.withValues(alpha: 0.82)),
      ),
    );
  }

  List<Widget> _emptyRoomHeaderActions({required bool isMobile}) {
    final useDesktopUiPreview = !isMobile && powerboardsUsesDesktopUiPreview(context);
    if (useDesktopUiPreview) {
      return const [];
    }

    return [
      if (isMobile) BackButton(projectId: widget.projectId),
      if (!isMobile) _buildEmptyRoomNameDisplay(context),
      Spacer(),
      if (!useDesktopUiPreview) InviteUserButton(projectId: widget.projectId, roomName: widget.room.roomName!),
      if (!isMobile) ...[
        if (!useDesktopUiPreview)
          RoomOptionsMenu(
            projectId: widget.projectId,
            room: widget.room,
            roomController: controller,
            isOwner: isOwner,
            canViewDeveloperLogs: canViewDeveloperLogs,
            boundaryContext: context,
          ),
        if (!useDesktopUiPreview) UserAvatarMenuButton(projectId: widget.projectId, projects: widget.projects, boundaryContext: context),
      ],
    ];
  }

  Widget _buildRoomInitializationError(BuildContext context, {required String title, required Object? error}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ShadAlert.destructive(
            title: Text(title),
            description: Text("$error"),
            trailing: ShadButton.outline(
              onPressed: () {
                services.refresh();
                canViewStorage.refresh();
                canViewDeveloperLogs.refresh();
                isOwner.refresh();
              },
              child: Text("Retry"),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShellArea(BuildContext context, ServiceSpec service, List<Widget> actions, {bool embedMobileChrome = true}) {
    final command = service.metadata.annotations["meshagent.service.shell.command"];
    final isMobile = _usesMobileRoomLayout(context);

    return Column(
      children: [
        if (!isMobile || embedMobileChrome) ActionsRow(actions: actions),
        if (!isMobile || embedMobileChrome) _buildDesktopSecondaryControlSpacer(context),
        if (!isMobile || embedMobileChrome) _buildAgentsActionRow(context),
        Expanded(
          child: Builder(
            builder: (context) {
              if (command == null) {
                return Center(child: ShadAlert.destructive(title: Text("Shell agent must have command")));
              }
              return ShellAgent(key: ValueKey(service.id), command: command, room: widget.room, service: service);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatArea(
    BuildContext context,
    String? agentName,
    List<Widget> actions, {
    required String? selectedAgentRouteId,
    bool showEmbeddedThreadList = true,
    ChatThreadDisplayMode threadDisplayMode = ChatThreadDisplayMode.singleThread,
    String? threadListPath,
    String? threadDir,
    String? threadPath,
    String? selectedThreadPath,
    String? selectedThreadDisplayName,
    ValueChanged<String?>? onSelectedThreadPathChanged,
    Widget? emptyState,
    bool hideChatInput = false,
    bool embedMobileChrome = true,
    bool showDesktopThreadListAlternatives = true,
  }) {
    final user = MeshagentAuth.current.getUser();
    final userEmail = user?["email"];
    final cs = ShadTheme.of(context).colorScheme;
    final normalizedThreadPath = threadPath?.trim();
    final documentPath = normalizedThreadPath == null || normalizedThreadPath.isEmpty
        ? getDocumentPath(agentName, threadDir: threadDir)
        : normalizedThreadPath;
    final isMultiThread = threadDisplayMode == ChatThreadDisplayMode.multiThreadComposer;
    final isMobile = _usesMobileRoomLayout(context);
    final chatActions = actions;
    final chatHorizontalInset = isMobile ? 0.0 : desktopPaneChatHorizontalInset;
    final chatBottomInset = isMobile ? 0.0 : desktopPaneBottomInset - 8;
    final resolvedThreadListPath = _resolvedThreadListPath(threadListPath, threadDir: threadDir, agentName: agentName);
    final hasThreadList = isMultiThread && resolvedThreadListPath != null;
    final showThreadRail = !isMobile && showEmbeddedThreadList && hasThreadList;
    final showInlineThreadList = !isMobile && !showEmbeddedThreadList && hasThreadList && showDesktopThreadListAlternatives;
    final showMobileThreadActions = isMobile && isMultiThread;
    final newThreadEmptyStateVerticalOffset = showInlineThreadList
        ? -((desktopPaneSecondaryControlHeight + desktopPaneBottomInset + desktopPaneSecondaryRowContentGap) / 2)
        : 0.0;
    final meetingActiveSingleThreadEmptyState =
        emptyState ??
        (_isMeetingSessionActive(context) && threadDisplayMode == ChatThreadDisplayMode.singleThread
            ? _buildMeetingSingleThreadChatEmptyState("Chat or share files")
            : null);
    final agentKey = selectedAgentRouteId;
    final composerAttachmentPaths = agentKey == null ? const <String>[] : _composerAttachmentPathsByAgentKey[agentKey] ?? const <String>[];
    final composerAttachmentSeedVersion = agentKey == null ? 0 : _composerAttachmentSeedVersionByAgentKey[agentKey] ?? 0;
    final normalizedSelectedThreadDisplayName = selectedThreadDisplayName?.trim();
    final resolvedSelectedThreadDisplayName = normalizedSelectedThreadDisplayName == null || normalizedSelectedThreadDisplayName.isEmpty
        ? null
        : normalizedSelectedThreadDisplayName;
    final currentThreadLabel = selectedThreadPath == null
        ? "New thread"
        : (resolvedSelectedThreadDisplayName ??
              _selectedThreadLabelForAgentKey(agentKey) ??
              defaultThreadDisplayNameFromPath(selectedThreadPath));
    final chatDropOverlayBuilder = !isMobile && powerboardsUsesDesktopUiPreview(context)
        ? (BuildContext context, bool dragging) => PbFilesDropTargetOverlayLayer(
            active: dragging,
            top: 0,
            padding: PbFilesPanelPadding(left: 18, right: 16),
            title: 'Drop files to attach',
            bottom: 24,
          )
        : null;
    final agentChatClient = _agentChatClientFor(agentName);
    final chatView = Padding(
      padding: EdgeInsets.fromLTRB(chatHorizontalInset, 0, chatHorizontalInset, chatBottomInset),
      child: MeshagentThreadView(
        agentName: agentName,
        chatClient: agentChatClient,
        threadDisplayMode: threadDisplayMode,
        threadListPath: resolvedThreadListPath,
        newThreadResetVersion: _newThreadResetVersion,
        client: widget.room,
        documentPath: documentPath,
        selectedThreadPath: selectedThreadPath,
        selectedThreadDisplayName: resolvedSelectedThreadDisplayName ?? _selectedThreadLabelForAgentKey(agentKey),
        onSelectedThreadPathChanged: onSelectedThreadPathChanged,
        onSelectedThreadResolved: (path, displayName) => _setSelectedThreadPath(agentKey, path, displayName: displayName),
        participantNames: [
          if (userEmail is String && userEmail.isNotEmpty) userEmail,
          if (agentName case final String agentParticipantName) agentParticipantName,
        ],
        newThreadEmptyStateVerticalOffset: newThreadEmptyStateVerticalOffset,
        joinMeeting: _joinMeeting,
        emptyState: meetingActiveSingleThreadEmptyState,
        hideChatInput: hideChatInput,
        onConnectAgents: () async {
          await showManageAgentsSurface(context: context, projectId: widget.projectId, room: widget.room);
        },
        onInvite: () async {
          final room = await getMeshagentClient().getRoom(name: widget.room.roomName!, projectId: widget.projectId);
          if (!context.mounted) {
            return;
          }
          await showUpdateRoomPermsDialog(context, projectId: widget.projectId, room: room);
        },
        onOpenFiles: () => _showFilesPane(context),
        onOpenMeet: () => _showMeetingPane(context),
        onThreadAttachmentsChanged: _recordLocalThreadAttachments,
        composerAttachmentPaths: composerAttachmentPaths,
        composerAttachmentSeedVersion: composerAttachmentSeedVersion,
        onComposerAttachmentSeedCleared: agentKey == null ? null : () => _clearComposerAttachmentSeed(agentKey),
        onComposerAttachmentOpen: !isMobile && powerboardsUsesDesktopUiPreview(context)
            ? (path) => _openDesktopPreviewAttachment(path, threadName: currentThreadLabel, fromComposerAttachment: true)
            : null,
        onComposerAttachmentRemoved: !isMobile && powerboardsUsesDesktopUiPreview(context)
            ? _closeDesktopPreviewAttachmentPreviewIfRemoved
            : null,
        onThreadAttachmentOpen: !isMobile && powerboardsUsesDesktopUiPreview(context)
            ? (path) {
                final effectiveThreadPath = selectedThreadPath ?? documentPath;
                final effectiveThreadName = currentThreadLabel == 'New thread'
                    ? defaultThreadDisplayNameFromPath(effectiveThreadPath)
                    : currentThreadLabel;
                _recordLocalThreadAttachments(
                  threadPath: effectiveThreadPath,
                  threadName: effectiveThreadName,
                  createdBy: userEmail is String ? userEmail : '',
                  attachmentPaths: [path],
                );
                _openDesktopPreviewAttachment(path, threadName: effectiveThreadName);
              }
            : null,
        fileDropOverlayBuilder: chatDropOverlayBuilder,
        projectId: widget.projectId,
      ),
    );

    return ColoredBox(
      color: isMobile ? cs.card : Colors.transparent,
      child: Column(
        children: [
          if ((showMobileThreadActions || showInlineThreadList) && selectedThreadPath != null && resolvedThreadListPath != null)
            _MobileSelectedThreadLabelResolver(
              key: ValueKey("mobile-thread-label-$agentKey-$selectedThreadPath"),
              client: widget.room,
              agentName: agentName,
              threadListPath: resolvedThreadListPath,
              selectedThreadPath: selectedThreadPath,
              onResolved: (displayName) => _setSelectedThreadPath(agentKey, selectedThreadPath, displayName: displayName),
            ),
          if (!isMobile || embedMobileChrome) ...[
            ActionsRow(actions: chatActions),
            _buildDesktopChatViewportCutoffSpacer(context),
            _buildAgentsActionRow(context),
          ],
          Expanded(
            child: showThreadRail
                ? _buildDesktopChatWithThreadRail(
                    context,
                    chatView: chatView,
                    threadListPath: resolvedThreadListPath,
                    agentKey: agentKey,
                    agentName: agentName,
                  )
                : showInlineThreadList
                ? _buildDesktopChatWithInlineThreadList(
                    context,
                    chatView: chatView,
                    threadListPath: resolvedThreadListPath,
                    agentKey: agentKey,
                    currentThreadLabel: currentThreadLabel,
                    horizontalInset: chatHorizontalInset,
                  )
                : chatView,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDesktopChatWithThreadRail(
    BuildContext context, {
    required Widget chatView,
    required String threadListPath,
    required String? agentKey,
    required String? agentName,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        if (!totalWidth.isFinite || totalWidth < 700) {
          return chatView;
        }

        final railMaxWidth = math.min(360.0, math.max(260.0, totalWidth - 440.0));
        final railWidth = (totalWidth * 0.28).clamp(260.0, railMaxWidth).toDouble();

        return Row(
          children: [
            Expanded(child: chatView),
            SizedBox(
              width: railWidth,
              child: _buildDesktopThreadRail(context, threadListPath: threadListPath, agentKey: agentKey, agentName: agentName),
            ),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildDesktopChatWithInlineThreadList(
    BuildContext context, {
    required Widget chatView,
    required String threadListPath,
    required String? agentKey,
    required String currentThreadLabel,
    required double horizontalInset,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: constraints.maxWidth,
                child: _buildDesktopInlineThreadList(
                  context,
                  agentKey: agentKey,
                  currentThreadLabel: currentThreadLabel,
                  horizontalInset: horizontalInset,
                ),
              ),
            ),
            const SizedBox(height: desktopPaneSecondaryRowContentGap),
            Expanded(child: chatView),
          ],
        );
      },
    );
  }

  Widget _buildVoiceArea(BuildContext context, String agentName, List<Widget> actions, {bool embedMobileChrome = true}) {
    final meetingSessionActive = _isMeetingSessionActive(context);
    final isMobile = _usesMobileRoomLayout(context);
    final useDesktopUiPreview = !isMobile && powerboardsUsesDesktopUiPreview(context);
    final showVoiceChrome = embedMobileChrome;

    return Column(
      children: [
        if (showVoiceChrome) ActionsRow(actions: actions),
        if (showVoiceChrome) _buildDesktopChatViewportCutoffSpacer(context),
        if (showVoiceChrome) _buildAgentsActionRow(context),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => WaitForAgentParticipantBuilder(
              key: ValueKey(agentName),
              room: widget.room,
              agentName: agentName,
              builder: (context, participant) => Column(
                children: [
                  Expanded(
                    child: participant == null
                        ? const Center(child: ShadButton(child: Text("Start Voice Session")))
                        : (isMobile
                              ? Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 500),
                                    child: SizedBox(
                                      height: constraints.maxHeight,
                                      child: VoiceAgentCaller(
                                        meeting: MeetingController.of(context),
                                        participant: participant,
                                        showDisconnectedAction: !meetingSessionActive,
                                        allowToggleTranscribe: !meetingSessionActive,
                                        emptyStateTitle: meetingSessionActive ? "This voice agent is private" : "Start an audio session",
                                        emptyStateDescription: meetingSessionActive
                                            ? "Start an audio session after this meeting to ask questions, or get hands free help."
                                            : "Connect with this agent using your microphone.",
                                        emptyStateAvailableWidth: constraints.maxWidth,
                                        pinActionToMobileFooter: true,
                                        connectedControlsBuilder: (context, meeting) => VoiceMeetingControls(controller: meeting),
                                      ),
                                    ),
                                  ),
                                )
                              : (useDesktopUiPreview
                                    ? SizedBox.expand(
                                        child: VoiceAgentCaller(
                                          meeting: MeetingController.of(context),
                                          participant: participant,
                                          showDisconnectedAction: !meetingSessionActive,
                                          allowToggleTranscribe: !meetingSessionActive,
                                          emptyStateTitle: meetingSessionActive ? "This voice agent is private" : "Start an audio session",
                                          emptyStateDescription: meetingSessionActive
                                              ? "Start an audio session after this meeting to ask questions, or get hands free help."
                                              : "Connect with this agent using your microphone.",
                                          emptyStateAvailableWidth: constraints.maxWidth,
                                          disconnectedEmptyStateBuilder: _buildDesktopV1VoiceSessionEmptyState,
                                          onSessionStarted: _showDesktopV1VoiceSessionStartedToast,
                                          connectedContentAlignment: const Alignment(0, -0.18),
                                          connectedControlsBuilder: (context, meeting) =>
                                              VoiceMeetingControls(controller: meeting, showHelperText: false),
                                        ),
                                      )
                                    : Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 560),
                                          child: VoiceAgentCaller(
                                            meeting: MeetingController.of(context),
                                            participant: participant,
                                            showDisconnectedAction: !meetingSessionActive,
                                            allowToggleTranscribe: !meetingSessionActive,
                                            emptyStateTitle: meetingSessionActive
                                                ? "This voice agent is private"
                                                : "Start an audio session",
                                            emptyStateDescription: meetingSessionActive
                                                ? "Start an audio session after this meeting to ask questions, or get hands free help."
                                                : "Connect with this agent using your microphone.",
                                            emptyStateAvailableWidth: constraints.maxWidth,
                                            connectedControlsBuilder: (context, meeting) => VoiceMeetingControls(controller: meeting),
                                            connectedVisualizationStyle: AudioWaveStyle.legacy,
                                          ),
                                        ),
                                      ))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopV1VoiceSessionEmptyState(BuildContext context, VoiceAgentDisconnectedState state) {
    return PbVoiceSessionEmptyState(
      title: state.title,
      subtitle: state.description,
      transcribe: state.transcribe,
      showStartSessionButton: state.showDisconnectedAction,
      showTranscribeToggle: state.allowToggleTranscribe && state.onTranscribeChanged != null,
      onStartSessionPressed: () => unawaited(state.onStartSessionPressed()),
      onTranscribeChanged: state.onTranscribeChanged,
    );
  }

  Future<void> _showDesktopV1VoiceSessionStartedToast(BuildContext context) async {
    final toaster = ShadToaster.maybeOf(context);
    if (toaster == null) {
      return;
    }

    toaster.show(
      powerboardsWidgetToast(
        title: const Text(VoiceMeetingControls.helperTitle),
        description: const Text(VoiceMeetingControls.helperDescription),
        duration: _voiceSessionInstructionToastDuration,
      ),
    );
  }

  Widget _buildMeetingTranscriberArea(BuildContext context, String agentName, List<Widget> actions, {bool embedMobileChrome = true}) {
    final meetingIsActive = _isMeetingSessionActive(context);
    final isMobile = _usesMobileRoomLayout(context);

    Widget startMeetingAction() {
      return ShadButton(
        onPressed: () {
          _joinMeeting();
        },
        child: const Text("Start Meeting"),
      );
    }

    return WaitForAgentParticipantBuilder(
      key: ValueKey(agentName),
      room: widget.room,
      agentName: agentName,
      builder: (context, participant) => Column(
        children: [
          if (!isMobile || embedMobileChrome) ActionsRow(actions: actions),
          if (!isMobile || embedMobileChrome) _buildDesktopPaneContentSpacer(context),
          if (!isMobile || embedMobileChrome) _buildAgentsActionRow(context),
          Expanded(
            child: participant == null
                ? _buildRoomLoading(context, title: "Waiting for transcriber agent to join room")
                : controller.inMeeting
                ? _buildChatArea(
                    context,
                    null,
                    [],
                    selectedAgentRouteId: null,
                    emptyState: !meetingIsActive
                        ? _buildMeetingTranscriberPreMeetingChatEmptyState()
                        : _buildMeetingTranscriberTitleOnlyEmptyState("Transcribe your meeting"),
                    hideChatInput: true,
                    embedMobileChrome: embedMobileChrome,
                  )
                : _buildAudioAgentEmptyState(
                    title: "Transcribe your meeting",
                    description: "Meet with this agent and include your team.",
                    action: isMobile && meetingIsActive ? null : startMeetingAction(),
                    verticalOffset: AudioAgentEmptyState.defaultVerticalOffset - 20,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesArea(
    BuildContext context,
    List<Widget> actions, {
    bool embedMobileChrome = true,
    bool showDesktopSidetrayToggle = true,
  }) {
    final cs = ShadTheme.of(context).colorScheme;
    final isMobile = _usesMobileRoomLayout(context);
    final usesDesktopUiPreview = !isMobile && powerboardsUsesDesktopUiPreview(context);
    final mobileFilesLocation = isMobile ? _mobileFilesLocation(context) : null;
    final hasOpenedFile = mobileFilesLocation?.openedFile != null;
    final horizontalInset = isMobile || usesDesktopUiPreview ? 0.0 : 20.0;
    final topInset = 0.0;
    final bottomInset = isMobile
        ? (hasOpenedFile ? 0.0 : 8.0)
        : usesDesktopUiPreview
        ? 0.0
        : desktopPaneBottomInset;
    final meetingSessionActive = _isMeetingSessionActive(context);

    return ColoredBox(
      color: isMobile ? cs.card : cs.background,
      child: Column(
        children: [
          if (isMobile && embedMobileChrome) ActionsRow(actions: actions),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalInset, topInset, horizontalInset, bottomInset),
              child: FileManagerView(
                client: widget.room,
                projectId: widget.projectId,
                services: services,
                hideSystem: true,
                mobileShellOwnsHeader: isMobile && !embedMobileChrome,
                showDesktopSidetrayToggle: showDesktopSidetrayToggle,
                controller: _filesHeaderController,
                desktopHeaderLeadingActions: isMobile || !meetingSessionActive ? const [] : _meetingHeaderPrimaryControls(context),
                desktopHeaderActions: isMobile ? const [] : actions,
                desktopHeaderActionLeadingWidthFloor: meetingSessionActive ? _meetingActivePaneActionLeadingWidthFloor : 0,
                desktopHeaderActionMinimumLeadingWidth: meetingSessionActive ? 160 : 0,
                desktopHeaderActionReserve: meetingSessionActive ? desktopPaneHeaderActionReserve + 32 : desktopPaneHeaderActionReserve,
                v1RoomPanelCollapsed: usesDesktopUiPreview ? _desktopPreviewRoomPanelCollapsed : null,
                onV1RoomPanelCollapsedChanged: usesDesktopUiPreview ? _setDesktopPreviewRoomPanelCollapsed : null,
                v1RoomPanelWidth: usesDesktopUiPreview ? _desktopPreviewRoomPanelWidth : null,
                onV1RoomPanelWidthChanged: usesDesktopUiPreview ? _setDesktopPreviewRoomPanelWidth : null,
                onV1FilePromptRequested: usesDesktopUiPreview
                    ? (action, filePath, {required responsiveHandoff}) => _handleDesktopPreviewFilePromptRequested(
                        context,
                        action: action,
                        filePath: filePath,
                        responsiveHandoff: responsiveHandoff,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _desktopPreviewMeetTranscriptSortDate(StorageEntry entry) {
    return _desktopPreviewTranscriptSortDate(entry);
  }

  PbAttachmentListItemData _desktopPreviewMeetTranscriptItem(StorageEntry entry) {
    return _desktopPreviewTranscriptItem(path: joinPaths(_meetingTranscriptFolder, entry.name), fileName: entry.name);
  }

  Future<List<PbAttachmentListItemData>> _loadDesktopPreviewMeetTranscripts() async {
    final entries = await widget.room.storage.list(_meetingTranscriptFolder);
    final records = <_DesktopPreviewTranscriptRecord>[
      for (final entry in entries)
        if (!entry.isFolder)
          _DesktopPreviewTranscriptRecord(
            data: _desktopPreviewMeetTranscriptItem(entry),
            sortDate: _desktopPreviewMeetTranscriptSortDate(entry),
          ),
    ];

    return _selectDesktopPreviewRecentTranscripts(records);
  }

  bool _desktopPreviewMeetRootEntryIsRoomFileContent(StorageEntry entry) {
    final name = entry.name.trim();
    return name.isNotEmpty && !name.startsWith('.') && name != 'transcripts';
  }

  Future<_DesktopPreviewMeetPaneData> _loadDesktopPreviewMeetPaneData() async {
    final transcriptsFuture = _loadDesktopPreviewMeetTranscripts();
    final rootEntriesFuture = widget.room.storage.list('');
    final transcripts = await transcriptsFuture;
    final rootEntries = await rootEntriesFuture;

    return _DesktopPreviewMeetPaneData(
      transcripts: transcripts,
      roomHasStoredFiles: rootEntries.any(_desktopPreviewMeetRootEntryIsRoomFileContent),
    );
  }

  void _setDesktopPreviewMeetTranscriptPreviewFullscreen(bool fullscreen, {bool closeOverlay = false}) {
    if (fullscreen && closeOverlay) {
      _desktopPreviewRoomPanelOverlayController.hide();
    }

    setState(() {
      _desktopPreviewMeetTranscriptPreviewFullscreen = fullscreen;
      if (fullscreen && closeOverlay) {
        _desktopPreviewRestoreTranscriptOverlayOnPreviewClose = true;
        _desktopPreviewRoomPanelOverlayOpen = false;
      } else if (!fullscreen && _desktopPreviewMeetTranscriptPreviewOpen) {
        _desktopPreviewRoomPanelOverlayOpen = true;
      }
    });
    setPreviewFilePreviewFullscreen(fullscreen);
  }

  void _setDesktopPreviewMeetingFullscreen(bool fullscreen) {
    if (_desktopPreviewMeetingFullscreen == fullscreen) {
      return;
    }

    setState(() => _desktopPreviewMeetingFullscreen = fullscreen);
    setPreviewFilePreviewFullscreen(fullscreen);
  }

  Widget? _buildDesktopPreviewMeetingControls(BuildContext context, {required double availableWidth}) {
    final compact = availableWidth < _desktopPreviewMeetingToolbarCompactThreshold;
    final controls = _meetingToolbarControls(context, compact: compact);
    if (controls.isEmpty) {
      return null;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, spacing: desktopPaneHeaderButtonGap, children: controls),
    );
  }

  Widget _buildDesktopPreviewMeeting(BuildContext context, String? agentName, {required bool roomPanelContentAvailable}) {
    final meetingSessionActive = _isMeetingSessionActive(context);

    return ColoredBox(
      color: PbColors.surfacePanelWash,
      child: FutureBuilder<_DesktopPreviewMeetPaneData>(
        future: _loadDesktopPreviewMeetPaneData(),
        builder: (context, snapshot) {
          final paneData = snapshot.data;
          final transcripts = paneData?.transcripts ?? const <PbAttachmentListItemData>[];
          final transcriptPreviewFile = _desktopPreviewMeetTranscriptPreviewFile;
          final transcriptSidePaneAvailable =
              !meetingSessionActive &&
              (roomPanelContentAvailable ||
                  paneData?.roomHasStoredFiles == true ||
                  transcripts.isNotEmpty ||
                  transcriptPreviewFile != null);
          final transcriptPreviewOpen = transcriptSidePaneAvailable && _desktopPreviewMeetTranscriptPreviewOpen;
          final transcriptPreviewFullscreen = transcriptSidePaneAvailable && _desktopPreviewMeetTranscriptPreviewFullscreen;
          final meetingFullscreen = meetingSessionActive && _desktopPreviewMeetingFullscreen;

          if (!transcriptSidePaneAvailable &&
              (_desktopPreviewMeetTranscriptPreviewOpen ||
                  _desktopPreviewMeetTranscriptPreviewFile != null ||
                  _desktopPreviewMeetTranscriptPreviewFullscreen)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }

              if (_desktopPreviewRoomPanelOverlayController.isShowing) {
                _desktopPreviewRoomPanelOverlayController.hide();
              }

              setState(() {
                _desktopPreviewMeetTranscriptPreviewOpen = false;
                _desktopPreviewMeetTranscriptPreviewFile = null;
                _desktopPreviewMeetTranscriptPreviewFullscreen = false;
                _desktopPreviewRestoreTranscriptOverlayOnPreviewClose = false;
                _desktopPreviewRoomPanelOverlayOpen = false;
              });
              setPreviewFilePreviewFullscreen(false);
            });
          }

          if (!meetingSessionActive && _desktopPreviewMeetingFullscreen) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }

              setState(() => _desktopPreviewMeetingFullscreen = false);
              setPreviewFilePreviewFullscreen(false);
            });
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final responsivePanel = constraints.maxWidth <= pbRoomPanelStackBreakpoint && !transcriptPreviewFullscreen;
              final responsiveOverlayMobile = constraints.maxWidth <= pbShellMobileBreakpoint;
              final roomPanelCollapsed = !transcriptSidePaneAvailable || _desktopPreviewRoomPanelCollapsed;
              final roomPanelExpanded = responsivePanel ? false : !roomPanelCollapsed;

              final mainPanel = Column(
                children: [
                  PbMeetHeader(
                    roomPanelExpanded: roomPanelExpanded,
                    showRoomPanelControls: transcriptSidePaneAvailable,
                    meetingFullscreen: meetingFullscreen,
                    onMeetingFullscreenToggle: meetingSessionActive ? () => _setDesktopPreviewMeetingFullscreen(!meetingFullscreen) : null,
                    onRoomPanelToggle: () {
                      if (!transcriptSidePaneAvailable) {
                        return;
                      }

                      setState(() {
                        if (responsivePanel) {
                          _desktopPreviewRoomPanelOverlayOpen = true;
                        } else {
                          _desktopPreviewRoomPanelCollapsed = !roomPanelCollapsed;
                        }
                      });
                    },
                    onOpenTranscripts: () {
                      if (!transcriptSidePaneAvailable) {
                        return;
                      }

                      setState(() {
                        if (responsivePanel) {
                          _desktopPreviewRoomPanelOverlayOpen = true;
                        } else {
                          _desktopPreviewRoomPanelCollapsed = false;
                        }
                      });
                    },
                    controls: meetingSessionActive
                        ? _buildDesktopPreviewMeetingControls(context, availableWidth: constraints.maxWidth)
                        : null,
                  ),
                  Expanded(
                    child: MeetingView(
                      key: meetingViewKey,
                      room: widget.room,
                      onCancel: _leaveMeeting,
                      joinMeeting: _joinMeeting,
                      agentName: agentName,
                    ),
                  ),
                ],
              );

              if (meetingSessionActive) {
                if (_desktopPreviewRoomPanelOverlayOpen || _desktopPreviewRoomPanelOverlayController.isShowing) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) {
                      return;
                    }

                    if (_desktopPreviewRoomPanelOverlayController.isShowing) {
                      _desktopPreviewRoomPanelOverlayController.hide();
                    }
                    setState(() => _desktopPreviewRoomPanelOverlayOpen = false);
                  });
                }

                return mainPanel;
              }

              PbMeetTranscriptPanel buildTranscriptPanel({bool responsiveOverlay = false, bool resizing = false}) {
                return PbMeetTranscriptPanel(
                  transcripts: transcripts,
                  emptyTranscripts: transcripts.isEmpty,
                  initialPreviewFile: transcriptPreviewFile,
                  initialFilePreviewOpen: transcriptPreviewOpen,
                  openFilePreviewAsFullscreen: transcriptPreviewFullscreen || (responsiveOverlay && responsiveOverlayMobile),
                  filePreviewBuilder: _buildAttachmentPreviewFallbackContent,
                  filePreviewSourceBuilder: _buildAttachmentPreviewSource,
                  onAskFileAgent: (file) => unawaited(_startDefaultAttachmentFilePrompt(file, responsiveHandoff: responsiveOverlay)),
                  onShareFile: supportsNativeFileShare ? (file) => unawaited(_shareAttachmentFile(file)) : null,
                  onDownloadFile: (file) => unawaited(_downloadAttachmentFile(file)),
                  onFilePreviewSelected: (file) {
                    setState(() => _desktopPreviewMeetTranscriptPreviewFile = file);
                  },
                  onFilePreviewOpenChanged: (open) {
                    final restoreTranscriptOverlay = _desktopPreviewRestoreTranscriptOverlayOnPreviewClose;
                    setState(() {
                      _desktopPreviewMeetTranscriptPreviewOpen = open;
                      if (!open) {
                        _desktopPreviewMeetTranscriptPreviewFile = null;
                        _desktopPreviewMeetTranscriptPreviewFullscreen = false;
                        _desktopPreviewRestoreTranscriptOverlayOnPreviewClose = false;
                        if (restoreTranscriptOverlay) {
                          _desktopPreviewRoomPanelOverlayOpen = true;
                        }
                      }
                    });
                    if (!open) {
                      setPreviewFilePreviewFullscreen(false);
                    }
                  },
                  onFilePreviewFullscreenChanged: (fullscreen) {
                    _setDesktopPreviewMeetTranscriptPreviewFullscreen(fullscreen, closeOverlay: responsiveOverlay);
                  },
                  filePreviewResizing: resizing,
                  borderOnTop: responsiveOverlay,
                  responsiveOverlay: responsiveOverlay,
                  responsiveOverlayMobile: responsiveOverlayMobile,
                  onResponsiveOverlayClose: _closeDesktopPreviewRoomPanelOverlay,
                );
              }

              if (responsivePanel) {
                if (!transcriptSidePaneAvailable && _desktopPreviewRoomPanelOverlayOpen) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _closeDesktopPreviewRoomPanelOverlay();
                    }
                  });
                } else if (_desktopPreviewRoomPanelOverlayOpen) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _desktopPreviewRoomPanelOverlayController.show();
                    }
                  });
                }

                return OverlayPortal(
                  controller: _desktopPreviewRoomPanelOverlayController,
                  overlayChildBuilder: (context) => Positioned.fill(
                    child: transcriptSidePaneAvailable ? buildTranscriptPanel(responsiveOverlay: true) : const SizedBox.shrink(),
                  ),
                  child: mainPanel,
                );
              }

              if (_desktopPreviewRoomPanelOverlayOpen ||
                  !transcriptSidePaneAvailable && _desktopPreviewRoomPanelOverlayController.isShowing) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    if (_desktopPreviewRoomPanelOverlayController.isShowing) {
                      _desktopPreviewRoomPanelOverlayController.hide();
                    }
                    setState(() => _desktopPreviewRoomPanelOverlayOpen = false);
                  }
                });
              }

              return PbRoomPanelMount(
                activeTab: PbRoomPanelTab.files,
                filePreviewOpen: transcriptPreviewOpen,
                filePreviewFullscreen: transcriptPreviewFullscreen,
                roomPanelCollapsed: roomPanelCollapsed,
                panelWidth: _desktopPreviewRoomPanelWidth,
                onPanelWidthChanged: _setDesktopPreviewRoomPanelWidth,
                threadPanel: mainPanel,
                roomPanelBuilder: (context, resizing) =>
                    transcriptSidePaneAvailable ? buildTranscriptPanel(resizing: resizing) : const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMeeting(
    BuildContext context,
    String? agentName,
    List<Widget> actions, {
    bool embedMobileChrome = true,
    bool showDesktopSidetrayToggle = true,
    bool desktopPreviewRoomPanelContentAvailable = false,
  }) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;

    final isMobile = _usesMobileRoomLayout(context);
    final meetingIsActive = _isMeetingSessionActive(context);

    if (!isMobile && powerboardsUsesDesktopUiPreview(context)) {
      return _buildDesktopPreviewMeeting(context, agentName, roomPanelContentAvailable: desktopPreviewRoomPanelContentAvailable);
    }

    return ColoredBox(
      color: isMobile ? cs.card : cs.background,
      child: Column(
        children: [
          if (isMobile)
            if (embedMobileChrome) ActionsRow(actions: actions) else const SizedBox.shrink()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final sidetrayScope = DesktopSidetrayToggleScope.maybeOf(context);
                final sidetrayOpenButton = showDesktopSidetrayToggle && sidetrayScope?.enabled == true && sidetrayScope?.collapsed == true
                    ? DesktopSidetrayToggleButton(collapsed: true, onPressed: sidetrayScope!.onExpand)
                    : null;
                final usesDesktopUiPreview = powerboardsUsesDesktopUiPreview(context);
                if (!meetingIsActive && usesDesktopUiPreview && sidetrayOpenButton == null && actions.isEmpty) {
                  return const SizedBox.shrink();
                }

                final sidetrayLeadingWidth = sidetrayOpenButton == null
                    ? 0.0
                    : (desktopPaneHeaderCompactButtonWidth + desktopPaneHeaderButtonGap);
                final leadingWidth =
                    (meetingIsActive
                        ? _measureActiveMeetingHeaderWidth(constraints.maxWidth)
                        : _measureMeetingHeaderTitleWidth(context, constraints.maxWidth)) +
                    sidetrayLeadingWidth;
                final localActionState = resolvePaneHeaderActionState(
                  constraints,
                  leadingWidth: leadingWidth,
                  minimumLeadingWidth: (meetingIsActive ? _meetingToolbarPreferredCompactWidth : 120) + sidetrayLeadingWidth,
                  reserve: meetingIsActive ? desktopPaneHeaderActionReserve + 32 : desktopPaneHeaderActionReserve,
                  actions: actions,
                  preferCompactBeforeOverflow: meetingIsActive,
                );
                final actionState = localActionState;
                final visibleActions = visiblePaneHeaderActions(actions, overflowCollapsed: actionState.overflowCollapsed);
                return CompactHeaderActions(
                  state: actionState,
                  child: SizedBox(
                    height: headerHeight,
                    child: meetingIsActive
                        ? Center(
                            child: SizedBox(
                              height: desktopPaneHeaderContentHeight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  spacing: desktopPaneHeaderButtonGap,
                                  children: [
                                    ?sidetrayOpenButton,
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, toolbarConstraints) {
                                          final compactControls = toolbarConstraints.maxWidth < _meetingToolbarCompactThreshold;
                                          return SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              spacing: desktopPaneHeaderButtonGap,
                                              children: _meetingToolbarControls(context, compact: compactControls),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    if (visibleActions.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          spacing: desktopPaneHeaderButtonGap,
                                          children: visibleActions,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: SizedBox(
                              height: desktopPaneHeaderContentHeight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  spacing: desktopPaneHeaderButtonGap,
                                  children: [
                                    ?sidetrayOpenButton,
                                    if (!usesDesktopUiPreview)
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            "Get ready to meet",
                                            style: meetingHeaderTitleStyle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                    else
                                      const Spacer(),
                                    if (visibleActions.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          spacing: desktopPaneHeaderButtonGap,
                                          children: visibleActions,
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
            ),
          Expanded(
            child: MeetingView(
              key: meetingViewKey,
              room: widget.room,
              onCancel: _leaveMeeting,
              joinMeeting: _joinMeeting,
              agentName: agentName,
            ),
          ),
        ],
      ),
    );
  }

  String _desktopPreviewAgentIconAssetForService(ServiceSpec service) {
    final type = _serviceType(service);
    return switch (type) {
      'VoiceBot' => 'audio-lines',
      'Shell' => 'terminal',
      _ => 'bot',
    };
  }

  AgentRuntimeStatus _desktopPreviewAgentRuntimeStatusForService(ServiceSpec service) {
    if (!hasMessagingParticipant(service)) {
      return AgentRuntimeStatus.running;
    }

    final identity = _serviceAgentName(service);
    if (identity == null) {
      return AgentRuntimeStatus.notRunning;
    }

    final participant = widget.room.messaging.remoteParticipants.firstWhereOrNull(
      (candidate) => candidate.getAttribute("name") == identity,
    );
    return participant == null ? AgentRuntimeStatus.notRunning : AgentRuntimeStatus.running;
  }

  String _desktopPreviewAgentStatusText(AgentRuntimeStatus status) {
    return switch (status) {
      AgentRuntimeStatus.running => 'Available',
      AgentRuntimeStatus.pulling => 'Downloading',
      AgentRuntimeStatus.notRunning => 'Initializing',
      AgentRuntimeStatus.error => 'Error',
      AgentRuntimeStatus.invalid => 'Invalid',
      AgentRuntimeStatus.unknown => 'Unknown',
    };
  }

  PbAgentStatusTone _desktopPreviewAgentStatusTone(AgentRuntimeStatus status) {
    return switch (status) {
      AgentRuntimeStatus.running => PbAgentStatusTone.online,
      AgentRuntimeStatus.pulling => PbAgentStatusTone.amber,
      AgentRuntimeStatus.notRunning => PbAgentStatusTone.gray,
      AgentRuntimeStatus.error || AgentRuntimeStatus.invalid || AgentRuntimeStatus.unknown => PbAgentStatusTone.error,
    };
  }

  PbAgentListItemData _desktopPreviewAgentItemForService(ServiceSpec service, _ResolvedAgentSelection selected) {
    final status = _desktopPreviewAgentRuntimeStatusForService(service);
    return PbAgentListItemData(
      id: _serviceId(service),
      title: service.agents.firstOrNull?.name ?? service.metadata.name,
      status: _desktopPreviewAgentStatusText(status),
      icon: _desktopPreviewAgentIconAssetForService(service),
      statusTone: _desktopPreviewAgentStatusTone(status),
      selected: selected.service == service,
    );
  }

  List<PbAgentListItemData> _desktopPreviewAgentItems(List<ServiceSpec> supported, _ResolvedAgentSelection selected) {
    final services = supported.where((service) => hasAgentMetadata(service) && _serviceType(service) != 'MeetingTranscriber').toList();
    services.sort((a, b) => a.metadata.name.toLowerCase().compareTo(b.metadata.name.toLowerCase()));
    final developmentParticipants = _developmentParticipants(supported);
    return [
      for (final service in services) _desktopPreviewAgentItemForService(service, selected),
      for (final participant in developmentParticipants)
        if (participantDisplayName(participant) case final String name)
          PbAgentListItemData(
            id: developmentAgentRouteId(name),
            title: name,
            status: 'Available',
            icon: _developmentAgentIcon(participant) == LucideIcons.audioWaveform ? 'audio-lines' : 'bot',
            statusTone: PbAgentStatusTone.online,
            selected: selected.developmentParticipant == participant,
          ),
    ];
  }

  String? _desktopPreviewSelectedThreadDisplayName(_MobileChatHeaderContext? chatContext, List<_DesktopPreviewThreadEntry> threads) {
    final selectedThreadPath = chatContext?.selectedThreadPath;
    if (selectedThreadPath == null) {
      return null;
    }

    for (final thread in threads) {
      if (thread.path == selectedThreadPath) {
        return thread.name;
      }
    }

    return _selectedThreadLabelForAgentKey(chatContext?.agentKey);
  }

  String _desktopPreviewSelectedThreadTitle(
    _MobileChatHeaderContext? chatContext,
    List<_DesktopPreviewThreadEntry> threads, {
    required bool threadListLoaded,
  }) {
    final selectedThreadPath = chatContext?.selectedThreadPath;
    final currentThreadLabelTrusted = selectedThreadPath != null && _selectedThreadLabelForAgentKey(chatContext?.agentKey) != null;

    return powerboardsDesktopPreviewSelectedThreadTitleForVisibleThreads(
      selectedThreadPath: selectedThreadPath,
      currentThreadLabel: chatContext?.currentThreadLabel,
      currentThreadLabelTrusted: currentThreadLabelTrusted,
      threadNamesByPath: {for (final thread in threads) thread.path: thread.name},
      threadListLoaded: threadListLoaded,
    );
  }

  _MobileChatHeaderContext? _desktopPreviewChatContextForVisibleThreads(
    _MobileChatHeaderContext? chatContext,
    List<_DesktopPreviewThreadEntry> threads, {
    required bool threadListLoaded,
  }) {
    return chatContext;
  }

  void _syncDesktopPreviewVisibleThreadSelection(_MobileChatHeaderContext? chatContext, String selectedThreadTitle) {
    final agentKey = chatContext?.agentKey;
    final selectedThreadPath = chatContext?.selectedThreadPath;
    if (agentKey == null || selectedThreadPath == null) {
      return;
    }

    final normalizedTitle = selectedThreadTitle.trim();
    final resolvedTitle = normalizedTitle.isEmpty ? null : normalizedTitle;
    if (_selectedThreadPathByAgentKey[agentKey] == selectedThreadPath &&
        (resolvedTitle == null || _selectedThreadLabelByAgentKey[agentKey] == resolvedTitle)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (_selectedThreadPathByAgentKey[agentKey] == selectedThreadPath &&
          (resolvedTitle == null || _selectedThreadLabelByAgentKey[agentKey] == resolvedTitle)) {
        return;
      }

      _setSelectedThreadPath(agentKey, selectedThreadPath, displayName: resolvedTitle);
    });
  }

  void _selectDesktopPreviewThread(_MobileChatHeaderContext? chatContext, String? path, {String? displayName}) {
    final agentKey = chatContext?.agentKey;
    if (agentKey == null) {
      return;
    }

    _setSelectedThreadPath(agentKey, path, displayName: displayName);
  }

  Future<void> _renameDesktopPreviewThread(_DesktopPreviewThreadEntry entry) async {
    final newName = await showRenameRoomDialog(
      context,
      title: "Rename thread",
      description: "Choose a clear name for this conversation.",
      initialValue: entry.name,
      label: "Name",
      placeholder: "e.g. Sprint planning",
    );
    if (!mounted || newName == null) {
      return;
    }

    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == entry.name) {
      return;
    }

    try {
      await entry.storage.renameThread(entry.path, trimmed);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ShadToaster.of(context).show(powerboardsToast(title: "Unable to rename thread", description: "$error", destructive: true));
    }
  }

  Future<void> _deleteDesktopPreviewThread(_MobileChatHeaderContext? chatContext, _DesktopPreviewThreadEntry entry) async {
    final confirmed =
        await showDeleteRoomDialog(
          context,
          title: "Delete thread",
          description: "Are you sure you want to delete \"${entry.name}\"? This cannot be undone.",
          confirmText: "Delete",
          destructive: true,
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }

    if (chatContext?.selectedThreadPath == entry.path) {
      _selectDesktopPreviewThread(chatContext, null);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return;
      }
    }

    try {
      await entry.storage.deleteThread(entry.path);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ShadToaster.of(context).show(powerboardsToast(title: "Unable to delete thread", description: "$error", destructive: true));
    }
  }

  Future<void> _selectDesktopPreviewAgent(
    PbAgentListItemData agent, {
    required BuildContext sourceContext,
    required String? currentRouteId,
  }) async {
    final routeId = agent.id;
    if (routeId == null || routeId.isEmpty) {
      return;
    }

    final didDisconnect = await _disconnectVoiceSessionForAgentSwitch(
      sourceContext: sourceContext,
      currentRouteId: currentRouteId,
      nextRouteId: routeId,
    );
    if (!didDisconnect) {
      return;
    }

    if (!mounted || !sourceContext.mounted) {
      return;
    }

    _persistSelectedRoomAgentRouteId(routeId);
    _navigateToAgentRoute(sourceContext, routeId);
  }

  void _closeDesktopPreviewRoomPanelOverlay() {
    _desktopPreviewRoomPanelOverlayController.hide();
    setState(() => _desktopPreviewRoomPanelOverlayOpen = false);
  }

  void _setDesktopPreviewRoomPanelCollapsed(bool collapsed) {
    if (_desktopPreviewRoomPanelCollapsed == collapsed) {
      return;
    }

    setState(() => _desktopPreviewRoomPanelCollapsed = collapsed);
  }

  void _setDesktopPreviewRoomPanelWidth(double width) {
    final currentWidth = _desktopPreviewRoomPanelWidth;
    if (currentWidth != null && (currentWidth - width).abs() < 0.5) {
      return;
    }

    setState(() => _desktopPreviewRoomPanelWidth = width);
  }

  void _setDesktopPreviewFilePreviewFullscreen(bool fullscreen, {bool closeOverlay = false}) {
    setState(() {
      _desktopPreviewFilePreviewFullscreen = fullscreen;
      if (fullscreen || closeOverlay) {
        _desktopPreviewRoomPanelOverlayOpen = false;
      } else if (_desktopPreviewFilePreviewOpen) {
        _desktopPreviewRoomPanelOverlayOpen = true;
      }
    });
    setPreviewFilePreviewFullscreen(fullscreen);
  }

  Widget _buildDesktopPreviewRoomSection(
    BuildContext context, {
    required List<ServiceSpec> supported,
    required _ResolvedAgentSelection selected,
    required List<RemoteParticipant> participants,
    required bool canViewStorageAllowed,
    required bool isAdaptiveWebapp,
  }) {
    if (controller.inMeeting) {
      return _buildMeeting(
        context,
        null,
        const [],
        showDesktopSidetrayToggle: false,
        desktopPreviewRoomPanelContentAvailable: _hasVisibleAgents(supported),
      );
    }

    if (canViewStorageAllowed && controller.isFilesShown) {
      return _buildFilesArea(context, const [], showDesktopSidetrayToggle: false);
    }

    final rawChatContext = _resolveMobileChatHeaderContext(supported, selected);
    final threadListPath = rawChatContext?.threadListPath;
    final threadListChatClient = _agentChatClientFor(rawChatContext?.agentName);
    final agentItems = _desktopPreviewAgentItems(supported, selected);
    final hasVisibleAgents = _hasVisibleAgents(supported);
    final voiceOnlyAgent = rawChatContext?.isVoiceOnly == true;

    return _DesktopPreviewThreadList(
      client: widget.room,
      agentName: rawChatContext?.agentName,
      threadListPath: threadListPath,
      chatClientFactory: (_, agentName) =>
          _agentChatClientFor(agentName) ??
          threadListChatClient ??
          agent_sessions.MessagingChatClient(room: widget.room, agentName: agentName),
      disposeChatClient: false,
      builder: (context, threads, threadListLoaded) {
        final chatContext = _desktopPreviewChatContextForVisibleThreads(rawChatContext, threads, threadListLoaded: threadListLoaded);
        final selectedThreadTitle = _desktopPreviewSelectedThreadTitle(chatContext, threads, threadListLoaded: threadListLoaded);
        final selectedThreadDisplayName = _desktopPreviewSelectedThreadDisplayName(chatContext, threads);
        final selectedThreadTitleResolving = chatContext?.selectedThreadPath != null && !threadListLoaded;
        if (selectedThreadDisplayName != null) {
          _syncDesktopPreviewVisibleThreadSelection(chatContext, selectedThreadDisplayName);
        }
        final agentContextLabel = chatContext?.isVoiceOnly == true ? 'Session with' : 'Thread with';
        final threadItems = powerboardsDesktopPreviewThreadItemsForVisibleThreads(
          selectedThreadPath: chatContext?.selectedThreadPath,
          selectedThreadTitle: selectedThreadDisplayName ?? selectedThreadTitle,
          threadItems: [for (final thread in threads) PbThreadListItemData(id: thread.path, title: thread.name)],
          threadListLoaded: threadListLoaded,
        );
        final agentName = chatContext?.agentName ?? selected.service?.agents.firstOrNull?.name ?? 'Assistant';
        final threadPanel = hasVisibleAgents
            ? Column(
                children: [
                  PbThreadHeader(
                    title: selectedThreadTitle,
                    agentName: agentName,
                    agentContextLabel: agentContextLabel,
                    selectedThreadTitle: selectedThreadTitle,
                    titleResolving: selectedThreadTitleResolving,
                    roomPanelExpanded: !_desktopPreviewRoomPanelCollapsed,
                    onRoomPanelToggle: () {
                      setState(() {
                        _desktopPreviewRoomPanelCollapsed = !_desktopPreviewRoomPanelCollapsed;
                      });
                    },
                    onOpenAllAgentsAndThreads: () {
                      setState(() {
                        _desktopPreviewRoomPanelCollapsed = false;
                        _desktopPreviewRoomPanelTab = PbRoomPanelTab.agents;
                      });
                    },
                  ),
                  Expanded(
                    child: _buildAgentArea(
                      context,
                      const [],
                      showEmbeddedThreadList: false,
                      embedMobileChrome: false,
                      showDesktopThreadListAlternatives: false,
                      useSelectedThreadOverride: chatContext != null,
                      selectedThreadPathOverride: chatContext?.selectedThreadPath,
                      selectedThreadDisplayNameOverride: selectedThreadDisplayName,
                    ),
                  ),
                ],
              )
            : SignalBuilder(
                builder: (context, _) {
                  final ownerResolved = isOwner.state.isReady || isOwner.state.hasError;
                  final canInstallAgent = isOwner.state.value == true;

                  if (!ownerResolved) {
                    return _buildRoomLoading(context, title: "Loading room permissions");
                  }

                  return _BlankDesktopPreviewRoomWorkspace(
                    onInstallAgent: !canInstallAgent
                        ? null
                        : () {
                            unawaited(
                              showManageAgentsSurface(
                                context: context,
                                room: widget.room,
                                projectId: widget.projectId,
                                onServiceChanged: () {
                                  services.refresh();
                                },
                              ),
                            );
                          },
                  );
                },
              );

        final shouldLoadThreadAttachments = powerboardsDesktopPreviewShouldLoadThreadAttachments(
          selectedTab: _desktopPreviewRoomPanelTab,
          filePreviewOpen: _desktopPreviewFilePreviewOpen,
        );

        Widget buildRoomWorkspace(
          List<PbAttachmentListItemData> sidePanelItems, {
          required String filesTabLabel,
          required String filesPanelDescription,
          required PbSidepaneFileEmptyStateData filesEmptyState,
        }) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final responsivePanel = constraints.maxWidth <= pbRoomPanelStackBreakpoint && !_desktopPreviewFilePreviewFullscreen;
              final responsiveOverlayMobile = constraints.maxWidth <= pbShellMobileBreakpoint;
              final roomPanelExpanded = responsivePanel ? false : !_desktopPreviewRoomPanelCollapsed;
              final effectiveThreadPanel = hasVisibleAgents
                  ? Column(
                      children: [
                        PbThreadHeader(
                          title: selectedThreadTitle,
                          agentName: agentName,
                          agentContextLabel: agentContextLabel,
                          selectedThreadTitle: selectedThreadTitle,
                          titleResolving: selectedThreadTitleResolving,
                          roomPanelExpanded: roomPanelExpanded,
                          onRoomPanelToggle: () {
                            setState(() {
                              if (responsivePanel) {
                                _desktopPreviewRoomPanelOverlayOpen = true;
                              } else {
                                _desktopPreviewRoomPanelCollapsed = !_desktopPreviewRoomPanelCollapsed;
                              }
                            });
                          },
                          onOpenAllAgentsAndThreads: () {
                            setState(() {
                              _desktopPreviewRoomPanelTab = PbRoomPanelTab.agents;
                              if (responsivePanel) {
                                _desktopPreviewRoomPanelOverlayOpen = true;
                              } else {
                                _desktopPreviewRoomPanelCollapsed = false;
                              }
                            });
                          },
                        ),
                        Expanded(
                          child: _buildAgentArea(
                            context,
                            const [],
                            showEmbeddedThreadList: false,
                            embedMobileChrome: false,
                            showDesktopThreadListAlternatives: false,
                            useSelectedThreadOverride: chatContext != null,
                            selectedThreadPathOverride: chatContext?.selectedThreadPath,
                            selectedThreadDisplayNameOverride: selectedThreadDisplayName,
                          ),
                        ),
                      ],
                    )
                  : threadPanel;

              Widget buildRoomPanel({bool responsiveOverlay = false, bool resizing = false}) {
                void selectThreadFromRoomPanel(String? path, {String? displayName}) {
                  _selectDesktopPreviewThread(chatContext, path, displayName: displayName);
                  if (responsiveOverlay) {
                    _closeDesktopPreviewRoomPanelOverlay();
                  }
                }

                return StatefulBuilder(
                  builder: (context, _) => PbRoomPanel(
                    selectedTab: _desktopPreviewRoomPanelTab,
                    onTabSelected: (tab) {
                      if (_desktopPreviewRoomPanelTab == tab) {
                        return;
                      }
                      setState(() {
                        _desktopPreviewRoomPanelTab = tab;
                      });
                    },
                    agents: agentItems,
                    selectedAgentId: selected.routeId,
                    selectedAgentTitle: agentName,
                    onAgentItemSelected: (agent) =>
                        unawaited(_selectDesktopPreviewAgent(agent, sourceContext: context, currentRouteId: selected.routeId)),
                    onManageAgents: isOwner.state.value == true ? showManageAgents : null,
                    agentsExpanded: _desktopPreviewAgentsExpanded,
                    onAgentsExpandedChanged: (expanded) {
                      setState(() {
                        _desktopPreviewAgentsExpanded = expanded;
                      });
                    },
                    showThreadsSection: threadListPath != null,
                    showFilesTab: true,
                    filesTabLabel: filesTabLabel,
                    filesPanelDescription: filesPanelDescription,
                    filesEmptyState: filesEmptyState,
                    threads: [for (final thread in threads) thread.name],
                    threadItems: threadItems,
                    selectedThreadId: chatContext?.selectedThreadPath,
                    selectedThreadTitle: chatContext?.selectedThreadPath == null ? null : selectedThreadTitle,
                    onThreadSelected: (_) {},
                    onThreadItemSelected: (thread) => selectThreadFromRoomPanel(thread.id, displayName: thread.title),
                    onThreadRename: (thread) {
                      final entry = threads.firstWhereOrNull((entry) => entry.path == thread.id);
                      if (entry != null) {
                        unawaited(_renameDesktopPreviewThread(entry));
                      }
                    },
                    onThreadDelete: (thread) {
                      final entry = threads.firstWhereOrNull((entry) => entry.path == thread.id);
                      if (entry != null) {
                        unawaited(_deleteDesktopPreviewThread(chatContext, entry));
                      }
                    },
                    onCreateThread: () => selectThreadFromRoomPanel(null),
                    attachments: sidePanelItems,
                    initialPreviewFile: _desktopPreviewFilePreviewFile,
                    initialFilePreviewOpen: _desktopPreviewFilePreviewOpen,
                    openFilePreviewAsFullscreen: _desktopPreviewFilePreviewFullscreen || (responsiveOverlay && responsiveOverlayMobile),
                    onFilePreviewSelected: (file) {
                      setState(() {
                        _desktopPreviewFilePreviewFile = file;
                        _desktopPreviewComposerAttachmentPreviewPath = null;
                      });
                    },
                    onFilePreviewOpenChanged: (open) {
                      setState(() {
                        _desktopPreviewFilePreviewOpen = open;
                        if (!open) {
                          _desktopPreviewFilePreviewFile = null;
                          _desktopPreviewFilePreviewFullscreen = false;
                          _desktopPreviewComposerAttachmentPreviewPath = null;
                        }
                      });
                      if (!open) {
                        setPreviewFilePreviewFullscreen(false);
                      }
                    },
                    onFilePreviewFullscreenChanged: (fullscreen) {
                      _setDesktopPreviewFilePreviewFullscreen(fullscreen, closeOverlay: responsiveOverlay);
                    },
                    filePreviewBuilder: _buildAttachmentPreviewFallbackContent,
                    filePreviewSourceBuilder: _buildAttachmentPreviewSource,
                    onAskFileAgent: (file) => unawaited(
                      _startDefaultAttachmentFilePrompt(file, agentKey: chatContext?.agentKey, responsiveHandoff: responsiveOverlay),
                    ),
                    onShareFile: supportsNativeFileShare ? (file) => unawaited(_shareAttachmentFile(file)) : null,
                    onExtractArchiveFile: (file) => unawaited(_showAttachmentArchiveExtractDialog(file)),
                    onDownloadFile: (file) => unawaited(_downloadAttachmentFile(file)),
                    filePreviewResizing: resizing,
                    borderOnTop: responsiveOverlay,
                    responsiveOverlay: responsiveOverlay,
                    responsiveOverlayMobile: responsiveOverlayMobile,
                    onResponsiveOverlayClose: _closeDesktopPreviewRoomPanelOverlay,
                  ),
                );
              }

              if (!hasVisibleAgents) {
                return ColoredBox(
                  color: PbColors.surfacePanelWash,
                  child: SizedBox.expand(child: effectiveThreadPanel),
                );
              }

              if (responsivePanel) {
                if (_desktopPreviewRoomPanelOverlayOpen) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _desktopPreviewRoomPanelOverlayController.show();
                    }
                  });
                }

                return OverlayPortal(
                  controller: _desktopPreviewRoomPanelOverlayController,
                  overlayChildBuilder: (context) => Positioned.fill(child: buildRoomPanel(responsiveOverlay: true)),
                  child: ColoredBox(color: PbColors.surfacePanelWash, child: effectiveThreadPanel),
                );
              }

              if (_desktopPreviewRoomPanelOverlayOpen) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    if (_desktopPreviewRoomPanelOverlayController.isShowing) {
                      _desktopPreviewRoomPanelOverlayController.hide();
                    }
                    setState(() => _desktopPreviewRoomPanelOverlayOpen = false);
                  }
                });
              }

              return ColoredBox(
                color: PbColors.surfacePanelWash,
                child: PbRoomPanelMount(
                  activeTab: _desktopPreviewRoomPanelTab,
                  filePreviewOpen: _desktopPreviewFilePreviewOpen,
                  filePreviewFullscreen: _desktopPreviewFilePreviewFullscreen,
                  roomPanelCollapsed: _desktopPreviewRoomPanelCollapsed,
                  panelWidth: _desktopPreviewRoomPanelWidth,
                  onPanelWidthChanged: _setDesktopPreviewRoomPanelWidth,
                  threadPanel: effectiveThreadPanel,
                  roomPanelBuilder: (context, resizing) => buildRoomPanel(resizing: resizing),
                ),
              );
            },
          );
        }

        if (voiceOnlyAgent) {
          return _DesktopPreviewVoiceSessionTranscripts(
            client: widget.room,
            agentName: agentName,
            builder: (context, transcripts) => buildRoomWorkspace(
              transcripts,
              filesTabLabel: 'Sessions',
              filesPanelDescription: 'Transcripts of recent audio sessions.',
              filesEmptyState: const PbSidepaneFileEmptyStateData(
                title: 'No transcripts yet',
                subtitle: 'Transcripts will show up here.',
                fileType: PbAttachmentFileType.transcript,
                iconAssetName: 'file',
              ),
            ),
          );
        }

        return _DesktopPreviewThreadAttachments(
          client: widget.room,
          enabled: shouldLoadThreadAttachments,
          threads: threads,
          selectedThreadPath: chatContext?.selectedThreadPath,
          selectedThreadName: selectedThreadTitle,
          chatClient: threadListChatClient,
          localLinks: _localThreadAttachmentLinks,
          builder: (context, attachments) => buildRoomWorkspace(
            attachments,
            filesTabLabel: 'Files',
            filesPanelDescription: 'Browse attachments by selected agent.',
            filesEmptyState: const PbSidepaneFileEmptyStateData(title: 'No files here yet', subtitle: 'Files attached will show up here.'),
          ),
        );
      },
    );
  }

  void _leaveMeeting() {
    final meetingViewController = Controller.ofType<MeetingViewController>(context);
    final navController = Controller.ofType<NavController>(context);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    videoChatKey.currentState?.hangup();
    meetingViewController.resetToLobby();
    navController.showNav();
    _setDesktopPreviewMeetingFullscreen(false);

    if (isMobile) {
      _closeMobileMeetingLobby(context);
      return;
    }

    _showChatPane(context);
  }

  void _endMeeting() {
    final meetingViewController = Controller.ofType<MeetingViewController>(context);
    final navController = Controller.ofType<NavController>(context);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    videoChatKey.currentState?.hangup();
    meetingViewController.resetToLobby();
    navController.showNav();
    _setDesktopPreviewMeetingFullscreen(false);
    _meetingSplitViewController.expand();
    _mobileMeetingOrigin = null;
    if (isMobile) {
      _showChatPane(context);
    }
  }

  void _joinMeeting() {
    final meetingViewController = Controller.ofType<MeetingViewController>(context);

    meetingViewController.resetToLobby();
    _showMeetingPane(context);
  }

  void _showMaximizedChat() {
    _showChatPane(context);
  }

  Widget _buildMobileContextAgentListItem({
    required String title,
    required String description,
    required IconData leadingIcon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final isMobile = powerboardsUsesNativeMobileDialogLayout(context);
    final avatarBackgroundColor = selected ? cs.foreground : cs.muted;
    final avatarIconColor = selected ? cs.background : cs.mutedForeground;
    final titleFontWeight = selected ? FontWeight.w700 : FontWeight.w600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 80),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Container(
                    width: userAvatarStandardDiameter,
                    height: userAvatarStandardDiameter,
                    decoration: BoxDecoration(color: avatarBackgroundColor, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(leadingIcon, size: 16, color: avatarIconColor),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: powerboardsInterTextStyle(color: cs.foreground, fontWeight: titleFontWeight),
                          ),
                        ),
                        if (selected && isMobile) ...[const SizedBox(width: 12), buildPowerboardsCurrentPill()],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(description, maxLines: 3, style: powerboardsInterTextStyle(color: theme.colorScheme.foreground)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 12),
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: SizedBox(width: 24, height: 24, child: Center(child: Icon(LucideIcons.check, size: 18))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMobileRoomContextSwitcher({
    required BuildContext context,
    required List<ServiceSpec> supported,
    required _MobileChatHeaderContext chatContext,
  }) async {
    final agentOptions = _mobileRoomContextAgentOptions(supported);
    var selectedAgentRouteId = chatContext.agentKey ?? agentOptions.firstOrNull?.routeId;
    final initialSwitcherState = chatContext.isVoiceOnly
        ? _MobileRoomContextSwitcherState.agents
        : (agentOptions.firstWhereOrNull((option) => option.routeId == selectedAgentRouteId)?.supportsThreads ?? false)
        ? _MobileRoomContextSwitcherState.threads
        : _MobileRoomContextSwitcherState.agents;
    var switcherState = initialSwitcherState;
    var didCommitSelection = false;

    await showPowerboardsFlowDialog<void>(
      context: context,
      builder: (dialogContext) {
        final usesLandscapeMobileDialogLayout = powerboardsUsesLandscapeMobileDialogLayout(dialogContext);

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final selectedAgent =
                agentOptions.firstWhereOrNull((option) => option.routeId == selectedAgentRouteId) ?? agentOptions.firstOrNull;
            selectedAgentRouteId = selectedAgent?.routeId;

            final selectedThreadPath = _selectedThreadPathForAgentKey(selectedAgentRouteId);
            final actions = <Widget>[
              if (switcherState == _MobileRoomContextSwitcherState.agents && isOwner.state.value == true)
                ShadButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    unawaited(showManageAgents());
                  },
                  child: const Text("Manage agents"),
                ),
              if (switcherState == _MobileRoomContextSwitcherState.threads)
                ShadButton(
                  onPressed: () {
                    setDialogState(() {
                      switcherState = _MobileRoomContextSwitcherState.agents;
                    });
                  },
                  child: const Text("Switch agents"),
                ),
              if (switcherState == _MobileRoomContextSwitcherState.threads &&
                  selectedAgent != null &&
                  selectedAgent.threadListPath != null &&
                  !selectedAgent.isVoiceOnly)
                ShadButton(
                  onPressed: () {
                    didCommitSelection = true;
                    unawaited(
                      _commitMobileRoomContextSelection(
                        dialogContext,
                        currentChatContext: chatContext,
                        agentOption: selectedAgent,
                        threadPath: null,
                      ),
                    );
                  },
                  child: const Text("New thread"),
                ),
            ];

            Widget body;
            if (switcherState == _MobileRoomContextSwitcherState.agents) {
              body = Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: double.infinity,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: usesLandscapeMobileDialogLayout ? double.infinity : 360.0),
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: powerboardsDialogScrollViewportVerticalInset),
                      itemCount: agentOptions.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, thickness: 1, color: ShadTheme.of(context).colorScheme.border.withValues(alpha: 0.5)),
                      itemBuilder: (context, index) {
                        final option = agentOptions[index];
                        return _buildMobileContextAgentListItem(
                          title: option.name,
                          description: option.description,
                          leadingIcon: option.leadingIcon,
                          selected: selectedAgentRouteId == option.routeId,
                          onTap: () {
                            final rememberedThreadPath = _selectedThreadPathForAgentKey(option.routeId);
                            final rememberedThreadLabel = _selectedThreadLabelForAgentKey(option.routeId);

                            didCommitSelection = true;
                            unawaited(
                              _commitMobileRoomContextSelection(
                                dialogContext,
                                currentChatContext: chatContext,
                                agentOption: option,
                                threadPath: option.supportsThreads ? rememberedThreadPath : null,
                                displayName: option.supportsThreads ? rememberedThreadLabel : null,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            } else if (selectedAgent == null || selectedAgent.threadListPath == null) {
              body = Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    "No thread-enabled agents are available in this room yet.",
                    textAlign: TextAlign.center,
                    style: powerboardsSecondaryTextStyle(color: ShadTheme.of(dialogContext).colorScheme.mutedForeground),
                  ),
                ),
              );
            } else {
              body = Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: double.infinity,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: usesLandscapeMobileDialogLayout ? double.infinity : 360.0),
                    child: MeshagentThreadListPane(
                      key: ValueKey("mobile-room-context-threads-${selectedAgent.routeId}"),
                      client: widget.room,
                      agentName: selectedAgent.name,
                      threadListPath: selectedAgent.threadListPath!,
                      selectedThreadPath: selectedThreadPath,
                      newThreadResetVersion: _newThreadResetVersion,
                      mobileListTopPadding: 0,
                      mobileListBottomPadding: 0,
                      mobileRowVerticalPadding: 16,
                      mobileUseDialogListStyle: true,
                      showCreateItem: false,
                      mobileHideEmptyStateWhenNoEntries: selectedAgent.isVoiceOnly,
                      onSelectedThreadPathChanged: (path) {
                        final threadPath = path?.trim();
                        didCommitSelection = true;
                        unawaited(
                          _commitMobileRoomContextSelection(
                            dialogContext,
                            currentChatContext: chatContext,
                            agentOption: selectedAgent,
                            threadPath: threadPath == null || threadPath.isEmpty ? null : threadPath,
                          ),
                        );
                      },
                      onSelectedThreadResolved: (path, displayName) {
                        _setSelectedThreadPath(selectedAgent.routeId, path, displayName: displayName);
                      },
                    ),
                  ),
                ),
              );
            }

            final flowTitle = switcherState == _MobileRoomContextSwitcherState.threads ? "Switch threads" : "Switch agents";
            final flowDescription = switcherState == _MobileRoomContextSwitcherState.threads
                ? Text.rich(
                    TextSpan(
                      text: "Threads with ",
                      children: [
                        TextSpan(
                          text: selectedAgent?.name ?? "selected agent",
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  )
                : const Text("Select to apply an agent installed in this room.");

            return PowerboardsShadDialog.listPicker(
              title: Text(flowTitle),
              description: flowDescription,
              onBack:
                  switcherState == _MobileRoomContextSwitcherState.agents && initialSwitcherState == _MobileRoomContextSwitcherState.threads
                  ? () {
                      setDialogState(() {
                        switcherState = _MobileRoomContextSwitcherState.threads;
                      });
                    }
                  : null,
              actions: actions,
              mobileFlowBodyBehavior: PowerboardsDialogMobileFlowBodyBehavior.fill,
              child: body,
            );
          },
        );
      },
    );

    if (!context.mounted || didCommitSelection) {
      return;
    }

    final selectedAgent = agentOptions.firstWhereOrNull((option) => option.routeId == selectedAgentRouteId);
    if (selectedAgent == null) {
      return;
    }

    final selectedThreadPath = _selectedThreadPathForAgentKey(selectedAgent.routeId);
    final displayName = _selectedThreadLabelForAgentKey(selectedAgent.routeId);
    final selectionChanged = selectedAgent.routeId != chatContext.agentKey || selectedThreadPath != chatContext.selectedThreadPath;
    if (!selectionChanged) {
      return;
    }

    _applyMobileRoomContextSelection(
      currentChatContext: chatContext,
      agentOption: selectedAgent,
      threadPath: selectedThreadPath,
      displayName: displayName,
    );
  }

  Future<void> _runMobileCreateAction(BuildContext dialogContext, FutureOr<void> Function() action) async {
    Navigator.of(dialogContext).pop();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    await action();
  }

  Future<void> _showMobileRoomCreateMenu({
    required BuildContext context,
    required _MobileRoomPane activePane,
    required bool canViewStorageAllowed,
    _MobileChatHeaderContext? chatContext,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) {
      return;
    }

    await showPowerboardsFlowDialog<void>(
      context: context,
      builder: (dialogContext) {
        final usesLandscapeMobileDialogLayout = powerboardsUsesLandscapeMobileDialogLayout(dialogContext);

        return PowerboardsShadDialog.listPicker(
          title: const Text('Create'),
          description: Text(
            activePane == _MobileRoomPane.files ? 'Choose something to add to this folder.' : 'Choose something to start in this room.',
          ),
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: powerboardsUsesNativeMobileDialogLayout(dialogContext) ? EdgeInsets.zero : powerboardsDialogScrollableListPadding,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: double.infinity,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: usesLandscapeMobileDialogLayout ? double.infinity : 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (activePane == _MobileRoomPane.files && canViewStorageAllowed) ...[
                        _MobileRoomCreateActionRow(
                          title: 'New folder',
                          icon: LucideIcons.folderPlus,
                          onPressed: () => _runMobileCreateAction(dialogContext, _filesHeaderController.createFolderInCurrentLocation),
                        ),
                        const ShadSeparator.horizontal(margin: EdgeInsets.zero),
                        _MobileRoomCreateActionRow(
                          title: 'New text file',
                          icon: LucideIcons.fileText,
                          onPressed: () => _runMobileCreateAction(dialogContext, () {
                            _filesHeaderController.createTextFileInCurrentLocation();
                          }),
                        ),
                        const ShadSeparator.horizontal(margin: EdgeInsets.zero),
                        _MobileRoomCreateActionRow(
                          title: 'Add files',
                          icon: LucideIcons.upload,
                          onPressed: () => _runMobileCreateAction(dialogContext, _filesHeaderController.addFilesInCurrentLocation),
                        ),
                      ] else ...[
                        if (chatContext != null) ...[
                          _MobileRoomCreateActionRow(
                            title: 'New chat thread',
                            icon: LucideIcons.messageSquarePlus,
                            onPressed: () => _runMobileCreateAction(dialogContext, () {
                              _showChatPane(context);
                              _setSelectedThreadPath(chatContext.agentKey, null);
                            }),
                          ),
                          const ShadSeparator.horizontal(margin: EdgeInsets.zero),
                        ],
                        _MobileRoomCreateActionRow(
                          title: 'Invite someone',
                          icon: LucideIcons.userPlus,
                          onPressed: () => _runMobileCreateAction(dialogContext, () async {
                            final room = await getMeshagentClient().getRoom(name: widget.room.roomName!, projectId: widget.projectId);
                            if (!context.mounted) {
                              return;
                            }
                            await showUpdateRoomPermsDialog(context, projectId: widget.projectId, room: room);
                          }),
                        ),
                      ],
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

  Widget _buildDesktopThreadRail(
    BuildContext context, {
    required String threadListPath,
    required String? agentKey,
    required String? agentName,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: FractionallySizedBox(
        widthFactor: 0.72,
        child: Padding(
          padding: const EdgeInsets.only(bottom: desktopPaneBottomInset),
          child: MeshagentThreadListPane(
            key: ValueKey("embedded-threads-${agentKey ?? "none"}"),
            client: widget.room,
            agentName: agentName,
            threadListPath: threadListPath,
            selectedThreadPath: _selectedThreadPathForAgentKey(agentKey),
            newThreadResetVersion: _newThreadResetVersion,
            onSelectedThreadPathChanged: (path) => _setSelectedThreadPath(agentKey, path),
            onSelectedThreadResolved: (path, displayName) => _setSelectedThreadPath(agentKey, path, displayName: displayName),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopInlineThreadList(
    BuildContext context, {
    required String? agentKey,
    required String currentThreadLabel,
    required double horizontalInset,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalInset, 0, horizontalInset, desktopPaneBottomInset),
      child: MeshagentInlineThreadCreatePrompt(
        key: ValueKey("inline-thread-create-${agentKey ?? "none"}"),
        createItemTopPadding: 0,
        currentThreadLabel: currentThreadLabel,
        isSelected: _selectedThreadPathForAgentKey(agentKey) == null,
        onOpen: _showMaximizedChat,
        onViewAllThreads: _showMaximizedChat,
      ),
    );
  }

  Widget _buildDesktopPaneContentSpacer(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (isMobile) {
      return const SizedBox.shrink();
    }

    return const SizedBox(height: desktopPaneHeaderToContentOffset);
  }

  Widget _buildDesktopChatViewportCutoffSpacer(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (isMobile) {
      return const SizedBox.shrink();
    }

    return const SizedBox(height: desktopPaneHeaderToChatViewportOffset);
  }

  Widget _buildDesktopSecondaryControlSpacer(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (isMobile) {
      return const SizedBox.shrink();
    }

    return const SizedBox(height: desktopPaneSecondaryControlTopOffset);
  }

  Widget _buildAgentArea(
    BuildContext context,
    List<Widget> actions, {
    bool showEmbeddedThreadList = true,
    bool embedMobileChrome = true,
    bool showDesktopThreadListAlternatives = true,
    bool useSelectedThreadOverride = false,
    String? selectedThreadPathOverride,
    String? selectedThreadDisplayNameOverride,
  }) {
    final cs = ShadTheme.of(context).colorScheme;
    final isMobile = _usesMobileRoomLayout(context);

    return ColoredBox(
      color: isMobile ? cs.card : Colors.transparent,
      child: ChangeNotifierBuilder(
        source: widget.room.messaging,
        builder: (context) => SignalBuilder(
          builder: (context, _) {
            if (!services.state.isReady) {
              if (services.state.hasError) {
                return _buildErrorArea(
                  context,
                  "Unable to load room services: ${services.state.error}",
                  actions,
                  embedMobileChrome: embedMobileChrome,
                );
              }
              return _buildRoomLoading(context, title: "Loading room services");
            }

            final all = services.state.value!;
            final supported = _supportedServices(all);
            final selected = _resolveSelectedAgent(supported, requestedRouteId: _preferredMobileAgentRouteId(context));
            final service = selected.service;
            final developmentParticipant = selected.developmentParticipant;

            if (service == null && developmentParticipant == null) {
              final requestedRouteId = _preferredMobileAgentRouteId(context);
              final requestedDevelopmentParticipantName = requestedRouteId == null ? null : developmentAgentNameFromRoute(requestedRouteId);
              final requestedLegacyDevelopmentParticipantId = requestedRouteId == null
                  ? null
                  : legacyDevelopmentAgentParticipantIdFromRoute(requestedRouteId);
              if (requestedDevelopmentParticipantName != null || requestedLegacyDevelopmentParticipantId != null) {
                return _buildErrorArea(
                  context,
                  "Development mode agent is not currently online",
                  actions,
                  embedMobileChrome: embedMobileChrome,
                );
              }

              if (supported.isEmpty) {
                return _buildErrorArea(context, "No supported agents installed", actions, embedMobileChrome: embedMobileChrome);
              }

              return _buildErrorArea(context, "Agent is not installed ${widget.service}", actions, embedMobileChrome: embedMobileChrome);
            }

            if (developmentParticipant != null) {
              final name = participantDisplayName(developmentParticipant);
              if (name == null) {
                return _buildErrorArea(context, "Development mode agent is missing a name", actions);
              }

              final descriptor = participantConversationDescriptor(developmentParticipant);
              final agentKey = selected.routeId;
              if (descriptor?.isVoiceOnly == true) {
                return _buildVoiceArea(context, name, actions, embedMobileChrome: embedMobileChrome);
              }

              if (descriptor?.isChat == true) {
                final selectedThreadPath = useSelectedThreadOverride
                    ? selectedThreadPathOverride
                    : _selectedThreadPathForAgentKey(agentKey);
                return _buildChatArea(
                  context,
                  name,
                  actions,
                  selectedAgentRouteId: agentKey,
                  showEmbeddedThreadList: showEmbeddedThreadList,
                  threadDisplayMode: descriptor!.chatThreadDisplayMode,
                  threadDir: descriptor.threadDir,
                  threadListPath: descriptor.threadListPath,
                  threadPath: descriptor.threadPath,
                  selectedThreadPath: selectedThreadPath,
                  selectedThreadDisplayName: useSelectedThreadOverride && selectedThreadPath != null
                      ? selectedThreadDisplayNameOverride
                      : null,
                  onSelectedThreadPathChanged: (path) => _setSelectedThreadPath(agentKey, path),
                  embedMobileChrome: embedMobileChrome,
                  showDesktopThreadListAlternatives: showDesktopThreadListAlternatives,
                );
              }

              return _buildErrorArea(
                context,
                "Selected development mode agent does not support chat or voice",
                actions,
                embedMobileChrome: embedMobileChrome,
              );
            }

            final descriptor = serviceConversationDescriptor(service!, remoteParticipants: widget.room.messaging.remoteParticipants);
            final type = _serviceType(service);
            final agentKey = selected.routeId;
            if (descriptor?.isChat == true) {
              final selectedThreadPath = useSelectedThreadOverride ? selectedThreadPathOverride : _selectedThreadPathForAgentKey(agentKey);
              return _buildChatArea(
                context,
                service.agents[0].name,
                actions,
                selectedAgentRouteId: agentKey,
                showEmbeddedThreadList: showEmbeddedThreadList,
                threadDisplayMode: descriptor!.chatThreadDisplayMode,
                threadDir: descriptor.threadDir,
                threadListPath: descriptor.threadListPath,
                threadPath: descriptor.threadPath,
                selectedThreadPath: selectedThreadPath,
                selectedThreadDisplayName: useSelectedThreadOverride && selectedThreadPath != null
                    ? selectedThreadDisplayNameOverride
                    : null,
                onSelectedThreadPathChanged: (path) => _setSelectedThreadPath(agentKey, path),
                embedMobileChrome: embedMobileChrome,
                showDesktopThreadListAlternatives: showDesktopThreadListAlternatives,
              );
            } else if (descriptor?.isMeeting == true) {
              return _buildMeetingTranscriberArea(context, service.agents[0].name, actions, embedMobileChrome: embedMobileChrome);
            } else if (descriptor?.isVoiceOnly == true) {
              return _buildVoiceArea(context, service.agents[0].name, actions, embedMobileChrome: embedMobileChrome);
            } else if (type == "Shell") {
              return _buildShellArea(context, service, actions, embedMobileChrome: embedMobileChrome);
            } else if (service.metadata.annotations["meshagent.service.readme"] != null) {
              return MarkdownViewer(markdown: service.metadata.annotations["meshagent.service.readme"] ?? "");
            } else {
              return _buildErrorArea(
                context,
                "Agent type '$type' is not currently supported by Powerboards",
                actions,
                embedMobileChrome: embedMobileChrome,
              );
            }
          },
        ),
      ),
    );
  }

  double _measureMeetingHeaderTitleWidth(BuildContext context, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: "Get ready to meet", style: meetingHeaderTitleStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();

    return painter.width.clamp(0.0, maxWidth * 0.45);
  }

  double _measureActiveMeetingHeaderWidth(double maxWidth) {
    return _meetingToolbarPreferredExpandedWidth.clamp(0.0, maxWidth);
  }

  static const double _meetingActivePaneActionLeadingWidthFloor = 260;

  bool _isLandscapePhoneViewport(BuildContext context) {
    return powerboardsIsLandscapePhoneViewport(context);
  }

  bool _usesMobileRoomLayout(BuildContext context) {
    if (powerboardsUsesDesktopUiPreview(context)) {
      return false;
    }

    return ResponsiveBreakpoints.of(context).isMobile || _isLandscapePhoneViewport(context);
  }

  List<PowerboardsFileAttachmentLink> get _localThreadAttachmentLinks {
    final links = _localThreadAttachmentLinksByKey.values.toList(growable: false)
      ..sort((left, right) {
        final rightCreatedAt = right.createdAt?.millisecondsSinceEpoch ?? 0;
        final leftCreatedAt = left.createdAt?.millisecondsSinceEpoch ?? 0;
        return rightCreatedAt.compareTo(leftCreatedAt);
      });
    return links;
  }

  void _recordLocalThreadAttachments({
    required String threadPath,
    required String threadName,
    required String createdBy,
    required Iterable<String> attachmentPaths,
  }) {
    final normalizedThreadPath = normalizePowerboardsThreadAttachmentPath(threadPath);
    if (normalizedThreadPath.isEmpty) {
      return;
    }

    final normalizedAttachmentPaths = attachmentPaths.map(powerboardsStorageAttachmentPathFromUrl).where((path) => path.isNotEmpty).toSet();
    if (normalizedAttachmentPaths.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
    var changed = false;
    final normalizedCreatedBy = createdBy.trim();
    final normalizedThreadName = threadName.trim();
    for (final filePath in normalizedAttachmentPaths) {
      final key = '$filePath\n$normalizedThreadPath';
      final existing = _localThreadAttachmentLinksByKey[key];
      if (existing != null) {
        final existingThreadName = existing.threadName.trim();
        final existingCreatedBy = existing.createdBy.trim();
        if ((existingThreadName.isEmpty && normalizedThreadName.isNotEmpty) ||
            (existingCreatedBy.isEmpty && normalizedCreatedBy.isNotEmpty)) {
          _localThreadAttachmentLinksByKey[key] = PowerboardsFileAttachmentLink(
            filePath: existing.filePath,
            threadPath: existing.threadPath,
            threadName: existingThreadName.isNotEmpty ? existing.threadName : normalizedThreadName,
            createdBy: existingCreatedBy.isNotEmpty ? existing.createdBy : normalizedCreatedBy,
            createdAt: existing.createdAt ?? now,
          );
          changed = true;
        }
        continue;
      }

      _localThreadAttachmentLinksByKey[key] = PowerboardsFileAttachmentLink(
        filePath: filePath,
        threadPath: normalizedThreadPath,
        threadName: normalizedThreadName,
        createdBy: normalizedCreatedBy,
        createdAt: now,
      );
      changed = true;
    }

    if (changed && mounted) {
      setState(() {});
    }

    unawaited(
      recordPowerboardsFileAttachmentLinks(
        room: widget.room,
        threadPath: normalizedThreadPath,
        threadName: threadName,
        createdBy: normalizedCreatedBy,
        attachmentPaths: normalizedAttachmentPaths,
      ).catchError((Object error, StackTrace stackTrace) {
        if (powerboardsIsExpectedRoomLifecycleClosure(error, stackTrace)) {
          return;
        }
        debugPrint('Failed to record file attachment index: $error');
      }),
    );
  }

  PbAttachmentListItemData _attachmentDataForPromptPath(String filePath, {required String threadName}) {
    final normalizedPath = powerboardsStorageAttachmentPathFromUrl(filePath);
    final title = normalizedPath.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? normalizedPath;
    final metadata = PbResolvedAttachmentMetadata.resolve(title: title);
    final displayThreadName = threadName.trim();

    return PbAttachmentListItemData(
      title: metadata.displayTitle,
      subtitle: displayThreadName.isEmpty ? metadata.displayType : '${metadata.displayType} / $displayThreadName',
      fileType: metadata.fileType,
      path: normalizedPath,
      previewState: powerboardsV1PreviewStateForPath(normalizedPath),
    );
  }

  String _storageEntrySizeLabel(StorageEntry? entry) {
    if (entry == null || entry.isFolder) {
      return '';
    }

    final size = entry.size;
    return size == null ? '' : pbFormatBytes(size);
  }

  Future<void> _refreshDesktopPreviewAttachmentSizeLabel(String normalizedPath) async {
    StorageEntry? entry;
    try {
      entry = await widget.room.storage.stat(normalizedPath);
    } catch (_) {}

    final sizeLabel = _storageEntrySizeLabel(entry);
    if (!mounted || sizeLabel.isEmpty) {
      return;
    }

    final previewFile = _desktopPreviewFilePreviewFile;
    if (!_desktopPreviewFilePreviewOpen || powerboardsStorageAttachmentPathFromUrl(previewFile?.path ?? '') != normalizedPath) {
      return;
    }

    if (previewFile!.sizeLabel == sizeLabel) {
      return;
    }

    setState(() {
      _desktopPreviewFilePreviewFile = PbAttachmentListItemData(
        title: previewFile.title,
        subtitle: previewFile.subtitle,
        fileType: previewFile.fileType,
        path: previewFile.path,
        previewState: previewFile.previewState,
        sizeLabel: sizeLabel,
      );
    });
  }

  void _openDesktopPreviewAttachment(String filePath, {required String threadName, bool fromComposerAttachment = false}) {
    final normalizedPath = powerboardsStorageAttachmentPathFromUrl(filePath);
    if (normalizedPath.isEmpty) {
      return;
    }

    final previewFile = _attachmentDataForPromptPath(normalizedPath, threadName: threadName);
    setState(() {
      _desktopPreviewRoomPanelTab = PbRoomPanelTab.files;
      _desktopPreviewRoomPanelCollapsed = false;
      _desktopPreviewRoomPanelOverlayOpen = true;
      _desktopPreviewFilePreviewFile = previewFile;
      _desktopPreviewFilePreviewOpen = true;
      _desktopPreviewFilePreviewFullscreen = false;
      _desktopPreviewComposerAttachmentPreviewPath = fromComposerAttachment ? normalizedPath : null;
    });
    setPreviewFilePreviewFullscreen(false);
    unawaited(_refreshDesktopPreviewAttachmentSizeLabel(normalizedPath));
  }

  void _closeDesktopPreviewAttachmentPreviewIfRemoved(String filePath) {
    if (!_desktopPreviewFilePreviewOpen) {
      return;
    }

    final normalizedRemovedPath = powerboardsStorageAttachmentPathFromUrl(filePath);
    if (!_desktopPreviewRemovedAttachmentMatchesPreview(normalizedRemovedPath)) {
      return;
    }

    setState(() {
      _desktopPreviewFilePreviewFile = null;
      _desktopPreviewFilePreviewOpen = false;
      _desktopPreviewFilePreviewFullscreen = false;
      _desktopPreviewComposerAttachmentPreviewPath = null;
    });
    setPreviewFilePreviewFullscreen(false);
  }

  bool _desktopPreviewRemovedAttachmentMatchesPreview(String normalizedRemovedPath) {
    if (normalizedRemovedPath.isEmpty) {
      return false;
    }

    final normalizedPreviewPath = powerboardsStorageAttachmentPathFromUrl(_desktopPreviewFilePreviewFile?.path ?? '');
    if (normalizedRemovedPath == normalizedPreviewPath) {
      return true;
    }

    final normalizedComposerPreviewPath = powerboardsStorageAttachmentPathFromUrl(_desktopPreviewComposerAttachmentPreviewPath ?? '');
    if (normalizedComposerPreviewPath.isEmpty) {
      return false;
    }

    if (normalizedRemovedPath == normalizedComposerPreviewPath) {
      return true;
    }

    final removedFileName = normalizedRemovedPath.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? '';
    final composerFileName = normalizedComposerPreviewPath.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? '';
    final previewFileName = normalizedPreviewPath.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? '';
    return removedFileName.isNotEmpty && (removedFileName == composerFileName || removedFileName == previewFileName);
  }

  Future<void> _handleDesktopPreviewFilePromptRequested(
    BuildContext context, {
    required ChatFilePromptAction action,
    required String filePath,
    String? preferredAgentKey,
    bool responsiveHandoff = false,
  }) async {
    if (!mounted || !context.mounted) {
      return;
    }

    final resolvedAction = await _resolveAttachmentPromptAction(action, filePath: filePath, preferredAgentKey: preferredAgentKey);
    if (resolvedAction == null || !mounted || !context.mounted) {
      return;
    }

    final agentKey = _agentRouteIdForFilePromptAction(resolvedAction) ?? preferredAgentKey;
    if (agentKey == null) {
      await showManageAgents();
      return;
    }

    if (responsiveHandoff) {
      _handoffResponsiveDesktopPreviewFilePrompt(context, agentKey: agentKey, filePath: filePath);
      return;
    }

    final previewFile = _attachmentDataForPromptPath(filePath, threadName: 'New thread');
    setState(() {
      _selectedThreadPathByAgentKey.remove(agentKey);
      _selectedThreadLabelByAgentKey.remove(agentKey);
      _newThreadResetVersion++;
      _desktopPreviewRoomPanelTab = PbRoomPanelTab.files;
      _desktopPreviewRoomPanelCollapsed = false;
      _desktopPreviewRoomPanelOverlayOpen = true;
      _desktopPreviewFilePreviewFile = previewFile;
      _desktopPreviewFilePreviewOpen = true;
      _desktopPreviewFilePreviewFullscreen = false;
      _desktopPreviewComposerAttachmentPreviewPath = powerboardsStorageAttachmentPathFromUrl(filePath);
    });
    _setComposerAttachmentSeed(agentKey, [filePath]);
    setPreviewFilePreviewFullscreen(false);

    if (!mounted || !context.mounted) {
      return;
    }
    _showDesktopPreviewChatPane(context, agentKey: agentKey);
  }

  void _handoffResponsiveDesktopPreviewFilePrompt(BuildContext context, {required String agentKey, required String filePath}) {
    final normalizedPath = powerboardsStorageAttachmentPathFromUrl(filePath);
    if (normalizedPath.isEmpty) {
      return;
    }

    setState(() {
      _selectedThreadPathByAgentKey.remove(agentKey);
      _selectedThreadLabelByAgentKey.remove(agentKey);
      _newThreadResetVersion++;
    });
    _setComposerAttachmentSeed(agentKey, [normalizedPath]);

    if (!mounted || !context.mounted) {
      return;
    }
    _showDesktopPreviewChatPane(context, agentKey: agentKey);
    _closeResponsiveDesktopPreviewFilePromptSurfaces();
  }

  void _closeResponsiveDesktopPreviewFilePromptSurfaces() {
    _desktopPreviewRoomPanelOverlayController.hide();
    setState(() {
      _desktopPreviewRoomPanelTab = PbRoomPanelTab.agents;
      _desktopPreviewRoomPanelCollapsed = true;
      _desktopPreviewRoomPanelOverlayOpen = false;
      _desktopPreviewFilePreviewFile = null;
      _desktopPreviewFilePreviewOpen = false;
      _desktopPreviewFilePreviewFullscreen = false;
      _desktopPreviewComposerAttachmentPreviewPath = null;
      _desktopPreviewMeetTranscriptPreviewFile = null;
      _desktopPreviewMeetTranscriptPreviewOpen = false;
      _desktopPreviewMeetTranscriptPreviewFullscreen = false;
      _desktopPreviewRestoreTranscriptOverlayOnPreviewClose = false;
    });
    setPreviewFilePreviewFullscreen(false);
  }

  String? _previewAttachmentPath(PbAttachmentListItemData file) {
    final path = file.path?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    return path;
  }

  Widget _buildAttachmentPreviewFallbackContent(PbAttachmentListItemData file) {
    final path = _previewAttachmentPath(file);
    if (path == null) {
      return Center(child: Text(file.title, style: powerboardsSectionTitleStyle()));
    }

    return Center(child: Text(file.title, style: powerboardsSectionTitleStyle()));
  }

  PbFilePreviewSource? _buildAttachmentPreviewSource(PbAttachmentListItemData file) {
    final path = _previewAttachmentPath(file);
    if (path == null) {
      return null;
    }

    return powerboardsV1PreviewSourceForAttachment(room: widget.room, file: file, path: path);
  }

  String? _chatAgentNameForService(ServiceSpec service) {
    final descriptor = serviceConversationDescriptor(service, remoteParticipants: widget.room.messaging.remoteParticipants);
    if (descriptor?.isChat != true) {
      return null;
    }

    final rawAgentName = service.agents.firstOrNull?.name;
    if (rawAgentName == null) {
      return null;
    }

    final agentName = rawAgentName.trim();
    return agentName.isEmpty ? null : agentName;
  }

  ChatFilePromptAction? _fallbackAttachmentFilePromptAction({String? preferredAgentKey}) {
    if (!services.state.isReady) {
      return null;
    }

    final supported = _supportedServices(services.state.value!);
    if (preferredAgentKey != null) {
      final developmentAgentName = _chatCapableDevelopmentAgentNameForRoute(preferredAgentKey, supported);
      if (developmentAgentName != null) {
        return defaultChatFilePromptAction(agentName: developmentAgentName);
      }

      for (final service in supported) {
        if (_serviceId(service) != preferredAgentKey) {
          continue;
        }

        final agentName = _chatAgentNameForService(service);
        if (agentName != null) {
          return defaultChatFilePromptAction(agentName: agentName);
        }
      }
    }

    for (final service in supported) {
      final agentName = _chatAgentNameForService(service);
      if (agentName != null) {
        return defaultChatFilePromptAction(agentName: agentName);
      }
    }

    for (final participant in _developmentParticipants(supported)) {
      if (participantConversationDescriptor(participant)?.isChat != true) {
        continue;
      }

      final agentName = participantDisplayName(participant);
      if (agentName != null) {
        return defaultChatFilePromptAction(agentName: agentName);
      }
    }

    return null;
  }

  List<ChatFilePromptAction> _attachmentFilePromptActions(String path, {String? preferredAgentKey}) {
    if (!services.state.isReady) {
      return const <ChatFilePromptAction>[];
    }

    final actions = resolveChatFilePromptActions(services: services.state.value!, filePath: path);
    if (actions.isNotEmpty) {
      return actions;
    }

    final fallback = _fallbackAttachmentFilePromptAction(preferredAgentKey: preferredAgentKey);
    return fallback == null ? const <ChatFilePromptAction>[] : [fallback];
  }

  Future<void> _startDefaultAttachmentFilePrompt(PbAttachmentListItemData file, {String? agentKey, bool responsiveHandoff = false}) async {
    final path = _previewAttachmentPath(file);
    if (path == null) {
      return;
    }

    final action = _attachmentFilePromptActions(path, preferredAgentKey: agentKey).firstOrNull;
    if (action == null) {
      await showManageAgents();
      return;
    }

    await _handleDesktopPreviewFilePromptRequested(
      context,
      action: action,
      filePath: path,
      preferredAgentKey: agentKey,
      responsiveHandoff: responsiveHandoff,
    );
  }

  Future<void> _showAttachmentArchiveExtractDialog(PbAttachmentListItemData file) async {
    final archivePath = _previewAttachmentPath(file);
    if (archivePath == null || !pbCanExtractArchive(file)) {
      return;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        void closeDialog() {
          Navigator.of(dialogContext).pop();
        }

        return Stack(
          children: [
            PbArchiveExtractPreviewDialog(
              file: file,
              onClose: closeDialog,
              onInspect: (_) => inspectPowerboardsArchive(
                room: widget.room,
                archivePath: archivePath,
                targetFolderName: pbArchiveExtractFolderName(file.title),
              ),
              onConfirm: (inspection) {
                closeDialog();
                unawaited(_extractAttachmentArchiveForPreview(file, inspection));
              },
              onDownload: () {
                closeDialog();
                unawaited(_downloadAttachmentFile(file));
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _extractAttachmentArchiveForPreview(PbAttachmentListItemData file, PbArchiveInspectionResult inspection) async {
    final archivePath = _previewAttachmentPath(file);
    if (archivePath == null) {
      return;
    }

    if (!mounted || !context.mounted) {
      return;
    }

    await startPowerboardsArchiveExtractionWithToast(
      context: context,
      room: widget.room,
      archivePath: archivePath,
      inspection: inspection,
      onOpenResult: _openExtractedAttachmentArchiveForPreview,
    );
  }

  void _openExtractedAttachmentArchiveForPreview(PowerboardsArchiveExtractionOpenTarget target) {
    if (!mounted || !context.mounted) {
      return;
    }

    final previewPath = target.previewPath;
    final rawPath = previewPath ?? (target.targetFolderPath.isEmpty ? '' : '${target.targetFolderPath}/');

    setState(() {
      _desktopPreviewFilePreviewFile = null;
      _desktopPreviewFilePreviewOpen = false;
      _desktopPreviewFilePreviewFullscreen = false;
      _desktopPreviewRoomPanelTab = PbRoomPanelTab.files;
    });
    setPreviewFilePreviewFullscreen(false);
    controller.showFiles();
    _replaceRoomRouteState(context, pane: _MobileRoomPane.files, rawPath: rawPath, clearPreviewOrigin: true);

    _filesHeaderController.openExtractedArchiveForPreview(target);
  }

  Future<void> _downloadAttachmentFile(PbAttachmentListItemData file) async {
    final path = _previewAttachmentPath(file);
    if (path == null) {
      return;
    }

    final url = await widget.room.storage.downloadUrl(path, download: true);
    await launchUrl(Uri.parse(url));
  }

  Future<void> _shareAttachmentFile(PbAttachmentListItemData file) async {
    final path = _previewAttachmentPath(file);
    if (path == null) {
      return;
    }

    try {
      await shareRemoteStorageFile(context: context, client: widget.room, path: path);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ShadToaster.of(context).show(powerboardsToast(title: 'Unable to share file', description: '$error', destructive: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rb = ResponsiveBreakpoints.of(context);
    final isMobile = _usesMobileRoomLayout(context);
    final isSmallDisplay = rb.smallerOrEqualTo("chromebook");
    final isAdaptiveWebapp = isSmallDisplay && !isMobile;

    _syncPreviewRoomRailMenuBridge(context);

    return RoomParticipantsBuilder(
      room: widget.room,
      builder: (context, participants) {
        return MeetingScope(
          client: widget.room,
          builder: (context, meeting) => ListenableBuilder(
            listenable: meeting,
            builder: (context, _) => SignalBuilder(
              builder: (context, _) {
                if (!services.state.isReady) {
                  if (services.state.hasError) {
                    return _buildRoomInitializationError(context, title: "Unable to load room services", error: services.state.error);
                  }

                  final useDesktopUiPreview = !isMobile && powerboardsUsesDesktopUiPreview(context);
                  final actions = _emptyRoomHeaderActions(isMobile: isMobile);
                  final cs = ShadTheme.of(context).colorScheme;
                  if (isMobile) {
                    return PowerboardsMobileOverlayScaffold(
                      leading: _buildMobileRoomLeadingAction(context, filesVisible: false),
                      titleBuilder: (context, _) => _buildMobileRoomNameHeaderTitle(context),
                      trailingActions: const [],
                      titleAlignment: Alignment.centerLeft,
                      backgroundColor: cs.card,
                      scrollIdentity: "room-loading",
                      body: _buildRoomLoading(context, title: "Loading room services"),
                    );
                  }

                  if (useDesktopUiPreview) {
                    return SafeArea(
                      child: ColoredBox(
                        color: cs.card,
                        child: _buildRoomLoading(context, title: "Loading room services"),
                      ),
                    );
                  }

                  return SafeArea(
                    child: ColoredBox(
                      color: cs.card,
                      child: Column(
                        children: [
                          ActionsRow(actions: actions),
                          Expanded(child: _buildRoomLoading(context, title: "Loading room services")),
                        ],
                      ),
                    ),
                  );
                }

                return room.VideoChatConnection(
                  key: videoChatKey,
                  child: ControllerBuilder(
                    controller: controller,
                    builder: (context) {
                      _roomMeetingController = meeting;
                      return ChangeNotifierBuilder(
                        source: widget.room.messaging,
                        builder: (context) {
                          return SignalBuilder(
                            builder: (context, _) {
                              final canViewStorageAllowed = canViewStorage.state.value == true;
                              final filesVisible = canViewStorageAllowed && controller.isFilesShown;
                              final supported = _supportedServices(services.state.value!);
                              final selected = _resolveSelectedAgent(supported, requestedRouteId: _preferredMobileAgentRouteId(context));
                              if (isMobile) {
                                _persistSelectedRoomAgentRouteId(selected.routeId);
                              }
                              final roomCreateChatContext = _resolveMobileChatHeaderContext(supported, selected);
                              final meetingSessionActive = _isMeetingSessionActive(context);
                              final voiceSessionActive = meeting.isConnected && !meetingSessionActive;
                              _syncPreviewRoomRailMenuBridge(
                                context,
                                meetingSessionActive: meetingSessionActive,
                                voiceSessionActive: voiceSessionActive,
                              );
                              final useLandscapePhoneMeetingPane = _isLandscapePhoneViewport(context) && controller.inMeeting;
                              final split = filesVisible || (controller.inMeeting && !useLandscapePhoneMeetingPane);
                              final useDesktopUiPreview = !isMobile && powerboardsUsesDesktopUiPreview(context);

                              if (!_hasVisibleAgents(supported) && !(useDesktopUiPreview && !isMobile)) {
                                final actions = _emptyRoomHeaderActions(isMobile: isMobile);
                                final cs = ShadTheme.of(context).colorScheme;
                                final emptyStateBody = SignalBuilder(
                                  builder: (context, _) {
                                    final ownerResolved = isOwner.state.isReady || isOwner.state.hasError;
                                    final canInstallAgent = isOwner.state.value == true;

                                    if (!ownerResolved) {
                                      return _buildRoomLoading(context, title: "Loading room permissions");
                                    }

                                    if (isMobile) {
                                      return PaneEmptyState(
                                        title: "Welcome to your room",
                                        description: canInstallAgent ? "Install an agent in this room to get started" : null,
                                        showActionOnMobile: canInstallAgent,
                                        pinActionToMobileFooterOnMobile: canInstallAgent,
                                        action: !canInstallAgent
                                            ? null
                                            : ShadButton(
                                                height: powerboardsFooterActionButtonHeight,
                                                onPressed: () async {
                                                  await showManageAgentsSurface(
                                                    context: context,
                                                    room: widget.room,
                                                    projectId: widget.projectId,
                                                    onServiceChanged: () {
                                                      services.refresh();
                                                    },
                                                  );
                                                },
                                                child: Text("Install an Agent"),
                                              ),
                                      );
                                    }

                                    return Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 520),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "Welcome to your room",
                                                style: ShadTheme.of(context).textTheme.h1,
                                                textAlign: TextAlign.center,
                                              ),
                                              if (canInstallAgent) ...[
                                                SizedBox(height: 8),
                                                Text(
                                                  "Install an agent in this room to get started",
                                                  style: ShadTheme.of(context).textTheme.p,
                                                  textAlign: TextAlign.center,
                                                ),
                                                SizedBox(height: 20),
                                                ShadButton(
                                                  onPressed: () async {
                                                    await showManageAgentsSurface(
                                                      context: context,
                                                      room: widget.room,
                                                      projectId: widget.projectId,
                                                      onServiceChanged: () {
                                                        services.refresh();
                                                      },
                                                    );
                                                  },
                                                  child: Text("Install an Agent"),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );

                                if (isMobile) {
                                  return PowerboardsMobileOverlayScaffold(
                                    leading: _buildMobileRoomLeadingAction(context, filesVisible: false),
                                    titleBuilder: (context, _) => _buildMobileRoomNameHeaderTitle(context),
                                    trailingActions: _buildMobileEmptyRoomHeaderActions(
                                      context,
                                      canViewStorageAllowed: canViewStorageAllowed,
                                    ),
                                    titleAlignment: Alignment.centerLeft,
                                    backgroundColor: cs.card,
                                    scrollIdentity: "room-empty",
                                    body: emptyStateBody,
                                  );
                                }

                                return SafeArea(
                                  child: ColoredBox(
                                    color: cs.card,
                                    child: Column(
                                      children: [
                                        ActionsRow(actions: actions),
                                        Expanded(child: emptyStateBody),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return ToolConnectionScope(
                                room: widget.room,
                                tools: [UIToolkit(context: context)],
                                builder: (context, error) {
                                  final cs = ShadTheme.of(context).colorScheme;

                                  if (isMobile) {
                                    final activePane = _mobileActivePane(filesVisible: filesVisible);
                                    final useMobileMeetingHeaderControls =
                                        activePane == _MobileRoomPane.meeting && _isMeetingSessionActive(context);
                                    final mobileBody = controller.inMeeting
                                        ? _buildMeeting(context, null, const [], embedMobileChrome: false)
                                        : filesVisible
                                        ? _buildFilesArea(context, const [], embedMobileChrome: false)
                                        : _buildAgentArea(context, const [], embedMobileChrome: false);

                                    if (activePane == _MobileRoomPane.meeting) {
                                      final theme = ShadTheme.of(context);
                                      final headerTitle = useMobileMeetingHeaderControls
                                          ? _buildMobileMeetingHeaderTitle(context)
                                          : Text(
                                              "Get ready to meet",
                                              style: powerboardsMobileHeaderPrimaryTextStyle(color: theme.colorScheme.foreground),
                                            );

                                      return _buildMobileRoomScaffold(
                                        context,
                                        leadingAction: useMobileMeetingHeaderControls
                                            ? const SizedBox.shrink()
                                            : _buildMobileRoomLeadingAction(context, filesVisible: filesVisible),
                                        title: headerTitle,
                                        trailingActions: _buildLegacyMobileMeetingHeaderActions(
                                          context,
                                          canViewStorageAllowed: canViewStorageAllowed,
                                        ),
                                        titleAlignment: !useMobileMeetingHeaderControls ? Alignment.center : Alignment.centerLeft,
                                        body: mobileBody,
                                        bottomActions: useMobileMeetingHeaderControls
                                            ? const []
                                            : (controller.inMeeting && meetingSessionActive ? meetingActions(context) : const []),
                                      );
                                    }

                                    final filesLocation = activePane == _MobileRoomPane.files ? _mobileFilesLocation(context) : null;
                                    final chatHeaderContext = activePane == _MobileRoomPane.chat
                                        ? _resolveMobileChatHeaderContext(supported, selected)
                                        : null;

                                    return PowerboardsMobileOverlayScaffold(
                                      leading: _buildMobileRoomLeadingAction(context, filesVisible: filesVisible),
                                      titleAlignment: Alignment.centerLeft,
                                      collapseBodyWithHeader: true,
                                      bodyTopPaddingOffset: 0,
                                      restoreChromeAtMaxScrollExtent: activePane == _MobileRoomPane.chat,
                                      collapseBottomSafeAreaWithHeader: activePane != _MobileRoomPane.chat,
                                      titleBuilder: (context, collapseProgress) {
                                        if (activePane == _MobileRoomPane.files && filesLocation != null) {
                                          return _buildMobileFilesContextHeaderTitle(
                                            context,
                                            filesLocation: filesLocation,
                                            collapseProgress: collapseProgress,
                                          );
                                        }

                                        if (chatHeaderContext != null) {
                                          return _buildMobileRoomContextHeaderTitle(
                                            context,
                                            supported: supported,
                                            chatContext: chatHeaderContext,
                                            collapseProgress: collapseProgress,
                                          );
                                        }

                                        return const SizedBox.shrink();
                                      },
                                      trailingActions: _buildMobileRoomHeaderActions(
                                        context,
                                        activePane: activePane,
                                        canViewStorageAllowed: canViewStorageAllowed,
                                        chatContext: roomCreateChatContext,
                                        filesLocation: filesLocation,
                                      ),
                                      backgroundColor: cs.card,
                                      scrollIdentity: switch (activePane) {
                                        _MobileRoomPane.chat =>
                                          "chat:${chatHeaderContext?.agentKey ?? "none"}:${chatHeaderContext?.selectedThreadPath ?? "new"}",
                                        _MobileRoomPane.files => "files:${filesLocation?.folder ?? ""}:${filesLocation?.openedFile ?? ""}",
                                        _MobileRoomPane.meeting => "meeting",
                                      },
                                      body: mobileBody,
                                    );
                                  }

                                  final actions = useDesktopUiPreview
                                      ? const <Widget>[]
                                      : _meetingPaneActions(context, canViewStorageAllowed: canViewStorageAllowed);

                                  return RoomDeveloperLogsListener(
                                    events: events,
                                    client: widget.room,
                                    child: ShadResizablePanelGroup(
                                      axis: .vertical,
                                      showHandle: true,
                                      children: [
                                        ShadResizablePanel(
                                          id: "top",
                                          defaultSize: 1 - defaultDebugSize,
                                          child: useDesktopUiPreview
                                              ? _buildDesktopPreviewRoomSection(
                                                  context,
                                                  supported: supported,
                                                  selected: selected,
                                                  participants: participants,
                                                  canViewStorageAllowed: canViewStorageAllowed,
                                                  isAdaptiveWebapp: isAdaptiveWebapp,
                                                )
                                              : ResizableSplitView(
                                                  allowCollapse: meetingSessionActive,
                                                  minArea1Width: meetingSessionActive ? 58 : 360,
                                                  minArea2Width: 440,
                                                  preferredArea2Fraction: meetingSessionActive ? 0.75 : null,
                                                  minArea2Fraction: meetingSessionActive ? 0.5 : null,
                                                  maxArea2Fraction: null,
                                                  collapseArea1Width: meetingSessionActive ? 300 : null,
                                                  controller: _meetingSplitViewController,
                                                  onCollapsedChanged: (_) {
                                                    if (!mounted) {
                                                      return;
                                                    }

                                                    setState(() {});
                                                  },
                                                  split: split,
                                                  area1: useLandscapePhoneMeetingPane
                                                      ? _buildMeeting(context, null, actions)
                                                      : ColoredBox(
                                                          color: cs.card,
                                                          child: _buildAgentArea(context, [
                                                            if (isMobile) BackButton(projectId: widget.projectId),

                                                            AgentsDropdown(
                                                              projectId: widget.projectId,
                                                              room: widget.room,
                                                              roomDisplayNameOverride: _roomDisplayName,
                                                              roomBreadcrumbMaxWidth: split || isAdaptiveWebapp ? 96 : null,
                                                              roomBreadcrumbEllipsisOnly: split || isAdaptiveWebapp,
                                                              showAdaptiveWebappNavOpener: isAdaptiveWebapp,
                                                              onRoomPressed: () => _showChatPane(context),
                                                              selectedService: selected.service,
                                                              selectedAgentRouteId: selected.routeId,
                                                              services: supported,
                                                              onOpen: services.refresh,
                                                              onManageAgents: isOwner.state.value != true ? null : showManageAgents,
                                                              showRoomBreadcrumb: true,
                                                            ),

                                                            ParticipantsButton(
                                                              participants: participants,
                                                              localParticipant: widget.room.localParticipant,
                                                            ),

                                                            if (!split) ...actions,
                                                          ], showEmbeddedThreadList: !split),
                                                        ),
                                                  area2: !split
                                                      ? Container()
                                                      : filesVisible
                                                      ? _buildFilesArea(context, actions, showDesktopSidetrayToggle: false)
                                                      : controller.inMeeting
                                                      ? _buildMeeting(context, null, actions, showDesktopSidetrayToggle: false)
                                                      : _buildAgentArea(context, actions, showEmbeddedThreadList: false),
                                                ),
                                        ),

                                        if (controller.isDebugShown)
                                          ShadResizablePanel(
                                            id: "bottom",
                                            defaultSize: defaultDebugSize,
                                            minSize: 0,
                                            child: RoomDeveloperConsole(
                                              pricing: null,
                                              events: events,
                                              room: widget.room,
                                              shellImage: "${MeshagentConfig.current!.imageTagPrefix}cli:{SERVER_VERSION}",
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ResourceFetcher<T> extends StatefulWidget {
  const _ResourceFetcher({super.key, required this.uri, required this.builder, required this.mapper});

  final T Function(Uint8List data) mapper;
  final Widget Function(BuildContext context, T? data, Object? error) builder;

  final Uri uri;

  @override
  State createState() => _ResourceFetcherState<T>();
}

class _ResourceFetcherState<T> extends State<_ResourceFetcher<T>> {
  T? data;
  Object? error;

  @override
  void initState() {
    super.initState();

    get(widget.uri).then((value) {
      setState(() {
        data = widget.mapper(value.bodyBytes);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, data, error);
  }
}

class WidgetConfig {
  const WidgetConfig({required this.initialJson, required this.schema});

  final Map<String, dynamic> initialJson;
  final MeshSchema schema;
}
