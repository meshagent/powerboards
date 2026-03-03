import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:meshagent/agent.dart';
import 'package:meshagent/client.dart' as meshagent_client;
import 'package:meshagent/protocol.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_flutter_dev/meshagent_flutter_dev.dart' as dev;
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:powerboards/meshagent/meshagent.dart';

class ConfigureServiceTemplateDialog extends StatelessWidget {
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

  final String template;
  final Map<String, String>? prefilledVars;
  final String projectId;
  final String? serviceId;
  final ServiceTemplateSpec manifest;
  final String? roomName;
  final String title;
  final String? description;

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
            ? 'Update variables or uninstall this agent.'
            : 'Installing this agent will grant it access to your room. Review the details before continuing.',
      ),
      child: SizedBox(
        height: 500,
        child: ConfigureServiceTemplate(
          template: template,
          header: [
            const SizedBox(height: 8),
            dev.ServiceNameCard(manifest: manifest),
            if (!isInstalled) ...[const SizedBox(height: 8), dev.ServiceInfoCard(manifest: manifest)],
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

class ConfigureServiceTemplate extends StatefulWidget {
  const ConfigureServiceTemplate({
    super.key,
    required this.template,
    required this.projectId,
    required this.serviceId,
    required this.manifest,
    required this.onDone,
    this.roomName,
    this.prefilledVars,
    this.customActions = const [],
    this.header = const [],
  });

  final ServiceTemplateSpec manifest;
  final Map<String, String>? prefilledVars;
  final String? serviceId;
  final String projectId;
  final String? roomName;
  final List<Widget> customActions;
  final List<Widget> header;
  final String template;
  final void Function(BuildContext) onDone;

  @override
  State<ConfigureServiceTemplate> createState() => _ConfigureServiceTemplateState();
}

class _ConfigureServiceTemplateState extends State<ConfigureServiceTemplate> {
  bool _saving = false;
  bool _removing = false;
  String? _error;

  String _requireRoomName() {
    final roomName = widget.roomName;
    if (roomName == null || roomName.isEmpty) {
      throw RoomServerException('room name is required to install a service');
    }
    return roomName;
  }

  Set<String> _servicePorts() {
    final ports = <String>{};
    for (final port in widget.manifest.ports) {
      final value = port.num.value;
      if (value != null) {
        ports.add(value.toString());
      }
    }
    return ports;
  }

  Future<List<meshagent_client.Route>> _domainsToDelete(meshagent_client.Meshagent client) async {
    final roomName = widget.roomName;
    if (roomName == null) {
      return <meshagent_client.Route>[];
    }
    final ports = _servicePorts();
    if (ports.isEmpty) {
      return <meshagent_client.Route>[];
    }
    final domains = await client.listRoomRoutes(projectId: widget.projectId, roomName: roomName);
    return domains.where((domain) => ports.contains(domain.port)).toList();
  }

  Future<void> _saveOrUpdate(Map<String, String> vars, bool Function() validate) async {
    if (!validate()) {
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      final client = getMeshagentClient();
      final projectId = widget.projectId;
      final roomName = _requireRoomName();
      final renderedTemplate = await client.renderTemplate(template: widget.template, values: vars);
      final service = renderedTemplate.toServiceSpec(values: vars);
      final inputVariables = renderedTemplate.variables ?? widget.manifest.variables ?? const <ServiceTemplateVariable>[];

      final serviceId = service.metadata.annotations['meshagent.service.id']?.trim();
      if (serviceId == null || serviceId.isEmpty) {
        throw RoomServerException('service is missing meshagent.service.id annotation');
      }

      String? email;
      String? emailQueue;
      var isMailboxPublic = false;

      for (final variable in inputVariables) {
        if (variable.type == 'email') {
          email = (vars[variable.name] ?? '').trim();
          final privacy = variable.annotations?['meshagent.email.privacy'];
          isMailboxPublic = switch (privacy) {
            'public' => true,
            'private' => false,
            null => false,
            _ => throw RoomServerException('invalid email privacy option'),
          };
        } else if (variable.type == 'email_queue') {
          emailQueue = (vars[variable.name] ?? '').trim();
        }
      }

      if (email != null && email.isNotEmpty) {
        try {
          final mailbox = await client.getMailbox(projectId: projectId, address: email);
          if (mailbox.room != roomName) {
            throw RoomServerException('Mailbox has already been assigned to another room');
          }

          await client.updateMailbox(
            projectId: projectId,
            address: email,
            room: roomName,
            queue: emailQueue == null || emailQueue.isEmpty ? email : emailQueue,
            public: isMailboxPublic,
            annotations: {'meshagent.service.id': serviceId},
          );
        } on meshagent_client.NotFoundException {
          await client.createMailbox(
            projectId: projectId,
            address: email,
            room: roomName,
            queue: emailQueue == null || emailQueue.isEmpty ? email : emailQueue,
            public: isMailboxPublic,
            annotations: {'meshagent.service.id': serviceId},
          );
        }
      }

      final routeRequests = <({String domain, String port})>[];
      for (final variable in inputVariables) {
        if (variable.type != 'route') {
          continue;
        }
        final domain = (vars[variable.name] ?? '').trim();
        if (domain.isEmpty) {
          continue;
        }
        final port = variable.annotations?['meshagent.route.port']?.trim();
        if (port == null || port.isEmpty) {
          throw RoomServerException('meshagent.route.port is missing for ${variable.name}');
        }
        routeRequests.add((domain: domain, port: port));
      }

      if (routeRequests.isNotEmpty) {
        final room = await client.getRoom(projectId: projectId, name: roomName);
        for (final route in routeRequests) {
          try {
            final existing = await client.getRoute(projectId: projectId, domain: route.domain);
            if (existing.roomName != room.name) {
              throw RoomServerException('Domain ${route.domain} has already been assigned to another room');
            }
            await client.updateRoute(
              projectId: projectId,
              domain: route.domain,
              roomName: room.name,
              port: route.port,
              annotations: {'meshagent.service.id': serviceId},
            );
          } on meshagent_client.NotFoundException {
            await client.createRoute(
              projectId: projectId,
              domain: route.domain,
              roomName: room.name,
              port: route.port,
              annotations: {'meshagent.service.id': serviceId},
            );
          }
        }
      }

      final roomConnection = await client.connectRoom(projectId: projectId, roomName: roomName);
      final roomClient = RoomClient(
        protocol: WebSocketClientProtocol(url: roomConnection.roomUrl, token: roomConnection.jwt),
      );

      try {
        roomClient.start();
        await roomClient.ready;

        for (final variable in inputVariables) {
          final secretId = variable.annotations?['meshagent.secret.id'];
          if (secretId == null || secretId.isEmpty) {
            continue;
          }

          final secretIdentity = variable.annotations?['meshagent.secret.identity'];
          final secretName = variable.annotations?['meshagent.secret.name'];
          final secretType = variable.annotations?['meshagent.secret.type'];

          if (secretIdentity == null || secretIdentity.isEmpty) {
            throw RoomServerException('meshagent.secret.identity is missing');
          }

          await roomClient.secrets.setSecret(
            secretId: secretId,
            name: secretName,
            mimeType: secretType,
            data: utf8.encode(vars[variable.name] ?? ''),
            forIdentity: secretIdentity,
          );
        }

        for (final agent in service.agents) {
          final databaseAnnotation = agent.annotations['meshagent.agent.database.schema'];
          if (databaseAnnotation == null) {
            continue;
          }

          final databaseDef = jsonDecode(databaseAnnotation);
          if (databaseDef is! Map<String, dynamic>) {
            continue;
          }
          final tables = databaseDef['tables'];
          if (tables is! List) {
            continue;
          }

          for (final tableJson in tables) {
            if (tableJson is! Map<String, dynamic>) {
              continue;
            }
            final table = RequiredTable.fromJson(tableJson);
            await installTable(roomClient, table);
          }
        }
      } finally {
        roomClient.dispose();
      }

      if (widget.serviceId != null) {
        await client.updateRoomServiceFromTemplate(
          projectId: projectId,
          serviceId: widget.serviceId!,
          template: widget.template,
          values: vars,
          roomName: roomName,
        );
      } else {
        await client.createRoomServiceFromTemplate(projectId: projectId, template: widget.template, values: vars, roomName: roomName);
      }

      try {
        await _deleteExistingTasks();
      } catch (_) {
        if (widget.manifest.agents.any((agent) => agent.annotations['meshagent.agent.schedule'] != null)) {
          if (mounted) {
            ShadToaster.of(context).show(
              ShadToast(
                title: Text('Unable to check for existing scheduled tasks'),
                description: Text('you may not have permission to modify scheduled tasks'),
              ),
            );
          }
        }
      }

      try {
        for (final agent in service.agents) {
          final scheduleRaw = agent.annotations['meshagent.agent.schedule'];
          if (scheduleRaw == null) {
            continue;
          }

          final scheduleSpec = jsonDecode(scheduleRaw);
          if (scheduleSpec is! Map<String, dynamic>) {
            continue;
          }

          final schedule = scheduleSpec['schedule'];
          final payload = scheduleSpec['payload'];
          final queue = scheduleSpec['queue'];
          final name = scheduleSpec['name'];
          if (queue is! String || queue.trim().isEmpty) {
            continue;
          }

          await client.createScheduledTask(
            projectId: projectId,
            roomName: roomName,
            queueName: queue,
            payload: payload,
            schedule: schedule,
            annotations: {'meshagent.agent.name': agent.name, 'meshagent.agent.task.name': name},
          );
        }
      } catch (_) {
        _showError('The service was installed but there was an error creating its scheduled tasks');
        return;
      }

      if (!mounted) {
        return;
      }
      widget.onDone(context);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _deleteExistingTasks() async {
    final roomName = widget.roomName;
    if (roomName == null || roomName.isEmpty) {
      return;
    }

    final client = getMeshagentClient();
    final tasks = await client.listScheduledTasks(projectId: widget.projectId, roomName: roomName);

    for (final task in tasks) {
      for (final agent in widget.manifest.agents) {
        final agentName = task.annotations['meshagent.agent.name'];
        if (agentName == agent.name) {
          await client.deleteScheduledTask(projectId: widget.projectId, taskId: task.id);
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
      final roomName = _requireRoomName();

      final domainsToDelete = await _domainsToDelete(client);
      if (domainsToDelete.isNotEmpty) {
        if (!mounted) {
          return;
        }
        final confirmed = await showShadDialog<bool>(
          context: context,
          builder: (context) => ShadDialog.alert(
            title: const Text('Delete routes?'),
            actions: [
              ShadButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('Cancel'),
              ),
              ShadButton.destructive(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Delete and uninstall'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Text(
                'This agent has ${domainsToDelete.length} route(s) mapped to its ports. '
                'Uninstalling will delete: ${domainsToDelete.map((domain) => domain.domain).join(', ')}',
              ),
            ),
          ),
        );
        if (confirmed != true) {
          if (mounted) {
            setState(() {
              _removing = false;
            });
          }
          return;
        }
      }

      final serviceId = widget.serviceId;
      if (serviceId == null || serviceId.isEmpty) {
        throw RoomServerException('service id is required to uninstall');
      }

      await client.deleteRoomService(projectId: widget.projectId, serviceId: serviceId, roomName: roomName);

      if (domainsToDelete.isNotEmpty) {
        for (final domain in domainsToDelete) {
          await client.deleteRoute(projectId: widget.projectId, domain: domain.domain);
        }
      }

      if (widget.manifest.agents.any((agent) => agent.annotations['meshagent.agent.schedule'] != null)) {
        try {
          await _deleteExistingTasks();
        } catch (_) {
          if (mounted) {
            ShadToaster.of(context).show(
              ShadToast(
                title: Text('Unable to delete existing scheduled tasks'),
                description: Text('you may not have permission to modify scheduled tasks'),
              ),
            );
          }
        }
      }

      if (!mounted) {
        return;
      }
      widget.onDone(context);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _removing = false;
        });
      }
    }
  }

  void _showError(Object error, {String prefix = 'Error'}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _error = '$prefix: $error';
    });
  }

  Widget _buildError(BuildContext context) {
    final error = _error;
    if (error == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: const ValueKey('error-alert'),
      padding: const EdgeInsets.only(bottom: 12),
      child: ShadAlert.destructive(
        icon: Icon(Icons.error_outline),
        title: const Text('Something went wrong'),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(error),
            const SizedBox(height: 12),
            ShadButton.ghost(
              onTapDown: (_) {
                setState(() {
                  _error = null;
                });
              },
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, Map<String, String> vars, bool Function() validate) {
    final isInstalled = widget.serviceId != null;

    return [
      if (isInstalled)
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
      ShadButton(
        leading: Icon(LucideIcons.download),
        onPressed: _saving
            ? null
            : () {
                if (!_removing && !_saving) {
                  _saveOrUpdate(vars, validate);
                }
              },
        child: Text(_saving ? (isInstalled ? 'Updating' : 'Installing') : (isInstalled ? 'Update' : 'Install')),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final routeDomains = MeshagentConfig.current?.domains ?? const <String>[];
    return dev.ConfigureServiceTemplate(
      spec: widget.manifest,
      prefilledVars: widget.prefilledVars,
      routeDomains: routeDomains,
      customActions: widget.customActions,
      header: [_buildError(context), ...widget.header],
      actionsBuilder: (context, vars, validate) => _actions(context, vars, validate),
    );
  }
}
