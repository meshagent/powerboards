import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/agent_containers.dart';
import 'package:powerboards/meshagent/install_agent.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:meshagent/room_server_client.dart';

import 'agent_config.dart';

class AgentOption {
  final String id;
  final String title;
  final String subtitle;
  final String? readme;
  final IconData icon;
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
    required this.color,
    required this.readme,
    required this.parsed,
    required this.template,
    this.config,
    this.iconColor = Colors.white,
    this.canChange = true,
  });
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
        return const Color(0xFFE11D48);
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ShadTheme.of(context).colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.option.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.option.subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: widget.option.color, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(widget.option.icon, color: Colors.white, size: 22),
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
  if (s.contains('not_running') || s.contains('notrun')) return AgentRuntimeStatus.notRunning;
  if (s.contains('err')) return AgentRuntimeStatus.error;
  if (s == 'invalid') return AgentRuntimeStatus.invalid;
  return AgentRuntimeStatus.unknown;
}

class ManageAgentsDialog extends StatefulWidget {
  final RoomClient room;
  final String projectId;
  final void Function()? onServiceChanged;

  const ManageAgentsDialog({super.key, required this.room, required this.projectId, this.onServiceChanged});

  @override
  State<ManageAgentsDialog> createState() => _ManageAgentsDialogState();
}

class _ManageAgentsDialogState extends State<ManageAgentsDialog> {
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
      services.refresh();
      _scheduleNextPoll();
    });
  }

  Future<void> _load() async {
    _scheduleNextPoll();
  }

  late final services = Resource(() async {
    final projectId = widget.projectId;

    return await getMeshagentClient().listRoomServices(projectId: projectId, roomName: widget.room.roomName!);
  });

  late final availableAgents = Resource(() async {
    final res = await http.get(Uri.parse(const String.fromEnvironment("SERVER_URL")).resolve("/directory"));
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
    final changed = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        useSafeArea: false,
        constraints: BoxConstraints(maxWidth: 800),
        title: const Text("Install custom agent"),
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(dialogContext).size.height - 250,
          child: AgentInstaller(
            initialProjectId: widget.projectId,
            initialRoomName: widget.room.roomName,
            onInstalled: (ctx, projectId, roomName, serviceId) {
              Navigator.of(ctx).pop(true);
            },
          ),
        ),
      ),
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

    final dialogContext = context;
    if (!mounted) {
      return;
    }
    final changed = await showShadDialog<bool?>(
      context: context,
      barrierDismissible: true,
      builder: (context) => existing != null
          ? ConfigureServiceTemplateDialog(
              prefilledVars: prefilled,
              title: "Change Agent",
              description: "Change the properties of this agent",
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
          : ShadDialog(
              useSafeArea: false,
              constraints: BoxConstraints(maxWidth: 800),
              title: const Text("Install custom agent"),
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.of(dialogContext).size.height - 250,
                child: AgentInstaller(
                  template: option.template,
                  initialProjectId: widget.projectId,
                  initialRoomName: widget.room.roomName,
                  onInstalled: (ctx, projectId, roomName, serviceId) {
                    Navigator.of(ctx).pop(true);
                  },
                ),
              ),
            ),
    );

    if (widget.onServiceChanged != null) {
      widget.onServiceChanged!();
    }

    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, _) {
        if (availableAgents.state.value == null || services.state.value == null) {
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
                subtitle: service.metadata.description ?? "",
                icon: LucideIcons.puzzle,
                color: Colors.black,
                canChange: true,
                template: null,
                parsed: null,
              ),

          for (final available in availableAgents.state.value!.templates)
            AgentOption(
              readme: available.parsed.metadata.annotations["meshagent.service.readme"],
              id: available.parsed.metadata.annotations["meshagent.service.id"] ?? "",
              title: available.parsed.metadata.name,
              subtitle: available.parsed.metadata.description ?? "",
              template: available.template,
              icon: LucideIcons.bot,
              color: Colors.black,
              parsed: available.parsed,
            ),
        ];

        return ShadDialog(
          useSafeArea: false,
          expandActionsWhenTiny: false,
          actionsAxis: Axis.horizontal,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height - 150, maxWidth: 500),
          crossAxisAlignment: CrossAxisAlignment.start,
          titlePinned: true,
          title: const Text('Manage room agents'),
          actions: [
            ShadButton.outline(onPressed: _openCustomDialog, child: const Text('Install custom agent')),
            ShadButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Close')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
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
                        busy: false,
                        version: "latest",
                        versionHasUpdate: false,
                        onPrimaryTap: () => _openManageDialog(option: option, existing: service),
                      );
                    },
                  ),
                  if (i < optionsToShow.length - 1) const SizedBox(height: 16),
                ],
              ],
            ),
          ),
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
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF111827), fontWeight: FontWeight.w600),
        ),
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
