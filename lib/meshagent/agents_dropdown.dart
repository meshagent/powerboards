import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/file_preview/markdown.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/ui/app_context_menu.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AgentsDropdown extends StatelessWidget {
  final String projectId;
  final RoomClient room;
  final ServiceSpec? selectedService;
  final List<ServiceSpec> services;
  final VoidCallback? onOpen;
  final VoidCallback? onManageAgents;

  const AgentsDropdown({
    super.key,
    required this.projectId,
    required this.room,
    required this.selectedService,
    required this.services,
    this.onOpen,
    this.onManageAgents,
  });

  String _serviceId(ServiceSpec service) => service.metadata.annotations["meshagent.service.id"] ?? "";
  bool _isBaseRouteId(String id) => id.isEmpty || id == "chat";

  void _navigateTo(BuildContext context, ServiceSpec service) {
    final pid = fromUUID(projectId);
    final id = _serviceId(service);

    if (_isBaseRouteId(id)) {
      context.go('/p/$pid/r/${room.roomName}');
    } else {
      context.go('/p/$pid/r/${room.roomName}/a/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = selectedService?.metadata.name ?? (services.isEmpty ? "No agents" : "Select agent");
    final readme = selectedService?.metadata.annotations["meshagent.service.readme"];

    final selectedId = selectedService == null ? null : _serviceId(selectedService!);
    final entries = <AppMenuEntry>[
      for (final service in services)
        AppMenuEntry(
          title: service.metadata.name,
          description: service.metadata.description ?? "",
          selected: selectedId != null && selectedId == _serviceId(service),
          icon: LucideIcons.bot,
          onPressed: () => _navigateTo(context, service),
        ),
    ];

    if (onManageAgents != null) {
      entries.add(
        AppMenuEntry(title: 'Manage agents', description: 'Install or remove agents.', icon: LucideIcons.blocks, onPressed: onManageAgents),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppContextMenuButton(
          anchor: const ShadAnchor(childAlignment: Alignment.topLeft),
          entries: entries,
          childBuilder: (context, controller) {
            return ShadButton.ghost(
              trailing: const Icon(LucideIcons.chevronDown, size: 18),
              onPressed: () {
                onOpen?.call();
                if (!controller.isOpen) controller.show();
              },
              leading: const Icon(LucideIcons.bot, size: 18),
              child: Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
            );
          },
        ),
        if (readme != null)
          ShadButton.ghost(
            onPressed: () {
              showShadDialog(
                context: context,
                builder: (context) => ShadDialog(
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
  }
}
