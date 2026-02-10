import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:localstorage/localstorage.dart';
import 'package:meshagent/client.dart';
import 'package:meshagent_flutter_auth/meshagent_auth.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/nav/switch_project_dialog.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/ui/app_context_menu.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class UserAvatarMenuButton extends StatefulWidget {
  const UserAvatarMenuButton({super.key, required this.projectId, required this.projects});
  final String? projectId;
  final Resource<List<Project>> projects;

  @override
  State<UserAvatarMenuButton> createState() => _UserAvatarMenuButtonState();
}

class _UserAvatarMenuButtonState extends State<UserAvatarMenuButton> {
  bool hovered = false;
  final billingUrl = MeshagentConfig.current?.billingUrl;

  late final _role = Resource<ProjectRole?>(() async {
    final pid = widget.projectId;
    if (pid == null) return null;

    final client = getMeshagentClient();

    return client.getProjectRole(pid);
  });

  @override
  void dispose() {
    _role.dispose();

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UserAvatarMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId) {
      _role.refresh();
    }
  }

  bool get _isAdmin {
    final state = _role.state;

    if (!state.isReady) return false;
    if (state.hasError && !state.isRefreshing) return false;

    return state.value == ProjectRole.admin;
  }

  String _initialsFromUser(Map<String, dynamic>? user) {
    String initials = "U";
    final email = (user?["email"] as String?)?.trim() ?? "";
    if (email.isNotEmpty) {
      final local = email.split("@").first;
      final parts = local.split(RegExp(r"[._\- ]+")).where((p) => p.isNotEmpty).toList();

      if (parts.length >= 2) {
        initials = "${parts[0].characters.first}${parts[1].characters.first}";
      } else if (parts.length == 1) {
        initials = parts[0].characters.first;
      }
    }
    return initials.toUpperCase();
  }

  void _signOut() {
    MeshagentAuth.current.signOut();
    localStorage.clear();

    final returnUrl = MeshagentConfig.current!.appUrl;
    final signOutUrl = MeshagentConfig.current!.serverUrl
        .resolve("/signout")
        .replace(queryParameters: {if (MeshagentConfig.current?.appUrl != null) "return_url": returnUrl.toString()});

    if (kIsWeb) {
      launchUrl(signOutUrl, webOnlyWindowName: "_self");
    } else {
      context.go("/");
    }
  }

  void _goToAccounts() {
    if (billingUrl == null) return;

    if (widget.projectId == null) {
      launchUrl(billingUrl!, webOnlyWindowName: "_self");
    } else {
      final pid = fromUUID(widget.projectId!);
      final pUrl = billingUrl!.replace(path: "/p/$pid");

      launchUrl(pUrl, webOnlyWindowName: "_self");
    }
  }

  void _goToProject(String id) {
    localStorage.setItem("lastProjectId", id);
    context.go("/p/${fromUUID(id)}");
  }

  void _switchProject() {
    widget.projects.refresh();

    showShadDialog(
      context: context,
      builder: (context) => SwitchProjectDialog(
        currentProjectId: widget.projectId ?? "",
        projects: widget.projects,
        onSwitch: (project) => _goToProject(project.id),
        onNewProject: _onNewProject,
      ),
    );
  }

  Future<void> _onNewProject() async {
    final p = await createMeshagentProject(context);

    if (!mounted) return;
    if (p == null) return;

    final projectId = p['id'] as String?;
    if (projectId == null) return;

    widget.projects.refresh();
    _goToProject(projectId);
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, _) {
        final user = MeshagentAuth.current.getUser();
        final initials = _initialsFromUser(user);
        final displayName = ((user?["name"] as String?) ?? (user?["full_name"] as String?) ?? "").trim();
        final email = ((user?["email"] as String?) ?? "").trim();
        final title = displayName.isNotEmpty ? displayName : (email.isNotEmpty ? email : "Account");

        final projectsState = widget.projects.state;
        final projectsList = projectsState.value ?? const <Project>[];
        final currentProject = widget.projectId == null ? null : projectsList.firstWhereOrNull((p) => p.id == widget.projectId);
        final description = currentProject?.name ?? "Signed in";

        final entries = <AppMenuEntry>[
          AppMenuEntry(
            title: title,
            description: description,
            onPressed: null,
            leading: UserAvatarCircle(initials: initials, size: 32),
          ),
          AppMenuEntry(
            title: "Change project",
            description: "Switch to a different project",
            icon: LucideIcons.package,
            onPressed: _switchProject,
          ),

          if (kIsWeb && _isAdmin)
            AppMenuEntry(
              title: "Account management",
              description: "Manage billing & members",
              icon: LucideIcons.users,
              onPressed: _goToAccounts,
            ),
          AppMenuEntry(title: "Sign out", description: "Sign out of your account.", icon: LucideIcons.logOut, onPressed: _signOut),
        ];

        return AppContextMenuButton(
          entries: entries,
          childBuilder: (context, controller) {
            return Tooltip(
              message: "Accounts",
              child: ShadButton.ghost(
                hoverBackgroundColor: Colors.transparent,
                padding: EdgeInsets.zero,
                decoration: ShadDecoration.none,
                onPressed: () {
                  if (!controller.isOpen) controller.show();
                },
                onHoverChange: (hovering) => setState(() => hovered = hovering),
                child: UserAvatarCircle(initials: initials, hovered: hovered),
              ),
            );
          },
        );
      },
    );
  }
}

class UserAvatarCircle extends StatelessWidget {
  const UserAvatarCircle({super.key, required this.initials, this.size = 40, this.hovered = false});

  final String initials;
  final double size;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final buttonTheme = theme.outlineButtonTheme;
    final hoverBackgroundColor = buttonTheme.hoverBackgroundColor ?? cs.muted;
    final backgroundColor = buttonTheme.backgroundColor ?? cs.background;

    return Container(
      width: size,
      height: size,
      alignment: .center,
      decoration: BoxDecoration(
        shape: .circle,
        color: hovered ? hoverBackgroundColor : backgroundColor,
        border: .all(color: cs.border, strokeAlign: BorderSide.strokeAlignOutside),
      ),
      child: Text(
        initials,
        style: tt.small.copyWith(fontWeight: .w700, color: cs.foreground),
      ),
    );
  }
}
