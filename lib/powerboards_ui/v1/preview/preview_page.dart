import 'package:flutter/material.dart';

import '../theme/pb_colors.dart';
import '../components/layouts/pb_primary_header.dart';
import '../components/layouts/pb_side_rail.dart';
import '../components/menus/pb_account_menu.dart';
import '../components/menus/pb_room_options_menu.dart';
import '../components/menus/pb_switcher_menu.dart';

enum _PreviewOpenMenu { none, project, room, more, account }

class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key});

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  _PreviewOpenMenu _openMenu = _PreviewOpenMenu.none;
  final TextEditingController _projectFilterController =
      TextEditingController();
  final TextEditingController _roomFilterController = TextEditingController();

  final List<String> _projects = ['ACME', 'Powerboards'];
  final List<String> _rooms = ['Product', 'Marketing', 'Client Demos'];

  String _selectedProject = 'ACME';
  String _selectedRoom = 'Product';
  bool _consoleVisible = false;

  @override
  void dispose() {
    _projectFilterController.dispose();
    _roomFilterController.dispose();
    super.dispose();
  }

  void _toggleMenu(_PreviewOpenMenu menu) {
    setState(() {
      _openMenu = _openMenu == menu ? _PreviewOpenMenu.none : menu;
    });
  }

  void _closeMenus() {
    if (_openMenu == _PreviewOpenMenu.none) {
      return;
    }

    setState(() => _openMenu = _PreviewOpenMenu.none);
  }

  List<PbSwitcherMenuItem> get _projectItems {
    final query = _projectFilterController.text.trim().toLowerCase();
    return _projects
        .where(
          (project) => query.isEmpty || project.toLowerCase().contains(query),
        )
        .map(
          (project) => PbSwitcherMenuItem(
            title: project,
            selected: project == _selectedProject,
          ),
        )
        .toList();
  }

  List<PbSwitcherMenuItem> get _roomItems {
    final query = _roomFilterController.text.trim().toLowerCase();
    return _rooms
        .where((room) => query.isEmpty || room.toLowerCase().contains(query))
        .map(
          (room) =>
              PbSwitcherMenuItem(title: room, selected: room == _selectedRoom),
        )
        .toList();
  }

  void _setProjectFilter(String value) => setState(() {});
  void _setRoomFilter(String value) => setState(() {});

  void _clearProjectFilter() {
    _projectFilterController.clear();
    setState(() {});
  }

  void _clearRoomFilter() {
    _roomFilterController.clear();
    setState(() {});
  }

  void _selectProject(String project) {
    setState(() {
      _selectedProject = project;
      _openMenu = _PreviewOpenMenu.none;
    });
  }

  void _selectRoom(String room) {
    setState(() {
      _selectedRoom = room;
      _openMenu = _PreviewOpenMenu.none;
    });
  }

  Future<void> _createProject() async {
    final name = await _promptForName(
      title: 'New Project',
      initialValue: '',
      confirmLabel: 'Create',
    );
    if (name == null || name.isEmpty) {
      return;
    }

    setState(() {
      if (!_projects.contains(name)) {
        _projects.add(name);
      }
      _selectedProject = name;
      _projectFilterController.clear();
      _openMenu = _PreviewOpenMenu.none;
    });
  }

  Future<void> _createRoom() async {
    final name = await _promptForName(
      title: 'New Room',
      initialValue: '',
      confirmLabel: 'Create',
    );
    if (name == null || name.isEmpty) {
      return;
    }

    setState(() {
      if (!_rooms.contains(name)) {
        _rooms.add(name);
      }
      _selectedRoom = name;
      _roomFilterController.clear();
      _openMenu = _PreviewOpenMenu.none;
    });
  }

  Future<void> _renameRoom() async {
    final nextName = await _promptForName(
      title: 'Rename Room',
      initialValue: _selectedRoom,
      confirmLabel: 'Rename',
    );
    if (nextName == null || nextName.isEmpty || nextName == _selectedRoom) {
      return;
    }

    setState(() {
      final index = _rooms.indexOf(_selectedRoom);
      if (index != -1) {
        _rooms[index] = nextName;
      }
      _selectedRoom = nextName;
      _openMenu = _PreviewOpenMenu.none;
    });
  }

  void _deleteRoom() {
    if (_rooms.isEmpty) {
      return;
    }

    setState(() {
      _rooms.remove(_selectedRoom);
      if (_rooms.isEmpty) {
        _rooms.add('New Room');
      }
      _selectedRoom = _rooms.first;
      _openMenu = _PreviewOpenMenu.none;
    });
  }

  void _toggleConsole() {
    setState(() {
      _consoleVisible = !_consoleVisible;
      _openMenu = _PreviewOpenMenu.none;
    });
  }

  Future<String?> _promptForName({
    required String title,
    required String initialValue,
    required String confirmLabel,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return value;
  }

  Widget _buildProjectMenu(double width) {
    final filtering = _projectFilterController.text.trim().isNotEmpty;
    return PbSwitcherMenu(
      width: width,
      filterController: _projectFilterController,
      onFilterChanged: _setProjectFilter,
      items: _projectItems,
      actionLabel: filtering ? 'Clear results' : 'New Project',
      actionLeadingIconAssetName: 'plus',
      actionLeadingIconTurns: filtering ? -0.125 : 0,
      onActionPressed: filtering ? _clearProjectFilter : _createProject,
      onItemPressed: _selectProject,
    );
  }

  Widget _buildRoomMenu(double width) {
    final filtering = _roomFilterController.text.trim().isNotEmpty;
    return PbSwitcherMenu(
      width: width,
      filterController: _roomFilterController,
      onFilterChanged: _setRoomFilter,
      items: _roomItems,
      actionLabel: filtering ? 'Clear results' : 'New Room',
      actionLeadingIconAssetName: 'plus',
      actionLeadingIconTurns: filtering ? -0.125 : 0,
      onActionPressed: filtering ? _clearRoomFilter : _createRoom,
      onItemPressed: _selectRoom,
    );
  }

  Widget _buildRoomOptionsMenu(double width) {
    return PbRoomOptionsMenu(
      width: width,
      consoleLabel: _consoleVisible ? 'Hide console' : 'Show console',
      onRenamePressed: _renameRoom,
      onDeleteRoomPressed: _deleteRoom,
      onToggleConsolePressed: _toggleConsole,
      onPermissionsPressed: _closeMenus,
      onManageAgentsPressed: _closeMenus,
      onKeychainPressed: _closeMenus,
      onShutdownPressed: _closeMenus,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PbColors.surfaceApp,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final shellWidth = constraints.maxWidth;
          final mobile = shellWidth <= 680;
          final iconOnly = shellWidth <= 780 && shellWidth > 680;
          final mobileMenuWidth = shellWidth - 40;

          if (mobile) {
            return Column(
              children: [
                SizedBox(
                  height: 84,
                  child: PbSideRail(
                    moreSelected: _openMenu == _PreviewOpenMenu.more,
                    moreMenu: _openMenu == _PreviewOpenMenu.more
                        ? _buildRoomOptionsMenu(mobileMenuWidth)
                        : null,
                    onMorePressed: () => _toggleMenu(_PreviewOpenMenu.more),
                    accountSelected: _openMenu == _PreviewOpenMenu.account,
                    accountMenu: _openMenu == _PreviewOpenMenu.account
                        ? PbAccountMenu(
                            onManageAccountPressed: _closeMenus,
                            onLogoutPressed: _closeMenus,
                          )
                        : null,
                    onAccountPressed: () =>
                        _toggleMenu(_PreviewOpenMenu.account),
                  ),
                ),
                PbPrimaryHeader(
                  shellMobile: true,
                  shellIconOnly: false,
                  projectValue: _selectedProject,
                  roomValue: _selectedRoom,
                  projectSelected: _openMenu == _PreviewOpenMenu.project,
                  roomSelected: _openMenu == _PreviewOpenMenu.room,
                  projectMenu: _openMenu == _PreviewOpenMenu.project
                      ? _buildProjectMenu(mobileMenuWidth)
                      : null,
                  roomMenu: _openMenu == _PreviewOpenMenu.room
                      ? _buildRoomMenu(mobileMenuWidth)
                      : null,
                  onProjectPressed: () => _toggleMenu(_PreviewOpenMenu.project),
                  onRoomPressed: () => _toggleMenu(_PreviewOpenMenu.room),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _closeMenus,
                    child: const _PreviewWorkspaceBody(),
                  ),
                ),
              ],
            );
          }

          const railWidth = 64.0;
          const headerHeight = 75.0;

          return Stack(
            children: [
              Row(
                children: [
                  const SizedBox(width: railWidth),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.only(top: headerHeight),
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _closeMenus,
                              child: const _PreviewWorkspaceBody(),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: PbPrimaryHeader(
                            shellMobile: false,
                            shellIconOnly: iconOnly,
                            projectValue: _selectedProject,
                            roomValue: _selectedRoom,
                            projectSelected:
                                _openMenu == _PreviewOpenMenu.project,
                            roomSelected: _openMenu == _PreviewOpenMenu.room,
                            avatarSelected:
                                _openMenu == _PreviewOpenMenu.account,
                            projectMenu: _openMenu == _PreviewOpenMenu.project
                                ? _buildProjectMenu(240)
                                : null,
                            roomMenu: _openMenu == _PreviewOpenMenu.room
                                ? _buildRoomMenu(240)
                                : null,
                            avatarMenu: _openMenu == _PreviewOpenMenu.account
                                ? PbAccountMenu(
                                    onManageAccountPressed: _closeMenus,
                                    onLogoutPressed: _closeMenus,
                                  )
                                : null,
                            onProjectPressed: () =>
                                _toggleMenu(_PreviewOpenMenu.project),
                            onRoomPressed: () =>
                                _toggleMenu(_PreviewOpenMenu.room),
                            onAvatarPressed: () =>
                                _toggleMenu(_PreviewOpenMenu.account),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                child: SizedBox(
                  width: railWidth,
                  child: PbSideRail(
                    moreSelected: _openMenu == _PreviewOpenMenu.more,
                    moreMenu: _openMenu == _PreviewOpenMenu.more
                        ? _buildRoomOptionsMenu(240)
                        : null,
                    onMorePressed: () => _toggleMenu(_PreviewOpenMenu.more),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PreviewWorkspaceBody extends StatelessWidget {
  const _PreviewWorkspaceBody();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Color(0x73FFFFFF), child: SizedBox.expand());
  }
}
