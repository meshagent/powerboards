import 'dart:ui' show lerpDouble;

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
import 'package:powerboards/settings/ui_mode.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/app_context_menu.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

String userAvatarInitialsFromEmail(String email) {
  String initials = "U";
  final normalizedEmail = email.trim();
  if (normalizedEmail.isNotEmpty) {
    final local = normalizedEmail.split("@").first;
    final parts = local.split(RegExp(r"[-._ ]+")).where((p) => p.isNotEmpty).toList();

    if (parts.length >= 2) {
      initials = "${parts[0].characters.first}${parts[1].characters.first}";
    } else if (parts.length == 1) {
      initials = parts[0].characters.first;
    }
  }
  return initials.toUpperCase();
}

enum UserAvatarVariant { header, standard, menu }

const Color powerboardsAvatarAccentColor = Color(0xFFE4E4FF);
const double userAvatarHeaderDiameter = 40;
const double userAvatarStandardDiameter = 32;
const double userAvatarMenuDiameter = 24;
const double _userAvatarHeaderFontSize = 13;
const double _userAvatarStandardFontSize = 11;
const double _userAvatarMenuFontSize = 8.5;
const double _userAvatarLargeFontSize = 14.5;

double userAvatarDiameter(UserAvatarVariant variant) => switch (variant) {
  UserAvatarVariant.header => userAvatarHeaderDiameter,
  UserAvatarVariant.standard => userAvatarStandardDiameter,
  UserAvatarVariant.menu => userAvatarMenuDiameter,
};

double userAvatarInitialsFontSize(double diameter) {
  if (diameter <= userAvatarMenuDiameter) {
    return _userAvatarMenuFontSize;
  }

  if (diameter <= userAvatarStandardDiameter) {
    final t = (diameter - userAvatarMenuDiameter) / (userAvatarStandardDiameter - userAvatarMenuDiameter);
    return lerpDouble(_userAvatarMenuFontSize, _userAvatarStandardFontSize, t) ?? _userAvatarStandardFontSize;
  }

  if (diameter <= userAvatarHeaderDiameter) {
    final t = (diameter - userAvatarStandardDiameter) / (userAvatarHeaderDiameter - userAvatarStandardDiameter);
    return lerpDouble(_userAvatarStandardFontSize, _userAvatarHeaderFontSize, t) ?? _userAvatarHeaderFontSize;
  }

  final largeDiameter = diameter.clamp(userAvatarHeaderDiameter, 48.0);
  final t = (largeDiameter - userAvatarHeaderDiameter) / (48.0 - userAvatarHeaderDiameter);
  return lerpDouble(_userAvatarHeaderFontSize, _userAvatarLargeFontSize, t) ?? _userAvatarLargeFontSize;
}

class UserAvatarMenuButton extends StatefulWidget {
  const UserAvatarMenuButton({super.key, required this.projectId, required this.projects, this.boundaryContext, this.avatarSize = 40});
  final String? projectId;
  final Resource<List<Project>> projects;
  final BuildContext? boundaryContext;
  final double avatarSize;

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
  void initState() {
    super.initState();
    syncPowerboardsUiModeFromStorage();
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

  void _signOut() {
    resetPowerboardsUiMode();
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
      launchUrl(billingUrl!);
    } else {
      final pid = fromUUID(widget.projectId!);
      final pUrl = billingUrl!.replace(path: "/p/$pid");

      launchUrl(pUrl);
    }
  }

  void _goToProject(String id) {
    localStorage.setItem("lastProjectId", id);
    context.go("/p/${fromUUID(id)}");
  }

  void _switchProject() {
    showSwitchProjectDialog(
      context: context,
      currentProjectId: widget.projectId ?? "",
      projects: widget.projects,
      onSwitch: (project) => _goToProject(project.id),
      onNewProject: _onNewProject,
    );
  }

  void _toggleUiMode() {
    togglePowerboardsUiMode();
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

  Future<void> _runAccountDialogAction(BuildContext dialogContext, VoidCallback action) async {
    Navigator.of(dialogContext).pop();
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) {
      return;
    }

    action();
  }

  Future<void> _showAccountFlowDialog(List<AppMenuEntry> entries) {
    return showPowerboardsFlowDialog<void>(
      context: context,
      builder: (dialogContext) {
        final usesLandscapeMobileDialogLayout = powerboardsUsesLandscapeMobileDialogLayout(dialogContext);

        return PowerboardsShadDialog.listPicker(
          title: const Text('Account'),
          description: const Text('Manage your account and project'),
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: powerboardsUsesNativeMobileDialogLayout(dialogContext) ? EdgeInsets.zero : powerboardsDialogScrollableListPadding,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: double.infinity,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: usesLandscapeMobileDialogLayout ? double.infinity : 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        if (i > 0) const ShadSeparator.horizontal(margin: EdgeInsets.zero),
                        _AccountFlowDialogRow(
                          entry: entries[i],
                          onPressed: entries[i].onPressed == null
                              ? null
                              : () => _runAccountDialogAction(dialogContext, entries[i].onPressed!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, _) {
        final currentUiMode = powerboardsUiModeSignal.value;
        final isMobile = powerboardsUsesNativeMobileDialogLayout(context);
        final user = MeshagentAuth.current.getUser();
        final initials = userAvatarInitialsFromEmail((user?["email"] as String?) ?? "");
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
            leading: UserAvatarCircle(initials: initials, variant: UserAvatarVariant.standard),
          ),
          AppMenuEntry(
            title: "Change project",
            description: "Switch to a different project",
            icon: LucideIcons.package,
            onPressed: _switchProject,
          ),
          if (!isMobile)
            AppMenuEntry(
              title: currentUiMode == PowerboardsUiMode.v1 ? "End new UI Preview" : "Preview new UI",
              description: currentUiMode == PowerboardsUiMode.v1 ? "Switch back" : "In-development",
              icon: currentUiMode == PowerboardsUiMode.v1 ? LucideIcons.rotateCcw : LucideIcons.eye,
              onPressed: _toggleUiMode,
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

        if (isMobile) {
          return Tooltip(
            message: "Accounts",
            child: ShadButton.ghost(
              hoverBackgroundColor: Colors.transparent,
              padding: EdgeInsets.zero,
              decoration: ShadDecoration.none,
              onPressed: () => _showAccountFlowDialog(entries),
              onHoverChange: (hovering) => setState(() => hovered = hovering),
              child: UserAvatarCircle(initials: initials, size: widget.avatarSize, hovered: hovered),
            ),
          );
        }

        return AppContextMenuButton(
          boundaryContext: widget.boundaryContext ?? context,
          entries: entries,
          childBuilder: (context, controller) {
            return Tooltip(
              message: "Accounts",
              child: ShadButton.ghost(
                hoverBackgroundColor: Colors.transparent,
                padding: EdgeInsets.zero,
                decoration: ShadDecoration.none,
                onPressed: controller.toggle,
                onHoverChange: (hovering) => setState(() => hovered = hovering),
                child: UserAvatarCircle(initials: initials, size: widget.avatarSize, hovered: hovered),
              ),
            );
          },
        );
      },
    );
  }
}

class _AccountFlowDialogRow extends StatelessWidget {
  const _AccountFlowDialogRow({required this.entry, required this.onPressed});

  final AppMenuEntry entry;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final foreground = theme.colorScheme.foreground;
    final titleStyle = powerboardsInterTextStyle(color: foreground, fontWeight: FontWeight.w600);
    final descriptionStyle = powerboardsInterTextStyle(color: foreground);
    final description = entry.description?.trim();
    final hasDescription = description != null && description.isNotEmpty;
    final leadingWidget =
        entry.leading ??
        (entry.icon != null
            ? SizedBox(
                width: 32,
                height: 32,
                child: Center(child: Icon(entry.icon, size: 20, color: foreground)),
              )
            : const SizedBox(width: 32, height: 32));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: hasDescription ? 80.0 : powerboardsMobileSecondaryRowHeight),
          child: Row(
            crossAxisAlignment: hasDescription ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(top: hasDescription ? 16.0 : 0.0),
                child: leadingWidget,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasDescription) const SizedBox(height: 16),
                    Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                    if (hasDescription) ...[
                      const SizedBox(height: 6),
                      Text(description, maxLines: 1, overflow: TextOverflow.ellipsis, style: descriptionStyle),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              if (entry.selected) ...[const SizedBox(width: 12), Icon(LucideIcons.check, size: 21, color: foreground)],
            ],
          ),
        ),
      ),
    );
  }
}

class UserAvatarCircle extends StatelessWidget {
  const UserAvatarCircle({super.key, required this.initials, this.variant = UserAvatarVariant.standard, this.size, this.hovered = false});

  final String initials;
  final UserAvatarVariant variant;
  final double? size;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final buttonTheme = theme.outlineButtonTheme;
    final hoverBackgroundColor = buttonTheme.hoverBackgroundColor ?? powerboardsAvatarAccentColor;
    const backgroundColor = powerboardsAvatarAccentColor;
    final diameter = size ?? userAvatarDiameter(variant);
    final fontSize = userAvatarInitialsFontSize(diameter);

    return Container(
      width: diameter,
      height: diameter,
      alignment: .center,
      decoration: BoxDecoration(
        shape: .circle,
        color: hovered ? hoverBackgroundColor : backgroundColor,
        border: .all(color: cs.border, strokeAlign: BorderSide.strokeAlignOutside),
      ),
      child: Text(
        initials,
        style: tt.small.copyWith(fontWeight: .w700, color: cs.foreground, fontSize: fontSize, height: 1.0),
      ),
    );
  }
}
