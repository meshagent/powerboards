import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/agent_containers.dart';
import 'package:powerboards/meshagent/install_agent.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_svg_icon.dart';
import 'package:powerboards/meshagent/route_service_match.dart';
import 'package:powerboards/ui/powerboards_back_icon_button.dart';
import 'package:powerboards/ui/powerboards_mobile_overlay_header.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:meshagent/meshagent.dart' as ma;
import 'package:url_launcher/url_launcher.dart';

import 'agent_config.dart';
import '../theme/theme.dart';

class AgentOption {
  final String id;
  final String title;
  final String subtitle;
  final String? readme;
  final IconData icon;
  final String? iconAssetName;
  final Color iconColor;
  final Color color;
  final AgentConfigItem? config;
  final bool canChange;
  final String? template;
  final ServiceTemplateSpec? parsed;

  const AgentOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconAssetName,
    required this.color,
    required this.readme,
    required this.parsed,
    required this.template,
    this.config,
    this.iconColor = Colors.white,
    this.canChange = true,
  });
}

String _agentDisplayTitle(String rawTitle) {
  final normalized = rawTitle.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) {
    return rawTitle.trim();
  }

  final lowerCased = normalized.toLowerCase();
  return '${lowerCased[0].toUpperCase()}${lowerCased.substring(1)}';
}

String? _voiceAgentIconAssetName({ServiceSpec? service, ServiceTemplateSpec? template}) {
  if (service != null && serviceUsesVoiceAgent(service)) {
    return 'audio-lines';
  }
  if (template != null && serviceTemplateUsesVoiceAgent(template)) {
    return 'audio-lines';
  }
  return null;
}

class AgentOptionTile extends StatefulWidget {
  final AgentOption option;
  final bool inRoom;
  final AgentRuntimeStatus? status;
  final bool busy;
  final VoidCallback onPrimaryTap;
  final String? version;
  final bool versionHasUpdate;
  final String? actionTextOverride;
  final List<Mailbox> mailboxes;
  final List<ma.Route> routes;

  const AgentOptionTile({
    super.key,
    required this.option,
    required this.onPrimaryTap,
    this.inRoom = false,
    this.status,
    this.busy = false,
    this.version,
    this.actionTextOverride,
    this.versionHasUpdate = false,
    required this.mailboxes,
    required this.routes,
  });

  @override
  State<AgentOptionTile> createState() => _AgentOptionTileState();
}

class _AgentOptionTileState extends State<AgentOptionTile> {
  Color _statusDot(AgentRuntimeStatus? s) {
    switch (s) {
      case AgentRuntimeStatus.running:
        return const Color(0xFF0DAE4E);
      case AgentRuntimeStatus.pulling:
        return const Color(0xFFFFB020);
      case AgentRuntimeStatus.notRunning:
        return const Color(0xFFc3c3c3);
      case AgentRuntimeStatus.error:
      case AgentRuntimeStatus.invalid:
      case AgentRuntimeStatus.unknown:
      case null:
        return statusError;
    }
  }

  String _statusText(bool inRoom, AgentRuntimeStatus? s) {
    if (!inRoom) return 'Initializing';
    switch (s) {
      case AgentRuntimeStatus.running:
        return 'Available';
      case AgentRuntimeStatus.pulling:
        return 'Downloading';
      case AgentRuntimeStatus.notRunning:
        return 'Initializing';
      case AgentRuntimeStatus.error:
        return 'Error';
      case AgentRuntimeStatus.invalid:
        return 'Invalid';
      case AgentRuntimeStatus.unknown:
      case null:
        return 'Unknown';
    }
  }

  String _actionText(bool inRoom, bool busy) {
    if (busy) return inRoom ? 'Changing' : 'Installing';
    return inRoom ? 'Change' : 'Install';
  }

  @override
  Widget build(BuildContext context) {
    const radius = 12.0;
    final theme = ShadTheme.of(context);
    final titleStyle = powerboardsAgentCardTitleTextStyle(context);
    final descriptionStyle = powerboardsAgentCardDescriptionTextStyle(context);
    final useAssetIcon = widget.option.iconAssetName != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  spacing: 6,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_agentDisplayTitle(widget.option.title), style: titleStyle, overflow: TextOverflow.ellipsis),

                    Text(widget.option.subtitle, style: descriptionStyle),

                    if (widget.mailboxes.isNotEmpty || widget.routes.isNotEmpty) SizedBox(height: 0),

                    for (final mailbox in widget.mailboxes)
                      ShadButton.link(
                        onPressed: () {
                          launchUrl(Uri.parse("mailto:${mailbox.address}"), mode: LaunchMode.externalApplication);
                        },
                        padding: EdgeInsets.all(0),

                        trailing: ShadIconButton.ghost(
                          width: 22,
                          height: 22,
                          padding: EdgeInsets.zero,
                          decoration: powerboardsAdaptiveIconButtonDecoration(context),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: mailbox.address));
                          },
                          icon: Icon(LucideIcons.copy, size: 16, color: ShadTheme.of(context).colorScheme.mutedForeground),
                        ),
                        child: Text(mailbox.address),
                      ),

                    for (final route in widget.routes)
                      ShadButton.link(
                        onPressed: () {
                          launchUrl(Uri.parse("https://${route.domain}"), mode: LaunchMode.externalApplication);
                        },
                        padding: EdgeInsets.all(0),
                        trailing: ShadIconButton.ghost(
                          width: 22,
                          height: 22,
                          padding: EdgeInsets.zero,
                          decoration: powerboardsAdaptiveIconButtonDecoration(context),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: "https://${route.domain}"));
                          },
                          icon: Icon(LucideIcons.copy, size: 16, color: ShadTheme.of(context).colorScheme.mutedForeground),
                        ),
                        child: Text("https://${route.domain}"),
                      ),

                    if (widget.mailboxes.isNotEmpty || widget.routes.isNotEmpty) SizedBox(height: 0),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: widget.option.color, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: useAssetIcon
                    ? PbSvgIcon(assetName: widget.option.iconAssetName!, size: 22, color: Colors.white)
                    : Icon(widget.option.icon, color: Colors.white, size: 22),
              ),
            ],
          ),

          SizedBox(height: 12),
          Row(
            children: [
              if (widget.option.canChange)
                ShadButton.outline(
                  onPressed: widget.busy ? null : widget.onPrimaryTap,
                  child: Text(widget.actionTextOverride ?? _actionText(widget.inRoom, widget.busy)),
                ),
              if (!widget.option.canChange)
                ShadButton.outline(enabled: false, child: Text(widget.actionTextOverride ?? _actionText(widget.inRoom, widget.busy))),
              const SizedBox(width: 14),
              if (widget.inRoom && !widget.busy)
                _StatusChip(color: _statusDot(widget.status), label: _statusText(widget.inRoom, widget.status)),
              Spacer(),
              if ((widget.version ?? '').trim().isNotEmpty)
                _VersionChip(
                  label: '${widget.version!.trim()}${widget.versionHasUpdate ? ' update available' : ''}',
                  highlight: widget.versionHasUpdate,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum AgentRuntimeStatus { pulling, running, notRunning, error, unknown, invalid }

AgentRuntimeStatus parseStatus(dynamic raw) {
  final s = (raw ?? '').toString().toLowerCase();
  if (s.contains('pulling')) return AgentRuntimeStatus.pulling;
  if (s == 'running') return AgentRuntimeStatus.running;
  if (s.contains('not_running') || s.contains('notrun')) {
    return AgentRuntimeStatus.notRunning;
  }
  if (s.contains('err')) return AgentRuntimeStatus.error;
  if (s == 'invalid') return AgentRuntimeStatus.invalid;
  return AgentRuntimeStatus.unknown;
}

class _InstallAgentDialog extends StatelessWidget {
  const _InstallAgentDialog({this.template, required this.projectId, required this.roomName});

  final String? template;
  final String projectId;
  final String? roomName;

  @override
  Widget build(BuildContext context) {
    return InstallServiceDialog(
      template: template,
      projectId: projectId,
      roomName: roomName,
      onInstalled: (ctx, projectId, roomName, serviceId) {
        Navigator.of(ctx).pop(true);
        if (serviceId == powerboardsWebServerServiceId && context.mounted) {
          context.go(powerboardsInstalledServiceRoute(projectId: projectId, roomName: roomName, serviceId: serviceId));
        }
      },
    );
  }
}

class _NoTransitionPageRoute<T> extends PageRouteBuilder<T> {
  _NoTransitionPageRoute({required this.builder})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => builder(context),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );

  final WidgetBuilder builder;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return child;
  }
}

Future<void> showManageAgentsSurface({
  required BuildContext context,
  required String projectId,
  required RoomClient room,
  void Function()? onServiceChanged,
}) async {
  if (powerboardsUsesNativeMobileDialogLayout(context)) {
    await dismissBackgroundKeyboardBeforeAdaptiveSurface(context);
    if (!context.mounted) {
      return;
    }

    await Navigator.of(context).push<void>(
      _NoTransitionPageRoute(
        builder: (_) => ManageAgentsDialog(projectId: projectId, room: room, onServiceChanged: onServiceChanged, asScreen: true),
      ),
    );
    return;
  }

  await showPowerboardsFlowDialog<void>(
    context: context,
    builder: (_) => ManageAgentsDialog(projectId: projectId, room: room, onServiceChanged: onServiceChanged),
  );
}

class ManageAgentsDialog extends StatefulWidget {
  final RoomClient room;
  final String projectId;
  final void Function()? onServiceChanged;
  final bool asScreen;

  const ManageAgentsDialog({super.key, required this.room, required this.projectId, this.onServiceChanged, this.asScreen = false});

  @override
  State<ManageAgentsDialog> createState() => _ManageAgentsDialogState();
}

class _ManageAgentsDialogState extends State<ManageAgentsDialog> {
  static const double _mobileManageAgentsScrollBottomInset = 148.0;

  Timer? _pollTimer;

  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    if (!mounted) return;
    _pollTimer = Timer(Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {});
      _scheduleNextPoll();
    });
  }

  Future<void> _load() async {
    services.refresh();
    routes.refresh();
    mailboxes.refresh();
    _scheduleNextPoll();
  }

  late final services = Resource(() async {
    final projectId = widget.projectId;

    final s = await getMeshagentClient().listRoomServices(projectId: projectId, roomName: widget.room.roomName!);
    s.sort((a, b) => a.metadata.name.toLowerCase().compareTo(b.metadata.name.toLowerCase()));
    return s;
  });

  late final routes = Resource(() async {
    final projectId = widget.projectId;

    return await getMeshagentClient().listRoomRoutes(projectId: projectId, roomName: widget.room.roomName!);
  });

  late final mailboxes = Resource(() async {
    final projectId = widget.projectId;

    return await getMeshagentClient().listRoomMailboxes(projectId: projectId, roomName: widget.room.roomName!);
  });

  late final availableAgents = Resource(() async {
    final serverUrl = MeshagentConfig.current?.serverUrl;
    if (serverUrl == null) {
      throw StateError("MeshagentConfig.current.serverUrl is not set");
    }

    final res = await http.get(serverUrl.resolve("/directory"));
    final json = jsonDecode(res.body);
    return ServiceDirectoryPage.fromJson(json);
  });

  Widget _buildError(BuildContext context) {
    return _error == null
        ? const SizedBox.shrink()
        : Padding(
            key: const ValueKey('error-alert'),
            padding: const EdgeInsets.only(bottom: 12),
            child: ShadAlert.destructive(
              icon: Icon(Icons.error_outline),
              title: const Text('Something went wrong'),
              description: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(_error!),
                  const SizedBox(height: 12),
                  ShadButton.ghost(onTapDown: (_) => setState(() => _error = null), child: const Text('Dismiss')),
                ],
              ),
            ),
          );
  }

  Future<void> _openCustomDialog() async {
    final changed = await showPowerboardsFlowDialog<bool>(
      context: context,
      builder: (dialogContext) => _InstallAgentDialog(projectId: widget.projectId, roomName: widget.room.roomName),
    );

    if (widget.onServiceChanged != null && changed == true) {
      widget.onServiceChanged!();
    }

    if (changed == true) {
      await _load();
    }
  }

  Future<void> _openManageDialog({required AgentOption option, ServiceSpec? existing}) async {
    ServiceTemplateSpec? spec;
    Map<String, String>? prefilled;

    if (existing != null) {
      prefilled = existing.metadata.annotations["meshagent.service.template.values"] != null
          ? (jsonDecode(existing.metadata.annotations["meshagent.service.template.values"]!) as Map).cast<String, String>()
          : null;

      String? value = existing.metadata.annotations["meshagent.service.template.yaml"];
      if (value != null) {
        final ma = getMeshagentClient();
        final rendered = await ma.renderTemplate(template: value, values: prefilled ?? {});
        spec = rendered;
      }
    }

    if (!mounted) {
      return;
    }
    final changed = await showPowerboardsFlowDialog<bool?>(
      context: context,
      barrierDismissible: true,
      builder: (context) => existing != null
          ? ConfigureServiceTemplateDialog(
              prefilledVars: prefilled,
              title: "Change agent",
              description: const Text("Change the properties of this agent"),
              template: option.template ?? "",
              projectId: widget.projectId,
              serviceId: existing.id!,
              roomName: widget.room.roomName,
              manifest:
                  spec ??
                  ServiceTemplateSpec(
                    metadata: ServiceTemplateMetadata(name: existing.metadata.name, description: existing.metadata.description),
                  ),
            )
          : _InstallAgentDialog(template: option.template, projectId: widget.projectId, roomName: widget.room.roomName),
    );

    if (widget.onServiceChanged != null) {
      widget.onServiceChanged!();
    }

    if (changed == true) {
      await _load();
    }
  }

  Widget _buildAdaptiveMobileScreenFooter(BuildContext context, {required bool installEnabled}) {
    final overlayHeaderScope = PowerboardsMobileOverlayHeaderScope.maybeOf(context);
    final collapseProgress = overlayHeaderScope?.collapseProgress ?? 0;
    final hideForScroll = collapseProgress > 0.1;

    return AnimatedSwitcher(
      duration: powerboardsMobileOverlayHeaderTransitionDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, transitionChild) {
            final offsetY = 16 * (1 - animation.value);
            return Transform.translate(
              offset: Offset(0, offsetY),
              child: ClipRect(
                child: FadeTransition(
                  opacity: animation,
                  child: SizeTransition(sizeFactor: animation, alignment: AlignmentDirectional.bottomStart, child: transitionChild),
                ),
              ),
            );
          },
        );
      },
      child: hideForScroll
          ? const SizedBox.shrink(key: ValueKey('manage-agents-mobile-footer-hidden'))
          : KeyedSubtree(
              key: const ValueKey('manage-agents-mobile-footer-visible'),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ShadButton.outline(onPressed: installEnabled ? _openCustomDialog : null, child: const Text('Install')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ShadButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Close')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _screenBody({required BuildContext context, required Widget child, required bool installEnabled, bool showFooter = true}) {
    final theme = ShadTheme.of(context);
    final titleStyle = powerboardsMobileHeaderPrimaryTextStyle(color: theme.colorScheme.foreground);
    final surfaceColor = theme.colorScheme.card;
    final trailingPlaceholder = IgnorePointer(
      child: Opacity(
        opacity: 0,
        child: PowerboardsBackIconButton(onPressed: () {}, tooltip: "Close", icon: LucideIcons.x),
      ),
    );

    return ColoredBox(
      color: surfaceColor,
      child: PowerboardsMobileOverlayScaffold(
        leading: PowerboardsBackIconButton(onPressed: () => Navigator.of(context).maybePop(), tooltip: "Close", icon: LucideIcons.x),
        titleBuilder: (context, collapseProgress) =>
            Text('Agents & Services', maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
        trailingActions: [trailingPlaceholder],
        backgroundColor: surfaceColor,
        body: Column(
          children: [
            Expanded(child: child),
            if (showFooter) Builder(builder: (context) => _buildAdaptiveMobileScreenFooter(context, installEnabled: installEnabled)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = powerboardsUsesNativeMobileDialogLayout(context);
            final isScreen = widget.asScreen && isMobile;
            final isLoading =
                availableAgents.state.value == null ||
                services.state.value == null ||
                mailboxes.state.value == null ||
                routes.state.value == null;

            if (isLoading) {
              final loadingBody = const Center(child: CircularProgressIndicator());

              if (isScreen) {
                return _screenBody(context: context, child: loadingBody, installEnabled: false, showFooter: false);
              }

              return const Center(child: CircularProgressIndicator());
            }

            final optionsToShow = <AgentOption>[
              for (final service in services.state.value!)
                if (availableAgents.state.value!.templates.firstWhereOrNull(
                      (x) => x.parsed.metadata.annotations["meshagent.service.id"] == service.metadata.annotations["meshagent.service.id"],
                    ) ==
                    null)
                  AgentOption(
                    id: service.metadata.annotations["meshagent.service.id"] ?? "",
                    readme: service.metadata.annotations["meshagent.service.readme"],
                    title: service.metadata.name,
                    subtitle: powerboardsDisplayServiceDescriptionForService(service) ?? "",
                    icon: LucideIcons.puzzle,
                    iconAssetName: powerboardsServiceIconAssetName(service: service) ?? _voiceAgentIconAssetName(service: service),
                    color: const Color(0xFF222222),
                    canChange: true,
                    template: null,
                    parsed: null,
                  ),

              for (final available in availableAgents.state.value!.templates)
                AgentOption(
                  readme: available.parsed.metadata.annotations["meshagent.service.readme"],
                  id: available.parsed.metadata.annotations["meshagent.service.id"] ?? "",
                  title: available.parsed.metadata.name,
                  subtitle: powerboardsDisplayServiceDescriptionForTemplate(available.parsed) ?? "",
                  template: available.template,
                  icon: LucideIcons.bot,
                  iconAssetName:
                      powerboardsServiceIconAssetName(template: available.parsed) ?? _voiceAgentIconAssetName(template: available.parsed),
                  color: const Color(0xFF222222),
                  parsed: available.parsed,
                ),
            ];

            final maxViewportHeight = constraints.maxHeight;
            final maxHeight = maxViewportHeight.isFinite ? (maxViewportHeight * 0.7).clamp(0.0, 860.0).toDouble() : 620.0;
            final optionsList = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildError(context),
                const SizedBox(height: 12),
                for (var i = 0; i < optionsToShow.length; i++) ...[
                  Builder(
                    builder: (context) {
                      final option = optionsToShow[i];
                      final service = services.state.value?.firstWhereOrNull(
                        (s) => s.metadata.annotations["meshagent.service.id"] == option.id,
                      );
                      final serviceRoutes = service == null
                          ? const <ma.Route>[]
                          : routesForService(routes: routes.state.value ?? const <ma.Route>[], service: service);
                      final inRoom = service != null;
                      final identity = service?.agents.firstOrNull?.name;
                      final hasMessaging = service != null && hasMessagingParticipant(service);

                      final status = !hasMessaging
                          ? AgentRuntimeStatus.running
                          : (identity == null ||
                                    widget.room.messaging.remoteParticipants.firstWhereOrNull((x) => x.getAttribute("name") == identity) ==
                                        null
                                ? AgentRuntimeStatus.notRunning
                                : AgentRuntimeStatus.running);
                      return AgentOptionTile(
                        option: option,
                        inRoom: inRoom,
                        status: status,
                        mailboxes:
                            (mailboxes.state.value
                                ?.where(
                                  (x) =>
                                      x.annotations["meshagent.service.id"] != null &&
                                      x.annotations["meshagent.service.id"] == service?.metadata.annotations["meshagent.service.id"],
                                )
                                .toList()) ??
                            [],
                        routes: serviceRoutes,
                        busy: false,
                        version: null,
                        versionHasUpdate: false,
                        onPrimaryTap: () => _openManageDialog(option: option, existing: service),
                      );
                    },
                  ),
                  if (i < optionsToShow.length - 1) const SizedBox(height: 16),
                ],
              ],
            );

            if (isScreen) {
              return _screenBody(
                context: context,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, _mobileManageAgentsScrollBottomInset),
                    child: optionsList,
                  ),
                ),
                installEnabled: true,
              );
            }

            return PowerboardsShadDialog.task(
              scrollable: false,
              constraints: isMobile ? null : BoxConstraints(maxWidth: 500.0, maxHeight: maxHeight),
              crossAxisAlignment: CrossAxisAlignment.start,
              title: const Text('Agents & Services'),
              actions: [
                ShadButton.outline(onPressed: _openCustomDialog, child: const Text('Install')),
                ShadButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Close')),
              ],
              child: isMobile
                  ? optionsList
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: powerboardsDialogScrollViewportVerticalInset),
                        Flexible(
                          fit: FlexFit.loose,
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                            child: SingleChildScrollView(child: optionsList),
                          ),
                        ),
                        const SizedBox(height: powerboardsDialogScrollViewportVerticalInset),
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Color color;
  final String label;
  const _StatusChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.small.copyWith(color: color)),
      ],
    );
  }
}

class _VersionChip extends StatelessWidget {
  final String label;

  final bool highlight;

  const _VersionChip({required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final border = const Color(0xffE3E3E3);
    final bg = highlight ? const Color(0xFFE8F2FF) : Colors.transparent;

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
    );

    return InkWell(borderRadius: BorderRadius.circular(999), child: child);
  }
}
