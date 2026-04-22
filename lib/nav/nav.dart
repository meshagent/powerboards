import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as fs;
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
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
import 'package:powerboards/ui/powerboards_adaptive_input.dart';

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

({String title, String description}) powerboardsMobileCreditBannerCopy({required bool outOfCredit, required ProjectRole? userRole}) {
  if (!outOfCredit) {
    return (title: "Low balance", description: "Add more credits to avoid service interruption.");
  }

  return (
    title: "Out of credit",
    description: userRole == ProjectRole.admin ? "Add more credits to re-enable rooms." : "Contact your project admin to add more credits.",
  );
}

class _NavState extends State<Nav> {
  final resizeController = ShadResizableController();
  double? _navRatio;
  bool _panelLayoutSyncScheduled = false;
  bool? _lastDesktopHidden;
  double? _lastDesktopWidth;
  bool? _lastSmallDisplay;
  int _mobileNavigationDirection = 1;

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

  ({({double minSize, double maxSize, double defaultSize}) nav, ({double minSize, double maxSize, double defaultSize}) main})
  _resolvePanelLayout(double width, {required bool hidden}) {
    if (hidden) {
      return (nav: (minSize: 0, maxSize: 0, defaultSize: 0), main: (minSize: 1, maxSize: 1, defaultSize: 1));
    }

    final rawMinRatio = _navBarMinWidth / width;
    final rawMaxRatio = _navBarMaxWidth / width;
    final minRatio = rawMinRatio.clamp(0.0, 1.0);
    final maxRatio = rawMaxRatio.clamp(minRatio, 1.0);
    final preferredRatio = (_navRatio ?? (navBarWidth / width)).clamp(minRatio, maxRatio).toDouble();
    final mainDefaultSize = (1.0 - preferredRatio).clamp(0.0, 1.0).toDouble();
    final mainMinSize = (1.0 - maxRatio).clamp(0.0, 1.0).toDouble();
    final mainMaxSize = (1.0 - minRatio).clamp(mainMinSize, 1.0).toDouble();

    return (
      nav: (minSize: minRatio, maxSize: maxRatio, defaultSize: preferredRatio),
      main: (minSize: mainMinSize, maxSize: mainMaxSize, defaultSize: mainDefaultSize),
    );
  }

  void _resetDesktopPanelState() {
    resizeController.clear();
    _lastDesktopHidden = null;
    _lastDesktopWidth = null;
    _panelLayoutSyncScheduled = false;
  }

  void _updatePanelLayout(BoxConstraints constraints, {required bool hidden}) {
    final navPanel = resizeController.panelsInfo.where((panel) => panel.id == "nav").firstOrNull;
    final mainPanel = resizeController.panelsInfo.where((panel) => panel.id == "main").firstOrNull;
    if (navPanel == null || mainPanel == null) {
      return;
    }

    final width = constraints.maxWidth;
    if (!width.isFinite || width <= 0) {
      return;
    }

    if (navPanel.size > 0) {
      _navRatio = navPanel.size;
    }

    final panelLayout = _resolvePanelLayout(width, hidden: hidden);
    final nextNav = ShadPanelInfo(
      id: "nav",
      minSize: panelLayout.nav.minSize,
      maxSize: panelLayout.nav.maxSize,
      defaultSize: panelLayout.nav.defaultSize,
    );
    final nextMain = ShadPanelInfo(
      id: "main",
      minSize: panelLayout.main.minSize,
      maxSize: panelLayout.main.maxSize,
      defaultSize: panelLayout.main.defaultSize,
    );

    if (!hidden && navPanel.size > 0) {
      nextNav.size = navPanel.size.clamp(nextNav.minSize, nextNav.maxSize).toDouble();
    }

    resizeController.update([nextNav, nextMain]);
  }

  void _schedulePanelLayoutSyncForBuild(BoxConstraints constraints, {required bool hidden}) {
    if (_panelLayoutSyncScheduled) {
      return;
    }

    _panelLayoutSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _panelLayoutSyncScheduled = false;
      if (!mounted) {
        return;
      }

      _updatePanelLayout(constraints, hidden: hidden);
    });
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
    resizeController.dispose();
    projects.dispose();
    isBalanceLowRes.dispose();
    rooms.dispose();
    role.dispose();
    balanceRes.dispose();

    super.dispose();
  }

  Widget desktopBody(BuildContext context, ProjectRole? userRole, bool balanceLow, bool canCreateRooms) {
    final cs = ShadTheme.of(context).colorScheme;

    if (userRole == ProjectRole.none) {
      return forbiddenView(context);
    }

    if (balanceLow) {
      if (userRole == null) {
        return const Center(child: CircularProgressIndicator());
      }

      return ColoredBox(
        color: cs.card,
        child: BalanceLowWarning(onAddCredits: onAddCredits, role: userRole),
      );
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
          return const SizedBox.shrink();
        }

        if (_lastDesktopWidth != width) {
          _lastDesktopWidth = width;
          _schedulePanelLayoutSyncForBuild(constraints, hidden: hidden);
        }

        if (_lastDesktopHidden != hidden) {
          _lastDesktopHidden = hidden;
          _schedulePanelLayoutSyncForBuild(constraints, hidden: hidden);
        }

        final panelLayout = _resolvePanelLayout(width, hidden: hidden);

        return ShadResizablePanelGroup(
          axis: .horizontal,
          showHandle: true,
          dividerColor: Colors.transparent,
          controller: resizeController,
          children: [
            ShadResizablePanel(
              id: "nav",
              defaultSize: panelLayout.nav.defaultSize,
              minSize: panelLayout.nav.minSize,
              maxSize: panelLayout.nav.maxSize,
              child: IgnorePointer(
                ignoring: hidden,
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
            ),

            ShadResizablePanel(
              id: "main",
              defaultSize: panelLayout.main.defaultSize,
              minSize: panelLayout.main.minSize,
              maxSize: panelLayout.main.maxSize,
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

    final mobileContent = widget.selectedRoom == null
        ? KeyedSubtree(
            key: const ValueKey('mobile-room-list'),
            child: ColoredBox(
              color: ShadTheme.of(context).colorScheme.card,
              child: SafeArea(
                minimum: powerboardsMobileScreenSafeAreaMinimum,
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
            ),
          )
        : KeyedSubtree(
            key: ValueKey('mobile-room-${widget.selectedRoom}'),
            child: ColoredBox(key: childKey, color: ShadTheme.of(context).colorScheme.card, child: widget.child),
          );

    return ClipRect(
      child: AnimatedSwitcher(
        duration: powerboardsMobileTransitionDuration,
        switchInCurve: powerboardsMobileTransitionInCurve,
        switchOutCurve: powerboardsMobileTransitionOutCurve,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(fit: StackFit.expand, children: [...previousChildren, if (currentChild != null) currentChild]);
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

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final isSmallDisplay = ResponsiveBreakpoints.of(context).smallerOrEqualTo("chromebook");
    final navController = Controller.ofType<NavController>(context);

    if (_lastSmallDisplay == true && !isSmallDisplay) {
      _resetDesktopPanelState();
    }
    _lastSmallDisplay = isSmallDisplay;

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
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final keyboardOpen = isMobile && (MediaQuery.maybeOf(context)?.viewInsets.bottom ?? 0.0) > 0;
    final horizontalPadding = isMobile
        ? powerboardsMobileHorizontalPadding
        : const EdgeInsets.symmetric(horizontal: desktopPaneSideHorizontalInset);

    return KeyboardSafe(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: desktopPaneSecondaryControlTopOffset),
          Padding(
            padding: horizontalPadding,
            child: Builder(
              builder: (context) {
                final filterInput = PowerboardsAdaptiveInput(
                  decoration: ShadDecoration(color: ShadTheme.of(context).colorScheme.input),
                  key: const Key('room-list-search-field'),
                  onChanged: setFilter,
                  inputPadding: isMobile ? const EdgeInsets.only(left: 5) : null,
                  placeholder: Text("Filter rooms..."),
                );

                if (isMobile) {
                  return filterInput;
                }

                return SizedBox(height: desktopPaneSecondaryControlHeight, child: filterInput);
              },
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
          if (canCreateRooms && !keyboardOpen)
            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? powerboardsMobileShellHorizontalInset : desktopPaneSideHorizontalInset,
                10,
                isMobile ? powerboardsMobileShellHorizontalInset : desktopPaneSideHorizontalInset,
                desktopPaneBottomInset,
              ),
              child: ShadButton.outline(
                height: powerboardsFooterActionButtonHeight,
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
    final mobileHeaderControlSize = desktopPaneHeaderCompactButtonWidth;
    final displayName = selectedProject?.name ?? "Select project";
    final projectTitleStyle = isSmallDisplay
        ? powerboardsMobileHeaderPrimaryTextStyle(color: theme.colorScheme.foreground)
        : powerboardsSectionTitleStyle(color: theme.colorScheme.foreground, height: 1.2);

    return Container(
      padding: isSmallDisplay ? powerboardsMobileHorizontalPadding : const EdgeInsets.symmetric(horizontal: desktopPaneSideHorizontalInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          if (isSmallDisplay)
            SizedBox(
              height: headerHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    child: SizedBox(
                      width: mobileHeaderControlSize,
                      height: headerHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: NavMainLogo(size: mobileHeaderControlSize - 8),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: SizedBox(
                      width: mobileHeaderControlSize,
                      height: headerHeight,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: UserAvatarMenuButton(
                          projectId: widget.projectId,
                          projects: widget.projects,
                          boundaryContext: context,
                          avatarSize: mobileHeaderControlSize,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: mobileHeaderControlSize + 8),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SizedBox(
                            width: constraints.maxWidth,
                            child: ShadButton.ghost(
                              expands: true,
                              height: desktopPaneHeaderContentHeight,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              onPressed: _switchProject,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
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
                                      const SizedBox(width: 8),
                                      Icon(LucideIcons.chevronsUpDown, size: 20, color: theme.colorScheme.foreground),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
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
                                  style: projectTitleStyle,
                                  strutStyle: StrutStyle.fromTextStyle(projectTitleStyle, forceStrutHeight: true),
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
