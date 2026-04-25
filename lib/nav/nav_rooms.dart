import 'package:flutter/material.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/settings/mobile_room_list_intent.dart';
import 'package:powerboards/settings/selected_room.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:meshagent/meshagent.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';

import 'package:powerboards/meshagent/file_list_primitives.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:powerboards/ui/avatar_menu_button.dart';
import 'package:powerboards/ui/hover_builder.dart';
import 'package:powerboards/ui/pane_header_action_scope.dart';

import 'rename_room_dialog.dart';
import 'delete_room_dialog.dart';
import 'update_room_perms_dialog.dart';

String roomDisplayName(Room room) => (room.metadata['displayName'] as String? ?? room.name).trim();

int _compareRoomNames(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

const double _mobileRoomTileTextLeadingInset = desktopPaneHeaderCompactButtonWidth / 2;
const double _mobileRoomTileActionSlotSize = 24;
const EdgeInsets _mobileRoomTilePadding = EdgeInsets.fromLTRB(_mobileRoomTileTextLeadingInset, 0, 12, 0);

class NavRooms extends StatefulWidget {
  const NavRooms({
    super.key,
    required this.projectId,
    required this.onSelect,
    required this.rooms,
    this.contentPadding,
    this.pendingCreateRoomName,
    this.pendingDeleteRoomName,
    this.onCreateRoom,
    this.onDeleteStarted,
    this.onDeleteFinished,
    this.onScrollActiveChanged,
    required this.onSave,
    required this.onRefresh,
    required this.balanceLow,
    this.selectedRoom,
  });

  final ValueChanged<Room> onSelect;
  final List<Room> rooms;
  final EdgeInsetsGeometry? contentPadding;
  final String? pendingCreateRoomName;
  final VoidCallback? onCreateRoom;
  final ValueChanged<Room>? onDeleteStarted;
  final void Function(Room room, bool deleted)? onDeleteFinished;
  final ValueChanged<bool>? onScrollActiveChanged;
  final VoidCallback onSave;
  final Future<void> Function() onRefresh;
  final String? selectedRoom;
  final String projectId;
  final bool balanceLow;
  final String? pendingDeleteRoomName;

  @override
  State<NavRooms> createState() => _NavRoomsState();
}

class _NavRoomsState extends State<NavRooms> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrollableExtent = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollableExtent());
  }

  @override
  void didUpdateWidget(covariant NavRooms oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rooms.length != widget.rooms.length ||
        oldWidget.pendingCreateRoomName != widget.pendingCreateRoomName ||
        oldWidget.pendingDeleteRoomName != widget.pendingDeleteRoomName) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollableExtent());
    }
  }

  void _syncScrollableExtent([double? maxScrollExtent]) {
    if (!mounted) {
      return;
    }

    final resolvedMaxScrollExtent =
        maxScrollExtent ??
        (_scrollController.hasClients && _scrollController.position.hasContentDimensions
            ? _scrollController.position.maxScrollExtent
            : 0.0);
    final nextHasScrollableExtent = resolvedMaxScrollExtent > 0.5;

    if (_hasScrollableExtent == nextHasScrollableExtent) {
      return;
    }

    setState(() {
      _hasScrollableExtent = nextHasScrollableExtent;
    });

    if (!nextHasScrollableExtent) {
      widget.onScrollActiveChanged?.call(false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trayBoundaryContext = context;
    final pendingCreateIndex = widget.pendingCreateRoomName == null
        ? null
        : widget.rooms.indexWhere((room) => _compareRoomNames(widget.pendingCreateRoomName!, roomDisplayName(room)) < 0);
    final resolvedPendingCreateIndex = pendingCreateIndex == null
        ? null
        : (pendingCreateIndex == -1 ? widget.rooms.length : pendingCreateIndex);
    const collapseThreshold = 12.0;

    bool handleScrollNotification(ScrollNotification notification) {
      if (notification.metrics.axis != Axis.vertical) {
        return false;
      }

      _syncScrollableExtent(notification.metrics.maxScrollExtent);
      widget.onScrollActiveChanged?.call(_hasScrollableExtent && notification.metrics.pixels > collapseThreshold);
      return false;
    }

    return Column(
      children: [
        if (widget.rooms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [if (widget.onCreateRoom != null) ShadButton(onPressed: widget.onCreateRoom, child: const Text('Create room'))],
            ),
          )
        else
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: handleScrollNotification,
              child: RefreshIndicator(
                onRefresh: widget.onRefresh,
                child: ListView.separated(
                  controller: _scrollController,
                  physics: _hasScrollableExtent ? null : const NeverScrollableScrollPhysics(),
                  padding:
                      widget.contentPadding ??
                      const EdgeInsets.fromLTRB(desktopPaneSideHorizontalInset, 10, desktopPaneSideHorizontalInset, 10),
                  itemCount: widget.rooms.length + (widget.pendingCreateRoomName != null ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    if (widget.pendingCreateRoomName != null && i == resolvedPendingCreateIndex) {
                      return _PendingRoomTile(name: widget.pendingCreateRoomName!);
                    }

                    final roomIndex =
                        widget.pendingCreateRoomName != null && resolvedPendingCreateIndex != null && i > resolvedPendingCreateIndex
                        ? i - 1
                        : i;
                    final room = widget.rooms[roomIndex];
                    final selected = room.name == widget.selectedRoom;

                    if (room.name == widget.pendingDeleteRoomName) {
                      return _PendingRoomTile(name: roomDisplayName(room));
                    }

                    return _RoomTile(
                      key: ValueKey(room.name),
                      projectId: widget.projectId,
                      room: room,
                      selected: selected,
                      menuBoundaryContext: trayBoundaryContext,
                      onTap: () => widget.onSelect(room),
                      onSave: widget.onSave,
                      balanceLow: widget.balanceLow,
                      onDeleteStarted: widget.onDeleteStarted,
                      onDeleteFinished: widget.onDeleteFinished,
                    );
                  },
                ),
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
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final textStyle = isMobile
        ? powerboardsFileListTitleStyle().copyWith(color: theme.colorScheme.foreground.withValues(alpha: 0.68))
        : theme.textTheme.p.copyWith(color: theme.colorScheme.foreground.withValues(alpha: 0.68));

    return Container(
      constraints: isMobile ? const BoxConstraints(minHeight: powerboardsFooterActionButtonHeight) : null,
      decoration: BoxDecoration(borderRadius: isMobile ? theme.radius : BorderRadius.circular(4), color: theme.colorScheme.muted),
      child: Padding(
        padding: isMobile ? _mobileRoomTilePadding : const EdgeInsets.only(left: desktopPaneSideListItemLeadingInset),
        child: Row(
          children: [
            Expanded(
              child: Text(name, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (isMobile) const SizedBox(width: 10),
            SizedBox(
              width: isMobile ? _mobileRoomTileActionSlotSize : 40,
              height: isMobile ? _mobileRoomTileActionSlotSize : 40,
              child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
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
          final selectedBackground = isMobile ? powerboardsAvatarAccentColor : cs.secondaryForeground;
          final bg = widget.balanceLow
              ? cs.background
              : (_isDeleting ? cs.muted : (widget.selected ? selectedBackground : Colors.transparent));
          final desktopTextStyle = widget.balanceLow
              ? tt.p.copyWith(color: cs.mutedForeground)
              : (widget.selected ? tt.p.copyWith(color: cs.secondary) : tt.p);
          final mobileReferenceTextStyle = powerboardsFileListTitleStyle().copyWith(
            fontWeight: widget.selected || hovered ? FontWeight.w700 : FontWeight.w400,
          );
          final mobileTextStyle = widget.balanceLow
              ? mobileReferenceTextStyle.copyWith(color: cs.mutedForeground)
              : mobileReferenceTextStyle;
          final baseTextStyle = isMobile ? mobileTextStyle : desktopTextStyle;
          final textColor = (baseTextStyle.color ?? cs.foreground).withValues(alpha: _isDeleting ? 0.55 : (menuOpen ? 0.5 : 1.0));
          final textStyle = baseTextStyle.copyWith(color: textColor);
          final settingsIcon = isMobile && !widget.selected ? LucideIcons.chevronRight : LucideIcons.ellipsis;
          final settingsIconSize = isMobile && !widget.selected ? 20.0 : (isMobile ? 18.0 : 20.0);
          final unselectedMobileIconColor = Color.lerp(cs.border, cs.mutedForeground, 0.36)!;
          final settingsColor = isMobile && !widget.selected
              ? unselectedMobileIconColor
              : (hovered || isMobile ? baseTextStyle.color : Colors.transparent);
          final menuItems = _buildContextMenuItems(context);

          return Container(
            constraints: isMobile ? const BoxConstraints(minHeight: powerboardsFooterActionButtonHeight) : null,
            decoration: BoxDecoration(borderRadius: isMobile ? theme.radius : BorderRadius.circular(4), color: bg),

            child: ShadGestureDetector(
              behavior: HitTestBehavior.opaque,
              cursor: widget.balanceLow ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
              onTap: widget.balanceLow || _isDeleting ? null : widget.onTap,
              child: Padding(
                padding: isMobile ? _mobileRoomTilePadding : const EdgeInsets.only(left: desktopPaneSideListItemLeadingInset),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(name, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),

                    if (_isDeleting)
                      SizedBox(
                        width: isMobile ? _mobileRoomTileActionSlotSize : 40,
                        height: isMobile ? _mobileRoomTileActionSlotSize : 40,
                        child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    else if (!widget.balanceLow) ...[
                      if (isMobile) const SizedBox(width: 10),
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
                            width: isMobile ? _mobileRoomTileActionSlotSize : 40,
                            height: isMobile ? _mobileRoomTileActionSlotSize : 40,
                            child: Center(
                              child: Icon(settingsIcon, size: settingsIconSize, color: settingsColor),
                            ),
                          ),
                        ),
                      ),
                    ],
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
