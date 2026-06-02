import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as fs;
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:localstorage/localstorage.dart';
import 'package:meshagent_flutter_auth/meshagent_auth.dart';
import 'package:powerboards/ui/avatar_menu_button.dart';
import 'package:powerboards/ui/desktop_sidetray_toggle.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/meshagent/room_not_found.dart';
import 'package:powerboards/powerboards_controller/powerboards_controller.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/settings/mobile_room_list_intent.dart';
import 'package:powerboards/settings/selected_room.dart';
import 'package:powerboards/settings/ui_mode.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_side_rail.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_room_options_menu.dart';
import 'package:powerboards/powerboards_ui/v1/preview/preview_room_rail_menu.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_tokens.dart';
import 'package:powerboards/nav/switch_project_dialog.dart';
import 'package:powerboards/nav/update_room_perms_dialog.dart';
import 'package:powerboards/meshagent/file_preview_origin.dart';
import 'package:powerboards/ui/empty_states.dart';
import 'package:powerboards/ui/keyboard_safe.dart';
import 'package:powerboards/ui/pane_header_action_scope.dart';
import 'package:powerboards/ui/powerboards_adaptive_input.dart';
import 'package:powerboards/ui/powerboards_breakpoints.dart';
import 'package:powerboards/ui/powerboards_mobile_overlay_header.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';

import 'package:meshagent/meshagent.dart';

import 'chrome_visibility.dart';
import 'desktop_preview_nav_header.dart';
import 'nav_rooms.dart';

const double _navBarMinWidth = 280.0;
const double _navBarMaxWidth = 560.0;

const double balanceLowThreshold = 200.0;
const double navBarWidth = 280.0;
final double _mobileSidetrayContentHorizontalInset = powerboardsMobileFlowDialogCompactPadding.left;
final EdgeInsets _mobileSidetrayHorizontalPadding = EdgeInsets.symmetric(horizontal: _mobileSidetrayContentHorizontalInset);

class NavController extends Controller {
  bool _hideNav = false;
  bool _desktopSidetrayCollapsed = true;
  bool _mobileRoomListOpen = false;

  bool get isNavHidden => _hideNav;
  bool get isDesktopSidetrayCollapsed => _desktopSidetrayCollapsed;
  bool get isMobileRoomListOpen => _mobileRoomListOpen;

  void hideNav() {
    _hideNav = true;
    notifyListeners();
  }

  void showNav() {
    _hideNav = false;
    notifyListeners();
  }

  void collapseDesktopSidetray() {
    if (_desktopSidetrayCollapsed) {
      return;
    }

    _desktopSidetrayCollapsed = true;
    notifyListeners();
  }

  void expandDesktopSidetray() {
    if (!_desktopSidetrayCollapsed) {
      return;
    }

    _desktopSidetrayCollapsed = false;
    notifyListeners();
  }

  void toggleDesktopSidetray() {
    if (_desktopSidetrayCollapsed) {
      expandDesktopSidetray();
      return;
    }

    collapseDesktopSidetray();
  }

  void openMobileRoomList() {
    if (_mobileRoomListOpen) {
      return;
    }

    _mobileRoomListOpen = true;
    notifyListeners();
  }

  void closeMobileRoomList() {
    if (!_mobileRoomListOpen) {
      return;
    }

    _mobileRoomListOpen = false;
    notifyListeners();
  }

  void toggleMobileRoomList() {
    if (_mobileRoomListOpen) {
      closeMobileRoomList();
      return;
    }

    openMobileRoomList();
  }
}

class Nav extends StatefulWidget {
  const Nav({super.key, this.selectedRoom, required this.child, this.projectId, required this.projects});

  final String? projectId;
  final String? selectedRoom;
  final Widget child;
  final Resource<List<Project>> projects;

  @override
  State createState() => _NavState();
}

enum _MobileRoomlessCloseAction { createRoom, switchProject }

class _MobileSidetrayCloseButton extends StatelessWidget {
  const _MobileSidetrayCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ShadIconButton.ghost(
      onPressed: onPressed,
      width: desktopPaneHeaderCompactButtonWidth,
      height: desktopPaneHeaderCompactButtonWidth,
      padding: EdgeInsets.zero,
      foregroundColor: theme.colorScheme.foreground.withValues(alpha: .58),
      hoverBackgroundColor: Colors.transparent,
      hoverForegroundColor: theme.colorScheme.foreground,
      pressedForegroundColor: theme.colorScheme.foreground,
      icon: const Icon(LucideIcons.x, size: 24),
    );
  }
}

({String title, String description}) powerboardsMobileCreditBannerCopy({required bool outOfCredit, required ProjectRole? userRole}) {
  if (!outOfCredit) {
    return (title: "Low balance", description: "Add more credits to avoid service interruption.");
  }

  return (
    title: "Out of credit",
    description: userRole == ProjectRole.admin ? "Add more credits to re-enable rooms." : "Contact your project admin to add more credits.",
  );
}

class _NavState extends State<Nav> with SingleTickerProviderStateMixin {
  int _mobileNavigationDirection = 1;
  double _mobileRoomListDragOffset = 0;
  String? _mobilePendingCreateProjectId;
  String? _mobilePendingCreateRoomName;
  String? _mobilePendingDeleteProjectId;
  String? _mobilePendingDeleteRoomName;
  bool _mobileRoomListFilterMode = false;
  bool _mobileRoomListScrollCollapsed = false;
  int _mobileRoomListInstance = 0;
  bool _previewRailMoreMenuOpen = false;
  String? _selectedRoomDisplayNameOverrideProjectId;
  String? _selectedRoomDisplayNameOverrideRoomName;
  String? _selectedRoomDisplayNameOverride;
  late final AnimationController _mobileRoomListCloseAnimationController;
  final childKey = GlobalKey();

  Resource<List<Project>> get projects {
    return widget.projects;
  }

  late final isBalanceLowRes = Resource<bool>(() => isBalanceLow(widget.projectId));
  late final role = Resource<ProjectRole?>(() async {
    if (widget.projectId == null) {
      return null;
    }

    final client = getMeshagentClient();

    try {
      return (await client.getProjectRole(widget.projectId!)).role;
    } on ForbiddenException {
      return ProjectRole.none;
    }
  });

  late final balanceRes = Resource<Balance?>(() async {
    if (role.state.value == ProjectRole.admin) {
      final client = getMeshagentClient();

      return await client.getBalance(widget.projectId!);
    }

    return null;
  }, source: role);

  String filter = "";
  final _mobileRoomListProjectId = Signal<String?>(null);
  final _mobileRoomListSelectedRoom = Signal<String?>(null);
  String? _roomsResourceProjectId;
  late Resource<List<Room>> rooms;
  late final mobileRoomListRooms = Resource<List<Room>>(() async {
    final projectId = _effectiveMobileRoomListProjectId;

    return projectId == null ? [] : await listMeshagentRooms(projectId);
  }, source: _mobileRoomListProjectId);

  late final canCreateRooms = Resource<bool>(() async {
    final projectId = widget.projectId;

    if (projectId == null) {
      return false;
    }

    if (role.state.value == ProjectRole.none) {
      return false;
    }

    final client = getMeshagentClient();

    return await client.canCreateRooms(projectId);
  }, source: role);

  void setFilter(String value) {
    setState(() {
      filter = value;
    });
  }

  String? get _effectiveMobileRoomListProjectId {
    return _mobileRoomListProjectId.value ?? widget.projectId;
  }

  String? get _effectiveMobileRoomListSelectedRoom {
    return _mobileRoomListSelectedRoom.value ?? widget.selectedRoom;
  }

  Resource<List<Room>> _createRoomsResource([String? projectIdOverride]) {
    final projectId = projectIdOverride ?? widget.projectId ?? localStorage.getItem("lastProjectId");
    _roomsResourceProjectId = projectId;

    return Resource<List<Room>>(() async {
      return projectId == null ? [] : await listMeshagentRooms(projectId);
    });
  }

  String? get _effectiveSelectedRoomDisplayNameOverride {
    final projectId = widget.projectId;
    final roomName = widget.selectedRoom;
    final displayName = _selectedRoomDisplayNameOverride?.trim();
    if (projectId == null || roomName == null || displayName == null || displayName.isEmpty) {
      return null;
    }

    if (_selectedRoomDisplayNameOverrideProjectId != projectId || _selectedRoomDisplayNameOverrideRoomName != roomName) {
      return null;
    }

    return displayName;
  }

  void _setSelectedRoomDisplayNameOverride({required String projectId, required String roomName, required String displayName}) {
    if (projectId != widget.projectId || roomName != widget.selectedRoom) {
      return;
    }

    final trimmedDisplayName = displayName.trim();
    if (trimmedDisplayName.isEmpty) {
      return;
    }

    setState(() {
      _selectedRoomDisplayNameOverrideProjectId = projectId;
      _selectedRoomDisplayNameOverrideRoomName = roomName;
      _selectedRoomDisplayNameOverride = trimmedDisplayName;
    });
  }

  void _clearSelectedRoomDisplayNameOverride() {
    if (_selectedRoomDisplayNameOverrideProjectId == null &&
        _selectedRoomDisplayNameOverrideRoomName == null &&
        _selectedRoomDisplayNameOverride == null) {
      return;
    }

    setState(() {
      _selectedRoomDisplayNameOverrideProjectId = null;
      _selectedRoomDisplayNameOverrideRoomName = null;
      _selectedRoomDisplayNameOverride = null;
    });
  }

  void _resetMobileRoomListBrowsingState() {
    if (_mobileRoomListProjectId.value != null) {
      _mobileRoomListProjectId.value = null;
    }

    if (_mobileRoomListSelectedRoom.value != null) {
      _mobileRoomListSelectedRoom.value = null;
    }
  }

  void _browseProjectInMobileRoomList(String projectId) {
    _mobileRoomListProjectId.value = projectId;
    _mobileRoomListSelectedRoom.value = getLastSelectedRoom(projectId);
  }

  void _setMobileRoomListFilterMode(bool enabled) {
    if (_mobileRoomListFilterMode == enabled) {
      return;
    }

    setState(() {
      _mobileRoomListFilterMode = enabled;
      if (enabled) {
        _mobileRoomListScrollCollapsed = false;
      }
    });
  }

  void _setMobileRoomListScrollCollapsed(bool collapsed) {
    if (_mobileRoomListScrollCollapsed == collapsed) {
      return;
    }

    setState(() {
      _mobileRoomListScrollCollapsed = collapsed;
    });
  }

  void _reinitializeMobileRoomListScroll() {
    setState(() {
      _mobileRoomListScrollCollapsed = false;
      _mobileRoomListInstance++;
    });
  }

  void _setMobilePendingCreateRoom(String projectId, String roomName) {
    setState(() {
      _mobilePendingCreateProjectId = projectId;
      _mobilePendingCreateRoomName = roomName;
    });
  }

  void _clearMobilePendingCreateRoom() {
    if (_mobilePendingCreateProjectId == null && _mobilePendingCreateRoomName == null) {
      return;
    }

    setState(() {
      _mobilePendingCreateProjectId = null;
      _mobilePendingCreateRoomName = null;
    });
  }

  void _setMobilePendingDeleteRoom(String projectId, String roomName) {
    setState(() {
      _mobilePendingDeleteProjectId = projectId;
      _mobilePendingDeleteRoomName = roomName;
    });
  }

  void _clearMobilePendingDeleteRoom() {
    if (_mobilePendingDeleteProjectId == null && _mobilePendingDeleteRoomName == null) {
      return;
    }

    setState(() {
      _mobilePendingDeleteProjectId = null;
      _mobilePendingDeleteRoomName = null;
    });
  }

  void _resetMobileRoomListDrag() {
    if (_mobileRoomListDragOffset == 0) {
      return;
    }

    setState(() {
      _mobileRoomListDragOffset = 0;
    });
  }

  void _resetMobileRoomListCloseAnimation() {
    if (_mobileRoomListCloseAnimationController.value == 0 && !_mobileRoomListCloseAnimationController.isAnimating) {
      return;
    }

    _mobileRoomListCloseAnimationController.stop();
    _mobileRoomListCloseAnimationController.value = 0;
  }

  void _updateMobileRoomListDrag(double delta, double maxWidth) {
    if (maxWidth <= 0) {
      return;
    }

    final nextOffset = (_mobileRoomListDragOffset + delta).clamp(-maxWidth, 0.0).toDouble();
    if (nextOffset == _mobileRoomListDragOffset) {
      return;
    }

    setState(() {
      _mobileRoomListDragOffset = nextOffset;
    });
  }

  void _completeMobileRoomListDrag({required double maxWidth, required double velocityX, required VoidCallback onDismissed}) {
    if (_mobileRoomListDragOffset == 0) {
      return;
    }

    final draggedEnough = _mobileRoomListDragOffset.abs() > (maxWidth * 0.22);
    final flungEnough = velocityX < -700;

    if (draggedEnough || flungEnough) {
      _resetMobileRoomListDrag();
      onDismissed();
      return;
    }

    _resetMobileRoomListDrag();
  }

  void onAddCredits() {
    final uri = MeshagentConfig.current?.billingUrl;

    if (widget.projectId == null || uri == null) {
      return;
    }

    final pid = fromUUID(widget.projectId!);
    final redirectUrl = uri.replace(path: "/p/$pid").replace(queryParameters: {"ref": "low_balance_warning"});

    launchUrl(redirectUrl);
  }

  @override
  void didUpdateWidget(Nav oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedRoom == null && widget.selectedRoom != null) {
      _mobileNavigationDirection = 1;
    } else if (oldWidget.selectedRoom != null && widget.selectedRoom == null) {
      _mobileNavigationDirection = -1;
    } else if (oldWidget.selectedRoom != widget.selectedRoom && widget.selectedRoom != null) {
      _mobileNavigationDirection = 1;
    }

    if (oldWidget.projectId != widget.projectId) {
      rooms.dispose();
      rooms = _createRoomsResource(widget.projectId);
      rooms.refresh();
      if (_mobileRoomListProjectId.value == null) {
        mobileRoomListRooms.refresh();
      }
    }

    if (oldWidget.projectId != widget.projectId) {
      projects.refresh();
      isBalanceLowRes.refresh();
      canCreateRooms.refresh();
      role.refresh();
      if (_mobilePendingDeleteProjectId != widget.projectId) {
        _clearMobilePendingDeleteRoom();
      }
    }

    final keepMobileRoomListOpen =
        widget.projectId != null &&
        oldWidget.selectedRoom != null &&
        widget.selectedRoom == null &&
        shouldStayOnMobileRoomList(widget.projectId!);

    if (oldWidget.projectId != widget.projectId || oldWidget.selectedRoom != widget.selectedRoom) {
      _selectedRoomDisplayNameOverrideProjectId = null;
      _selectedRoomDisplayNameOverrideRoomName = null;
      _selectedRoomDisplayNameOverride = null;
      _closePreviewRailMoreMenu();
      exposePreviewRoomRailMenuBridge(null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        if (keepMobileRoomListOpen) {
          Controller.maybeOfType<NavController>(context)?.openMobileRoomList();
          return;
        }

        _reinitializeMobileRoomListScroll();
        _setMobileRoomListFilterMode(false);
        Controller.maybeOfType<NavController>(context)?.closeMobileRoomList();
        _resetMobileRoomListBrowsingState();
      });
    }
  }

  List<Room> _filteredRooms(List<Room> allRooms) {
    if (filter.isEmpty) {
      return allRooms;
    }

    return allRooms.where((room) {
      final roomName = room.name;

      return roomName.toLowerCase().contains(filter.toLowerCase());
    }).toList();
  }

  List<Room> get filteredRooms => _filteredRooms(rooms.state.value ?? []);

  Future<void> onCreateProject() async {
    final p = await createMeshagentProject(context);
    projects.refresh();
    if (p != null) {
      final projectId = p['id'] as String?;

      if (mounted) {
        if (projectId != null) {
          localStorage.setItem("lastProjectId", projectId);
          context.go("/p/${fromUUID(projectId)}");
        } else {
          context.go("/");
        }
      }
    }
  }

  Future<void> _createRoomFromPreviewHeader(String projectId) async {
    final room = await createMeshagentRoom(context, projectId);
    if (!mounted || room == null) {
      return;
    }

    await rooms.refresh();

    if (!mounted) {
      return;
    }

    context.go("/p/${fromUUID(projectId)}/r/${room.name}");
  }

  void _signOutFromPreviewHeader() {
    resetPowerboardsUiMode();
    MeshagentAuth.current.signOut();
    localStorage.clear();

    final returnUrl = MeshagentConfig.current?.appUrl;
    final signOutUrl = MeshagentConfig.current!.serverUrl
        .resolve("/signout")
        .replace(queryParameters: {if (returnUrl != null) "return_url": returnUrl.toString()});

    if (kIsWeb) {
      launchUrl(signOutUrl, webOnlyWindowName: "_self");
    } else {
      context.go("/");
    }
  }

  void _goToAccountsFromPreviewHeader() {
    final billingUrl = MeshagentConfig.current?.billingUrl;
    if (billingUrl == null) {
      return;
    }

    if (widget.projectId == null) {
      launchUrl(billingUrl);
      return;
    }

    final pid = fromUUID(widget.projectId!);
    launchUrl(billingUrl.replace(path: "/p/$pid"));
  }

  void _toggleUiModeFromPreviewHeader() {
    togglePowerboardsUiModeAndReload();
  }

  Future<void> _openInviteFromPreviewHeader() async {
    final projectId = widget.projectId;
    final roomName = widget.selectedRoom?.trim();
    if (projectId == null || roomName == null || roomName.isEmpty) {
      return;
    }

    final room = await getMeshagentClient().getRoom(name: roomName, projectId: projectId);

    if (!mounted) {
      return;
    }

    await showUpdateRoomPermsDialog(context, projectId: projectId, room: room);
  }

  void _togglePreviewRailMoreMenu() {
    setState(() {
      _previewRailMoreMenuOpen = !_previewRailMoreMenuOpen;
    });
  }

  void _closePreviewRailMoreMenu() {
    if (!_previewRailMoreMenuOpen) {
      return;
    }

    setState(() {
      _previewRailMoreMenuOpen = false;
    });
  }

  String _currentPreviewRoomPane(BuildContext context) {
    final pane = PathRouteMatch.of(context).uri.queryParameters['pane'];
    return switch (pane) {
      'files' => 'files',
      'meeting' => 'meeting',
      _ => 'chat',
    };
  }

  void _goToPreviewRoomPane(BuildContext context, String pane) {
    final currentUri = PathRouteMatch.of(context).uri;
    final updatedQueryParameters = Map<String, String>.from(currentUri.queryParameters)..['pane'] = pane;
    if (pane == 'chat') {
      updatedQueryParameters.remove('p');
      updatedQueryParameters.remove(filePreviewOriginQueryParameter);
    }

    final nextUri = currentUri.replace(queryParameters: updatedQueryParameters);
    if (nextUri.toString() == currentUri.toString()) {
      return;
    }

    context.go(nextUri.toString());
  }

  Widget _buildPreviewRailMenu(PreviewRoomRailMenuBridge bridge) {
    return PbRoomOptionsMenu(
      width: 240,
      showRename: bridge.showRename,
      showPermissions: bridge.showPermissions,
      showManageAgents: bridge.showManageAgents,
      showDeleteRoom: bridge.showDeleteRoom,
      showKeychain: bridge.showKeychain,
      showConsoleToggle: bridge.showConsoleToggle,
      showShutdown: bridge.showShutdown,
      consoleLabel: bridge.consoleLabel,
      onRenamePressed: () {
        _closePreviewRailMoreMenu();
        bridge.onRenamePressed?.call();
      },
      onPermissionsPressed: () {
        _closePreviewRailMoreMenu();
        bridge.onPermissionsPressed?.call();
      },
      onManageAgentsPressed: () {
        _closePreviewRailMoreMenu();
        bridge.onManageAgentsPressed?.call();
      },
      onDeleteRoomPressed: () {
        _closePreviewRailMoreMenu();
        bridge.onDeleteRoomPressed?.call();
      },
      onKeychainPressed: () {
        _closePreviewRailMoreMenu();
        bridge.onKeychainPressed?.call();
      },
      onToggleConsolePressed: () {
        _closePreviewRailMoreMenu();
        bridge.onToggleConsolePressed?.call();
      },
      onShutdownPressed: () {
        _closePreviewRailMoreMenu();
        bridge.onShutdownPressed?.call();
      },
    );
  }

  @override
  void initState() {
    super.initState();
    syncPowerboardsUiModeFromStorage();
    rooms = _createRoomsResource(widget.projectId);
    registerPreviewRoomListRefreshCallback(() => rooms.refresh());
    registerPreviewRoomDisplayNameOverrideCallback(_setSelectedRoomDisplayNameOverride);

    _mobileRoomListCloseAnimationController = AnimationController(vsync: this, duration: powerboardsMobileTransitionDuration)
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _mobileRoomListCloseAnimationController.value = 0;
        }
      });

    projects.untilReady.then((list) async {
      final p = await list();

      if (widget.projectId != null) {
        // Check that id is in list
        final exists = p.any((proj) => proj.id == widget.projectId);

        if (exists) {
          localStorage.setItem("lastProjectId", widget.projectId!);
        }
      }

      if (mounted && p.isNotEmpty && widget.projectId == null) {
        String? projectId = localStorage.getItem("lastProjectId") ?? p[0].id;
        final exists = p.any((proj) => proj.id == projectId);
        if (!exists) {
          projectId = p.first.id;
        }
        localStorage.setItem("lastProjectId", projectId);
        context.go("/p/${fromUUID(projectId)}");
      }
    });
  }

  @override
  void dispose() {
    registerPreviewRoomListRefreshCallback(null);
    registerPreviewRoomDisplayNameOverrideCallback(null);
    _mobileRoomListCloseAnimationController.dispose();
    _mobileRoomListProjectId.dispose();
    _mobileRoomListSelectedRoom.dispose();
    projects.dispose();
    isBalanceLowRes.dispose();
    rooms.dispose();
    mobileRoomListRooms.dispose();
    role.dispose();
    balanceRes.dispose();

    super.dispose();
  }

  Widget desktopBody(BuildContext context, ProjectRole? userRole, bool balanceLow, bool canCreateRooms) {
    final cs = ShadTheme.of(context).colorScheme;

    if (balanceLow) {
      if (userRole == null) {
        return const Center(child: CircularProgressIndicator());
      }

      return ColoredBox(
        color: cs.card,
        child: BalanceLowWarning(onAddCredits: onAddCredits, role: userRole),
      );
    }

    return _buildRoomContent(useStableGlobalKey: true);
  }

  Widget _buildRoomContent({bool useStableGlobalKey = false}) {
    final key = useStableGlobalKey ? childKey : ValueKey('nav-room-content-${widget.projectId}-${widget.selectedRoom}');
    return KeyedSubtree(key: key, child: widget.child);
  }

  Widget desktopView(
    BuildContext context,
    ProjectRole? userRole,
    bool balanceLow,
    bool canCreateRooms, {
    required bool useDesktopUiPreview,
  }) {
    if (useDesktopUiPreview) {
      final user = MeshagentAuth.current.getUser();
      final avatarInitials = userAvatarInitialsFromEmail((user?['email'] as String?) ?? '');
      final avatarEmail = ((user?['email'] as String?) ?? '').trim();
      final roomItems = _roomsResourceProjectId == widget.projectId ? (rooms.state.value ?? const <Room>[]) : const <Room>[];
      final selectedRoomDisplayNameOverride = _effectiveSelectedRoomDisplayNameOverride;
      final hasSelectedRoom = (widget.selectedRoom?.trim().isNotEmpty) ?? false;
      final showPreviewRail = widget.projectId != null;
      final previewPane = _currentPreviewRoomPane(context);
      const railWidth = 64.0;
      const headerHeight = PbSizes.workspaceTopbarHeight;

      if (selectedRoomDisplayNameOverride != null) {
        final selectedRoom = roomItems.firstWhereOrNull((room) => room.name == widget.selectedRoom);
        if (selectedRoom != null && roomDisplayName(selectedRoom) == selectedRoomDisplayNameOverride) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _effectiveSelectedRoomDisplayNameOverride == selectedRoomDisplayNameOverride) {
              _clearSelectedRoomDisplayNameOverride();
            }
          });
        }
      }

      return ValueListenableBuilder<bool>(
        valueListenable: previewFilePreviewFullscreenListenable,
        builder: (context, filePreviewFullscreen, _) {
          final showPreviewChrome = !filePreviewFullscreen;

          return Row(
            key: const ValueKey('desktop-ui-preview-v1'),
            children: [
              if (showPreviewChrome && showPreviewRail)
                SizedBox(
                  width: railWidth,
                  child: ValueListenableBuilder<PreviewRoomRailMenuBridge?>(
                    valueListenable: previewRoomRailMenuBridgeListenable,
                    builder: (context, bridge, _) {
                      if (bridge == null) {
                        final showDestinations = hasSelectedRoom;
                        final showMore = hasSelectedRoom;
                        final destinationsEnabled = showDestinations && !balanceLow;
                        final moreEnabled = showMore && !balanceLow && bridge != null;
                        if (!moreEnabled && _previewRailMoreMenuOpen) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _closePreviewRailMoreMenu();
                            }
                          });
                        }
                        return PbSideRail(
                          showRecent: false,
                          showDestinations: showDestinations,
                          destinationsEnabled: destinationsEnabled,
                          showMore: showMore,
                          moreEnabled: moreEnabled,
                          meetActive: false,
                          selectedDestination: switch (previewPane) {
                            'files' => PbSideRailDestination.files,
                            'meeting' => PbSideRailDestination.meet,
                            _ => PbSideRailDestination.chat,
                          },
                          onChatPressed: () => _goToPreviewRoomPane(context, 'chat'),
                          onFilesPressed: () => _goToPreviewRoomPane(context, 'files'),
                          onMeetPressed: () => _goToPreviewRoomPane(context, 'meeting'),
                          moreSelected: false,
                          onMoreDismissRequested: _closePreviewRailMoreMenu,
                        );
                      }

                      return ListenableBuilder(
                        listenable: bridge,
                        builder: (context, _) {
                          final showDestinations = balanceLow ? hasSelectedRoom : bridge.showDestinations;
                          final showMore = balanceLow ? hasSelectedRoom : bridge.showMore;
                          final destinationsEnabled = showDestinations && !balanceLow;
                          final moreEnabled = showMore && !balanceLow;
                          if (!moreEnabled && _previewRailMoreMenuOpen) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                _closePreviewRailMoreMenu();
                              }
                            });
                          }

                          return PbSideRail(
                            showRecent: false,
                            showDestinations: showDestinations,
                            destinationsEnabled: destinationsEnabled,
                            showMore: showMore,
                            moreEnabled: moreEnabled,
                            meetActive: bridge.meetActive,
                            selectedDestination: switch (previewPane) {
                              'files' => PbSideRailDestination.files,
                              'meeting' => PbSideRailDestination.meet,
                              _ => PbSideRailDestination.chat,
                            },
                            onChatPressed: () => _goToPreviewRoomPane(context, 'chat'),
                            onFilesPressed: () => _goToPreviewRoomPane(context, 'files'),
                            onMeetPressed: () => _goToPreviewRoomPane(context, 'meeting'),
                            moreSelected: moreEnabled && _previewRailMoreMenuOpen,
                            moreMenu: moreEnabled && _previewRailMoreMenuOpen ? _buildPreviewRailMenu(bridge) : null,
                            onMorePressed: moreEnabled ? _togglePreviewRailMoreMenu : null,
                            onMoreDismissRequested: _closePreviewRailMoreMenu,
                          );
                        },
                      );
                    },
                  ),
                ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(top: showPreviewChrome ? headerHeight : 0),
                        child: desktopBody(context, userRole, balanceLow, canCreateRooms),
                      ),
                    ),
                    if (showPreviewChrome)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: DesktopPreviewNavHeader(
                          key: ValueKey('desktop-preview-header-${widget.projectId}-${widget.selectedRoom}'),
                          projects: projects.state.value ?? const <Project>[],
                          rooms: roomItems,
                          projectId: widget.projectId,
                          selectedRoom: widget.selectedRoom,
                          canCreateRooms: canCreateRooms,
                          selectedRoomDisplayNameOverride: selectedRoomDisplayNameOverride,
                          avatarInitials: avatarInitials,
                          avatarEmail: avatarEmail,
                          onCreateProject: onCreateProject,
                          onSelectProject: (project) {
                            localStorage.setItem("lastProjectId", project.id);
                            context.go("/p/${fromUUID(project.id)}");
                          },
                          onSelectRoom: (room) {
                            final projectId = widget.projectId;
                            if (projectId == null) {
                              return;
                            }

                            context.go("/p/${fromUUID(projectId)}/r/${room.name}");
                          },
                          onCreateRoom: widget.projectId == null || !canCreateRooms
                              ? null
                              : () => _createRoomFromPreviewHeader(widget.projectId!),
                          onManageAccountPressed: kIsWeb && userRole == ProjectRole.admin ? _goToAccountsFromPreviewHeader : null,
                          onSharePressed: widget.projectId == null || widget.selectedRoom == null
                              ? null
                              : () {
                                  _openInviteFromPreviewHeader();
                                },
                          onPreviewTogglePressed: _toggleUiModeFromPreviewHeader,
                          onLogoutPressed: _signOutFromPreviewHeader,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    }

    final cs = ShadTheme.of(context).colorScheme;
    final navController = Controller.ofType<NavController>(context);
    final chromeVisible = ChromeVisibilityModel.of(context).visible;
    final desktopSidetrayCollapsed = navController.isDesktopSidetrayCollapsed;
    final hidden = navController.isNavHidden || !chromeVisible;
    final sidetrayHidden = hidden || desktopSidetrayCollapsed;
    const animationDuration = Duration(milliseconds: 360);
    const animationCurve = Curves.easeInOutCubicEmphasized;

    return LayoutBuilder(
      key: const ValueKey('desktop-ui-legacy'),
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || width <= 0) {
          return const SizedBox.shrink();
        }

        final effectiveNavWidth = math.min(_navBarMaxWidth, math.max(_navBarMinWidth, math.min(navBarWidth, width - 320)));
        final targetNavWidth = sidetrayHidden ? 0.0 : effectiveNavWidth;
        final contentOffsetX = sidetrayHidden ? -10.0 : 0.0;
        final contentOpacity = sidetrayHidden ? 0.0 : 1.0;

        return DesktopSidetrayToggleScope(
          collapsed: desktopSidetrayCollapsed,
          enabled: !hidden,
          onToggle: navController.toggleDesktopSidetray,
          onCollapse: navController.collapseDesktopSidetray,
          onExpand: navController.expandDesktopSidetray,
          child: Row(
            children: [
              AnimatedContainer(
                duration: animationDuration,
                curve: animationCurve,
                width: targetNavWidth,
                child: IgnorePointer(
                  ignoring: sidetrayHidden,
                  child: ClipRect(
                    child: AnimatedOpacity(
                      duration: animationDuration,
                      curve: animationCurve,
                      opacity: contentOpacity,
                      child: AnimatedSlide(
                        duration: animationDuration,
                        curve: animationCurve,
                        offset: Offset(contentOffsetX / math.max(effectiveNavWidth, 1), 0),
                        child: ColoredBox(
                          color: cs.background,
                          child: SizedBox(
                            width: effectiveNavWidth,
                            child: Column(
                              mainAxisSize: .min,
                              children: [
                                _NavBarTop(
                                  projectId: widget.projectId,
                                  projects: projects,
                                  onCreateProject: onCreateProject,
                                  forceDesktopLayout: true,
                                  desktopLeading: DesktopSidetrayToggleButton(
                                    collapsed: false,
                                    onPressed: hidden ? null : navController.collapseDesktopSidetray,
                                  ),
                                ),

                                SignalBuilder(
                                  builder: (context, _) => Expanded(
                                    child: _NavBar(
                                      projectId: widget.projectId,
                                      rooms: rooms.state.isReady ? filteredRooms : [],
                                      currentFilter: filter,
                                      canCreateRooms: canCreateRooms,
                                      forceDesktopLayout: true,
                                      setFilter: setFilter,
                                      selectedRoom: widget.selectedRoom,
                                      onSave: () => rooms.refresh(),
                                      onRefresh: () => rooms.refresh(),
                                      balanceLow: balanceLow,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: desktopBody(context, userRole, balanceLow, canCreateRooms)),
            ],
          ),
        );
      },
    );
  }

  Widget mobileView(BuildContext context, ProjectRole? userRole, bool balanceLow, bool canCreateRooms) {
    final navController = Controller.ofType<NavController>(context);
    final roomItems = rooms.state.value ?? const <Room>[];
    final isRoomlessProjectState = widget.projectId != null && widget.selectedRoom == null && rooms.state.isReady && roomItems.isEmpty;
    final isStayOnTraySelectionState =
        widget.projectId != null &&
        widget.selectedRoom == null &&
        rooms.state.isReady &&
        roomItems.isNotEmpty &&
        navController.isMobileRoomListOpen;

    if (balanceLow) {
      if (userRole == null) {
        return const Center(child: CircularProgressIndicator());
      }

      return Column(
        children: [
          _NavBarTop(projectId: widget.projectId, projects: projects, onCreateProject: onCreateProject),
          Expanded(
            child: BalanceLowWarning(onAddCredits: onAddCredits, role: userRole),
          ),
          const SizedBox(height: 180.0),
        ],
      );
    }

    final mobileContent = isRoomlessProjectState
        ? KeyedSubtree(
            key: ValueKey('mobile-roomless-${widget.projectId}'),
            child: _buildMobileRoomlessProjectSurface(context, canCreateRooms: canCreateRooms, balanceLow: balanceLow),
          )
        : isStayOnTraySelectionState
        ? KeyedSubtree(
            key: ValueKey('mobile-room-select-${widget.projectId}'),
            child: _buildMobileRoomlessProjectSurface(context, canCreateRooms: canCreateRooms, balanceLow: balanceLow),
          )
        : widget.selectedRoom == null
        ? KeyedSubtree(
            key: const ValueKey('mobile-room-list'),
            child: _buildMobileRoomListSurface(context, canCreateRooms: canCreateRooms, balanceLow: balanceLow),
          )
        : KeyedSubtree(
            key: ValueKey('mobile-active-room-${widget.projectId}-${widget.selectedRoom}'),
            child: _buildMobileRoomSurfaceWithSidetray(
              context,
              canCreateRooms: canCreateRooms,
              balanceLow: balanceLow,
              sidetrayOpen: navController.isMobileRoomListOpen,
            ),
          );

    return ClipRect(
      child: AnimatedSwitcher(
        duration: powerboardsMobileTransitionDuration,
        switchInCurve: powerboardsMobileTransitionInCurve,
        switchOutCurve: powerboardsMobileTransitionOutCurve,
        layoutBuilder: (currentChild, previousChildren) {
          bool isActiveRoomChild(Widget child) {
            final key = child.key;
            return key is ValueKey<String> && key.value.startsWith('mobile-active-room-');
          }

          final includesActiveRoom = (currentChild != null && isActiveRoomChild(currentChild)) || previousChildren.any(isActiveRoomChild);
          final retainedPreviousChildren = includesActiveRoom ? const <Widget>[] : previousChildren;

          return Stack(fit: StackFit.expand, children: [...retainedPreviousChildren, ?currentChild]);
        },
        transitionBuilder: (child, animation) {
          final isCurrentChild = child.key == mobileContent.key;
          final direction = _mobileNavigationDirection.toDouble();
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut, reverseCurve: Curves.easeIn);

          if (isCurrentChild) {
            final position = Tween<Offset>(
              begin: Offset(direction, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: powerboardsMobileTransitionInCurve));

            return SlideTransition(
              position: position,
              child: FadeTransition(opacity: fade, child: child),
            );
          }

          final reverseAnimation = ReverseAnimation(animation);
          final position = Tween<Offset>(
            begin: Offset.zero,
            end: Offset(-0.18 * direction, 0),
          ).animate(CurvedAnimation(parent: reverseAnimation, curve: powerboardsMobileTransitionOutCurve));

          return SlideTransition(
            position: position,
            child: FadeTransition(opacity: fade, child: child),
          );
        },
        child: mobileContent,
      ),
    );
  }

  Widget _buildMobileRoomListSurface(
    BuildContext context, {
    required bool canCreateRooms,
    required bool balanceLow,
    VoidCallback? onClose,
    VoidCallback? onAnimatedClose,
    String? projectIdOverride,
    String? selectedRoomOverride,
    Resource<List<Room>>? roomsOverride,
    ValueChanged<Project>? onProjectSwitched,
  }) {
    final useOverlayChrome = onClose != null;
    final closeTray = onClose;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final mobileScrollCollapseProgress = isMobile && !_mobileRoomListFilterMode && _mobileRoomListScrollCollapsed ? 1.0 : 0.0;
    final roomListProjectId = projectIdOverride ?? widget.projectId;
    final roomListSelectedRoom = selectedRoomOverride ?? widget.selectedRoom;
    final roomListRooms = roomsOverride ?? rooms;
    final pendingCreateRoomName = _mobilePendingCreateProjectId == roomListProjectId ? _mobilePendingCreateRoomName : null;
    final pendingDeleteRoomName = _mobilePendingDeleteProjectId == roomListProjectId ? _mobilePendingDeleteRoomName : null;
    final roomListItems = roomListRooms.state.value ?? const <Room>[];

    if (pendingDeleteRoomName != null && roomListRooms.state.isReady && !roomListItems.any((room) => room.name == pendingDeleteRoomName)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _mobilePendingDeleteProjectId != roomListProjectId || _mobilePendingDeleteRoomName != pendingDeleteRoomName) {
          return;
        }

        _clearMobilePendingDeleteRoom();
      });
    }

    return ColoredBox(
      color: ShadTheme.of(context).colorScheme.card,
      child: SafeArea(
        minimum: powerboardsMobileScreenSafeAreaMinimum,
        child: Stack(
          children: [
            Positioned.fill(
              child: SignalBuilder(
                builder: (context, _) => _NavBar(
                  key: isMobile ? ValueKey('mobile-room-list-$roomListProjectId-$_mobileRoomListInstance') : null,
                  projectId: roomListProjectId,
                  rooms: _filteredRooms(roomListItems),
                  currentFilter: filter,
                  pendingCreateRoomName: pendingCreateRoomName,
                  pendingDeleteRoomName: pendingDeleteRoomName,
                  canCreateRooms: canCreateRooms,
                  setFilter: setFilter,
                  hasProjectRooms: roomListItems.isNotEmpty || pendingCreateRoomName != null || pendingDeleteRoomName != null,
                  mobileFilterMode: _mobileRoomListFilterMode,
                  onMobileFilterModeChanged: isMobile ? _setMobileRoomListFilterMode : null,
                  mobileScrollCollapseProgress: mobileScrollCollapseProgress,
                  onMobileScrollActiveChanged: isMobile ? _setMobileRoomListScrollCollapsed : null,
                  selectedRoom: roomListSelectedRoom,
                  mobileHeaderInset: isMobile && !_mobileRoomListFilterMode ? powerboardsMobileOverlayHeaderExpandedHeight : 0,
                  onSave: () {
                    rooms.refresh();
                    roomListRooms.refresh();
                  },
                  onRefresh: () async {
                    await roomListRooms.refresh();
                    if (roomListRooms != rooms) {
                      rooms.refresh();
                    }
                  },
                  balanceLow: balanceLow,
                  onRoomSelected: !useOverlayChrome
                      ? null
                      : (room) {
                          final currentProjectId = roomListProjectId;
                          if (currentProjectId == null) {
                            return;
                          }

                          if (filter.isNotEmpty) {
                            setFilter('');
                          }
                          closeTray?.call();

                          final pid = fromUUID(currentProjectId);
                          context.go("/p/$pid/r/${room.name}");
                        },
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedSwitcher(
                duration: powerboardsMobileTransitionDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: !(isMobile && _mobileRoomListFilterMode)
                    ? _NavBarTop(
                        key: const ValueKey('mobile-room-list-header'),
                        projectId: roomListProjectId,
                        projects: projects,
                        onCreateProject: onCreateProject,
                        onSwitchProject: onProjectSwitched,
                        mobileHorizontalPadding: _mobileSidetrayHorizontalPadding,
                        mobileHeaderContentHorizontalInset: 0,
                        mobileCollapseProgress: mobileScrollCollapseProgress,
                        onExpandCollapsedMobileChrome: () => _setMobileRoomListScrollCollapsed(false),
                        mobileLeading: !useOverlayChrome
                            ? null
                            : UserAvatarMenuButton(
                                projectId: roomListProjectId,
                                projects: projects,
                                boundaryContext: context,
                                avatarSize: desktopPaneHeaderCompactButtonWidth,
                              ),
                        mobileTrailing: !useOverlayChrome ? null : _MobileSidetrayCloseButton(onPressed: onAnimatedClose ?? onClose),
                      )
                    : const SizedBox(key: ValueKey('mobile-room-list-header-hidden')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRoomlessProjectSurface(BuildContext context, {required bool canCreateRooms, required bool balanceLow}) {
    final theme = ShadTheme.of(context);

    return ColoredBox(
      color: theme.colorScheme.card,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const SizedBox.expand(),
              SizedBox.expand(
                child: ColoredBox(
                  color: theme.colorScheme.background,
                  child: _buildMobileRoomListSurface(
                    context,
                    canCreateRooms: canCreateRooms,
                    balanceLow: balanceLow,
                    onClose: () => _handleMobileRoomlessCloseAttempt(context, canCreateRooms: canCreateRooms),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleMobileRoomlessCloseAttempt(BuildContext context, {required bool canCreateRooms}) async {
    final projectId = widget.projectId;
    if (projectId == null) {
      return;
    }

    final result = await showPowerboardsAlertDialog<_MobileRoomlessCloseAction?>(
      context: context,
      builder: (dialogContext) => PowerboardsShadDialog.compact(
        title: const Text("No room selected"),
        description: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            canCreateRooms
                ? "Create a new room to work in this project, or switch to another project."
                : "You need a room to work in this project. Switch to another project, or ask an admin to create a room.",
          ),
        ),
        actions: [
          ShadButton.outline(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Cancel")),
          ShadButton.outline(
            onPressed: () => Navigator.of(dialogContext).pop(_MobileRoomlessCloseAction.switchProject),
            child: const Text("Switch Project"),
          ),
          if (canCreateRooms)
            ShadButton(
              onPressed: () => Navigator.of(dialogContext).pop(_MobileRoomlessCloseAction.createRoom),
              child: const Text("Create Room"),
            ),
        ],
        child: const SizedBox.shrink(),
      ),
    );

    if (!mounted || !context.mounted) {
      return;
    }

    if (result == _MobileRoomlessCloseAction.createRoom) {
      final room = await createMeshagentRoom(context, projectId);
      if (!mounted || !context.mounted || room == null) {
        return;
      }

      context.go("/p/${fromUUID(projectId)}/r/${room.name}");
      return;
    }

    if (result == _MobileRoomlessCloseAction.switchProject) {
      if (!context.mounted) {
        return;
      }

      await showSwitchProjectDialog(
        context: context,
        currentProjectId: projectId,
        projects: projects,
        onSwitch: (project) {
          localStorage.setItem("lastProjectId", project.id);
          context.go("/p/${fromUUID(project.id)}");
        },
        onNewProject: onCreateProject,
      );
    }
  }

  Widget _buildMobileRoomSurfaceWithSidetray(
    BuildContext context, {
    required bool canCreateRooms,
    required bool balanceLow,
    required bool sidetrayOpen,
  }) {
    final theme = ShadTheme.of(context);
    final navController = Controller.ofType<NavController>(context);
    void closeMobileRoomListOverlay() {
      _reinitializeMobileRoomListScroll();
      _setMobileRoomListFilterMode(false);
      _resetMobileRoomListCloseAnimation();
      _resetMobileRoomListDrag();
      _resetMobileRoomListBrowsingState();
      navController.closeMobileRoomList();
    }

    void animateCloseMobileRoomListOverlay() {
      _reinitializeMobileRoomListScroll();
      _setMobileRoomListFilterMode(false);
      _resetMobileRoomListDrag();
      _resetMobileRoomListBrowsingState();
      _mobileRoomListCloseAnimationController.forward(from: 0);
      navController.closeMobileRoomList();
    }

    return ColoredBox(
      color: theme.colorScheme.card,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canSwipeDismiss = mobileRoomListRooms.state.isReady && (mobileRoomListRooms.state.value?.isNotEmpty ?? false);
          final dragProgress = constraints.maxWidth <= 0 ? 0.0 : (_mobileRoomListDragOffset.abs() / constraints.maxWidth).clamp(0.0, 1.0);
          final closeProgress = sidetrayOpen ? 0.0 : _mobileRoomListCloseAnimationController.value;
          final revealProgress = _mobileRoomListDragOffset != 0 ? dragProgress : closeProgress;
          final isSwipeRevealActive = (_mobileRoomListDragOffset != 0 && sidetrayOpen) || closeProgress > 0;
          final overlayOpacity = sidetrayOpen ? (1 - dragProgress) : 0.0;
          final baseOffset = sidetrayOpen ? 0.0 : -1.02;
          final dragOffset = constraints.maxWidth <= 0 ? 0.0 : (_mobileRoomListDragOffset / constraints.maxWidth);
          final effectiveSlideOffset = baseOffset + dragOffset;
          final dragAnimationDuration = _mobileRoomListDragOffset == 0 ? powerboardsMobileTransitionDuration : Duration.zero;
          final revealedRoomScale = 0.90 + (0.10 * revealProgress);
          final revealedRoomInset = 16.0 * (1 - revealProgress);
          final revealedRoomRadius = 28.0 * (1 - revealProgress);
          final revealedRoomOpacity = ((revealProgress - 0.72) / 0.28).clamp(0.0, 1.0);
          final revealedCardDimness = 0.20 * (1 - revealProgress);

          return SignalBuilder(
            builder: (context, _) => Stack(
              fit: StackFit.expand,
              children: [
                if (!isSwipeRevealActive)
                  _buildRoomContent()
                else
                  ColoredBox(
                    color: Colors.black,
                    child: Padding(
                      padding: EdgeInsets.all(revealedRoomInset),
                      child: Transform.scale(
                        scale: revealedRoomScale,
                        alignment: Alignment.center,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(revealedRoomRadius),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ColoredBox(color: theme.colorScheme.card),
                              if (revealedCardDimness > 0)
                                IgnorePointer(
                                  child: ColoredBox(color: Colors.black.withValues(alpha: revealedCardDimness)),
                                ),
                              if (revealedRoomOpacity > 0)
                                IgnorePointer(
                                  child: Opacity(opacity: revealedRoomOpacity, child: _buildRoomContent()),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                IgnorePointer(
                  ignoring: !sidetrayOpen,
                  child: AnimatedOpacity(
                    duration: dragAnimationDuration,
                    curve: Curves.easeOut,
                    opacity: overlayOpacity,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: closeMobileRoomListOverlay,
                      child: ColoredBox(color: isSwipeRevealActive ? Colors.transparent : Colors.black.withValues(alpha: 0.24)),
                    ),
                  ),
                ),
                IgnorePointer(
                  ignoring: !sidetrayOpen,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: !canSwipeDismiss
                        ? null
                        : (details) {
                            _updateMobileRoomListDrag(details.delta.dx, constraints.maxWidth);
                          },
                    onHorizontalDragEnd: !canSwipeDismiss
                        ? null
                        : (details) {
                            _completeMobileRoomListDrag(
                              maxWidth: constraints.maxWidth,
                              velocityX: details.primaryVelocity ?? 0,
                              onDismissed: closeMobileRoomListOverlay,
                            );
                          },
                    onHorizontalDragCancel: !canSwipeDismiss ? null : _resetMobileRoomListDrag,
                    child: AnimatedSlide(
                      duration: dragAnimationDuration,
                      curve: powerboardsMobileTransitionInCurve,
                      offset: Offset(effectiveSlideOffset, 0),
                      child: SizedBox.expand(
                        child: ColoredBox(
                          color: theme.colorScheme.background,
                          child: _buildMobileRoomListSurface(
                            context,
                            canCreateRooms: canCreateRooms,
                            balanceLow: balanceLow,
                            onClose: closeMobileRoomListOverlay,
                            onAnimatedClose: animateCloseMobileRoomListOverlay,
                            projectIdOverride: _effectiveMobileRoomListProjectId,
                            selectedRoomOverride: _effectiveMobileRoomListSelectedRoom,
                            roomsOverride: mobileRoomListRooms,
                            onProjectSwitched: (project) => _browseProjectInMobileRoomList(project.id),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget outOfCreditBanner(BuildContext context, ProjectRole? userRole) {
    final theme = ShadTheme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    if (userRole == null) {
      return SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 48),
      color: statusError,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Center(
        child: isMobile
            ? _buildMobileBalanceBannerText(context, outOfCredit: true, userRole: userRole)
            : Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "Out of Credit - ",
                      style: tt.small.copyWith(fontWeight: FontWeight.bold, color: cs.destructiveForeground),
                    ),

                    if (userRole == ProjectRole.admin)
                      TextSpan(text: "Add more credits to re-enable rooms.")
                    else
                      TextSpan(text: "Contact your project admin to add more credits."),
                  ],
                ),
                style: tt.small.copyWith(color: cs.destructiveForeground, height: 1.5),
                textAlign: TextAlign.center,
              ),
      ),
    );
  }

  Widget balanceLowWarning(BuildContext context) {
    final theme = ShadTheme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Container(
      constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 48),
      color: statusError,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Center(
        child: isMobile
            ? _buildMobileBalanceBannerText(context, outOfCredit: false, userRole: null)
            : Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "Low Balance - ",
                          style: tt.small.copyWith(fontWeight: FontWeight.bold, color: cs.destructiveForeground),
                        ),

                        TextSpan(text: "Add more credits to avoid service interruption."),
                      ],
                    ),
                    style: tt.small.copyWith(color: cs.destructiveForeground, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  ShadButton(key: const Key('add-credits-button'), onPressed: onAddCredits, child: const Text("Add Credits")),
                ],
              ),
      ),
    );
  }

  Widget _buildMobileBalanceBannerText(BuildContext context, {required bool outOfCredit, required ProjectRole? userRole}) {
    final theme = ShadTheme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final copy = powerboardsMobileCreditBannerCopy(outOfCredit: outOfCredit, userRole: userRole);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          copy.title,
          style: tt.small.copyWith(fontWeight: FontWeight.bold, color: cs.destructiveForeground),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          copy.description,
          style: tt.small.copyWith(fontSize: 12, color: cs.destructiveForeground, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget forbiddenView(BuildContext context) {
    final isSmallDisplay = ResponsiveBreakpoints.of(context).smallerOrEqualTo("chromebook");

    if (isSmallDisplay) {
      return SafeArea(
        minimum: powerboardsMobileScreenSafeAreaMinimum,
        child: Column(
          children: [
            _NavBarTop(projectId: widget.projectId, projects: projects, onCreateProject: onCreateProject),
            const Expanded(child: UserForbiddenWarning()),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const .all(12.0),
          child: Row(
            children: [
              Spacer(),
              UserAvatarMenuButton(projectId: widget.projectId, projects: widget.projects, boundaryContext: context),
            ],
          ),
        ),
        const Expanded(child: UserForbiddenWarning()),
      ],
    );
  }

  Widget inaccessibleView(BuildContext context) {
    if (widget.selectedRoom != null) {
      return const RoomNotFound();
    }

    return forbiddenView(context);
  }

  Widget _previewModeEmptyProjectsView(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(12),
      child: Column(
        children: [Expanded(child: EmptyProjectsState(onCreateProject: onCreateProject))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final useMobileNav = ResponsiveBreakpoints.of(context).isMobile || powerboardsIsLandscapePhoneViewport(context);
    final navController = Controller.ofType<NavController>(context);

    return SignalBuilder(
      builder: (context, _) {
        if (!projects.state.isReady || !role.state.isReady) {
          return useMobileNav ? const SizedBox.shrink() : const Center(child: CircularProgressIndicator());
        }

        final uiMode = powerboardsUiModeSignal.value;
        final useDesktopUiPreview = uiMode == PowerboardsUiMode.v1 && !useMobileNav;

        if (projects.state.value!.isEmpty) {
          return useDesktopUiPreview ? _previewModeEmptyProjectsView(context) : EmptyProjectsState(onCreateProject: onCreateProject);
        }

        final userRole = role.state.value;
        if (userRole == ProjectRole.none) {
          return ColoredBox(color: cs.background, child: inaccessibleView(context));
        }

        if (!isBalanceLowRes.state.isReady || !balanceRes.state.isReady) {
          return useMobileNav ? const SizedBox.shrink() : const Center(child: CircularProgressIndicator());
        }

        final balanceLow = isBalanceLowRes.state.value ?? false;
        final canCreateRooms = this.canCreateRooms.state.value ?? false;
        final balance = balanceRes.state.value;
        final balanceBelowThreshold = balance != null && balance.balance < balanceLowThreshold;

        return ControllerBuilder(
          controller: navController,
          builder: (context) => Column(
            children: [
              if (kIsWeb && balanceBelowThreshold)
                SafeArea(child: balanceLowWarning(context))
              else if (balanceLow)
                SafeArea(child: outOfCreditBanner(context, userRole)),

              Expanded(
                child: Container(
                  color: cs.background,
                  child: useMobileNav
                      ? mobileView(context, userRole, balanceLow, canCreateRooms)
                      : desktopView(context, userRole, balanceLow, canCreateRooms, useDesktopUiPreview: useDesktopUiPreview),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavBar extends StatefulWidget {
  const _NavBar({
    super.key,
    this.selectedRoom,
    required this.rooms,
    required this.currentFilter,
    this.pendingCreateRoomName,
    this.pendingDeleteRoomName,
    required this.setFilter,
    this.hasProjectRooms = true,
    this.mobileFilterMode = false,
    this.onMobileFilterModeChanged,
    this.mobileScrollCollapseProgress = 0,
    this.onMobileScrollActiveChanged,
    this.mobileHeaderInset = 0,
    required this.onSave,
    required this.onRefresh,
    required this.projectId,
    required this.balanceLow,
    required this.canCreateRooms,
    this.onRoomSelected,
    this.forceDesktopLayout = false,
  });

  final String? selectedRoom;
  final List<Room> rooms;
  final String currentFilter;
  final String? pendingCreateRoomName;
  final String? pendingDeleteRoomName;
  final void Function(String) setFilter;
  final bool hasProjectRooms;
  final bool mobileFilterMode;
  final ValueChanged<bool>? onMobileFilterModeChanged;
  final double mobileScrollCollapseProgress;
  final ValueChanged<bool>? onMobileScrollActiveChanged;
  final double mobileHeaderInset;
  final void Function() onSave;
  final Future<void> Function() onRefresh;
  final String? projectId;
  final bool balanceLow;
  final bool canCreateRooms;
  final ValueChanged<Room>? onRoomSelected;
  final bool forceDesktopLayout;

  @override
  State<_NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<_NavBar> {
  late final TextEditingController _filterController;
  late final FocusNode _filterFocusNode;

  bool get _isMobile => !widget.forceDesktopLayout && ResponsiveBreakpoints.of(context).isMobile;
  bool get _isMobileFilterMode => _isMobile && widget.mobileFilterMode;

  Future<void> addNewRoomDialog(BuildContext context) async {
    String? pendingRoomName;
    try {
      final room = await createMeshagentRoom(
        context,
        widget.projectId!,
        onCreateStarted: widget.onRoomSelected == null
            ? null
            : (name) {
                pendingRoomName = name;
                final navState = context.findAncestorStateOfType<_NavState>();
                navState?._setMobilePendingCreateRoom(widget.projectId!, name);
              },
      );
      if (!context.mounted) {
        return;
      }

      if (room != null) {
        if (widget.onRoomSelected != null) {
          await waitForMeshagentRoomConnectionReady(widget.projectId!, room.name);
          if (!context.mounted) {
            return;
          }
          widget.onRoomSelected!(room);
          return;
        }

        final pid = fromUUID(widget.projectId!);

        if (!context.mounted) {
          return;
        }

        context.go("/p/$pid/r/${room.name}");
      }
    } finally {
      if (pendingRoomName != null && context.mounted) {
        final navState = context.findAncestorStateOfType<_NavState>();
        navState?._clearMobilePendingCreateRoom();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _filterController = TextEditingController(text: widget.currentFilter);
    _filterFocusNode = FocusNode()
      ..addListener(() {
        if (_filterFocusNode.hasFocus && _isMobile) {
          widget.onMobileFilterModeChanged?.call(true);
        }
      });
  }

  @override
  void didUpdateWidget(covariant _NavBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.currentFilter != _filterController.text) {
      _filterController.value = TextEditingValue(
        text: widget.currentFilter,
        selection: TextSelection.collapsed(offset: widget.currentFilter.length),
      );
    }
  }

  @override
  void dispose() {
    _filterFocusNode.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _closeMobileFilterMode() {
    widget.onMobileFilterModeChanged?.call(false);
    _filterFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile;
    final keyboardOpen = isMobile && (MediaQuery.maybeOf(context)?.viewInsets.bottom ?? 0.0) > 0;
    final isCreatePending = widget.pendingCreateRoomName != null;
    final hideMobileFilterForEmptyProject = isMobile && !widget.hasProjectRooms;
    final effectiveMobileFilterMode = _isMobileFilterMode && !hideMobileFilterForEmptyProject;
    final mobileScrollCollapseProgress = isMobile && !_isMobileFilterMode ? widget.mobileScrollCollapseProgress : 0.0;
    final horizontalPadding = isMobile
        ? _mobileSidetrayHorizontalPadding
        : const EdgeInsets.symmetric(horizontal: desktopPaneSideHorizontalInset);
    const mobileFilterFocusTop = 0.0;
    const mobileChromeCutoffGap = 18.0;
    const mobileFooterChromeTopGap = 18.0;
    final hasMobileFooterAction = effectiveMobileFilterMode || (widget.canCreateRooms && !keyboardOpen);
    final mobileFilterTop = effectiveMobileFilterMode
        ? mobileFilterFocusTop
        : widget.mobileHeaderInset + powerboardsMobileOverlaySecondaryRowLift;
    final mobileTopChromeHeight = hideMobileFilterForEmptyProject
        ? widget.mobileHeaderInset + mobileChromeCutoffGap
        : mobileFilterTop + powerboardsMobileSecondaryRowHeight + mobileChromeCutoffGap;
    final mobileBottomChromeHeight = hasMobileFooterAction
        ? mobileFooterChromeTopGap + powerboardsFooterActionButtonHeight + desktopPaneBottomInset
        : desktopPaneBottomInset + 10;

    Widget buildNavRooms(EdgeInsetsGeometry? contentPadding) {
      return widget.projectId == null
          ? const SizedBox.shrink()
          : NavRooms(
              projectId: widget.projectId!,
              rooms: widget.rooms,
              contentPadding: contentPadding,
              pendingCreateRoomName: widget.pendingCreateRoomName,
              pendingDeleteRoomName: widget.pendingDeleteRoomName,
              selectedRoom: widget.selectedRoom,
              onSelect:
                  widget.onRoomSelected ??
                  (room) async {
                    final pid = fromUUID(widget.projectId!);

                    if (!context.mounted) {
                      return;
                    }

                    context.go("/p/$pid/r/${room.name}");
                  },
              onDeleteStarted: !isMobile
                  ? null
                  : (room) {
                      final navState = context.findAncestorStateOfType<_NavState>();
                      navState?._setMobilePendingDeleteRoom(widget.projectId!, room.name);
                    },
              onDeleteFinished: !isMobile
                  ? null
                  : (room, deleted) {
                      if (deleted) {
                        return;
                      }

                      final navState = context.findAncestorStateOfType<_NavState>();
                      if (navState?._mobilePendingDeleteProjectId == widget.projectId &&
                          navState?._mobilePendingDeleteRoomName == room.name) {
                        navState?._clearMobilePendingDeleteRoom();
                      }
                    },
              onScrollActiveChanged: isMobile ? widget.onMobileScrollActiveChanged : null,
              onSave: widget.onSave,
              onRefresh: widget.onRefresh,
              balanceLow: widget.balanceLow,
            );
    }

    Widget buildFilterInput() {
      return Builder(
        builder: (context) {
          final colorScheme = ShadTheme.of(context).colorScheme;
          final desktopFilterRadius = BorderRadius.circular(999);
          final filterInput = PowerboardsAdaptiveInput(
            controller: _filterController,
            focusNode: _filterFocusNode,
            padding: isMobile ? const EdgeInsets.fromLTRB(14, 8, 12, 8) : null,
            alignment: isMobile ? null : Alignment.centerLeft,
            decoration: !isMobile
                ? ShadDecoration(
                    color: colorScheme.input,
                    border: ShadBorder.all(radius: desktopFilterRadius, color: colorScheme.border, width: 1),
                    focusedBorder: ShadBorder.all(radius: desktopFilterRadius, color: colorScheme.ring, width: 1),
                    errorBorder: ShadBorder.all(radius: desktopFilterRadius, width: 1),
                    disableSecondaryBorder: true,
                  )
                : ShadDecoration(
                    color: colorScheme.input,
                    border: ShadBorder.all(radius: desktopFilterRadius),
                    focusedBorder: ShadBorder.all(radius: desktopFilterRadius),
                    errorBorder: ShadBorder.all(radius: desktopFilterRadius),
                    secondaryBorder: ShadBorder.all(radius: desktopFilterRadius),
                    secondaryFocusedBorder: ShadBorder.all(radius: desktopFilterRadius),
                    secondaryErrorBorder: ShadBorder.all(radius: desktopFilterRadius),
                  ),
            key: const Key('room-list-search-field'),
            onChanged: widget.setFilter,
            leading: Icon(LucideIcons.search, size: 16, color: colorScheme.mutedForeground),
            gap: 10,
            inputPadding: isMobile ? EdgeInsets.zero : null,
            placeholderAlignment: isMobile ? null : Alignment.centerLeft,
            placeholder: const Text("Filter rooms..."),
          );

          if (isMobile) {
            return SizedBox(
              height: powerboardsMobileSecondaryRowHeight,
              child: Center(child: filterInput),
            );
          }

          return SizedBox(height: desktopPaneSecondaryControlHeight, child: filterInput);
        },
      );
    }

    Widget buildDesktopFooter() {
      if (!(widget.canCreateRooms && !keyboardOpen)) {
        return const SizedBox.shrink(key: ValueKey('nav-no-footer-action'));
      }

      return Padding(
        key: const ValueKey('nav-create-room-action'),
        padding: const EdgeInsets.fromLTRB(desktopPaneSideHorizontalInset, 10, desktopPaneSideHorizontalInset, desktopPaneBottomInset),
        child: SizedBox(
          width: double.infinity,
          child: ShadButton.outline(
            height: powerboardsFooterActionButtonHeight,
            decoration: ShadDecoration(border: ShadBorder.all(color: ShadTheme.of(context).colorScheme.border)),
            backgroundColor: Colors.white,
            hoverBackgroundColor: Colors.white,
            foregroundColor: ShadTheme.of(context).colorScheme.foreground,
            hoverForegroundColor: ShadTheme.of(context).colorScheme.foreground,
            key: const Key('nav-create-room-button'),
            onPressed: isCreatePending ? null : () => addNewRoomDialog(context),
            child: const Text("New Room"),
          ),
        ),
      );
    }

    Widget? buildMobileFooterAction() {
      return effectiveMobileFilterMode
          ? Row(
              children: [
                Expanded(
                  child: ShadButton.outline(
                    height: powerboardsFooterActionButtonHeight,
                    onPressed: _closeMobileFilterMode,
                    child: const Text("Close"),
                  ),
                ),
              ],
            )
          : widget.canCreateRooms && !keyboardOpen
          ? SizedBox(
              width: double.infinity,
              child: ShadButton(
                height: powerboardsFooterActionButtonHeight,
                key: const Key('nav-create-room-button'),
                onPressed: isCreatePending ? null : () => addNewRoomDialog(context),
                child: const Text("New Room"),
              ),
            )
          : null;
    }

    Widget buildMobileTopChrome(double collapseProgress) {
      final theme = ShadTheme.of(context);
      final collapseCurve = Curves.easeInOutCubic.transform(collapseProgress);
      final chromeHeight = ui.lerpDouble(mobileTopChromeHeight, powerboardsMobileOverlayHeaderCollapsedHeight, collapseCurve)!;
      final filterVisibility = effectiveMobileFilterMode ? 1.0 : 1 - Curves.easeInCubic.transform(collapseProgress);
      final animatedFilterTop = effectiveMobileFilterMode
          ? mobileFilterTop
          : ui.lerpDouble(mobileFilterTop, powerboardsMobileOverlayHeaderCollapsedHeight + 2, collapseCurve)!;
      final solidStop = ui.lerpDouble(0.82, 0.24, collapseCurve)!;
      final topColor = Color.lerp(
        theme.colorScheme.card,
        powerboardsMobileGlassColor(theme.colorScheme.card, tint: 0.92, alpha: 0.82),
        collapseCurve,
      )!;
      final middleColor = Color.lerp(
        theme.colorScheme.card,
        powerboardsMobileGlassColor(theme.colorScheme.card, tint: 0.74, alpha: 0.62),
        collapseCurve,
      )!;
      final edgeColor = Color.lerp(theme.colorScheme.card, theme.colorScheme.card.withValues(alpha: 0), collapseCurve)!;

      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SizedBox(
          height: chromeHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: ui.lerpDouble(10, 18, collapseCurve)!,
                      sigmaY: ui.lerpDouble(10, 18, collapseCurve)!,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [topColor, middleColor, edgeColor],
                          stops: [0.0, solidStop, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!hideMobileFilterForEmptyProject)
                Positioned(
                  top: animatedFilterTop,
                  left: _mobileSidetrayContentHorizontalInset,
                  right: _mobileSidetrayContentHorizontalInset,
                  child: IgnorePointer(
                    ignoring: !_isMobileFilterMode && filterVisibility < 0.1,
                    child: Opacity(
                      opacity: filterVisibility,
                      child: Transform.translate(offset: Offset(0, -8 * collapseCurve), child: buildFilterInput()),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget buildMobileBottomChrome(double collapseProgress) {
      final footerChild = buildMobileFooterAction();
      final theme = ShadTheme.of(context);
      final collapseCurve = Curves.easeInOutCubic.transform(collapseProgress);
      final chromeHeight = ui.lerpDouble(mobileBottomChromeHeight, 0, collapseCurve)!;
      final footerVisibility = effectiveMobileFilterMode ? 1.0 : 1 - Curves.easeOutCubic.transform(collapseProgress);
      final solidStop = ui.lerpDouble(0.72, 0.42, collapseCurve)!;
      final bottomColor = Color.lerp(
        theme.colorScheme.card,
        powerboardsMobileGlassColor(theme.colorScheme.card, tint: 0.88, alpha: 0.82),
        collapseCurve,
      )!;
      final middleColor = Color.lerp(
        theme.colorScheme.card,
        powerboardsMobileGlassColor(theme.colorScheme.card, tint: 0.72, alpha: 0.62),
        collapseCurve,
      )!;
      final edgeColor = Color.lerp(theme.colorScheme.card, theme.colorScheme.card.withValues(alpha: 0), collapseCurve)!;

      return Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: SizedBox(
          height: chromeHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: ui.lerpDouble(10, 18, collapseCurve)!,
                      sigmaY: ui.lerpDouble(10, 18, collapseCurve)!,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [bottomColor, middleColor, edgeColor],
                          stops: [0.0, solidStop, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (footerChild != null)
                Positioned(
                  left: _mobileSidetrayContentHorizontalInset,
                  right: _mobileSidetrayContentHorizontalInset,
                  bottom: desktopPaneBottomInset,
                  child: IgnorePointer(
                    ignoring: !_isMobileFilterMode && footerVisibility < 0.1,
                    child: Opacity(
                      opacity: footerVisibility,
                      child: Transform.translate(offset: Offset(0, 8 * collapseCurve), child: footerChild),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (isMobile) {
      return KeyboardSafe(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: mobileScrollCollapseProgress),
          duration: powerboardsMobileOverlayHeaderTransitionDuration,
          curve: Curves.easeOutCubic,
          builder: (context, animatedCollapseProgress, _) {
            final filterCollapseProgress = effectiveMobileFilterMode ? 0.0 : animatedCollapseProgress;
            final collapseCurve = Curves.easeInOutCubic.transform(filterCollapseProgress);
            final listTopPadding = ui.lerpDouble(mobileTopChromeHeight, powerboardsMobileOverlayHeaderCollapsedHeight, collapseCurve)!;
            final listBottomPadding = ui.lerpDouble(mobileBottomChromeHeight, 0, collapseCurve)!;
            final navRooms = buildNavRooms(
              EdgeInsets.fromLTRB(
                _mobileSidetrayContentHorizontalInset,
                listTopPadding,
                _mobileSidetrayContentHorizontalInset,
                listBottomPadding,
              ),
            );

            return Stack(
              fit: StackFit.expand,
              children: [navRooms, buildMobileTopChrome(filterCollapseProgress), buildMobileBottomChrome(filterCollapseProgress)],
            );
          },
        ),
      );
    }

    return KeyboardSafe(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: desktopPaneSecondaryControlTopOffset),
          Padding(padding: horizontalPadding, child: buildFilterInput()),
          const SizedBox(height: desktopPaneSecondaryRowContentGap),
          Expanded(child: buildNavRooms(null)),
          AnimatedSwitcher(
            duration: powerboardsMobileTransitionDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, axisAlignment: 1, child: child),
            ),
            child: buildDesktopFooter(),
          ),
        ],
      ),
    );
  }
}

class _NavBarTop extends StatefulWidget {
  const _NavBarTop({
    super.key,
    required this.projects,
    required this.projectId,
    required this.onCreateProject,
    this.mobileCollapseProgress = 0,
    this.onExpandCollapsedMobileChrome,
    this.mobileLeading,
    this.mobileTrailing,
    this.onSwitchProject,
    this.mobileHorizontalPadding = powerboardsMobileHorizontalPadding,
    this.mobileHeaderContentHorizontalInset = powerboardsMobileShellHorizontalInset,
    this.desktopLeading,
    this.forceDesktopLayout = false,
  });

  final String? projectId;
  final Resource<List<Project>> projects;
  final Future<void> Function() onCreateProject;
  final double mobileCollapseProgress;
  final VoidCallback? onExpandCollapsedMobileChrome;
  final Widget? mobileLeading;
  final Widget? mobileTrailing;
  final ValueChanged<Project>? onSwitchProject;
  final EdgeInsetsGeometry mobileHorizontalPadding;
  final double mobileHeaderContentHorizontalInset;
  final Widget? desktopLeading;
  final bool forceDesktopLayout;

  @override
  State createState() => _NavBarTopState();
}

class _NavBarTopState extends State<_NavBarTop> {
  void toggleChromeVisibility() {
    final visibility = !ChromeVisibilityState.of(context).visible;
    ChromeVisibilityState.of(context).visible = visibility;
    FullScreenWindow.setFullScreen(!visibility);
  }

  void _switchProject() {
    if (widget.mobileCollapseProgress > 0.01 && widget.onExpandCollapsedMobileChrome != null) {
      widget.onExpandCollapsedMobileChrome!();
      return;
    }

    showSwitchProjectDialog(
      context: context,
      currentProjectId: widget.projectId ?? "",
      projects: widget.projects,
      onSwitch: (project) {
        if (widget.onSwitchProject != null) {
          widget.onSwitchProject!(project);
          return;
        }

        localStorage.setItem("lastProjectId", project.id);
        context.go("/p/${fromUUID(project.id)}");
      },
      onNewProject: () {
        widget.onCreateProject();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final projectList = widget.projects.state.value ?? const <Project>[];
    final selectedProject = projectList.firstWhereOrNull((p) => p.id == widget.projectId);
    final isSmallDisplay = !widget.forceDesktopLayout && ResponsiveBreakpoints.of(context).smallerOrEqualTo("chromebook");
    final mobileHeaderControlSize = desktopPaneHeaderCompactButtonWidth;
    final displayName = selectedProject?.name ?? "Select project";
    final mobileCollapseProgress = isSmallDisplay ? widget.mobileCollapseProgress.clamp(0.0, 1.0) : 0.0;
    final hasDesktopLeading = widget.desktopLeading != null;
    final desktopLeadingSlotSize = hasDesktopLeading ? desktopSidetrayToggleButtonSize : desktopPaneSideHeaderSlotSize;
    final desktopHeaderVisualInset = hasDesktopLeading
        ? math.max(desktopPaneSideHeaderVisualInset, desktopLeadingSlotSize)
        : desktopPaneSideHeaderVisualInset;
    final projectTitleStyle = isSmallDisplay
        ? powerboardsMobileHeaderPrimaryTextStyle(color: theme.colorScheme.foreground)
        : powerboardsSectionTitleStyle(color: theme.colorScheme.foreground, height: 1.2);

    return Container(
      padding: isSmallDisplay ? widget.mobileHorizontalPadding : const EdgeInsets.symmetric(horizontal: desktopPaneSideHorizontalInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          if (isSmallDisplay)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: mobileCollapseProgress),
              duration: powerboardsMobileOverlayHeaderTransitionDuration,
              curve: Curves.easeOutCubic,
              builder: (context, animatedCollapseProgress, _) {
                final switchIconVisibility = (1 - Curves.easeOutCubic.transform(animatedCollapseProgress)).clamp(0.0, 1.0);
                final title = ShadButton.ghost(
                  expands: true,
                  height: ui.lerpDouble(
                    desktopPaneHeaderContentHeight,
                    powerboardsMobileOverlayHeaderCollapsedHeight - 4,
                    animatedCollapseProgress,
                  )!,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  onPressed: _switchProject,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: projectTitleStyle,
                              strutStyle: StrutStyle.fromTextStyle(projectTitleStyle, forceStrutHeight: true),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                          ClipRect(
                            child: Align(
                              widthFactor: switchIconVisibility,
                              child: Opacity(
                                opacity: switchIconVisibility,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(width: 8),
                                    Icon(LucideIcons.chevronsUpDown, size: 20, color: theme.colorScheme.foreground),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                final header = PowerboardsMobileOverlayHeader(
                  leading: widget.mobileLeading ?? NavMainLogo(size: mobileHeaderControlSize - 8),
                  title: title,
                  trailingActions: [
                    widget.mobileTrailing ??
                        UserAvatarMenuButton(
                          projectId: widget.projectId,
                          projects: widget.projects,
                          boundaryContext: context,
                          avatarSize: mobileHeaderControlSize,
                        ),
                  ],
                  backgroundColor: theme.colorScheme.card,
                  collapseProgress: animatedCollapseProgress,
                  titleAlignment: Alignment.center,
                  horizontalInset: widget.mobileHeaderContentHorizontalInset,
                );

                if (animatedCollapseProgress <= 0.01 || widget.onExpandCollapsedMobileChrome == null) {
                  return header;
                }

                return Stack(
                  children: [
                    header,
                    Positioned.fill(
                      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onExpandCollapsedMobileChrome),
                    ),
                  ],
                );
              },
            ),
          if (!isSmallDisplay)
            SizedBox(
              height: headerHeight,
              child: Center(
                child: SizedBox(
                  height: desktopPaneHeaderContentHeight,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 0,
                          child: SizedBox(
                            width: desktopLeadingSlotSize,
                            height: desktopLeadingSlotSize,
                            child: Center(child: widget.desktopLeading ?? const NavMainLogo(size: desktopPaneSideHeaderSlotSize)),
                          ),
                        ),
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: desktopHeaderVisualInset),
                            child: Tooltip(
                              message: "Switch project",
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _switchProject,
                                  child: Center(
                                    child: Text(
                                      displayName,
                                      style: projectTitleStyle,
                                      strutStyle: StrutStyle.fromTextStyle(projectTitleStyle, forceStrutHeight: true),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: SizedBox(
                            width: desktopHeaderVisualInset,
                            child: Tooltip(
                              message: "Switch project",
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _switchProject,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Icon(LucideIcons.chevronsUpDown, size: 20, color: theme.colorScheme.foreground),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NavMainLogo extends StatelessWidget {
  const NavMainLogo({super.key, this.size});

  final double? size;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size ?? (kIsWeb ? 42.0 : 46.0),
      height: size ?? (kIsWeb ? 42.0 : 46.0),
      child: fs.SvgPicture.asset('lib/assets/powerboards-brand-symbol.svg', fit: BoxFit.contain),
    );
  }
}
