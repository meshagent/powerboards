import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/markdown_viewer.dart';
import 'package:meshagent_flutter_shadcn/viewers/builder.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/meshagent/agent_participants.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/ui/app_context_menu.dart';
import 'package:powerboards/ui/desktop_sidetray_toggle.dart';
import 'package:powerboards/ui/powerboards_breakpoints.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';

class _DevelopmentAgentMenuItem {
  const _DevelopmentAgentMenuItem({required this.participant, required this.name});

  final RemoteParticipant participant;
  final String name;

  String get routeId => developmentAgentRouteId(name);
}

class AgentsDropdown extends StatelessWidget {
  final String projectId;
  final RoomClient room;
  final ServiceSpec? selectedService;
  final String? selectedAgentRouteId;
  final List<ServiceSpec> services;
  final VoidCallback? onOpen;
  final VoidCallback? onManageAgents;
  final BuildContext? boundaryContext;
  final bool expandToAvailableWidth;
  final bool showRoomBreadcrumb;
  final String? roomDisplayNameOverride;
  final VoidCallback? onRoomPressed;
  final VoidCallback? onOpenNavigation;
  final double? roomBreadcrumbMaxWidth;
  final bool roomBreadcrumbEllipsisOnly;
  final bool showAdaptiveWebappNavOpener;

  const AgentsDropdown({
    super.key,
    required this.projectId,
    required this.room,
    required this.selectedService,
    required this.selectedAgentRouteId,
    required this.services,
    this.onOpen,
    this.onManageAgents,
    this.boundaryContext,
    this.expandToAvailableWidth = false,
    this.showRoomBreadcrumb = false,
    this.roomDisplayNameOverride,
    this.onRoomPressed,
    this.onOpenNavigation,
    this.roomBreadcrumbMaxWidth,
    this.roomBreadcrumbEllipsisOnly = false,
    this.showAdaptiveWebappNavOpener = false,
  });

  String _serviceId(ServiceSpec service) => service.metadata.annotations["meshagent.service.id"] ?? "";
  String? _serviceAgentName(ServiceSpec service) {
    final name = service.agents.firstOrNull?.name;
    if (name == null) {
      return null;
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  bool _isBaseRouteId(String id) => id.isEmpty || id == "chat";

  void _navigateToRoute(BuildContext context, String routeId) {
    final pid = fromUUID(projectId);
    final currentUri = PathRouteMatch.of(context).uri;
    final nextPath = _isBaseRouteId(routeId) ? '/p/$pid/r/${room.roomName}' : '/p/$pid/r/${room.roomName}/a/$routeId';
    final nextUri = currentUri.replace(path: nextPath);

    context.go(nextUri.toString());
  }

  List<_DevelopmentAgentMenuItem> _developmentAgents() {
    final serviceAgentNames = <String>{};
    for (final service in services) {
      final name = _serviceAgentName(service);
      if (name != null) {
        serviceAgentNames.add(name);
      }
    }

    final seenNames = <String>{};
    final participants = <_DevelopmentAgentMenuItem>[];
    for (final participant in room.messaging.remoteParticipants) {
      if (!isChatOrVoiceBotParticipant(participant)) {
        continue;
      }

      final name = participantDisplayName(participant);
      if (name == null || serviceAgentNames.contains(name) || !seenNames.add(name)) {
        continue;
      }

      participants.add(_DevelopmentAgentMenuItem(participant: participant, name: name));
    }

    participants.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return participants;
  }

  IconData _developmentAgentIcon(RemoteParticipant participant) {
    if (participantSupportsVoice(participant)) {
      return LucideIcons.audioWaveform;
    }
    if (!participantSupportsChat(participant)) {
      return LucideIcons.badgeQuestionMark;
    }
    return LucideIcons.bot;
  }

  Widget _developmentAgentLeading(RemoteParticipant participant) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Center(child: Opacity(opacity: 0.25, child: Icon(_developmentAgentIcon(participant), size: 20))),
    );
  }

  bool _isLandscapePhoneViewport(BuildContext context) {
    return powerboardsIsLandscapePhoneViewport(context);
  }

  String _capitalizeDisplayLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      return label;
    }

    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  Widget _desktopBreadcrumb({required BuildContext parentContext, required String roomName}) {
    final textStyle = powerboardsSectionTitleStyle();
    final sidetrayScope = DesktopSidetrayToggleScope.maybeOf(parentContext);
    final showSidetrayOpenButton =
        roomBreadcrumbEllipsisOnly && sidetrayScope != null && (sidetrayScope.collapsed || !sidetrayScope.enabled);

    void onOpenNavPressed() {
      if (onOpenNavigation != null) {
        onOpenNavigation!();
        return;
      }
      if (sidetrayScope != null && sidetrayScope.enabled) {
        sidetrayScope.onExpand();
      }
    }

    void onRoomPressed() {
      if (showAdaptiveWebappNavOpener && onOpenNavigation != null) {
        onOpenNavigation!();
        return;
      }

      if (sidetrayScope?.enabled == true) {
        sidetrayScope!.onToggle();
        return;
      }

      this.onRoomPressed?.call();
      if (this.onRoomPressed == null) {
        _navigateToRoute(parentContext, '');
      }
    }

    final roomButton = roomBreadcrumbEllipsisOnly
        ? ShadButton.ghost(
            padding: EdgeInsets.zero,
            gap: 0,
            width: 40,
            height: 40,
            onPressed: onRoomPressed,
            child: const Icon(LucideIcons.ellipsis, size: 18),
          )
        : ShadButton.ghost(
            expands: roomBreadcrumbMaxWidth != null,
            mainAxisAlignment: MainAxisAlignment.start,
            onPressed: onRoomPressed,
            child: Text(roomName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.left, style: textStyle),
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSidetrayOpenButton) ...[
          DesktopSidetrayToggleButton(collapsed: true, onPressed: onOpenNavPressed),
          const SizedBox(width: 8),
        ],
        if (roomBreadcrumbMaxWidth != null)
          Flexible(
            fit: FlexFit.loose,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: roomBreadcrumbMaxWidth!),
              child: roomButton,
            ),
          )
        else
          roomButton,
        const SizedBox(width: 4),
        const Icon(LucideIcons.chevronRight, size: 18, color: Color(0xffa5a5a5)),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentSidetrayContext = context;
    return ChangeNotifierBuilder(
      source: room.messaging,
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        final isLandscapePhone = _isLandscapePhoneViewport(context);
        final isMobileAdaptive = powerboardsUsesNativeMobileAdaptiveLayout(context);
        final centerMenuInViewport = isMobileAdaptive && !isLandscapePhone;
        final developmentAgents = _developmentAgents();
        final selectedRouteId = selectedAgentRouteId ?? (selectedService == null ? null : _serviceId(selectedService!));
        final selectedDevelopmentAgent = selectedRouteId == null
            ? null
            : developmentAgents.firstWhereOrNull((item) => item.routeId == selectedRouteId);

        final hasAgents = services.isNotEmpty || developmentAgents.isNotEmpty;
        final label = selectedService?.metadata.name ?? selectedDevelopmentAgent?.name ?? (hasAgents ? "Select agent" : "No agents");
        final readme = selectedService?.metadata.annotations["meshagent.service.readme"];

        final entries = <AppMenuEntry>[
          for (final service in services)
            AppMenuEntry(
              title: _capitalizeDisplayLabel(service.metadata.name),
              description: service.metadata.description ?? "",
              selected: selectedRouteId != null && selectedRouteId == _serviceId(service),
              icon: LucideIcons.bot,
              onPressed: () => _navigateToRoute(context, _serviceId(service)),
            ),
          for (final participant in developmentAgents)
            AppMenuEntry(
              title: _capitalizeDisplayLabel(participant.name),
              description: "Development mode agent",
              selected: selectedRouteId != null && selectedRouteId == participant.routeId,
              leading: _developmentAgentLeading(participant.participant),
              onPressed: () => _navigateToRoute(context, participant.routeId),
            ),
        ];

        if (onManageAgents != null) {
          entries.add(
            AppMenuEntry(
              title: 'Manage agents',
              description: 'Install or remove agents and services.',
              icon: LucideIcons.blocks,
              onPressed: onManageAgents,
            ),
          );
        }

        final mobileMenuWidth = max(240.0, min(size.width - 32, 420.0));
        final mobileMenuHeight = max(220.0, size.height - 96.0);
        final usesExpandedTrigger = expandToAvailableWidth;

        final readmeButton = readme == null
            ? null
            : ShadButton.ghost(
                onPressed: () {
                  showShadDialog(
                    context: context,
                    builder: (context) => PowerboardsShadDialog(
                      constraints: BoxConstraints(
                        maxWidth: min(MediaQuery.of(context).size.width - 60, 800),
                        maxHeight: min(MediaQuery.of(context).size.height - 60, 800),
                      ),
                      child: MarkdownViewer(markdown: readme),
                    ),
                  );
                },
                child: const Icon(LucideIcons.info),
              );

        Widget buildAgentTriggerButton(BuildContext _, VoidCallback onTriggerPressed) {
          return ShadButton.ghost(
            expands: usesExpandedTrigger,
            mainAxisAlignment: usesExpandedTrigger ? MainAxisAlignment.start : MainAxisAlignment.center,
            trailing: usesExpandedTrigger ? null : const Icon(LucideIcons.chevronDown, size: 18),
            onPressed: onTriggerPressed,
            leading: usesExpandedTrigger
                ? null
                : isMobileAdaptive
                ? null
                : selectedDevelopmentAgent == null
                ? const Icon(LucideIcons.bot, size: 18)
                : Opacity(opacity: 0.25, child: Icon(_developmentAgentIcon(selectedDevelopmentAgent.participant), size: 18)),
            child: usesExpandedTrigger
                ? Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Flexible(
                        child: Text(
                          _capitalizeDisplayLabel(label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: powerboardsSectionTitleStyle(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(LucideIcons.chevronDown, size: 18),
                    ],
                  )
                : Text(
                    _capitalizeDisplayLabel(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: powerboardsSectionTitleStyle(),
                  ),
          );
        }

        if (!isMobileAdaptive && showRoomBreadcrumb) {
          final breadcrumbLeading = _desktopBreadcrumb(
            parentContext: parentSidetrayContext,
            roomName: roomDisplayNameOverride ?? room.roomName ?? "Room",
          );
          final agentMenuButton = AppContextMenuButton(
            anchor: const ShadAnchor(childAlignment: Alignment.topLeft),
            boundaryContext: boundaryContext,
            constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
            entries: entries,
            childBuilder: (context, controller) {
              void onTriggerPressed() {
                onOpen?.call();
                controller.toggle();
              }

              return buildAgentTriggerButton(context, onTriggerPressed);
            },
          );

          return Row(
            mainAxisSize: expandToAvailableWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              breadcrumbLeading,
              Flexible(fit: FlexFit.loose, child: agentMenuButton),
              if (readmeButton != null) ...[const SizedBox(width: 4), readmeButton],
            ],
          );
        }

        final menuButton = AppContextMenuButton(
          anchor: isMobileAdaptive ? null : const ShadAnchor(childAlignment: Alignment.topLeft),
          boundaryContext: boundaryContext,
          constraints: isMobileAdaptive
              ? BoxConstraints(minWidth: mobileMenuWidth, maxWidth: mobileMenuWidth)
              : const BoxConstraints(minWidth: 320, maxWidth: 420),
          maxMenuHeight: isMobileAdaptive ? mobileMenuHeight : null,
          centerHorizontallyInBoundary: centerMenuInViewport,
          entries: entries,
          childBuilder: (context, controller) {
            void onTriggerPressed() {
              onOpen?.call();
              controller.toggle();
            }

            return buildAgentTriggerButton(context, onTriggerPressed);
          },
        );

        return Row(
          mainAxisSize: expandToAvailableWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (expandToAvailableWidth) Expanded(child: menuButton) else menuButton,
            if (readmeButton != null) ...[if (expandToAvailableWidth) const SizedBox(width: 4), readmeButton],
          ],
        );
      },
    );
  }
}
