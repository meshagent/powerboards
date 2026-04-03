import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/meshagent_flutter_shadcn.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:powerboards/chat/meshagent_room.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/nav/delete_room_dialog.dart';
import 'package:powerboards/nav/update_room_perms_dialog.dart';
import 'package:powerboards/ui/app_context_menu.dart';
import 'package:powerboards/ui/pane_header_action_scope.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'agent_option.dart';

class RoomOptionsMenu extends StatefulWidget {
  final String projectId;
  final RoomClient room;
  final MeshagentRoomController roomController;
  final Resource<bool> isOwner;
  final Resource<bool> canViewDeveloperLogs;
  final BuildContext? boundaryContext;
  final bool showMeetingPaneEntriesInOverflow;
  final bool showFilesAction;
  final bool showMeetAction;
  final VoidCallback? onShowChat;
  final VoidCallback? onShowFiles;
  final VoidCallback? onShowMeet;

  const RoomOptionsMenu({
    super.key,
    required this.projectId,
    required this.room,
    required this.roomController,
    required this.isOwner,
    required this.canViewDeveloperLogs,
    this.boundaryContext,
    this.showMeetingPaneEntriesInOverflow = false,
    this.showFilesAction = false,
    this.showMeetAction = false,
    this.onShowChat,
    this.onShowFiles,
    this.onShowMeet,
  });

  @override
  State createState() => _RoomOptionsMenuState();
}

class _RoomOptionsMenuState extends State<RoomOptionsMenu> {
  late final isOwner = widget.isOwner;
  late final canViewDeveloperLogs = widget.canViewDeveloperLogs;

  bool _usesMobileRoomLayout(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ResponsiveBreakpoints.of(context).isMobile || (size.width > size.height && size.shortestSide < 600);
  }

  Future<void> _addAgent() async {
    await showShadDialog<void>(
      context: context,
      builder: (context) => ManageAgentsDialog(projectId: widget.projectId, room: widget.room),
    );
  }

  Future<void> _openPermissions() async {
    final room = await getMeshagentClient().getRoom(name: widget.room.roomName!, projectId: widget.projectId);
    if (!mounted) return;
    showUpdateRoomPermsDialog(context, projectId: widget.projectId, room: room);
  }

  Future<void> _shutdownRoom() async {
    final toaster = ShadToaster.of(context);
    final sessionId = widget.room.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      toaster.show(ShadToast.destructive(description: Text("Unable to shut down room: session id is not available yet.")));
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
      await getMeshagentClient().terminate(projectId: widget.projectId, sessionId: sessionId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      toaster.show(ShadToast.destructive(description: Text("Unable to shut down room: $error")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, _) {
        final isOwnerValue = isOwner.state.value == true;
        final canViewDeveloperLogsValue = canViewDeveloperLogs.state.value == true;
        final isMobile = _usesMobileRoomLayout(widget.boundaryContext ?? context);
        final overflowCollapsed = CompactHeaderActions.overflowCollapsedOf(context);
        final showPaneEntriesInMenu = widget.showMeetingPaneEntriesInOverflow && (isMobile || overflowCollapsed);
        final showInlineMeetingInvite = widget.showMeetingPaneEntriesInOverflow && !isMobile;

        final entries = <AppMenuEntry>[
          if (showPaneEntriesInMenu)
            AppMenuEntry(
              title: "Chat",
              description: widget.roomController.isFilesShown || widget.roomController.inMeeting
                  ? "Show the chat pane."
                  : "You are viewing chat.",
              icon: LucideIcons.messageSquareText,
              selected: !widget.roomController.isFilesShown && !widget.roomController.inMeeting,
              onPressed: widget.onShowChat ?? widget.roomController.showChat,
            ),
          if (showPaneEntriesInMenu && widget.showFilesAction)
            AppMenuEntry(
              title: "Files",
              description: widget.roomController.isFilesShown
                  ? (isMobile ? "You are viewing files." : "Hide the files pane.")
                  : "Show the files pane.",
              icon: LucideIcons.files,
              selected: widget.roomController.isFilesShown,
              onPressed:
                  widget.onShowFiles ??
                  (isMobile
                      ? () => widget.roomController.selectFilesTab(isMobile: true)
                      : (widget.roomController.isFilesShown ? widget.roomController.hideFiles : widget.roomController.showFiles)),
            ),
          if (showPaneEntriesInMenu && widget.showMeetAction)
            AppMenuEntry(
              title: "Meet",
              description: widget.roomController.inMeeting
                  ? (isMobile ? "You are viewing meet." : "Hide the meeting pane.")
                  : "Show the meeting pane.",
              icon: LucideIcons.video,
              selected: widget.roomController.inMeeting,
              onPressed:
                  widget.onShowMeet ??
                  (isMobile
                      ? () => widget.roomController.selectMeetingTab(isMobile: true)
                      : (widget.roomController.inMeeting ? widget.roomController.exitMeeting : widget.roomController.enterMeeting)),
            ),
          if (!isMobile && overflowCollapsed && !showInlineMeetingInvite)
            AppMenuEntry(
              title: "Invite user",
              description: "Invite someone by email to join this room.",
              icon: LucideIcons.userPlus,
              onPressed: _openPermissions,
              separatorBefore: showPaneEntriesInMenu,
            ),
          AppMenuEntry(
            title: "Permissions",
            description: isOwnerValue ? "Add or remove users from this room." : "View users of this room",
            icon: LucideIcons.userPlus,
            onPressed: _openPermissions,
            separatorBefore: showPaneEntriesInMenu && !(!isMobile && overflowCollapsed && !showInlineMeetingInvite),
          ),
          if (isOwnerValue)
            AppMenuEntry(title: "Manage agents", description: "Install or remove agents.", icon: LucideIcons.blocks, onPressed: _addAgent),
          if (!isMobile)
            AppMenuEntry(
              title: "Keychain",
              description: "Manage saved connections.",
              icon: LucideIcons.plug,
              onPressed: () {
                showShadDialog<void>(
                  context: context,
                  builder: (context) => KeychainDialog(room: widget.room),
                );
              },
            ),
          if (!isMobile && canViewDeveloperLogsValue)
            AppMenuEntry(
              title: "Developer console",
              description: "Show or hide the developer console.",
              icon: LucideIcons.terminal,
              selected: widget.roomController.isDebugShown,
              onPressed: widget.roomController.isDebugShown ? widget.roomController.hideDebug : widget.roomController.showDebug,
            ),
          if (isOwnerValue && !isMobile)
            AppMenuEntry(
              title: "Shutdown",
              description: "Stop the current room session.",
              icon: LucideIcons.circleStop,
              onPressed: _shutdownRoom,
              separatorBefore: canViewDeveloperLogsValue,
            ),
        ];

        return AppContextMenuButton(
          compact: true,
          boundaryContext: widget.boundaryContext ?? context,
          entries: entries,
          constraints: const BoxConstraints(minWidth: 220),
          childBuilder: (context, controller) {
            return Tooltip(
              message: "Room options",
              child: ShadIconButton.outline(
                icon: const Icon(LucideIcons.ellipsis, size: paneHeaderIconButtonIconSize),
                onPressed: controller.toggle,
              ),
            );
          },
        );
      },
    );
  }
}
