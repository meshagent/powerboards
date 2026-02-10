import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:meshagent/agent.dart';
import 'package:meshagent/client.dart';
import 'package:meshagent/participant_token.dart';
import 'package:meshagent/protocol.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:powerboards/meshagent/meshagent.dart';

class ConfigureServiceTemplateDialog extends StatelessWidget {
  final String template;
  final Map<String, String>? prefilledVars; // {varName: value}
  final String projectId;
  final String? serviceId;
  final ServiceTemplateSpec manifest;
  final String? roomName;
  final String title;
  final String? description;

  const ConfigureServiceTemplateDialog({
    super.key,
    required this.template,
    required this.projectId,
    required this.serviceId,
    required this.manifest,
    required this.title,
    required this.description,
    this.roomName,
    this.prefilledVars,
  });

  @override
  Widget build(BuildContext context) {
    final isInstalled = serviceId != null;
    return ShadDialog(
      useSafeArea: false,
      expandActionsWhenTiny: false,
      actionsAxis: Axis.horizontal,
      constraints: BoxConstraints(maxWidth: 600, minWidth: 600),
      scrollable: false,
      title: Text(isInstalled ? 'Edit agent' : 'Install agent'),
      description: Text(
        isInstalled
            ? "Update variables or uninstall this agent."
            : "Installing this agent will grant it access to your room. Review the details before continuing.",
      ),
      child: SizedBox(
        height: 500,
        child: ConfigureServiceTemplate(
          template: template,
          header: [
            const SizedBox(height: 8),
            ServiceNameCard(manifest: manifest),
            if (serviceId == null) ...[const SizedBox(height: 8), ServiceInfoCard(manifest: manifest)],
          ],
          projectId: projectId,
          serviceId: serviceId,
          manifest: manifest,
          roomName: roomName,
          prefilledVars: prefilledVars,
          onDone: (context) {
            Navigator.of(context).pop(true);
          },
        ),
      ),
    );
  }
}

class ServiceNameCard extends StatelessWidget {
  const ServiceNameCard({super.key, required this.manifest});
  final ServiceTemplateSpec manifest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: ShadTheme.of(context).colorScheme.border, width: 1),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manifest.metadata.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (manifest.metadata.description != null) ...[
                      const SizedBox(height: 6),

                      Text(
                        manifest.metadata.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: ShadTheme.of(context).colorScheme.foreground, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(LucideIcons.bot, color: ShadTheme.of(context).colorScheme.background, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final permissionHelp = {
  "agents": "Use tools in the room or talk to other agents",
  "containers": "Run custom code in sandboxed containers",
  "database": "Interact with database tables",
  "developer": "Watch logs in the room",
  "livekit": "Join meetings",
  "messaging": "Communicate with users and agents",
  "sync": "Interact with threads and synchronized documents",
  "storage": "Interact with files in the room",
  "queues": "Interact with job queues",
};

class ServiceInfoCard extends StatelessWidget {
  const ServiceInfoCard({super.key, required this.manifest});
  final ServiceTemplateSpec manifest;

  List<String> _summarize(List<PortSpec> ports) {
    Set<String> keys = {};

    for (final p in ports) {
      for (final e in p.endpoints) {
        final scope = e.meshagent?.api ?? ApiScope.agentDefault();
        // Detect templates
        final asJson = scope.toJson();

        keys.addAll(asJson.keys);
      }
    }

    return keys.toList();
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (manifest.agents.isNotEmpty) ...[
            Text('This package will install:', style: labelStyle),

            Padding(
              padding: EdgeInsets.only(left: 8, top: 8, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final a in manifest.agents) ...[
                    if (a.annotations["meshagent.agent.type"] == "ChatBot") Text("• A chatbot"),
                    if (a.annotations["meshagent.agent.type"] == "Mailbot") Text("• A mailbot"),
                    if (a.annotations["meshagent.agent.type"] == "VoiceBot") Text("• A voicebot"),
                    if (a.annotations["meshagent.agent.type"] == "Shell") Text("• A terminal based agent"),
                    if (a.annotations["meshagent.agent.widget"] != null) Text("• A custom interface"),
                    if (a.annotations["meshagent.agent.database.schema"] != null) Text("• A custom database"),
                    if (a.annotations["meshagent.agent.schedule"] != null) Text("• Scheduled tasks"),
                  ],
                ],
              ),
            ),
          ],

          if (manifest.ports.isNotEmpty) ...[
            Text('Installing this agent will grant it permission to:', style: labelStyle),

            Padding(
              padding: EdgeInsets.only(left: 8, top: 8),
              child: Text(_summarize(manifest.ports).map((t) => "• ${permissionHelp[t] ?? t}").join("\n"), style: TextStyle(height: 1.75)),
            ),
          ],
        ],
      ),
    );
  }
}

class ConfigureServiceTemplate extends StatefulWidget {
  final ServiceTemplateSpec manifest;
  final Map<String, String>? prefilledVars; // {varName: value}
  final String? serviceId;
  final String projectId;
  final String? roomName;
  final List<Widget> customActions;
  final List<Widget> header;
  final String template;
  final void Function(BuildContext) onDone;

  const ConfigureServiceTemplate({
    super.key,
    required this.template,
    required this.projectId,
    required this.serviceId,
    required this.manifest,
    this.roomName,
    this.prefilledVars,
    this.customActions = const [],
    this.header = const [],
    required this.onDone,
  });

  @override
  State createState() => _ConfigureServiceTemplateState();
}

class _ConfigureServiceTemplateState extends State<ConfigureServiceTemplate> {
  final _formKey = GlobalKey<ShadFormState>();
  late Map<String, String> _vars; // {varName: value}

  bool _saving = false;
  bool _removing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = <String, String>{};
    for (final v in widget.manifest.variables ?? []) {
      initial[v.name] = '';
    }
    if (widget.prefilledVars != null) {
      initial.addAll(widget.prefilledVars!);
    }
    _vars = initial;
  }

  Future<void> _saveOrUpdate() async {
    if (!(_formKey.currentState?.validate(autoScrollWhenFocusOnInvalid: true) ?? false)) return;

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      final client = getMeshagentClient();
      final projectId = widget.projectId;
      var service = widget.manifest.toServiceSpec(values: _vars);

      String? email;
      String? emailQueue;
      bool public = false;
      for (final variable in widget.manifest.variables ?? <ServiceTemplateVariable>[]) {
        if (variable.type == "email") {
          email = _vars[variable.name] ?? "";
          final privacy = variable.annotations?["meshagent.email.privacy"];
          public = switch (privacy) {
            "public" => true,
            "private" => false,
            null => false,
            _ => throw RoomServerException("invalid email prviacy option"),
          };
        } else if (variable.type == "email_queue") {
          emailQueue = emailQueue;
        }
      }

      final ma = getMeshagentClient();
      if (email != null && email != "") {
        try {
          final mailbox = await ma.getMailbox(projectId: projectId, address: email);
          if (mailbox.room != widget.roomName) {
            throw RoomServerException("Mailbox has already been assigned to another room");
          }

          ma.updateMailbox(projectId: projectId, address: email, room: widget.roomName!, queue: emailQueue ?? email, public: public);
        } on NotFoundException catch (_) {
          await ma.createMailbox(projectId: projectId, address: email, room: widget.roomName!, queue: emailQueue ?? email, public: public);
        }

        final roomConnection = await ma.connectRoom(projectId: projectId, roomName: widget.roomName!);

        final roomClient = RoomClient(
          protocol: WebSocketClientProtocol(url: roomConnection.roomUrl, token: roomConnection.jwt),
        );
        try {
          roomClient.start();
          await roomClient.ready;
          for (final a in service.agents) {
            final databaseAnnotation = a.annotations["meshagent.agent.database.schema"];
            if (databaseAnnotation != null) {
              final databaseDef = jsonDecode(a.annotations["meshagent.agent.database.schema"]) as Map<String, dynamic>;
              for (final t in databaseDef["tables"]) {
                final table = RequiredTable.fromJson(t);
                await installTable(roomClient, table);
              }
            }
          }
        } finally {
          roomClient.dispose();
        }
      }

      if (widget.serviceId != null) {
        await client.updateRoomServiceFromTemplate(
          projectId: projectId,
          serviceId: widget.serviceId!,
          template: widget.template,
          values: _vars,
          roomName: widget.roomName!,
        );
      } else {
        await client.createRoomServiceFromTemplate(
          projectId: projectId,
          template: widget.template,
          values: _vars,
          roomName: widget.roomName!,
        );
      }

      try {
        await deleteExistingTasks();
      } catch (err) {
        if (widget.manifest.agents.where((x) => x.annotations["meshagent.agent.schedule"] != null).isNotEmpty) {
          if (mounted) {
            ShadToaster.of(context).show(
              ShadToast(
                title: Text("Unable to check for existing scheduled tasks"),
                description: Text("you may not have permission to modify scheduled tasks"),
              ),
            );
          }
        }
      }

      try {
        for (final a in service.agents) {
          if (a.annotations["meshagent.agent.schedule"] != null) {
            final scheduleSpec = jsonDecode(a.annotations["meshagent.agent.schedule"]);

            final schedule = scheduleSpec["schedule"];
            final payload = scheduleSpec["payload"];
            final queue = scheduleSpec["queue"];
            final name = scheduleSpec["name"];

            await client.createScheduledTask(
              projectId: projectId,
              roomName: widget.roomName!,
              queueName: queue,
              payload: payload,
              schedule: schedule,
              annotations: {"meshagent.agent.name": a.name, "meshagent.agent.task.name": name},
            );
          }
        }
      } catch (err) {
        _showError("The service was installed but there was an error creating it's scheduled tasks");
        return;
      }

      if (!mounted) return;
      widget.onDone(context);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> deleteExistingTasks() async {
    final client = getMeshagentClient();

    for (final st in await client.listScheduledTasks(projectId: widget.projectId, roomName: widget.roomName)) {
      for (final a in widget.manifest.agents) {
        final agentName = st.annotations["meshagent.agent.name"];
        if (agentName == a.name) {
          await client.deleteScheduledTask(projectId: widget.projectId, taskId: st.id);
        }
      }
    }
  }

  Future<void> _uninstall() async {
    setState(() {
      _error = null;
      _removing = true;
    });

    try {
      final client = getMeshagentClient();

      await client.deleteRoomService(projectId: widget.projectId, serviceId: widget.serviceId!, roomName: widget.roomName!);

      if (widget.manifest.agents.where((x) => x.annotations["meshagent.agent.schedule"] != null).isNotEmpty) {
        try {
          deleteExistingTasks();
        } catch (e) {
          if (mounted) {
            ShadToaster.of(context).show(
              ShadToast(
                title: Text("Unable to delete existing scheduled tasks"),
                description: Text("you may not have permission to modify scheduled tasks"),
              ),
            );
          }
        }
      }

      if (!mounted) return;
      widget.onDone(context);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  void _showError(Object e, {String prefix = 'Error'}) {
    if (!mounted) return;
    setState(() => _error = '$prefix: $e');
  }

  final info = ShadTooltipController();
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

  List<Widget> actions(BuildContext context) {
    final isInstalled = widget.serviceId != null;

    return [
      if (isInstalled) ...[
        ShadButton.outline(
          onPressed: _removing
              ? null
              : () {
                  if (!_removing && !_saving) {
                    _uninstall();
                  }
                },

          child: Text(_removing ? 'Uninstalling' : 'Uninstall'),
        ),
      ],
      ShadButton(
        leading: Icon(LucideIcons.download),
        onPressed: _saving
            ? null
            : () {
                if (!_removing && !_saving) {
                  _saveOrUpdate();
                }
              },
        child: Text(_saving ? (isInstalled ? 'Updating' : 'Installing') : (isInstalled ? 'Update' : 'Install')),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    final suffix = "@${const String.fromEnvironment("MESHAGENT_MAIL_DOMAIN")}";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Expanded(
          child: ShadForm(
            key: _formKey,
            child: ListView(
              padding: .only(top: 15),
              children: [
                if (_error != null) _buildError(context),

                ...widget.header,

                // ── Variable inputs (spec-driven) ─────────────────────────────
                if (widget.manifest.variables?.isNotEmpty ?? false) ...[
                  for (final v in widget.manifest.variables ?? <ServiceTemplateVariable>[])
                    switch (v.type) {
                      "email" => Column(
                        mainAxisAlignment: .start,
                        crossAxisAlignment: .start,
                        children: [
                          ShadInputFormField(
                            id: v.name,
                            constraints: BoxConstraints(maxWidth: 400),
                            padding: EdgeInsets.only(left: 8, top: 0, bottom: 0, right: 0),
                            label: Text('${v.name} (${v.optional ? 'optional' : 'required'})', style: labelStyle),
                            obscureText: v.obscure,
                            initialValue: (_vars[v.name] ?? '').replaceAll(suffix, ''),
                            onChanged: (txt) => setState(() => _vars[v.name] = txt.trim().isEmpty ? "" : ("${txt.trim()}$suffix").trim()),
                            trailing: Container(
                              color: ShadTheme.of(context).colorScheme.muted,
                              padding: EdgeInsets.all(8),
                              child: Text(suffix),
                            ),
                          ),
                          if (v.description != null) Padding(padding: EdgeInsets.symmetric(vertical: 7), child: Text(v.description ?? '')),
                        ],
                      ),
                      _ =>
                        v.enumValues == null
                            ? ShadInputFormField(
                                id: v.name,
                                label: Text('${v.name} (${v.optional ? 'optional' : 'required'})', style: labelStyle),
                                obscureText: v.obscure,
                                initialValue: _vars[v.name] ?? '',
                                description: v.description == null ? null : Text(v.description ?? ''),
                                validator: (txt) {
                                  final val = (txt).trim();
                                  if (v.optional) return null;
                                  final msg = val.isEmpty ? '${v.name} is required' : null;

                                  return msg;
                                },
                                onChanged: (txt) => setState(() => _vars[v.name] = txt.trim()),
                              )
                            : ShadSelectFormField<String>(
                                label: Text(v.name, style: labelStyle),
                                id: v.name,
                                initialValue: _vars[v.name] ?? v.enumValues!.first,
                                selectedOptionBuilder: (context, value) => Text(value),
                                options: [...v.enumValues!.map((val) => ShadOption<String>(value: val, child: Text(val)))],
                                description: v.description == null ? null : Text(v.description ?? ''),
                                validator: v.optional
                                    ? null
                                    : (txt) {
                                        final msg = (txt?.trim().isEmpty == true || txt == null) ? '${v.name} is required' : null;
                                        if (msg != null) {}
                                        return msg;
                                      },
                                onChanged: (txt) => setState(() => _vars[v.name] = txt!),
                              ),
                    },
                ],

                if (widget.manifest.container != null) ...[
                  if (widget.manifest.container!.storage != null && widget.manifest.container!.storage?.room != null) ...[
                    for (final rs in widget.manifest.container!.storage!.room!) ...[
                      Text(rs.subpath == null ? "Mounts entire room's storage to" : "Mounts only ${rs.subpath} to", style: labelStyle),
                      Text(rs.path),
                    ],
                  ],
                ],
              ].map((x) => Container(margin: EdgeInsets.only(bottom: 10), child: x)).toList(),
            ),
          ),
        ),
        Row(spacing: 8, children: [...widget.customActions, Spacer(), ...actions(context)]),
      ],
    );
  }
}
