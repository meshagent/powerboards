import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/chat/meshagent_room.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/nav/update_room_perms_dialog.dart';
import 'package:powerboards/ui/app_context_menu.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'agent_option.dart';
import 'manage_connectors_dialog.dart';

class RoomOptionsMenu extends StatefulWidget {
  final String projectId;
  final RoomClient room;
  final MeshagentRoomController roomController;
  final Resource<bool> isOwner;
  final Resource<bool> canViewDeveloperLogs;

  const RoomOptionsMenu({
    super.key,
    required this.projectId,
    required this.room,
    required this.roomController,
    required this.isOwner,
    required this.canViewDeveloperLogs,
  });

  @override
  State createState() => _RoomOptionsMenuState();
}

class _RoomOptionsMenuState extends State<RoomOptionsMenu> {
  late final isOwner = widget.isOwner;
  late final canViewDeveloperLogs = widget.canViewDeveloperLogs;

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

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, _) {
        final isOwnerValue = isOwner.state.value == true;
        final canViewDeveloperLogsValue = canViewDeveloperLogs.state.value == true;

        final entries = <AppMenuEntry>[
          AppMenuEntry(
            title: "Permissions",
            description: isOwnerValue ? "Add or remove users from this room." : "View users of this room",
            icon: LucideIcons.user,
            onPressed: _openPermissions,
          ),
          if (isOwnerValue)
            AppMenuEntry(title: "Manage agents", description: "Install or remove agents.", icon: LucideIcons.blocks, onPressed: _addAgent),
          AppMenuEntry(
            title: "Keychain",
            description: "Manage saved connections.",
            icon: LucideIcons.plug,
            onPressed: () {
              showShadDialog<void>(
                context: context,
                builder: (context) => ManageConnectorsDialog(projectId: widget.projectId, room: widget.room),
              );
            },
          ),
          if (canViewDeveloperLogsValue)
            AppMenuEntry(
              title: "Developer console",
              description: "Show or hide the developer console.",
              icon: LucideIcons.terminal,
              selected: widget.roomController.isDebugShown,
              onPressed: widget.roomController.isDebugShown ? widget.roomController.hideDebug : widget.roomController.showDebug,
            ),
        ];

        return AppContextMenuButton(
          entries: entries,
          childBuilder: (context, controller) {
            return Tooltip(
              message: "Room options",
              child: ShadIconButton.outline(
                icon: const Icon(LucideIcons.ellipsis),
                onPressed: () {
                  if (!controller.isOpen) controller.show();
                },
              ),
            );
          },
        );
      },
    );
  }
}
