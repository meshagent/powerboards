import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/file_preview/markdown.dart';
import 'package:meshagent_flutter_shadcn/viewers/builder.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:powerboards/meshagent/agent_participants.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/ui/app_context_menu.dart';
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
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height && size.shortestSide < 600;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierBuilder(
      source: room.messaging,
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        final isLandscapePhone = _isLandscapePhoneViewport(context);
        final isMobileAdaptive = ResponsiveBreakpoints.of(context).isMobile || isLandscapePhone;
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
              title: service.metadata.name,
              description: service.metadata.description ?? "",
              selected: selectedRouteId != null && selectedRouteId == _serviceId(service),
              icon: LucideIcons.bot,
              onPressed: () => _navigateToRoute(context, _serviceId(service)),
            ),
          for (final participant in developmentAgents)
            AppMenuEntry(
              title: participant.name,
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

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppContextMenuButton(
              anchor: isMobileAdaptive ? null : const ShadAnchor(childAlignment: Alignment.topLeft),
              boundaryContext: boundaryContext,
              constraints: isMobileAdaptive
                  ? BoxConstraints(minWidth: mobileMenuWidth, maxWidth: mobileMenuWidth)
                  : const BoxConstraints(minWidth: 320, maxWidth: 420),
              maxMenuHeight: isMobileAdaptive ? mobileMenuHeight : null,
              centerHorizontallyInBoundary: centerMenuInViewport,
              entries: entries,
              childBuilder: (context, controller) {
                return ShadButton.ghost(
                  trailing: const Icon(LucideIcons.chevronDown, size: 18),
                  onPressed: () {
                    onOpen?.call();
                    controller.toggle();
                  },
                  leading: isMobileAdaptive
                      ? null
                      : selectedDevelopmentAgent == null
                      ? const Icon(LucideIcons.bot, size: 18)
                      : Opacity(opacity: 0.25, child: Icon(_developmentAgentIcon(selectedDevelopmentAgent.participant), size: 18)),
                  child: Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                );
              },
            ),
            if (readme != null)
              ShadButton.ghost(
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
              ),
          ],
        );
      },
    );
  }
}
