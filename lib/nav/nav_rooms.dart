import 'package:flutter/material.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/settings/mobile_room_list_intent.dart';
import 'package:powerboards/settings/selected_room.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:meshagent/meshagent.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';

import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:powerboards/ui/hover_builder.dart';
import 'package:powerboards/ui/pane_header_action_scope.dart';

import 'rename_room_dialog.dart';
import 'delete_room_dialog.dart';
import 'update_room_perms_dialog.dart';

String roomDisplayName(Room room) => (room.metadata['displayName'] as String? ?? room.name).trim();

int _compareRoomNames(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

class NavRooms extends StatelessWidget {
  const NavRooms({
    super.key,
    required this.projectId,
    required this.onSelect,
    required this.rooms,
    this.pendingCreateRoomName,
    this.pendingDeleteRoomName,
    this.onCreateRoom,
    this.onDeleteStarted,
    this.onDeleteFinished,
    required this.onSave,
    required this.onRefresh,
    required this.balanceLow,
    this.selectedRoom,
  });

  final ValueChanged<Room> onSelect;
  final List<Room> rooms;
  final String? pendingCreateRoomName;
  final VoidCallback? onCreateRoom;
  final ValueChanged<Room>? onDeleteStarted;
  final void Function(Room room, bool deleted)? onDeleteFinished;
  final VoidCallback onSave;
  final Future<void> Function() onRefresh;
  final String? selectedRoom;
  final String projectId;
  final bool balanceLow;
  final String? pendingDeleteRoomName;

  @override
  Widget build(BuildContext context) {
    final trayBoundaryContext = context;
    final pendingCreateIndex = pendingCreateRoomName == null
        ? null
        : rooms.indexWhere((room) => _compareRoomNames(pendingCreateRoomName!, roomDisplayName(room)) < 0);
    final resolvedPendingCreateIndex = pendingCreateIndex == null ? null : (pendingCreateIndex == -1 ? rooms.length : pendingCreateIndex);

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
                padding: const EdgeInsets.fromLTRB(desktopPaneSideHorizontalInset, 10, desktopPaneSideHorizontalInset, 10),
                itemCount: rooms.length + (pendingCreateRoomName != null ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  if (pendingCreateRoomName != null && i == resolvedPendingCreateIndex) {
                    return _PendingRoomTile(name: pendingCreateRoomName!);
                  }

                  final roomIndex = pendingCreateRoomName != null && resolvedPendingCreateIndex != null && i > resolvedPendingCreateIndex
                      ? i - 1
                      : i;
                  final room = rooms[roomIndex];
                  final selected = room.name == selectedRoom;

                  if (room.name == pendingDeleteRoomName) {
                    return _PendingRoomTile(name: roomDisplayName(room));
                  }

                  return _RoomTile(
                    key: ValueKey(room.name),
                    projectId: projectId,
                    room: room,
                    selected: selected,
                    menuBoundaryContext: trayBoundaryContext,
                    onTap: () => onSelect(room),
                    onSave: onSave,
                    balanceLow: balanceLow,
                    onDeleteStarted: onDeleteStarted,
                    onDeleteFinished: onDeleteFinished,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _PendingRoomTile extends StatelessWidget {
  const _PendingRoomTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final textStyle = theme.textTheme.p.copyWith(color: theme.colorScheme.foreground.withValues(alpha: 0.68));

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: theme.colorScheme.muted),
      child: Padding(
        padding: const EdgeInsets.only(left: desktopPaneSideListItemLeadingInset),
        child: Row(
          children: [
            Expanded(
              child: Text(name, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(
              width: 40,
              height: 40,
              child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomTile extends StatefulWidget {
  const _RoomTile({
    super.key,
    required this.projectId,
    required this.room,
    required this.selected,
    required this.menuBoundaryContext,
    required this.onTap,
    required this.onSave,
    required this.balanceLow,
    this.onDeleteStarted,
    this.onDeleteFinished,
  });

  final String projectId;
  final Room room;
  final bool selected;
  final BuildContext menuBoundaryContext;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final bool balanceLow;
  final ValueChanged<Room>? onDeleteStarted;
  final void Function(Room room, bool deleted)? onDeleteFinished;

  @override
  State createState() => _RoomTileState();
}

class _RoomTileState extends State<_RoomTile> {
  final controller = ShadContextMenuController();
  bool _isDeleting = false;

  @override
  void dispose() {
    controller.dispose();

    super.dispose();
  }

  List<ShadContextMenuItem> _buildContextMenuItems(BuildContext context) {
    final name = roomDisplayName(widget.room);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    final renameItem = ShadContextMenuItem(
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
    );

    final permissionsItem = ShadContextMenuItem(
      height: 40.0,
      leading: Icon(LucideIcons.userPlus, size: 16),
      onPressed: () {
        showUpdateRoomPermsDialog(context, room: widget.room, projectId: widget.projectId);
      },
      child: Text('Permissions'),
    );

    final deleteItem = ShadContextMenuItem(
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
          final shouldShowDeletingState = isMobile && mounted;
          var deleted = false;
          if (shouldShowDeletingState) {
            setState(() {
              _isDeleting = true;
            });
          }

          if (isMobile) {
            widget.onDeleteStarted?.call(widget.room);
          }

          try {
            final client = getMeshagentClient();
            await client.deleteRoom(projectId: widget.projectId, roomId: widget.room.id);
            deleted = true;

            widget.onSave();

            if (widget.selected && context.mounted) {
              clearLastSelectedRoom(widget.projectId);
              if (isMobile) {
                requestStayOnMobileRoomList(widget.projectId);
              }
              context.go('/p/${fromUUID(widget.projectId)}');
            }
          } finally {
            widget.onDeleteFinished?.call(widget.room, deleted);
            if (shouldShowDeletingState && mounted) {
              setState(() {
                _isDeleting = false;
              });
            }
          }
        } else if (mounted) {
          setState(() {
            _isDeleting = false;
          });
        }
      },
      child: Text('Delete'),
    );

    return isMobile ? [renameItem, permissionsItem, deleteItem] : [renameItem, deleteItem, permissionsItem];
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final name = roomDisplayName(widget.room);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => HoverBuilder(
        builder: (context, hovered, focused) {
          final breakpoints = ResponsiveBreakpoints.of(context);
          final isMobile = breakpoints.isMobile;
          final menuOpen = controller.isOpen;
          final bg = widget.balanceLow
              ? cs.background
              : (_isDeleting ? cs.muted : (widget.selected ? cs.secondaryForeground : Colors.transparent));
          final baseTextStyle = widget.balanceLow
              ? tt.p.copyWith(color: cs.mutedForeground)
              : (widget.selected ? tt.p.copyWith(color: cs.secondary) : tt.p);
          final textColor = (baseTextStyle.color ?? cs.foreground).withValues(alpha: _isDeleting ? 0.55 : (menuOpen ? 0.5 : 1.0));
          final textStyle = baseTextStyle.copyWith(color: textColor);
          final settingsColor = hovered || isMobile ? baseTextStyle.color : Colors.transparent;
          final menuItems = _buildContextMenuItems(context);

          return Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: bg),

            child: ShadGestureDetector(
              behavior: HitTestBehavior.opaque,
              cursor: widget.balanceLow ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
              onTap: widget.balanceLow || _isDeleting ? null : widget.onTap,
              child: Padding(
                padding: const EdgeInsets.only(left: desktopPaneSideListItemLeadingInset),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(name, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),

                    if (_isDeleting)
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    else if (!widget.balanceLow)
                      AdaptiveShadContextMenu(
                        controller: controller,
                        boundaryContext: widget.menuBoundaryContext,
                        constraints: const BoxConstraints(minWidth: 200),
                        estimatedMenuWidth: 200,
                        estimatedMenuHeight: menuItems.length * 40.0 + 8.0,
                        items: menuItems,
                        child: ShadGestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: controller.toggle,
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
      ),
    );
  }
}
