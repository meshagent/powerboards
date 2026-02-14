import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:localstorage/localstorage.dart';
import 'package:powerboards/ui/avatar_menu_button.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:vector_graphics/vector_graphics.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/powerboards_controller/powerboards_controller.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/empty_states.dart';
import 'package:powerboards/ui/keyboard_safe.dart';
import 'package:powerboards/ui/powerboards_dialog.dart';

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

    launchUrl(redirectUrl, webOnlyWindowName: "_self");
  }

  void debounceResize(BoxConstraints constraints) {
    if (lastConstraints == null) {
      lastConstraints = constraints;
    } else if (lastConstraints!.maxWidth != constraints.maxWidth) {
      resizeDebounceTimer?.cancel();
      resizeDebounceTimer = Timer(const Duration(milliseconds: 30), () {
        final navPanel = resizeController.panelsInfo.where((panel) => panel.id == "nav").firstOrNull;
        final mainPanel = resizeController.panelsInfo.where((panel) => panel.id == "main").firstOrNull;
        if (navPanel == null || mainPanel == null) {
          return;
        }

        final minSize = _navBarMinWidth / constraints.maxWidth;
        final maxSize = _navBarMaxWidth / constraints.maxWidth;
        final defaultSize = navBarWidth / constraints.maxWidth;

        final newPanel = ShadPanelInfo(id: "nav", minSize: minSize, maxSize: maxSize, defaultSize: defaultSize);

        // Don't change the size - prevent flickering
        final currentSize = (navPanel.size * lastConstraints!.maxWidth) / constraints.maxWidth;
        if (currentSize > minSize && currentSize < maxSize) {
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
        final minRatio = _navBarMinWidth / constraints.maxWidth;
        final maxRatio = _navBarMaxWidth / constraints.maxWidth;
        final defaultSize = navBarWidth / constraints.maxWidth;

        // Debounce resize to avoid excessive rebuilds when resizing the window
        debounceResize(constraints);

        return ShadResizablePanelGroup(
          axis: .horizontal,
          showHandle: true,
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
                  color: cs.accent,
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
            ShadResizablePanel(
              id: "main",
              defaultSize: 1.0 - defaultSize,
              child: desktopBody(context, userRole, balanceLow, canCreateRooms),
            ),
          ],
        );
      },
    );
  }

  Widget mobileView(BuildContext context, ProjectRole? userRole, bool balanceLow, bool canCreateRooms) {
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
      return SafeArea(
        child: Column(
          children: [
            _NavBarTop(projectId: widget.projectId, projects: projects, onCreateProject: onCreateProject),
            Expanded(
              child: _NavBar(
                projectId: widget.projectId,
                rooms: filteredRooms,
                canCreateRooms: canCreateRooms,
                onSave: () => rooms.refresh(),
                onRefresh: () => rooms.refresh(),
                setFilter: setFilter,
                balanceLow: balanceLow,
              ),
            ),
          ],
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
      color: cs.destructive,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Center(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "Out of Credit - ",
                style: tt.small.copyWith(fontWeight: FontWeight.bold),
              ),

              if (userRole == ProjectRole.admin)
                TextSpan(text: "Add more credits to re-enable rooms.")
              else
                TextSpan(text: "Contact your project admin to add more credits."),
            ],
          ),
          style: tt.small.copyWith(color: cs.background, height: 1.5),
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
      color: cs.destructive,
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
                    style: tt.small.copyWith(fontWeight: FontWeight.bold),
                  ),

                  TextSpan(text: "Add more credits to avoid service interruption."),
                ],
              ),
              style: tt.small.copyWith(color: cs.background, height: 1.5),
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
              UserAvatarMenuButton(projectId: widget.projectId, projects: widget.projects),
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
          Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 0),
            child: ShadInput(
              decoration: ShadDecoration(color: ShadTheme.of(context).colorScheme.background),
              key: const Key('room-list-search-field'),
              onChanged: setFilter,
              placeholder: Text("Filter rooms..."),
            ),
          ),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: ShadButton.outline(
                decoration: ShadDecoration(border: ShadBorder.all(color: ShadTheme.of(context).colorScheme.foreground.withAlpha(60))),
                hoverBackgroundColor: ShadTheme.of(context).colorScheme.background,
                hoverForegroundColor: ShadTheme.of(context).colorScheme.foreground,
                key: const Key('nav-create-room-button'),
                leading: Icon(LucideIcons.plus),
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
  static const _newProjectValue = '__new_project__';

  final dialogController = DialogController();
  final popoverController = ShadPopoverController();

  late final projectSelectController = ShadSelectController<String?>(initialValue: {widget.projectId});

  void toggleChromeVisibility() {
    final visibility = !ChromeVisibilityState.of(context).visible;
    ChromeVisibilityState.of(context).visible = visibility;
    FullScreenWindow.setFullScreen(!visibility);
  }

  @override
  void initState() {
    super.initState();

    popoverController.addListener(() {
      if (popoverController.isOpen) {
        widget.projects.refresh();
      }
    });
  }

  @override
  void didUpdateWidget(_NavBarTop oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId) {
      projectSelectController.value = {widget.projectId};
    }
  }

  @override
  void dispose() {
    dialogController.dispose();
    projectSelectController.dispose();
    popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectsReady = widget.projects.state.isReady;
    final projectList = projectsReady ? widget.projects.state.value! : const <Project>[];
    final selectedProject = projectList.firstWhereOrNull((p) => p.id == widget.projectId);
    final isSmallDisplay = ResponsiveBreakpoints.of(context).smallerOrEqualTo("chromebook");
    final selectHeight = MediaQuery.of(context).size.height;

    return DialogAnchor(
      controller: dialogController,
      child: Container(
        padding: const EdgeInsets.only(left: 20, right: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            if (isSmallDisplay)
              SizedBox(
                height: headerHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const NavMainLogo(),
                    const Spacer(),
                    if (isSmallDisplay) UserAvatarMenuButton(projectId: widget.projectId, projects: widget.projects),
                  ],
                ),
              ),
            if (!isSmallDisplay) SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  spacing: 16,
                  children: [
                    if (!isSmallDisplay) const NavMainLogo(size: 30),
                    Expanded(
                      child: ShadSelect<String?>(
                        anchor: ShadAnchor(childAlignment: .topLeft),
                        decoration: .none,
                        padding: .zero,
                        maxHeight: selectHeight,
                        controller: projectSelectController,
                        popoverController: popoverController,
                        placeholder: const Text('Select project'),
                        showScrollToTopChevron: false,
                        showScrollToBottomChevron: false,
                        onChanged: (value) {
                          if (value != null && context.mounted) {
                            localStorage.setItem("lastProjectId", value);
                            context.go("/p/${fromUUID(value)}");
                          }
                        },
                        options: [
                          if (projectsReady)
                            ...projectList.map(
                              (project) => ShadOption<String?>(
                                value: project.id,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(minWidth: 200),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(project.name, overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              ),
                            ),
                        ],
                        trailing: isSmallDisplay ? null : Icon(LucideIcons.ellipsisVertical),
                        footer: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ShadSeparator.horizontal(margin: .zero),
                            ShadButton.ghost(
                              onPressed: widget.onCreateProject,
                              leading: Icon(LucideIcons.plus, size: 16),
                              child: const Text("New Project"),
                            ),
                          ],
                        ),
                        selectedOptionBuilder: (context, value) {
                          final effectiveValue = value == _newProjectValue ? widget.projectId : value;
                          final displayName = effectiveValue == null
                              ? selectedProject?.name
                              : projectList.firstWhereOrNull((p) => p.id == effectiveValue)?.name ?? selectedProject?.name;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  displayName ?? 'Select project',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF222222)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NavMainLogo extends StatelessWidget {
  const NavMainLogo({super.key, this.size});

  final double? size;
  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;

    return Container(
      width: size ?? (kIsWeb ? 42.0 : 46.0),
      height: size ?? (kIsWeb ? 42.0 : 46.0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: .all(color: Color.from(alpha: 1, red: .5, green: .5, blue: .5), width: 7),
        borderRadius: .circular(8),
        color: Color.from(alpha: 1, red: .5, green: .5, blue: .5),
      ),
      child: SvgPicture(const AssetBytesLoader('lib/assets/powerboards-logo.vec'), colorFilter: .mode(cs.background, BlendMode.srcIn)),
    );
  }
}
