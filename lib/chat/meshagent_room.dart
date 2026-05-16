import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:http/http.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/shell/shell_agent.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter/meshagent_flutter.dart';
import 'package:meshagent_flutter_auth/meshagent_flutter_auth.dart';
import 'package:meshagent_flutter_dev/developer_console.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/chat/conversation_descriptor.dart' as ma;
import 'package:meshagent_flutter_shadcn/meetings/meetings.dart';
import 'package:meshagent_flutter_shadcn/markdown_viewer.dart';
import 'package:meshagent_flutter_shadcn/secrets/keychain_dialog.dart';
import 'package:meshagent_flutter_shadcn/storage/transcript_file_name.dart';
import 'package:meshagent_flutter_shadcn/theme/colors.dart';
import 'package:meshagent_flutter_shadcn/viewers/builder.dart';
import 'package:meshagent_flutter_shadcn/voice/voice.dart';

import 'package:powerboards/chat/hangup_button.dart';
import 'package:powerboards/livekit/room.dart' as room;
import 'package:powerboards/livekit/voice_meeting_controls.dart';
import 'package:powerboards/meshagent/agent_participants.dart';
import 'package:powerboards/meshagent/agent_option.dart';
import 'package:powerboards/meshagent/agents_dropdown.dart';
import 'package:powerboards/meshagent/file_preview_origin.dart';
import 'package:powerboards/meshagent/file_list_primitives.dart';
import 'package:powerboards/meshagent/file_table_view.dart';
import 'package:powerboards/meshagent/thread_display_name.dart';
import 'package:powerboards/meshagent/grant.dart' as grant;
import 'package:powerboards/meshagent/loader.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/options_menu.dart';
import 'package:powerboards/meshagent/path.dart';
import 'package:powerboards/meshagent/thread_view.dart';
import 'package:powerboards/meshagent/tool_connection_scope.dart';
import 'package:powerboards/meshagent/tools/ui_toolkit.dart';
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
import 'package:powerboards/powerboards_ui/v1/preview/preview_room_rail_menu.dart';
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

const defaultDebugSize = 0.4;
final meetingHeaderTitleStyle = powerboardsSectionTitleStyle();
const double _meetingToolbarCompactThreshold = 620;
const double _meetingToolbarPreferredExpandedWidth = 640;
const double _meetingToolbarPreferredCompactWidth = _meetingToolbarCompactThreshold;
const double _mobileRoomHeaderGap = 8;
const String _roomPaneQueryParameter = 'pane';

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
    required this.threadListPath,
    required this.selectedThreadPath,
    required this.onResolved,
  });

  final RoomClient client;
  final String threadListPath;
  final String selectedThreadPath;
  final ValueChanged<String?> onResolved;

  @override
  State<_MobileSelectedThreadLabelResolver> createState() => _MobileSelectedThreadLabelResolverState();
}

class _MobileSelectedThreadLabelResolverState extends State<_MobileSelectedThreadLabelResolver> {
  MeshDocument? _document;
  String? _openedThreadListPath;
  String? _lastResolvedDisplayName;

  String _normalizedSelectedThreadPath() => widget.selectedThreadPath.trim();

  String? _displayNameForSelectedThread() {
    final document = _document;
    final selectedThreadPath = _normalizedSelectedThreadPath();
    if (document == null) {
      return defaultThreadDisplayNameFromPath(selectedThreadPath);
    }
    for (final node in document.root.getChildren()) {
      if (node is! MeshElement || node.tagName != "thread") {
        continue;
      }

      final rawPath = node.getAttribute("path");
      if (rawPath is! String || rawPath.trim() != selectedThreadPath) {
        continue;
      }

      final rawName = node.getAttribute("name");
      if (rawName is! String) {
        return defaultThreadDisplayNameFromPath(selectedThreadPath);
      }

      final trimmedName = rawName.trim();
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
    final document = _document;
    final openedThreadListPath = _openedThreadListPath;

    if (document != null) {
      document.removeListener(_onThreadListChanged);
    }

    _document = null;
    _openedThreadListPath = null;

    if (openedThreadListPath != null) {
      try {
        await widget.client.sync.close(openedThreadListPath);
      } catch (_) {}
    }
  }

  Future<void> _rebindDocument() async {
    final nextThreadListPath = widget.threadListPath.trim();
    if (_openedThreadListPath == nextThreadListPath && _document != null) {
      _emitResolved();
      return;
    }

    await _closeDocument();

    try {
      final document = await widget.client.sync.open(nextThreadListPath);
      if (!mounted || widget.threadListPath.trim() != nextThreadListPath) {
        try {
          await widget.client.sync.close(nextThreadListPath);
        } catch (_) {}
        return;
      }

      document.addListener(_onThreadListChanged);
      _document = document;
      _openedThreadListPath = nextThreadListPath;
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

    if (oldWidget.client != widget.client || oldWidget.threadListPath != widget.threadListPath) {
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
  final ResizableSplitViewController _meetingSplitViewController = ResizableSplitViewController();
  final FileManagerViewController _filesHeaderController = FileManagerViewController();
  final PreviewRoomRailMenuBridge _previewRoomRailMenuBridge = PreviewRoomRailMenuBridge();

  final videoChatKey = GlobalKey<room.VideoChatConnectionState>();
  final meetingViewKey = GlobalKey();

  final Map<String, String> _selectedThreadPathByAgentKey = <String, String>{};
  final Map<String, String> _selectedThreadLabelByAgentKey = <String, String>{};
  static const Duration _roomResourceTimeout = Duration(seconds: 30);

  final MeshagentRoomController controller = MeshagentRoomController();
  int _newThreadResetVersion = 0;
  String _lastRoomStatusText = "Connecting to room";
  String? _resolvedRoomDisplayName;
  String? _lastPersistedMobileAgentRouteId;
  String? _lastSyncedRoutePath;
  _MobileRoomPane? _lastSyncedRoutePane;
  bool _didNormalizeInitialDesktopPane = false;
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
      unawaited(_loadRoomDisplayName());
    }
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
    )).where((x) => x.agents.isNotEmpty).toList();
    services.sort(_compareServices);
    return services;
  });

  @override
  void dispose() {
    if (identical(previewRoomRailMenuBridgeListenable.value, _previewRoomRailMenuBridge)) {
      exposePreviewRoomRailMenuBridge(null);
    }
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

  String? _persistedSelectedThreadPathForAgentKey(String? agentKey) {
    final roomName = _roomNameForSelectionPersistence;
    if (roomName == null || agentKey == null) {
      return null;
    }

    final stored = getLastSelectedRoomThread(widget.projectId, roomName, agentKey);
    if (stored == null) {
      return null;
    }

    final trimmed = stored.trim();
    return trimmed.isEmpty ? null : trimmed;
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

  String? _selectedThreadPathForAgentKey(String? agentKey, {bool includePersistedMobileSelection = false}) {
    if (agentKey == null) {
      return null;
    }

    final inMemory = _selectedThreadPathByAgentKey[agentKey];
    if (inMemory != null) {
      return inMemory;
    }

    if (!includePersistedMobileSelection) {
      return null;
    }

    return _persistedSelectedThreadPathForAgentKey(agentKey);
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
    final effectiveDisplayName = resolvedPath == previousPath && resolvedDisplayName == null ? previousDisplayName : resolvedDisplayName;

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

    final roomName = _roomNameForSelectionPersistence;
    if (roomName == null) {
      return;
    }

    if (resolvedPath == null) {
      clearLastSelectedRoomThread(widget.projectId, roomName, agentKey);
      return;
    }

    setLastSelectedRoomThread(widget.projectId, roomName, agentKey, resolvedPath);
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
    if (!_usesMobileRoomLayout(context)) {
      return widget.service;
    }

    return widget.service ?? _persistedSelectedRoomAgentRouteId();
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
      final threadListPath = _resolvedThreadListPath(descriptor?.threadListPath, threadDir: descriptor?.threadDir, agentName: serviceName);
      final supportsThreads = threadListPath != null;
      final rawServiceDescription = service.metadata.description;
      final serviceDescription = rawServiceDescription == null || rawServiceDescription.trim().isEmpty
          ? (supportsVoice && !supportsChat ? "Voice agent" : "Chat agent")
          : rawServiceDescription;
      options.add(
        _MobileRoomContextAgentOption(
          routeId: _serviceId(service),
          name: serviceName,
          description: serviceDescription,
          threadListPath: threadListPath,
          leadingIcon: supportsVoice ? LucideIcons.audioWaveform : LucideIcons.bot,
          supportsThreads: supportsThreads,
          isVoiceOnly: supportsVoice && !supportsChat,
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
      final threadListPath = _resolvedThreadListPath(
        descriptor?.threadListPath,
        threadDir: descriptor?.threadDir,
        agentName: participantName,
      );
      final supportsThreads = threadListPath != null;

      options.add(
        _MobileRoomContextAgentOption(
          routeId: developmentAgentRouteId(participantName),
          name: participantName,
          description: supportsVoice && !supportsChat ? "Development mode voice agent" : "Development mode agent",
          threadListPath: threadListPath,
          leadingIcon: _developmentAgentIcon(participant),
          supportsThreads: supportsThreads,
          isVoiceOnly: supportsVoice && !supportsChat,
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
      threadListPath = _resolvedThreadListPath(descriptor.threadListPath, threadDir: descriptor.threadDir, agentName: agentName);
      supportsThreads = threadListPath != null;
      isVoiceOnly = descriptor.isVoiceOnly == true && descriptor.isChat != true;
      currentThreadLabel = isVoiceOnly ? "Audio session" : "New thread";
    } else if (selection.service != null) {
      final service = selection.service!;
      final descriptor = serviceConversationDescriptor(service, remoteParticipants: widget.room.messaging.remoteParticipants);
      if (descriptor == null || (descriptor.isChat != true && descriptor.isVoiceOnly != true)) {
        return null;
      }

      agentName = service.agents.firstOrNull?.name ?? service.metadata.name;
      threadListPath = _resolvedThreadListPath(descriptor.threadListPath, threadDir: descriptor.threadDir, agentName: agentName);
      supportsThreads = threadListPath != null;
      isVoiceOnly = descriptor.isVoiceOnly == true && descriptor.isChat != true;
      currentThreadLabel = isVoiceOnly ? "Audio session" : "New thread";
    }

    if (agentName == null) {
      return null;
    }

    final agentKey = selection.routeId;
    final selectedThreadPath = supportsThreads ? _selectedThreadPathForAgentKey(agentKey, includePersistedMobileSelection: true) : null;
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
      HangupButton(onPressed: _endMeeting),
      room.MicToggle(),
      room.CameraToggle(),
      room.ChangeSettings(),
    ];
  }

  List<Widget> _meetingToolbarControls(BuildContext context, {bool compact = false}) {
    final primaryControls = _meetingHeaderPrimaryControls(context);
    if (primaryControls.isEmpty) {
      return [];
    }

    final usesMobileRoomLayout = _usesMobileRoomLayout(context);
    final isLandscapePhone = _isLandscapePhoneViewport(context);
    final compactTranscriptionControl = compact && !isLandscapePhone;

    return [
      ...primaryControls,
      if (!usesMobileRoomLayout) room.ShareScreen(compact: compact),
      MeetingToolkits(room: widget.room, compact: compactTranscriptionControl),
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
      builder: (dialogContext) => KeychainDialog(room: widget.room),
    );
  }

  Future<void> _shutdownRoomFromPreviewRail() async {
    final toaster = ShadToaster.of(context);
    final sessionId = widget.room.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      toaster.show(ShadToast.destructive(description: const Text("Unable to shut down room: session id is not available yet.")));
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
      toaster.show(const ShadToast(title: Text("Room shutdown requested")));
      widget.room.dispose();
      await getMeshagentClient().terminate(projectId: widget.projectId, sessionId: sessionId);
    } catch (error) {
      if (!mounted) {
        return;
      }

      toaster.show(ShadToast.destructive(description: Text("Unable to shut down room: $error")));
    }
  }

  void _syncPreviewRoomRailMenuBridge(BuildContext context) {
    final shouldExpose = !ResponsiveBreakpoints.of(context).isMobile && powerboardsUsesDesktopUiPreview(context);
    if (!shouldExpose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (identical(previewRoomRailMenuBridgeListenable.value, _previewRoomRailMenuBridge)) {
          exposePreviewRoomRailMenuBridge(null);
        }
      });
      return;
    }

    _previewRoomRailMenuBridge.configure(
      showRename: true,
      showPermissions: true,
      showManageAgents: isOwner.state.value == true,
      showDeleteRoom: true,
      showKeychain: true,
      showConsoleToggle: canViewDeveloperLogs.state.value == true,
      showShutdown: isOwner.state.value == true,
      consoleLabel: controller.isDebugShown ? 'Hide console' : 'Show console',
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
        _syncPreviewRoomRailMenuBridge(context);
      },
      onShutdownPressed: () => unawaited(_shutdownRoomFromPreviewRail()),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

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
    ValueChanged<String?>? onSelectedThreadPathChanged,
    Widget? emptyState,
    bool hideChatInput = false,
    bool embedMobileChrome = true,
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
    final showInlineThreadList = !isMobile && !showEmbeddedThreadList && hasThreadList;
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
    final currentThreadLabel = selectedThreadPath == null
        ? "New thread"
        : (_selectedThreadLabelForAgentKey(agentKey) ?? defaultThreadDisplayNameFromPath(selectedThreadPath));
    final chatView = Padding(
      padding: EdgeInsets.fromLTRB(chatHorizontalInset, 0, chatHorizontalInset, chatBottomInset),
      child: MeshagentThreadView(
        agentName: agentName,
        threadDisplayMode: threadDisplayMode,
        threadListPath: resolvedThreadListPath,
        newThreadResetVersion: _newThreadResetVersion,
        client: widget.room,
        documentPath: documentPath,
        selectedThreadPath: selectedThreadPath,
        selectedThreadDisplayName: _selectedThreadLabelForAgentKey(agentKey),
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

    return Column(
      children: [
        if (!isMobile || embedMobileChrome) ActionsRow(actions: actions),
        if (!isMobile || embedMobileChrome) _buildDesktopChatViewportCutoffSpacer(context),
        if (!isMobile || embedMobileChrome) _buildAgentsActionRow(context),
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
                              : Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 500, maxHeight: 560),
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
                                      connectedControlsBuilder: (context, meeting) => VoiceMeetingControls(controller: meeting),
                                    ),
                                  ),
                                )),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
    final mobileFilesLocation = isMobile ? _mobileFilesLocation(context) : null;
    final hasOpenedFile = mobileFilesLocation?.openedFile != null;
    final horizontalInset = isMobile ? 0.0 : 20.0;
    final topInset = 0.0;
    final bottomInset = isMobile ? (hasOpenedFile ? 0.0 : 8.0) : desktopPaneBottomInset;
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeeting(
    BuildContext context,
    String? agentName,
    List<Widget> actions, {
    bool embedMobileChrome = true,
    bool showDesktopSidetrayToggle = true,
  }) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;

    final isMobile = _usesMobileRoomLayout(context);
    final meetingIsActive = _isMeetingSessionActive(context);

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

  Widget _buildDesktopPreviewRoomSection(
    BuildContext context, {
    required List<ServiceSpec> supported,
    required _ResolvedAgentSelection selected,
    required List<RemoteParticipant> participants,
    required bool canViewStorageAllowed,
    required bool isAdaptiveWebapp,
  }) {
    if (controller.inMeeting) {
      return _buildMeeting(context, null, const [], showDesktopSidetrayToggle: false);
    }

    if (canViewStorageAllowed && controller.isFilesShown) {
      return _buildFilesArea(context, const [], showDesktopSidetrayToggle: false);
    }

    final chatActions = <Widget>[
      AgentsDropdown(
        projectId: widget.projectId,
        room: widget.room,
        roomDisplayNameOverride: _roomDisplayName,
        roomBreadcrumbMaxWidth: isAdaptiveWebapp ? 96 : null,
        roomBreadcrumbEllipsisOnly: isAdaptiveWebapp,
        showAdaptiveWebappNavOpener: isAdaptiveWebapp,
        onRoomPressed: () => _showChatPane(context),
        selectedService: selected.service,
        selectedAgentRouteId: selected.routeId,
        services: supported,
        onOpen: services.refresh,
        onManageAgents: isOwner.state.value != true ? null : showManageAgents,
        showRoomBreadcrumb: true,
      ),
      ParticipantsButton(participants: participants, localParticipant: widget.room.localParticipant),
    ];

    return ColoredBox(color: ShadTheme.of(context).colorScheme.card, child: _buildAgentArea(context, chatActions));
  }

  void _leaveMeeting() {
    final meetingViewController = Controller.ofType<MeetingViewController>(context);
    final navController = Controller.ofType<NavController>(context);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    videoChatKey.currentState?.hangup();
    meetingViewController.resetToLobby();
    navController.showNav();

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

            final selectedThreadPath = _selectedThreadPathForAgentKey(selectedAgentRouteId, includePersistedMobileSelection: true);
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
                            final rememberedThreadPath = _selectedThreadPathForAgentKey(
                              option.routeId,
                              includePersistedMobileSelection: true,
                            );
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

    final selectedThreadPath = _selectedThreadPathForAgentKey(selectedAgent.routeId, includePersistedMobileSelection: true);
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

  Widget _buildAgentArea(BuildContext context, List<Widget> actions, {bool showEmbeddedThreadList = true, bool embedMobileChrome = true}) {
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
                  selectedThreadPath: _selectedThreadPathForAgentKey(agentKey, includePersistedMobileSelection: isMobile),
                  onSelectedThreadPathChanged: (path) => _setSelectedThreadPath(agentKey, path),
                  embedMobileChrome: embedMobileChrome,
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
                selectedThreadPath: _selectedThreadPathForAgentKey(agentKey, includePersistedMobileSelection: isMobile),
                onSelectedThreadPathChanged: (path) => _setSelectedThreadPath(agentKey, path),
                embedMobileChrome: embedMobileChrome,
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
    return ResponsiveBreakpoints.of(context).isMobile || _isLandscapePhoneViewport(context);
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
          builder: (context, meeting) => SignalBuilder(
            builder: (context, _) {
              if (!services.state.isReady) {
                if (services.state.hasError) {
                  return _buildRoomInitializationError(context, title: "Unable to load room services", error: services.state.error);
                }

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
                            final useLandscapePhoneMeetingPane = _isLandscapePhoneViewport(context) && controller.inMeeting;
                            final split = filesVisible || (controller.inMeeting && !useLandscapePhoneMeetingPane);
                            final useDesktopUiPreview = !isMobile && powerboardsUsesDesktopUiPreview(context);

                            if (!_hasVisibleAgents(supported)) {
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
                                            shellImage: "${MeshagentConfig.current!.imageTagPrefix}cli:{SERVER_VERSION}-esgz",
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
