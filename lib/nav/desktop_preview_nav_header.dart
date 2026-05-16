import 'package:flutter/material.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/nav/nav_rooms.dart';
import 'package:powerboards/powerboards_ui/active.dart';

class DesktopPreviewNavHeader extends StatefulWidget {
  const DesktopPreviewNavHeader({
    super.key,
    required this.projects,
    required this.rooms,
    required this.projectId,
    required this.selectedRoom,
    required this.canCreateRooms,
    required this.onCreateProject,
    required this.onSelectProject,
    required this.onSelectRoom,
    this.onCreateRoom,
    this.avatarInitials = 'JP',
    this.avatarEmail = '',
    this.onManageAccountPressed,
    this.onPreviewTogglePressed,
    this.onLogoutPressed,
  });

  final List<Project> projects;
  final List<Room> rooms;
  final String? projectId;
  final String? selectedRoom;
  final bool canCreateRooms;
  final Future<void> Function() onCreateProject;
  final ValueChanged<Project> onSelectProject;
  final ValueChanged<Room> onSelectRoom;
  final Future<void> Function()? onCreateRoom;
  final String avatarInitials;
  final String avatarEmail;
  final VoidCallback? onManageAccountPressed;
  final VoidCallback? onPreviewTogglePressed;
  final VoidCallback? onLogoutPressed;

  @override
  State<DesktopPreviewNavHeader> createState() => _DesktopPreviewNavHeaderState();
}

enum _DesktopPreviewNavMenu { none, project, room, account }

class _DesktopPreviewNavHeaderState extends State<DesktopPreviewNavHeader> {
  late final TextEditingController _projectFilterController;
  late final TextEditingController _roomFilterController;
  _DesktopPreviewNavMenu _openMenu = _DesktopPreviewNavMenu.none;

  @override
  void initState() {
    super.initState();
    _projectFilterController = TextEditingController();
    _roomFilterController = TextEditingController();
  }

  @override
  void dispose() {
    _projectFilterController.dispose();
    _roomFilterController.dispose();
    super.dispose();
  }

  void _toggleMenu(_DesktopPreviewNavMenu menu) {
    setState(() {
      _openMenu = _openMenu == menu ? _DesktopPreviewNavMenu.none : menu;
    });
  }

  void _closeMenuAndRun(VoidCallback? action) {
    if (action == null) {
      return;
    }

    if (_openMenu != _DesktopPreviewNavMenu.none) {
      setState(() {
        _openMenu = _DesktopPreviewNavMenu.none;
      });
    }

    WidgetsBinding.instance.endOfFrame.then((_) => action());
  }

  String get _projectQuery => _projectFilterController.text.trim().toLowerCase();
  String get _roomQuery => _roomFilterController.text.trim().toLowerCase();

  List<Project> get _filteredProjects {
    if (_projectQuery.isEmpty) {
      return widget.projects;
    }

    return widget.projects.where((project) => project.name.toLowerCase().contains(_projectQuery)).toList();
  }

  List<Room> get _filteredRooms {
    if (_roomQuery.isEmpty) {
      return widget.rooms;
    }

    return widget.rooms.where((room) => roomDisplayName(room).toLowerCase().contains(_roomQuery)).toList();
  }

  String? get _selectedRoomFallbackLabel {
    final selectedRoomName = widget.selectedRoom?.trim();
    if (selectedRoomName == null || selectedRoomName.isEmpty) {
      return null;
    }

    final hasSelectedRoom = widget.rooms.any((room) => room.name == selectedRoomName);
    return hasSelectedRoom ? null : selectedRoomName;
  }

  Widget _buildProjectMenu() {
    final filtering = _projectFilterController.text.trim().isNotEmpty;

    return PbSwitcherMenu(
      width: 240,
      filterPlaceholder: 'Filter projects...',
      filterController: _projectFilterController,
      onFilterChanged: (_) => setState(() {}),
      items: _filteredProjects
          .map(
            (project) => PbSwitcherMenuItem(
              title: project.name,
              selected: project.id == widget.projectId,
              onPressed: () => _closeMenuAndRun(() => widget.onSelectProject(project)),
            ),
          )
          .toList(),
      actionLabel: filtering ? 'Clear results' : 'New Project',
      actionLeadingIconAssetName: 'plus',
      actionLeadingIconTurns: filtering ? -0.125 : 0,
      onActionPressed: () async {
        if (filtering) {
          _projectFilterController.clear();
          setState(() {});
          return;
        }

        _closeMenuAndRun(() {
          widget.onCreateProject();
        });
      },
    );
  }

  Widget _buildRoomMenu() {
    final filtering = _roomFilterController.text.trim().isNotEmpty;

    return PbSwitcherMenu(
      width: 240,
      filterPlaceholder: 'Filter rooms...',
      filterController: _roomFilterController,
      onFilterChanged: (_) => setState(() {}),
      items: [
        if (_selectedRoomFallbackLabel != null && _roomQuery.isEmpty)
          PbSwitcherMenuItem(title: _selectedRoomFallbackLabel!, selected: true),
        ..._filteredRooms.map(
          (room) => PbSwitcherMenuItem(
            title: roomDisplayName(room),
            selected: room.name == widget.selectedRoom,
            onPressed: () => _closeMenuAndRun(() => widget.onSelectRoom(room)),
          ),
        ),
      ],
      actionLabel: filtering
          ? 'Clear results'
          : widget.canCreateRooms
          ? 'New Room'
          : null,
      actionLeadingIconAssetName: 'plus',
      actionLeadingIconTurns: filtering ? -0.125 : 0,
      onActionPressed: () async {
        if (filtering) {
          _roomFilterController.clear();
          setState(() {});
          return;
        }

        if (widget.onCreateRoom == null) {
          return;
        }

        _closeMenuAndRun(() {
          widget.onCreateRoom!();
        });
      },
    );
  }

  Widget _buildAccountMenu() {
    return PbAccountMenu(
      initials: widget.avatarInitials,
      email: widget.avatarEmail,
      onManageAccountPressed: widget.onManageAccountPressed,
      previewTitle: 'End new UI Preview',
      onPreviewPressed: () => _closeMenuAndRun(widget.onPreviewTogglePressed),
      onLogoutPressed: widget.onLogoutPressed == null ? null : () => _closeMenuAndRun(widget.onLogoutPressed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentProject = widget.projects.where((project) => project.id == widget.projectId).firstOrNull;
    final currentRoom = widget.rooms.where((room) => room.name == widget.selectedRoom).firstOrNull;
    final resolvedRoomValue = currentRoom != null ? roomDisplayName(currentRoom) : (_selectedRoomFallbackLabel ?? 'Select room');
    final showRoomSwitcher = widget.rooms.isNotEmpty || ((widget.selectedRoom?.trim().isNotEmpty) ?? false);

    return PbPrimaryHeader(
      shellMobile: false,
      shellIconOnly: false,
      showRoomSwitcher: showRoomSwitcher,
      projectValue: currentProject?.name ?? 'Select project',
      roomValue: resolvedRoomValue,
      projectSelected: _openMenu == _DesktopPreviewNavMenu.project,
      roomSelected: _openMenu == _DesktopPreviewNavMenu.room,
      avatarSelected: _openMenu == _DesktopPreviewNavMenu.account,
      avatarInitials: widget.avatarInitials,
      projectMenu: _openMenu == _DesktopPreviewNavMenu.project ? _buildProjectMenu() : null,
      roomMenu: showRoomSwitcher && _openMenu == _DesktopPreviewNavMenu.room ? _buildRoomMenu() : null,
      avatarMenu: _openMenu == _DesktopPreviewNavMenu.account ? _buildAccountMenu() : null,
      onProjectPressed: () => _toggleMenu(_DesktopPreviewNavMenu.project),
      onRoomPressed: showRoomSwitcher ? () => _toggleMenu(_DesktopPreviewNavMenu.room) : null,
      onAvatarPressed: () => _toggleMenu(_DesktopPreviewNavMenu.account),
    );
  }
}
