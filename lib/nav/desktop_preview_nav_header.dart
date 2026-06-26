import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_desktop_updater/meshagent_flutter_desktop_updater.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/nav/nav_rooms.dart';
import 'package:powerboards/powerboards_ui/active.dart';
import 'package:powerboards/settings/shared_profiles.dart';
import 'package:powerboards/settings/shared_profiles_dialog.dart';
import 'package:powerboards/settings/ui_mode.dart';

class DesktopPreviewNavHeader extends StatefulWidget {
  const DesktopPreviewNavHeader({
    super.key,
    required this.projects,
    required this.rooms,
    required this.projectId,
    required this.selectedRoom,
    required this.canCreateRooms,
    this.shellMobile = false,
    this.shellIconOnly = false,
    this.selectedRoomDisplayNameOverride,
    required this.onCreateProject,
    required this.onSelectProject,
    required this.onSelectRoom,
    this.onCreateRoom,
    this.avatarInitials = 'JP',
    this.avatarEmail = '',
    this.onManageAccountPressed,
    this.onSharePressed,
    this.onPreviewTogglePressed,
    this.onLogoutPressed,
  });

  final List<Project> projects;
  final Resource<List<Room>> rooms;
  final String? projectId;
  final String? selectedRoom;
  final bool canCreateRooms;
  final bool shellMobile;
  final bool shellIconOnly;
  final String? selectedRoomDisplayNameOverride;
  final Future<void> Function() onCreateProject;
  final ValueChanged<Project> onSelectProject;
  final ValueChanged<Room> onSelectRoom;
  final Future<void> Function()? onCreateRoom;
  final String avatarInitials;
  final String avatarEmail;
  final VoidCallback? onManageAccountPressed;
  final VoidCallback? onSharePressed;
  final VoidCallback? onPreviewTogglePressed;
  final VoidCallback? onLogoutPressed;

  @override
  State<DesktopPreviewNavHeader> createState() => _DesktopPreviewNavHeaderState();
}

enum _DesktopPreviewNavMenu { none, room, account }

class _DesktopPreviewNavHeaderState extends State<DesktopPreviewNavHeader> {
  late final TextEditingController _projectFilterController;
  late final TextEditingController _roomFilterController;
  final OverlayPortalController _projectDialogController = OverlayPortalController();
  _DesktopPreviewNavMenu _openMenu = _DesktopPreviewNavMenu.none;
  bool _projectDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _projectFilterController = TextEditingController();
    _roomFilterController = TextEditingController();
  }

  @override
  void dispose() {
    if (_projectDialogController.isShowing) {
      _projectDialogController.hide();
    }
    _projectFilterController.dispose();
    _roomFilterController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DesktopPreviewNavHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId == widget.projectId) {
      return;
    }

    if (_roomFilterController.text.isNotEmpty) {
      _roomFilterController.clear();
    }

    if (_openMenu == _DesktopPreviewNavMenu.room) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _openMenu != _DesktopPreviewNavMenu.room) {
          return;
        }

        setState(() {
          _openMenu = _DesktopPreviewNavMenu.none;
        });
      });
    }
  }

  void _toggleMenu(_DesktopPreviewNavMenu menu) {
    setState(() {
      _openMenu = _openMenu == menu ? _DesktopPreviewNavMenu.none : menu;
    });
  }

  void _closeMenu() {
    if (_openMenu == _DesktopPreviewNavMenu.none) {
      return;
    }

    setState(() {
      _openMenu = _DesktopPreviewNavMenu.none;
    });
  }

  void _closeMenuAndRun(VoidCallback? action) {
    if (action == null) {
      return;
    }

    final hadOpenMenu = _openMenu != _DesktopPreviewNavMenu.none;
    _closeMenu();

    if (!hadOpenMenu) {
      scheduleMicrotask(action);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }

  String get _projectQuery => _projectFilterController.text.trim().toLowerCase();
  String get _roomQuery => _roomFilterController.text.trim().toLowerCase();
  String? get _selectedRoomDisplayNameOverride {
    final override = widget.selectedRoomDisplayNameOverride?.trim();
    return override == null || override.isEmpty ? null : override;
  }

  Project? get _currentProject {
    for (final project in widget.projects) {
      if (project.id == widget.projectId) {
        return project;
      }
    }

    return null;
  }

  List<Room> get _rooms => widget.rooms.state.value ?? const <Room>[];

  List<Project> get _filteredProjects {
    if (_projectQuery.isEmpty) {
      return widget.projects;
    }

    return widget.projects.where((project) => project.name.toLowerCase().contains(_projectQuery)).toList();
  }

  List<Room> get _filteredRooms {
    if (_roomQuery.isEmpty) {
      return _rooms;
    }

    return _rooms.where((room) => _roomDisplayName(room).toLowerCase().contains(_roomQuery)).toList();
  }

  String _roomDisplayName(Room room) {
    final override = _selectedRoomDisplayNameOverride;
    if (override != null && room.name == widget.selectedRoom) {
      return override;
    }

    return roomDisplayName(room);
  }

  String? get _selectedRoomFallbackLabel {
    final selectedRoomName = widget.selectedRoom?.trim();
    if (selectedRoomName == null || selectedRoomName.isEmpty) {
      return null;
    }

    final hasSelectedRoom = _rooms.any((room) => room.name == selectedRoomName);
    return hasSelectedRoom ? null : (_selectedRoomDisplayNameOverride ?? selectedRoomName);
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
            title: _roomDisplayName(room),
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
    final canPreviewNewUi = emailCanPreviewPowerboardsUiMode(widget.avatarEmail);
    final currentUiMode = powerboardsUiModeSignal.value;
    final currentProject = _currentProject;
    final desktopUpdateController = DesktopUpdateControllerScope.maybeOf(context);

    return PbAccountMenu(
      initials: widget.avatarInitials,
      email: widget.avatarEmail,
      projectLabel: 'Browsing project: ${currentProject?.name ?? 'No project selected'}',
      onSelectProjectPressed: () => _closeMenuAndRun(_openProjectDialog),
      onSwitchProfilePressed: isSharedProfilesSupported ? () => _closeMenuAndRun(() => showPowerboardsSharedProfilesDialog(context)) : null,
      onManageAccountPressed: widget.onManageAccountPressed,
      previewTitle: canPreviewNewUi ? (currentUiMode == PowerboardsUiMode.v1 ? 'Old Theme' : 'New Theme') : null,
      previewIconAssetName: currentUiMode == PowerboardsUiMode.v1 ? 'rotate-ccw' : 'eye',
      onPreviewPressed: canPreviewNewUi ? () => _closeMenuAndRun(widget.onPreviewTogglePressed) : null,
      onCheckForUpdatesPressed: desktopUpdateController == null
          ? null
          : () => _closeMenuAndRun(
              () => showDesktopUpdateCheckDialog(context: context, controller: desktopUpdateController, appName: 'Powerboards'),
            ),
      onLogoutPressed: widget.onLogoutPressed == null ? null : () => _closeMenuAndRun(widget.onLogoutPressed),
    );
  }

  void _openProjectDialog() {
    _projectFilterController.clear();
    setState(() {
      _projectDialogOpen = true;
    });
    _projectDialogController.show();
  }

  void _closeProjectDialog() {
    if (!_projectDialogOpen) {
      return;
    }

    _projectDialogController.hide();
    setState(() {
      _projectDialogOpen = false;
    });
  }

  void _selectProjectFromDialog(String projectName) {
    Project? selectedProject;
    for (final project in widget.projects) {
      if (project.name == projectName) {
        selectedProject = project;
        break;
      }
    }

    if (selectedProject == null) {
      return;
    }

    _closeProjectDialog();
    widget.onSelectProject(selectedProject);
  }

  void _createProjectFromDialog() {
    _closeProjectDialog();
    widget.onCreateProject();
  }

  @override
  Widget build(BuildContext context) {
    final currentProject = _currentProject;

    return OverlayPortal(
      controller: _projectDialogController,
      overlayChildBuilder: (context) => PbProjectSelectDialog(
        projects: _filteredProjects.map((project) => project.name).toList(),
        selectedProject: currentProject?.name ?? '',
        filterController: _projectFilterController,
        onFilterChanged: (_) => setState(() {}),
        onProjectSelected: _selectProjectFromDialog,
        onCreateProjectPressed: _createProjectFromDialog,
        onClose: _closeProjectDialog,
      ),
      child: SignalBuilder(
        builder: (context, _) {
          final rooms = _rooms;
          final currentRoom = rooms.where((room) => room.name == widget.selectedRoom).firstOrNull;
          final resolvedRoomValue = currentRoom != null ? _roomDisplayName(currentRoom) : (_selectedRoomFallbackLabel ?? 'Select room');
          final showRoomSwitcher = rooms.isNotEmpty || ((widget.selectedRoom?.trim().isNotEmpty) ?? false);

          return PbPrimaryHeader(
            shellMobile: widget.shellMobile,
            shellIconOnly: widget.shellIconOnly,
            showRoomSwitcher: showRoomSwitcher,
            roomValue: resolvedRoomValue,
            roomSelected: _openMenu == _DesktopPreviewNavMenu.room,
            avatarSelected: _openMenu == _DesktopPreviewNavMenu.account,
            avatarInitials: widget.avatarInitials,
            roomMenu: showRoomSwitcher && _openMenu == _DesktopPreviewNavMenu.room ? _buildRoomMenu() : null,
            avatarMenu: _openMenu == _DesktopPreviewNavMenu.account ? _buildAccountMenu() : null,
            onRoomPressed: showRoomSwitcher ? () => _toggleMenu(_DesktopPreviewNavMenu.room) : null,
            onAvatarPressed: () => _toggleMenu(_DesktopPreviewNavMenu.account),
            onRoomDismissRequested: _closeMenu,
            onAvatarDismissRequested: _closeMenu,
            onSharePressed: widget.onSharePressed,
          );
        },
      ),
    );
  }
}
