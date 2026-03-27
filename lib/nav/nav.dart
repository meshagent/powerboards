import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as fs;
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:localstorage/localstorage.dart';
import 'package:powerboards/ui/avatar_menu_button.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/powerboards_controller/powerboards_controller.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/nav/switch_project_dialog.dart';
import 'package:powerboards/ui/empty_states.dart';
import 'package:powerboards/ui/keyboard_safe.dart';
import 'package:powerboards/ui/pane_header_action_scope.dart';

import 'package:meshagent/meshagent.dart';

import 'chrome_visibility.dart';
import 'nav_rooms.dart';

const double _navBarMinWidth = 280.0;
const double _navBarMaxWidth = 560.0;

const double balanceLowThreshold = 200.0;
const double navBarWidth = 280.0;

class NavController extends Controller {
  bool _hideNav = false;

  bool get isNavHidden => _hideNav;

  void hideNav() {
    _hideNav = true;
    notifyListeners();
  }

  void showNav() {
    _hideNav = false;
    notifyListeners();
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

class _NavState extends State<Nav> {
  final resizeController = ShadResizableController();
  BoxConstraints? lastConstraints;
  Timer? resizeDebounceTimer;

  final childKey = GlobalKey();
  Resource<List<Project>> get projects {
    return widget.projects;
  }

  late final isBalanceLowRes = Resource<bool>(() => isBalanceLow(widget.projectId));
  late final role = Resource(() async {
    if (widget.projectId == null) {
      return null;
    }

    final client = getMeshagentClient();

    try {
      return await client.getProjectRole(widget.projectId!);
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
  late final rooms = Resource<List<Room>>(() async {
    final projectId = widget.projectId ?? localStorage.getItem("lastProjectId");

    return projectId == null ? [] : await listMeshagentRooms(projectId);
  });

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

  void onAddCredits() {
    final uri = MeshagentConfig.current?.billingUrl;

    if (widget.projectId == null || uri == null) {
      return;
    }

    final pid = fromUUID(widget.projectId!);
    final redirectUrl = uri.replace(path: "/p/$pid").replace(queryParameters: {"ref": "low_balance_warning"});

    launchUrl(redirectUrl);
  }

  void _resetResizeState() {
    resizeDebounceTimer?.cancel();
    resizeDebounceTimer = null;
    lastConstraints = null;
  }

  void debounceResize(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    if (!width.isFinite || width <= 0) {
      _resetResizeState();
      return;
    }

    if (lastConstraints == null || lastConstraints!.maxWidth != width) {
      lastConstraints ??= constraints;

      resizeDebounceTimer?.cancel();
      resizeDebounceTimer = Timer(const Duration(milliseconds: 30), () {
        resizeDebounceTimer = null;
        if (!mounted) {
          return;
        }

        final previousWidth = lastConstraints?.maxWidth;
        if (previousWidth == null || !previousWidth.isFinite || previousWidth <= 0) {
          return;
        }

        final navPanel = resizeController.panelsInfo.where((panel) => panel.id == "nav").firstOrNull;
        final mainPanel = resizeController.panelsInfo.where((panel) => panel.id == "main").firstOrNull;
        if (navPanel == null || mainPanel == null) {
          return;
        }

        final rawMinSize = _navBarMinWidth / width;
        final rawMaxSize = _navBarMaxWidth / width;
        final minSize = rawMinSize.clamp(0.0, 1.0);
        final maxSize = rawMaxSize.clamp(minSize, 1.0);
        final defaultSize = (navBarWidth / width).clamp(minSize, maxSize);

        final newPanel = ShadPanelInfo(id: "nav", minSize: minSize, maxSize: maxSize, defaultSize: defaultSize);

        // Don't change the size - prevent flickering
        final currentSize = (navPanel.size * previousWidth) / width;
        if (currentSize.isFinite && currentSize > minSize && currentSize < maxSize) {
          newPanel.size = currentSize;
        }

        lastConstraints = constraints;
        resizeController.update([newPanel, mainPanel]);
      });
    }
  }

  @override
  void didUpdateWidget(Nav oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId || oldWidget.selectedRoom != widget.selectedRoom) {
      rooms.refresh();
    }

    if (oldWidget.projectId != widget.projectId) {
      projects.refresh();
      isBalanceLowRes.refresh();
      canCreateRooms.refresh();
      role.refresh();
    }
  }

  List<Room> get filteredRooms {
    if (filter.isEmpty) {
      return rooms.state.value ?? [];
    }

    return (rooms.state.value ?? []).where((room) {
      final roomName = room.name;

      return roomName.toLowerCase().contains(filter.toLowerCase());
    }).toList();
  }

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

  @override
  void initState() {
    super.initState();

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
    _resetResizeState();
    projects.dispose();
    isBalanceLowRes.dispose();
    rooms.dispose();
    role.dispose();
    balanceRes.dispose();

    super.dispose();
  }

  Widget desktopBody(BuildContext context, ProjectRole? userRole, bool balanceLow, bool canCreateRooms) {
    if (userRole == ProjectRole.none) {
      return forbiddenView(context);
    }

    if (balanceLow) {
      if (userRole == null) {
        return const Center(child: CircularProgressIndicator());
      }

      return BalanceLowWarning(onAddCredits: onAddCredits, role: userRole);
    }

    return Container(key: childKey, child: widget.child);
  }

  Widget desktopView(BuildContext context, ProjectRole? userRole, bool balanceLow, bool canCreateRooms) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final navController = Controller.ofType<NavController>(context);
    final chromeVisible = ChromeVisibilityModel.of(context).visible;

    final hidden = navController.isNavHidden || !chromeVisible;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || width <= 0) {
          _resetResizeState();
          return const SizedBox.shrink();
        }

        final rawMinRatio = _navBarMinWidth / width;
        final rawMaxRatio = _navBarMaxWidth / width;
        final minRatio = rawMinRatio.clamp(0.0, 1.0);
        final maxRatio = rawMaxRatio.clamp(minRatio, 1.0);
        final defaultSize = (navBarWidth / width).clamp(minRatio, maxRatio);
        final mainDefaultSize = (1.0 - defaultSize).clamp(0.0, 1.0);

        // Debounce resize to avoid excessive rebuilds when resizing the window
        debounceResize(constraints);

        return ShadResizablePanelGroup(
          axis: .horizontal,
          showHandle: true,
          dividerColor: Colors.transparent,
          controller: resizeController,
          children: [
            // left nav
            if (!hidden)
              ShadResizablePanel(
                id: "nav",
                defaultSize: defaultSize,
                minSize: minRatio,
                maxSize: maxRatio,
                child: ColoredBox(
                  color: cs.background,
                  child: Column(
                    mainAxisSize: .min,
                    children: [
                      _NavBarTop(projectId: widget.projectId, projects: projects, onCreateProject: onCreateProject),

                      SignalBuilder(
                        builder: (context, _) => Expanded(
                          child: _NavBar(
                            projectId: widget.projectId,
                            rooms: rooms.state.isReady ? filteredRooms : [],
                            canCreateRooms: canCreateRooms,
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

            // main content
            ShadResizablePanel(id: "main", defaultSize: mainDefaultSize, child: desktopBody(context, userRole, balanceLow, canCreateRooms)),
          ],
        );
      },
    );
  }

  Widget mobileView(BuildContext context, ProjectRole? userRole, bool balanceLow, bool canCreateRooms) {
    _resetResizeState();

    if (userRole == ProjectRole.none) {
      return forbiddenView(context);
    }

    if (balanceLow) {
      if (userRole == null) {
        return const Center(child: CircularProgressIndicator());
      }

      if (userRole == ProjectRole.none) {
        return forbiddenView(context);
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

    if (widget.selectedRoom == null) {
      return ColoredBox(
        color: ShadTheme.of(context).colorScheme.card,
        child: SafeArea(
          child: Column(
            children: [
              _NavBarTop(projectId: widget.projectId, projects: projects, onCreateProject: onCreateProject),

              SignalBuilder(
                builder: (context, _) => Expanded(
                  child: _NavBar(
                    projectId: widget.projectId,
                    rooms: rooms.state.isReady ? filteredRooms : [],
                    canCreateRooms: canCreateRooms,
                    setFilter: setFilter,
                    onSave: () => rooms.refresh(),
                    onRefresh: () => rooms.refresh(),
                    balanceLow: balanceLow,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(key: childKey, child: widget.child);
    }
  }

  Widget outOfCreditBanner(BuildContext context, ProjectRole? userRole) {
    final theme = ShadTheme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;

    if (userRole == null) {
      return SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 48),
      color: statusError,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Center(
        child: Text.rich(
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

    return Container(
      constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 48),
      color: statusError,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Center(
        child: Row(
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

  Widget forbiddenView(BuildContext context) {
    final isSmallDisplay = ResponsiveBreakpoints.of(context).smallerOrEqualTo("chromebook");

    if (isSmallDisplay) {
      return SafeArea(
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

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final isSmallDisplay = ResponsiveBreakpoints.of(context).smallerOrEqualTo("chromebook");
    final navController = Controller.ofType<NavController>(context);

    return SignalBuilder(
      builder: (context, _) {
        if (!projects.state.isReady || !role.state.isReady || !isBalanceLowRes.state.isReady || !balanceRes.state.isReady) {
          return const Center(child: CircularProgressIndicator());
        }

        if (projects.state.value!.isEmpty) {
          return EmptyProjectsState(onCreateProject: onCreateProject);
        }

        final balanceLow = isBalanceLowRes.state.value ?? false;
        final userRole = role.state.value;
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
                  child: isSmallDisplay
                      ? mobileView(context, userRole, balanceLow, canCreateRooms)
                      : desktopView(context, userRole, balanceLow, canCreateRooms),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    this.selectedRoom,
    required this.rooms,
    required this.setFilter,
    required this.onSave,
    required this.onRefresh,
    required this.projectId,
    required this.balanceLow,
    required this.canCreateRooms,
  });

  final String? selectedRoom;
  final List<Room> rooms;
  final void Function(String) setFilter;
  final void Function() onSave;
  final Future<void> Function() onRefresh;
  final String? projectId;
  final bool balanceLow;
  final bool canCreateRooms;

  Future<void> addNewRoomDialog(BuildContext context) async {
    final room = await createMeshagentRoom(context, projectId!);
    if (!context.mounted) {
      return;
    }

    if (room != null) {
      final pid = fromUUID(projectId!);

      if (!context.mounted) {
        return;
      }

      context.go("/p/$pid/r/${room.name}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardSafe(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: desktopPaneSecondaryControlTopOffset),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: desktopPaneSideHorizontalInset),
            child: SizedBox(
              height: desktopPaneSecondaryControlHeight,
              child: ShadInput(
                decoration: ShadDecoration(color: ShadTheme.of(context).colorScheme.input),
                key: const Key('room-list-search-field'),
                onChanged: setFilter,
                placeholder: Text("Filter rooms..."),
              ),
            ),
          ),
          const SizedBox(height: desktopPaneSecondaryRowContentGap),
          Expanded(
            child: projectId == null
                ? Center(child: CircularProgressIndicator())
                : NavRooms(
                    projectId: projectId!,
                    rooms: rooms,
                    selectedRoom: selectedRoom,
                    onSelect: (room) async {
                      final pid = fromUUID(projectId!);

                      if (!context.mounted) {
                        return;
                      }

                      context.go("/p/$pid/r/${room.name}");
                    },
                    onSave: onSave,
                    onRefresh: onRefresh,
                    balanceLow: balanceLow,
                  ),
          ),
          if (canCreateRooms)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                desktopPaneSideHorizontalInset,
                10,
                desktopPaneSideHorizontalInset,
                desktopPaneBottomInset,
              ),
              child: ShadButton.outline(
                decoration: ShadDecoration(border: ShadBorder.all(color: ShadTheme.of(context).colorScheme.border)),
                backgroundColor: ShadTheme.of(context).colorScheme.background,
                hoverBackgroundColor: ShadTheme.of(context).colorScheme.background,
                hoverForegroundColor: ShadTheme.of(context).colorScheme.foreground,
                key: const Key('nav-create-room-button'),
                leading: Icon(LucideIcons.packagePlus),
                onPressed: () => addNewRoomDialog(context),
                child: const Text("New Room"),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavBarTop extends StatefulWidget {
  const _NavBarTop({required this.projects, required this.projectId, required this.onCreateProject});

  final String? projectId;
  final Resource<List<Project>> projects;
  final Future<void> Function() onCreateProject;

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
    showSwitchProjectDialog(
      context: context,
      currentProjectId: widget.projectId ?? "",
      projects: widget.projects,
      onSwitch: (project) {
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
    final isSmallDisplay = ResponsiveBreakpoints.of(context).smallerOrEqualTo("chromebook");
    final displayName = selectedProject?.name ?? "Select project";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: desktopPaneSideHorizontalInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          if (isSmallDisplay)
            SizedBox(
              height: headerHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxLabelWidth = (constraints.maxWidth - 160).clamp(80.0, 320.0);

                  return Stack(
                    children: [
                      const Align(alignment: Alignment.centerLeft, child: NavMainLogo()),
                      Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _switchProject,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: maxLabelWidth),
                                  child: Text(
                                    displayName,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.foreground,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(LucideIcons.chevronsUpDown, size: 20, color: theme.colorScheme.foreground),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: UserAvatarMenuButton(projectId: widget.projectId, projects: widget.projects, boundaryContext: context),
                      ),
                    ],
                  );
                },
              ),
            ),
          if (!isSmallDisplay)
            SizedBox(
              height: headerHeight,
              child: Center(
                child: SizedBox(
                  height: desktopPaneHeaderContentHeight,
                  width: double.infinity,
                  child: Tooltip(
                    message: "Switch project",
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _switchProject,
                        child: DecoratedBox(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Positioned(
                                left: 0,
                                child: SizedBox(
                                  width: desktopPaneSideHeaderSlotSize,
                                  height: desktopPaneSideHeaderSlotSize,
                                  child: Center(child: NavMainLogo(size: desktopPaneSideHeaderSlotSize)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: desktopPaneSideHeaderVisualInset),
                                child: Text(
                                  displayName,
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: theme.colorScheme.foreground),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                child: SizedBox(
                                  width: desktopPaneSideHeaderVisualInset,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Icon(LucideIcons.chevronsUpDown, size: 20, color: theme.colorScheme.foreground),
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
