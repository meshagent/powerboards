import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart';
import 'package:meshagent_flutter_shadcn/file_preview/markdown.dart';
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
import 'package:meshagent_flutter_shadcn/meetings/meetings.dart';
import 'package:meshagent_flutter_shadcn/ui/ui.dart';
import 'package:meshagent_flutter_shadcn/viewers/builder.dart';
import 'package:meshagent_flutter_shadcn/voice/voice.dart';

import 'package:powerboards/chat/hangup_button.dart';
import 'package:powerboards/livekit/room.dart' as room;
import 'package:powerboards/livekit/voice_meeting_controls.dart';
import 'package:powerboards/meshagent/agent_participants.dart';
import 'package:powerboards/meshagent/agent_option.dart';
import 'package:powerboards/meshagent/agents_dropdown.dart';
import 'package:powerboards/meshagent/file_table_view.dart';
import 'package:powerboards/meshagent/file_upload.dart';
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
import 'package:powerboards/nav/update_room_perms_dialog.dart';
import 'package:powerboards/powerboards_controller/powerboards_controller.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/app_context_menu.dart';
import 'package:powerboards/ui/avatar_menu_button.dart';
import 'package:powerboards/ui/keyboard_safe.dart';
import 'package:powerboards/ui/meeting_view.dart';
import 'package:powerboards/ui/powerboards_back_icon_button.dart';
import 'package:powerboards/ui/pane_header_action_scope.dart';
import 'package:powerboards/ui/resizable_split_view.dart';
import 'package:powerboards/ui/sweep_status_text.dart';
import 'package:powerboards/ui/text_validators.dart';

const defaultDebugSize = 0.4;
final meetingHeaderTitleStyle = GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600);
const double _meetingToolbarCompactThreshold = 620;
const double _meetingToolbarPreferredExpandedWidth = 640;
const double _meetingToolbarPreferredCompactWidth = _meetingToolbarCompactThreshold;
const double _mobileRoomHeaderGap = 8;
const double _mobilePlainHeaderTitleInset = 8;
const String _roomPaneQueryParameter = 'pane';
const String _mobileFilesPlaceholderFileName = '.placeholder';

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

    return path.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? "Files";
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
    if (document == null) {
      return null;
    }

    final selectedThreadPath = _normalizedSelectedThreadPath();
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
        return null;
      }

      final trimmedName = rawName.trim();
      return trimmedName.isEmpty ? null : trimmedName;
    }

    return null;
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
  required String tooltip,
  required IconData icon,
  required VoidCallback? onPressed,
  ShadButtonVariant variant = ShadButtonVariant.outline,
  Color? iconColor,
}) {
  final iconWidget = Icon(icon, size: paneHeaderIconButtonIconSize, color: iconColor);

  final button = switch (variant) {
    ShadButtonVariant.primary => ShadIconButton(icon: iconWidget, onPressed: onPressed),
    ShadButtonVariant.destructive => ShadIconButton.destructive(icon: iconWidget, onPressed: onPressed),
    ShadButtonVariant.secondary => ShadIconButton.secondary(icon: iconWidget, onPressed: onPressed),
    ShadButtonVariant.ghost => ShadIconButton.ghost(icon: iconWidget, onPressed: onPressed),
    _ => ShadIconButton.outline(icon: iconWidget, onPressed: onPressed),
  };

  return Tooltip(message: tooltip, child: button);
}

Color _mobileRoomSurfaceColor(BuildContext context) {
  return ShadTheme.of(context).colorScheme.card;
}

class ParticipantsButton extends StatefulWidget {
  const ParticipantsButton({super.key, required this.participants, required this.localParticipant});

  final List<RemoteParticipant> participants;
  final LocalParticipant? localParticipant;

  @override
  State createState() => _ParticipantsButtonState();
}

class _ParticipantsButtonState extends State<ParticipantsButton> {
  late final popoverController = ShadPopoverController();
  final statesController = ShadStatesController();

  String _initialFromText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return "U";

    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  String _initialsFromName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return "U";

    final localPart = trimmed.split("@").first;
    final parts = localPart.split(RegExp(r"[._\- ]+")).where((part) => part.isNotEmpty).toList();

    if (parts.length >= 2) {
      return "${_initialFromText(parts[0])}${_initialFromText(parts[1])}";
    }

    if (parts.length == 1) {
      return _initialFromText(parts[0]);
    }

    return _initialFromText(trimmed);
  }

  Widget _buildOverlapAvatars(List<String> names, Set<ShadState> states) {
    const avatarSize = 38.0;
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
              child: UserAvatarCircle(initials: _initialsFromName(name), size: avatarSize, hovered: hovered),
            ),
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
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
                hoverBackgroundColor: cs.background,
                padding: .zero,
                onPressed: popoverController.toggle,
                decoration: ShadDecoration(shape: .circle),
                child: _buildOverlapAvatars(sortedNames, states),
              );
            },
          )
        : ShadButton.outline(leading: Icon(LucideIcons.users), onPressed: popoverController.toggle, child: Text("+${nameSet.length}"));

    return ShadPopover(
      controller: popoverController,
      popover: (context) => Container(
        width: 250,
        padding: const .symmetric(vertical: 8),
        child: Column(
          spacing: 16,
          mainAxisSize: .min,
          mainAxisAlignment: .start,
          crossAxisAlignment: .start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text("People here right now", style: tt.large),
            ),
            Column(
              spacing: 8,
              mainAxisSize: .min,
              mainAxisAlignment: .start,
              crossAxisAlignment: .start,
              children: sortedNames.map((name) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(LucideIcons.user, size: 16),
                      SizedBox(width: 8),
                      Flexible(child: Text(name, overflow: .ellipsis)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
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
    final buttonVariant = controller.inMeeting
        ? ShadButtonVariant.primary
        : meetingSessionActive
        ? ShadButtonVariant.destructive
        : ShadButtonVariant.outline;
    final iconData = meetingSessionActive ? LucideIcons.circleDot : LucideIcons.video;
    final iconColor = controller.inMeeting && meetingSessionActive ? theme.colorScheme.destructive : null;

    if (isMobile || compact) {
      return _buildPaneHeaderIconButton(
        tooltip: "Meet",
        icon: iconData,
        iconColor: iconColor,
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
          leading: Icon(iconData, color: iconColor),
          onPressed: onPressed ?? () => controller.selectMeetingTab(isMobile: isMobile),
          child: Text("Meet"),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return SizedBox.shrink();
    }

    final act = [...actions];

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
      act.insert(0, Spacer());
    }

    final spacerIndex = act.indexWhere((widget) => widget is Spacer);
    final leadingActions = spacerIndex == -1 ? const <Widget>[] : act.take(spacerIndex).toList(growable: false);
    final trailingActions = spacerIndex == -1 ? act : act.skip(spacerIndex + 1).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveBreakpoints.of(context).isMobile;
        final state = resolvePaneHeaderActionState(constraints, leadingWidth: 320, minimumLeadingWidth: 220, actions: trailingActions);
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
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: leadingActions),
                            ),
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

  final videoChatKey = GlobalKey();
  final meetingViewKey = GlobalKey();

  final Map<String, String> _selectedThreadPathByAgentKey = <String, String>{};
  final Map<String, String> _selectedThreadLabelByAgentKey = <String, String>{};
  static const Duration _roomResourceTimeout = Duration(seconds: 30);

  final MeshagentRoomController controller = MeshagentRoomController();
  int _newThreadResetVersion = 0;
  String _lastRoomStatusText = "Connecting to room";
  String? _lastSyncedRoutePath;
  _MobileRoomPane? _lastSyncedRoutePane;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncViewWithRoute();
  }

  void _syncViewWithRoute() {
    final state = PathRouteMatch.of(context);
    final currentUri = state.uri;
    final path = currentUri.queryParameters['p'];
    final pane = _roomPaneFromUri(currentUri);

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
        if (path != null && path.isNotEmpty) {
          controller.showFiles();
        }
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

  _ResolvedAgentSelection _resolveSelectedAgent(List<ServiceSpec> supported) {
    final requestedRouteId = widget.service;
    if (requestedRouteId != null) {
      final service = supported.firstWhereOrNull((candidate) => _serviceId(candidate) == requestedRouteId);
      if (service != null) {
        return _ResolvedAgentSelection(routeId: requestedRouteId, service: service, developmentParticipant: null);
      }

      final participantName = developmentAgentNameFromRoute(requestedRouteId);
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

      final legacyParticipantId = legacyDevelopmentAgentParticipantIdFromRoute(requestedRouteId);
      if (legacyParticipantId != null) {
        final participant = widget.room.messaging.remoteParticipants.firstWhereOrNull(
          (candidate) => candidate.id == legacyParticipantId && isChatOrVoiceBotParticipant(candidate),
        );
        final participantName = participant == null ? null : participantDisplayName(participant);
        return _ResolvedAgentSelection(
          routeId: participantName == null ? requestedRouteId : developmentAgentRouteId(participantName),
          service: null,
          developmentParticipant: participant,
        );
      }

      return _ResolvedAgentSelection(routeId: requestedRouteId, service: null, developmentParticipant: null);
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

  bool _hasVisibleAgents(List<ServiceSpec> supported) {
    if (supported.isNotEmpty) {
      return true;
    }

    return _developmentParticipants(supported).isNotEmpty;
  }

  String? _selectedThreadAgentKey(List<ServiceSpec> supported) {
    return _resolveSelectedAgent(supported).routeId;
  }

  String? _selectedThreadPathForAgentKey(String? agentKey) {
    if (agentKey == null) {
      return null;
    }

    return _selectedThreadPathByAgentKey[agentKey];
  }

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

    if (resolvedPath == previousPath && resolvedDisplayName == previousDisplayName) {
      return;
    }

    setState(() {
      if (resolvedPath == null) {
        _selectedThreadPathByAgentKey.remove(agentKey);
        _selectedThreadLabelByAgentKey.remove(agentKey);
        _newThreadResetVersion++;
      } else {
        _selectedThreadPathByAgentKey[agentKey] = resolvedPath;
        if (resolvedDisplayName == null) {
          _selectedThreadLabelByAgentKey.remove(agentKey);
        } else {
          _selectedThreadLabelByAgentKey[agentKey] = resolvedDisplayName;
        }
      }
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
    if (threadListPath != null) {
      final trimmed = threadListPath.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    final normalizedThreadDir = _normalizedThreadDocumentDir(threadDir);
    if (normalizedThreadDir == null) {
      final defaultThreadDir = _defaultThreadDocumentDir(agentName);
      if (defaultThreadDir == null) {
        return null;
      }
      return "$defaultThreadDir/index.threadl";
    }

    return "$normalizedThreadDir/index.threadl";
  }

  String getDocumentPath(String? agent, {String? threadDir}) {
    final normalizedThreadDir = _normalizedThreadDocumentDir(threadDir);
    if (normalizedThreadDir != null) {
      return "$normalizedThreadDir/main.thread";
    }

    final defaultThreadDir = _defaultThreadDocumentDir(agent);
    if (defaultThreadDir != null) {
      return "$defaultThreadDir/main.thread";
    }

    return '.threads/main.thread';
  }

  List<Widget> _meetingToolbarControls(BuildContext context, {bool compact = false}) {
    final model = room.VideoRoomModel.maybeOf(context);
    if (model?.room == null) {
      return [];
    }
    final usesMobileRoomLayout = _usesMobileRoomLayout(context);
    final isLandscapePhone = _isLandscapePhoneViewport(context);
    final meetingSessionActive = _isMeetingSessionActive(context);
    final showExpandSplitButton = !usesMobileRoomLayout && meetingSessionActive && _meetingSplitViewController.collapsed;
    final compactTranscriptionControl = compact && !isLandscapePhone;

    return [
      if (showExpandSplitButton)
        Tooltip(
          message: "Expand chat",
          child: ShadIconButton.ghost(
            icon: const Icon(LucideIcons.panelLeftOpen),
            onPressed: () {
              _meetingSplitViewController.expand();
              setState(() {});
            },
          ),
        ),
      HangupButton(
        onPressed: () {
          _endMeeting();
        },
      ),
      room.MicToggle(),
      room.CameraToggle(),
      room.ChangeSettings(),
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
      PaneHeaderActionItem(
        expandedWidth: desktopPaneHeaderInviteButtonWidth,
        compactWidth: desktopPaneHeaderCompactButtonWidth,
        overflowOnCompact: !activeMeetingPane,
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
      PaneHeaderActionItem(
        expandedWidth: desktopPaneHeaderAvatarButtonWidth,
        compactWidth: desktopPaneHeaderAvatarButtonWidth,
        child: UserAvatarMenuButton(projectId: widget.projectId, projects: widget.projects, boundaryContext: context),
      ),
    ];
  }

  Future<void> showManageAgents() async {
    await showShadDialog(
      context: context,
      builder: (context) => ManageAgentsDialog(projectId: widget.projectId, room: widget.room),
    );
    if (!mounted) return;
    services.refresh();
  }

  Widget _buildAgentsActionRow(BuildContext context, {Widget? mobileBelowDropdown}) {
    final isMobile = _usesMobileRoomLayout(context);
    if (!isMobile) return const SizedBox.shrink();

    if (!services.state.isReady) return const SizedBox.shrink();

    final supported = _supportedServices(services.state.value!);
    final selected = _resolveSelectedAgent(supported);
    final dropdown = AgentsDropdown(
      projectId: widget.projectId,
      room: widget.room,
      selectedService: selected.service,
      selectedAgentRouteId: selected.routeId,
      services: supported,
      onOpen: services.refresh,
      onManageAgents: isOwner.state.value != true ? null : showManageAgents,
      boundaryContext: context,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            dropdown,
            if (mobileBelowDropdown != null) ...[const SizedBox(height: 10), mobileBelowDropdown],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileThreadGetStartedActions(
    BuildContext context, {
    required VoidCallback onNewThread,
    required bool isNewThreadSelected,
    required String currentThreadLabel,
    VoidCallback? onManage,
  }) {
    final theme = ShadTheme.of(context);
    final createActionStyle = GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: theme.colorScheme.foreground);
    final secondaryActionStyle = GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: onManage == null ? theme.colorScheme.mutedForeground.withValues(alpha: 0.7) : theme.colorScheme.mutedForeground,
    );

    return Padding(
      padding: powerboardsMobileSecondaryRowPadding,
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onManage ?? onNewThread,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: powerboardsAdaptiveTransitionDuration(context),
                        switchInCurve: powerboardsAdaptiveTransitionInCurve(context),
                        switchOutCurve: powerboardsAdaptiveTransitionOutCurve(context),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(animation), child: child),
                        ),
                        child: Icon(
                          isNewThreadSelected ? LucideIcons.check : LucideIcons.messageSquare,
                          key: ValueKey(currentThreadLabel),
                          size: 16,
                          color: theme.colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          currentThreadLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: createActionStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ShadButton.ghost(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            onPressed: onManage,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("All threads", maxLines: 1, overflow: TextOverflow.visible, softWrap: false, style: secondaryActionStyle),
                const SizedBox(width: 6),
                Icon(LucideIcons.chevronRight, size: 16, color: secondaryActionStyle.color),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  void _replaceRoomRouteState(BuildContext context, {required _MobileRoomPane pane, String? rawPath}) {
    final state = PathRouteMatch.of(context);
    final currentUri = state.uri;
    final updatedQueryParameters = Map<String, String>.from(currentUri.queryParameters);

    updatedQueryParameters[_roomPaneQueryParameter] = _roomPaneQueryValue(pane);

    if (rawPath != null) {
      updatedQueryParameters['p'] = rawPath;
    }

    final newUri = currentUri.replace(queryParameters: updatedQueryParameters);
    if (newUri.toString() == currentUri.toString()) {
      return;
    }

    context.go(newUri.toString());
  }

  void _showChatPane(BuildContext context) {
    controller.showChat();
    _replaceRoomRouteState(context, pane: _MobileRoomPane.chat);
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

    if (ancestorDestinations.isEmpty && filesLocation.openedFile == null) {
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

  Future<void> _uploadFileToRoom(Stream<Uint8List> stream, String path, int totalBytes) async {
    final upload = MeshagentFileUpload(room: widget.room, path: path, dataStream: stream, size: totalBytes);
    await upload.done;
  }

  Future<void> _addFilesToFolder(String path) async {
    await FileUploadHelper.pickAndUploadFiles(path: path, onUpload: _uploadFileToRoom);
  }

  Future<void> _addFolderToCurrentFilesLocation(BuildContext context) async {
    final folder = _mobileFilesLocation(context).folder;
    final result = await showShadDialog<String>(
      context: context,
      builder: (context) {
        return ControlledForm(
          builder: (context, controller, formKey) {
            void submit() {
              if (!formKey.currentState!.saveAndValidate()) {
                return;
              }

              Navigator.of(context).pop(formKey.currentState!.value["name"] ?? "");
            }

            return PowerboardsShadDialog.compact(
              crossAxisAlignment: CrossAxisAlignment.start,
              title: const Text("New folder"),
              actions: [
                ShadButton.outline(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                ShadButton(onPressed: submit, child: const Text("OK")),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    ShadInputFormField(
                      initialValue: "",
                      validator: TextValidators.folder,
                      id: "name",
                      label: const Text("Name"),
                      autofocus: true,
                      onSubmitted: (_) => submit(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || result.trim().isEmpty) {
      return;
    }

    final fileName = joinPaths(folder, "${result.trim()}/$_mobileFilesPlaceholderFileName");
    await _uploadFileToRoom(Stream<Uint8List>.value(Uint8List(0)), fileName, 0);
  }

  Future<void> _showNewTextFileDialogForCurrentFilesLocation(BuildContext context) async {
    final folder = _mobileFilesLocation(context).folder;
    final resolvedName = await showShadDialog<String>(
      context: context,
      builder: (context) {
        return ControlledForm(
          builder: (context, controller, formKey) {
            Future<void> submit(_) async {
              if (!formKey.currentState!.saveAndValidate()) {
                return;
              }

              final String name = (formKey.currentState!.value["name"] ?? "").trim();
              var nextName = name;

              if (!name.contains('.')) {
                final maybeName = await showShadDialog<String>(
                  context: context,
                  builder: (context) => PowerboardsShadDialog.compact(
                    title: const Text("Add .txt extension?"),
                    description: Text("`$name` has no extension."),
                    actions: [
                      ShadButton.outline(onPressed: () => Navigator.of(context).pop(name), child: const Text("No extension")),
                      ShadButton(onPressed: () => Navigator.of(context).pop("$name.txt"), child: const Text("Add .txt")),
                    ],
                  ),
                );

                if (maybeName == null) {
                  return;
                }
                nextName = maybeName;
              }

              if (!context.mounted) {
                return;
              }

              Navigator.of(context).pop(nextName);
            }

            return PowerboardsShadDialog.compact(
              crossAxisAlignment: CrossAxisAlignment.start,
              title: const Text("New Text File"),
              actions: [
                ShadButton.outline(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                ShadButton(onPressed: () => submit(null), child: const Text("OK")),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    ShadInputFormField(
                      id: "name",
                      initialValue: "",
                      validator: (value) => value.trim().isEmpty ? "File name cannot be empty" : null,
                      label: const Text("Name"),
                      autofocus: true,
                      onSubmitted: submit,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (resolvedName == null || resolvedName.trim().isEmpty) {
      return;
    }

    await _uploadFileToRoom(Stream<Uint8List>.value(Uint8List(0)), joinPaths(folder, resolvedName.trim()), 0);
  }

  Widget _buildMobileFilesCreateMenuButton(BuildContext context) {
    final folder = _mobileFilesLocation(context).folder;

    return AppContextMenuButton(
      compact: true,
      boundaryContext: context,
      entries: [
        AppMenuEntry(
          title: "New folder",
          description: "Create a folder in this location.",
          icon: LucideIcons.folderPlus,
          onPressed: () => _addFolderToCurrentFilesLocation(context),
        ),
        AppMenuEntry(
          title: "New text file",
          description: "Create a new text file in this location.",
          icon: LucideIcons.fileText,
          onPressed: () => _showNewTextFileDialogForCurrentFilesLocation(context),
        ),
        AppMenuEntry(
          title: "Upload files",
          description: "Upload files to this folder.",
          icon: LucideIcons.upload,
          onPressed: () => _addFilesToFolder(folder),
        ),
      ],
      constraints: const BoxConstraints(minWidth: 220),
      childBuilder: (context, controller) => Tooltip(
        message: "Create or upload",
        child: ShadIconButton.outline(
          icon: const Icon(LucideIcons.plus, size: paneHeaderIconButtonIconSize),
          onPressed: controller.toggle,
        ),
      ),
    );
  }

  Widget _buildMobileRoomLeadingAction(BuildContext context, {required bool filesVisible}) {
    final pane = _mobileActivePane(filesVisible: filesVisible);

    if (pane == _MobileRoomPane.chat) {
      return BackButton(projectId: widget.projectId);
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
      return Text("Get ready to meet", style: meetingHeaderTitleStyle);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, spacing: desktopPaneHeaderButtonGap, children: controls),
      ),
    );
  }

  Widget _buildMobilePlainHeaderTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: _mobilePlainHeaderTitleInset),
      child: Text(title, style: meetingHeaderTitleStyle),
    );
  }

  List<Widget> _buildMobileEmptyRoomHeaderActions(BuildContext context, {required bool canManageAgents}) {
    return [
      InviteUserButton(projectId: widget.projectId, roomName: widget.room.roomName!),
      if (canManageAgents) _buildPaneHeaderIconButton(tooltip: "Manage agents", icon: LucideIcons.blocks, onPressed: showManageAgents),
    ];
  }

  List<Widget> _buildMobileRoomHeaderActions(BuildContext context, {required bool canViewStorageAllowed, required bool filesVisible}) {
    final pane = _mobileActivePane(filesVisible: filesVisible);
    final filesLocation = pane == _MobileRoomPane.files ? _mobileFilesLocation(context) : null;
    final showMeetingInviteAction = pane == _MobileRoomPane.meeting && _isMeetingSessionActive(context);
    final showFilesHeaderStack = pane == _MobileRoomPane.files;
    final showFilesCreateAction = showFilesHeaderStack && filesLocation?.openedFile == null;
    final meetingSessionActive = _isMeetingSessionActive(context);

    return [
      if (showFilesCreateAction) _buildMobileFilesCreateMenuButton(context),
      if (pane == _MobileRoomPane.chat) InviteUserButton(projectId: widget.projectId, roomName: widget.room.roomName!),
      if (showFilesHeaderStack)
        MeetButton(controller: controller, meetingSessionActive: meetingSessionActive, onPressed: () => _showMeetingPane(context)),
      if (pane == _MobileRoomPane.chat)
        MeetButton(controller: controller, meetingSessionActive: meetingSessionActive, onPressed: () => _showMeetingPane(context)),
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

  List<Widget> _emptyRoomHeaderActions({required bool isSmallDisplay, required bool isMobile}) {
    return [
      if (isSmallDisplay) BackButton(projectId: widget.projectId),
      Spacer(),
      InviteUserButton(projectId: widget.projectId, roomName: widget.room.roomName!),
      if (!isMobile) ...[
        RoomOptionsMenu(
          projectId: widget.projectId,
          room: widget.room,
          roomController: controller,
          isOwner: isOwner,
          canViewDeveloperLogs: canViewDeveloperLogs,
          boundaryContext: context,
        ),
        UserAvatarMenuButton(projectId: widget.projectId, projects: widget.projects, boundaryContext: context),
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
    bool showEmbeddedThreadList = true,
    ChatThreadDisplayMode threadDisplayMode = ChatThreadDisplayMode.singleThread,
    String? threadListPath,
    String? threadDir,
    String? selectedThreadPath,
    ValueChanged<String?>? onSelectedThreadPathChanged,
    Widget? emptyState,
    bool hideChatInput = false,
    bool embedMobileChrome = true,
  }) {
    final user = MeshagentAuth.current.getUser();
    final userEmail = user?["email"];
    final cs = ShadTheme.of(context).colorScheme;
    final documentPath = getDocumentPath(agentName, threadDir: threadDir);
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
    final agentKey = _selectedThreadAgentKey(
      services.state.value == null ? const <ServiceSpec>[] : _supportedServices(services.state.value!),
    );
    final currentThreadLabel = selectedThreadPath == null ? "New thread" : (_selectedThreadLabelForAgentKey(agentKey) ?? "New thread");
    final chatView = Padding(
      padding: EdgeInsets.fromLTRB(chatHorizontalInset, 0, chatHorizontalInset, chatBottomInset),
      child: MeshagentThreadView(
        agentName: agentName,
        threadDisplayMode: threadDisplayMode,
        threadListPath: resolvedThreadListPath,
        newThreadResetVersion: _newThreadResetVersion,
        key: ValueKey("thread-view-$documentPath-${selectedThreadPath ?? "composer"}"),
        client: widget.room,
        documentPath: documentPath,
        selectedThreadPath: selectedThreadPath,
        onSelectedThreadPathChanged: onSelectedThreadPathChanged,
        participantNames: [
          if (userEmail is String && userEmail.isNotEmpty) userEmail,
          if (agentName case final String agentParticipantName) agentParticipantName,
        ],
        newThreadEmptyStateVerticalOffset: newThreadEmptyStateVerticalOffset,
        joinMeeting: _joinMeeting,
        emptyState: meetingActiveSingleThreadEmptyState,
        hideChatInput: hideChatInput,
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
            _buildAgentsActionRow(
              context,
              mobileBelowDropdown: showMobileThreadActions
                  ? _buildMobileThreadGetStartedActions(
                      context,
                      onNewThread: () => onSelectedThreadPathChanged?.call(null),
                      isNewThreadSelected: selectedThreadPath == null,
                      currentThreadLabel: currentThreadLabel,
                      onManage: resolvedThreadListPath == null
                          ? null
                          : () => _showMobileThreadPicker(threadListPath: resolvedThreadListPath, agentKey: agentKey, agentName: agentName),
                    )
                  : null,
            ),
          ] else if (showMobileThreadActions)
            SizedBox(
              height: powerboardsMobileSecondaryRowHeight,
              child: Center(
                child: _buildMobileThreadGetStartedActions(
                  context,
                  onNewThread: () => onSelectedThreadPathChanged?.call(null),
                  isNewThreadSelected: selectedThreadPath == null,
                  currentThreadLabel: currentThreadLabel,
                  onManage: resolvedThreadListPath == null
                      ? null
                      : () => _showMobileThreadPicker(threadListPath: resolvedThreadListPath, agentKey: agentKey, agentName: agentName),
                ),
              ),
            ),
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
                    child: Center(
                      child: participant == null
                          ? ShadButton(child: Text("Start Voice Session"))
                          : ConstrainedBox(
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
                    ),
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

  Widget _buildFilesArea(BuildContext context, List<Widget> actions, {bool embedMobileChrome = true}) {
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
                services: services,
                hideSystem: true,
                mobileShellOwnsHeader: isMobile && !embedMobileChrome,
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

  Widget _buildMeeting(BuildContext context, String? agentName, List<Widget> actions, {bool embedMobileChrome = true}) {
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
                final leadingWidth = meetingIsActive
                    ? _measureActiveMeetingHeaderWidth(constraints.maxWidth)
                    : _measureMeetingHeaderTitleWidth(context, constraints.maxWidth);
                final localActionState = resolvePaneHeaderActionState(
                  constraints,
                  leadingWidth: leadingWidth,
                  minimumLeadingWidth: meetingIsActive ? _meetingToolbarPreferredCompactWidth : 120,
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

  void _leaveMeeting() {
    final meetingViewController = Controller.ofType<MeetingViewController>(context);
    final navController = Controller.ofType<NavController>(context);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    context.findAncestorStateOfType<room.VideoChatConnectionState>()?.hangup();
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
    context.findAncestorStateOfType<room.VideoChatConnectionState>()?.hangup();
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

  Future<void> _showMobileThreadPicker({required String threadListPath, required String? agentKey, required String? agentName}) async {
    await showShadDialog<void>(
      context: context,
      builder: (dialogContext) {
        Widget footerButton({required VoidCallback onPressed, required Widget child, bool primary = false}) {
          final button = primary ? ShadButton.new : ShadButton.outline;
          return SizedBox(
            width: double.infinity,
            child: button(onPressed: onPressed, child: child),
          );
        }

        return PowerboardsShadDialog.listPicker(
          title: const Text("All threads"),
          description: const Text("Select a thread to view."),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360.0, maxHeight: 520.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: Padding(
                    padding: powerboardsDialogScrollableListPadding,
                    child: MeshagentThreadListPane(
                      key: ValueKey("mobile-threads-${agentKey ?? "none"}"),
                      client: widget.room,
                      agentName: agentName,
                      threadListPath: threadListPath,
                      selectedThreadPath: _selectedThreadPathForAgentKey(agentKey),
                      newThreadResetVersion: _newThreadResetVersion,
                      mobileListTopPadding: 0,
                      mobileListBottomPadding: 0,
                      mobileRowVerticalPadding: 16,
                      mobileUseDialogListStyle: true,
                      showCreateItem: false,
                      onSelectedThreadPathChanged: (path) {
                        _setSelectedThreadPath(agentKey, path);
                        Navigator.of(dialogContext).pop();
                      },
                      onSelectedThreadResolved: (path, displayName) {
                        _setSelectedThreadPath(agentKey, path, displayName: displayName);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    footerButton(
                      primary: true,
                      onPressed: () {
                        _setSelectedThreadPath(agentKey, null);
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text("New Thread"),
                    ),
                    const SizedBox(height: 12),
                    footerButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Close")),
                  ],
                ),
              ],
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
            final selected = _resolveSelectedAgent(supported);
            final service = selected.service;
            final developmentParticipant = selected.developmentParticipant;

            if (service == null && developmentParticipant == null) {
              final requestedRouteId = widget.service;
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
                  showEmbeddedThreadList: showEmbeddedThreadList,
                  threadDisplayMode: descriptor!.chatThreadDisplayMode,
                  threadDir: descriptor.threadDir,
                  threadListPath: descriptor.threadListPath,
                  selectedThreadPath: _selectedThreadPathForAgentKey(agentKey),
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
                showEmbeddedThreadList: showEmbeddedThreadList,
                threadDisplayMode: descriptor!.chatThreadDisplayMode,
                threadDir: descriptor.threadDir,
                threadListPath: descriptor.threadListPath,
                selectedThreadPath: _selectedThreadPathForAgentKey(agentKey),
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
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height && size.shortestSide < 600;
  }

  bool _usesMobileRoomLayout(BuildContext context) {
    return ResponsiveBreakpoints.of(context).isMobile || _isLandscapePhoneViewport(context);
  }

  @override
  Widget build(BuildContext context) {
    final rb = ResponsiveBreakpoints.of(context);
    final isMobile = _usesMobileRoomLayout(context);
    final isSmallDisplay = rb.smallerOrEqualTo("chromebook");

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

                final actions = _emptyRoomHeaderActions(isSmallDisplay: isSmallDisplay, isMobile: isMobile);
                if (isMobile) {
                  return _buildMobileRoomScaffold(
                    context,
                    leadingAction: BackButton(projectId: widget.projectId),
                    title: Text(widget.room.roomName ?? "Room", style: meetingHeaderTitleStyle),
                    trailingActions: const [],
                    body: _buildRoomLoading(context, title: "Loading room services"),
                  );
                }

                return SafeArea(
                  child: Column(
                    children: [
                      ActionsRow(actions: actions),
                      Expanded(child: _buildRoomLoading(context, title: "Loading room services")),
                    ],
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
                            final selected = _resolveSelectedAgent(supported);
                            final meetingSessionActive = _isMeetingSessionActive(context);
                            final useLandscapePhoneMeetingPane = _isLandscapePhoneViewport(context) && controller.inMeeting;
                            final split = filesVisible || (controller.inMeeting && !useLandscapePhoneMeetingPane);

                            if (!_hasVisibleAgents(supported)) {
                              final actions = _emptyRoomHeaderActions(isSmallDisplay: isSmallDisplay, isMobile: isMobile);
                              final cs = ShadTheme.of(context).colorScheme;
                              final emptyStateBody = SignalBuilder(
                                builder: (context, _) {
                                  final ownerResolved = isOwner.state.isReady || isOwner.state.hasError;
                                  final canInstallAgent = isOwner.state.value == true;

                                  if (!ownerResolved) {
                                    return _buildRoomLoading(context, title: "Loading room permissions");
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
                                                  await showShadDialog(
                                                    context: context,
                                                    builder: (context) => ManageAgentsDialog(
                                                      room: widget.room,
                                                      projectId: widget.projectId,
                                                      onServiceChanged: () {
                                                        services.refresh();
                                                      },
                                                    ),
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
                                return ColoredBox(
                                  color: cs.card,
                                  child: _buildMobileRoomScaffold(
                                    context,
                                    leadingAction: BackButton(projectId: widget.projectId),
                                    title: const SizedBox.shrink(),
                                    trailingActions: _buildMobileEmptyRoomHeaderActions(
                                      context,
                                      canManageAgents: isOwner.state.value == true,
                                    ),
                                    body: emptyStateBody,
                                  ),
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
                              tools: [UIToolkit(context, room: widget.room)],
                              builder: (context, error) {
                                final cs = ShadTheme.of(context).colorScheme;

                                if (isMobile) {
                                  final activePane = _mobileActivePane(filesVisible: filesVisible);
                                  final useMobileMeetingHeaderControls =
                                      activePane == _MobileRoomPane.meeting && _isMeetingSessionActive(context);
                                  final centerMobileHeaderTitle = activePane == _MobileRoomPane.meeting && !useMobileMeetingHeaderControls;
                                  final headerTitle = switch (activePane) {
                                    _MobileRoomPane.chat => AgentsDropdown(
                                      projectId: widget.projectId,
                                      room: widget.room,
                                      selectedService: selected.service,
                                      selectedAgentRouteId: selected.routeId,
                                      services: supported,
                                      onOpen: services.refresh,
                                      onManageAgents: isOwner.state.value != true ? null : showManageAgents,
                                    ),
                                    _MobileRoomPane.files => _buildMobilePlainHeaderTitle(_mobileFilesLocation(context).title),
                                    _MobileRoomPane.meeting =>
                                      useMobileMeetingHeaderControls
                                          ? _buildMobileMeetingHeaderTitle(context)
                                          : Text("Get ready to meet", style: meetingHeaderTitleStyle),
                                  };

                                  final mobileBody = controller.inMeeting
                                      ? _buildMeeting(context, null, const [], embedMobileChrome: false)
                                      : filesVisible
                                      ? _buildFilesArea(context, const [], embedMobileChrome: false)
                                      : _buildAgentArea(context, const [], embedMobileChrome: false);

                                  return _buildMobileRoomScaffold(
                                    context,
                                    leadingAction: useMobileMeetingHeaderControls
                                        ? const SizedBox.shrink()
                                        : _buildMobileRoomLeadingAction(context, filesVisible: filesVisible),
                                    title: headerTitle,
                                    trailingActions: _buildMobileRoomHeaderActions(
                                      context,
                                      canViewStorageAllowed: canViewStorageAllowed,
                                      filesVisible: filesVisible,
                                    ),
                                    titleAlignment: centerMobileHeaderTitle ? Alignment.center : Alignment.centerLeft,
                                    body: mobileBody,
                                    bottomActions: useMobileMeetingHeaderControls
                                        ? const []
                                        : (controller.inMeeting ? meetingActions(context) : const []),
                                  );
                                }

                                final actions = _meetingPaneActions(context, canViewStorageAllowed: canViewStorageAllowed);

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
                                        child: ResizableSplitView(
                                          key: ValueKey('meeting-split-$meetingSessionActive-$split'),
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
                                                    if (isSmallDisplay) BackButton(projectId: widget.projectId),

                                                    AgentsDropdown(
                                                      projectId: widget.projectId,
                                                      room: widget.room,
                                                      selectedService: selected.service,
                                                      selectedAgentRouteId: selected.routeId,
                                                      services: supported,
                                                      onOpen: services.refresh,
                                                      onManageAgents: isOwner.state.value != true ? null : showManageAgents,
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
                                              ? _buildFilesArea(context, actions)
                                              : controller.inMeeting
                                              ? _buildMeeting(context, null, actions)
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
