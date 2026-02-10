import 'package:flutter/material.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/settings/selected_room.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:meshagent/meshagent.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';

import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/ui/hover_builder.dart';

import 'rename_room_dialog.dart';
import 'delete_room_dialog.dart';
import 'update_room_perms_dialog.dart';

String roomDisplayName(Room room) => (room.metadata['displayName'] as String? ?? room.name).trim();

class NavRooms extends StatelessWidget {
  const NavRooms({
    super.key,
    required this.projectId,
    required this.onSelect,
    required this.rooms,
    this.onCreateRoom,
    required this.onSave,
    required this.onRefresh,
    required this.balanceLow,
    this.selectedRoom,
  });

  final ValueChanged<Room> onSelect;
  final List<Room> rooms;
  final VoidCallback? onCreateRoom;
  final VoidCallback onSave;
  final Future<void> Function() onRefresh;
  final String? selectedRoom;
  final String projectId;
  final bool balanceLow;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (rooms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [if (onCreateRoom != null) ShadButton(onPressed: onCreateRoom, child: const Text('Create room'))],
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(10),
                itemCount: rooms.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final room = rooms[i];
                  final selected = room.name == selectedRoom;

                  return _RoomTile(
                    key: ValueKey(room.name),
                    projectId: projectId,
                    room: room,
                    selected: selected,
                    onTap: () => onSelect(room),
                    onSave: onSave,
                    balanceLow: balanceLow,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _RoomTile extends StatefulWidget {
  const _RoomTile({
    super.key,
    required this.projectId,
    required this.room,
    required this.selected,
    required this.onTap,
    required this.onSave,
    required this.balanceLow,
  });

  final String projectId;
  final Room room;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final bool balanceLow;

  @override
  State createState() => _RoomTileState();
}

class _RoomTileState extends State<_RoomTile> {
  final controller = ShadContextMenuController();

  @override
  void dispose() {
    controller.dispose();

    super.dispose();
  }

  List<ShadContextMenuItem> _buildContextMenuItems(BuildContext context) {
    final name = roomDisplayName(widget.room);

    return [
      ShadContextMenuItem(
        height: 40.0,
        leading: Icon(LucideIcons.pencil, size: 16),
        onPressed: () async {
          final newName = await showRenameRoomDialog(context, initialValue: name);

          if (newName == null || newName == name) return;

          final client = getMeshagentClient();

          await client.updateRoom(
            projectId: widget.projectId,
            roomId: widget.room.id,
            name: widget.room.name,
            metadata: {"displayName": newName},
          );

          widget.onSave();
        },
        child: Text('Rename'),
      ),

      ShadContextMenuItem(
        height: 40.0,
        leading: Icon(LucideIcons.trash, size: 16),
        onPressed: () async {
          final confirmed =
              await showDeleteRoomDialog(
                context,
                title: 'Delete room',
                description: 'Are you sure you want to delete the room "$name"? This action cannot be undone.',
                confirmText: 'Delete',
                destructive: true,
              ) ??
              false;

          if (confirmed) {
            final client = getMeshagentClient();
            await client.deleteRoom(projectId: widget.projectId, roomId: widget.room.id);

            widget.onSave();

            if (widget.selected && context.mounted) {
              clearLastSelectedRoom(widget.projectId);
              context.go('/p/${fromUUID(widget.projectId)}');
            }
          }
        },
        child: Text('Delete'),
      ),

      ShadContextMenuItem(
        height: 40.0,
        leading: Icon(LucideIcons.lock, size: 16),
        onPressed: () {
          showUpdateRoomPermsDialog(context, room: widget.room, projectId: widget.projectId);
        },
        child: Text('Permissions'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    final bg = widget.balanceLow ? cs.background : (widget.selected ? cs.secondaryForeground : Colors.transparent);

    final textStyle = widget.balanceLow
        ? tt.p.copyWith(color: cs.mutedForeground)
        : (widget.selected ? tt.p.copyWith(color: cs.secondary) : tt.p);

    final name = roomDisplayName(widget.room);

    return HoverBuilder(
      builder: (context, hovered, focused) {
        final breakpoints = ResponsiveBreakpoints.of(context);
        final isMobile = breakpoints.isMobile;
        final isSmallDisplay = breakpoints.smallerOrEqualTo("chromebook");
        final settingsColor = hovered || isMobile ? textStyle.color : Colors.transparent;

        return Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: bg),

          child: ShadGestureDetector(
            behavior: HitTestBehavior.opaque,
            cursor: widget.balanceLow ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
            onTap: widget.balanceLow ? null : widget.onTap,
            child: Padding(
              padding: EdgeInsets.only(left: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(name, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),

                  if (!widget.balanceLow)
                    ShadContextMenu(
                      anchor: isSmallDisplay
                          ? ShadAnchorAuto(followerAnchor: Alignment.bottomLeft, targetAnchor: Alignment.bottomRight)
                          : null,
                      controller: controller,
                      constraints: const BoxConstraints(minWidth: 200),
                      items: _buildContextMenuItems(context),
                      child: ShadGestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: controller.show,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(child: Icon(LucideIcons.ellipsis, size: 20, color: settingsColor)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
