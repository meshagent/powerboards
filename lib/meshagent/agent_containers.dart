import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:meshagent/agent.dart';
import 'package:meshagent/client.dart' as meshagent_client;
import 'package:meshagent/protocol.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_flutter_dev/meshagent_flutter_dev.dart' as dev;
import 'package:powerboards/theme/theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';

import 'package:powerboards/meshagent/meshagent.dart';

typedef ConfigureServiceTemplateDone = void Function(BuildContext context, String serviceId);

const double _mobileConfigureFlowSectionGap = powerboardsMobileFlowDialogContentSectionGap * 3;

String powerboardsDisplayServiceName(String rawName) {
  final trimmed = rawName.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
}

TextStyle powerboardsAgentCardTitleTextStyle(BuildContext context) {
  final theme = ShadTheme.of(context);
  return powerboardsEmphasizedTitleStyle(color: theme.colorScheme.foreground);
}

ServiceTemplateSpec powerboardsDisplayServiceTemplateSpec(ServiceTemplateSpec manifest) {
  return ServiceTemplateSpec(
    version: manifest.version,
    kind: manifest.kind,
    variables: manifest.variables,
    metadata: ServiceTemplateMetadata(
      name: powerboardsDisplayServiceName(manifest.metadata.name),
      description: manifest.metadata.description,
      icon: manifest.metadata.icon,
      repo: manifest.metadata.repo,
      annotations: Map<String, String>.from(manifest.metadata.annotations),
    ),
    ports: manifest.ports,
    container: manifest.container,
    external: manifest.external,
    agents: manifest.agents,
  );
}

TextStyle powerboardsAgentCardDescriptionTextStyle(BuildContext context) {
  final theme = ShadTheme.of(context);
  final descriptionStyle = theme.decoration.descriptionStyle ?? theme.textTheme.muted;
  return descriptionStyle.copyWith(color: descriptionStyle.color ?? theme.colorScheme.mutedForeground);
}

class PowerboardsServiceNameCard extends StatelessWidget {
  const PowerboardsServiceNameCard({super.key, required this.manifest});

  final ServiceTemplateSpec manifest;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final descriptionStyle = powerboardsAgentCardDescriptionTextStyle(context);
    final titleStyle = powerboardsAgentCardTitleTextStyle(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: theme.colorScheme.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(manifest.metadata.name, style: titleStyle, overflow: TextOverflow.ellipsis),
                if (manifest.metadata.description case final description? when description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: descriptionStyle),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: theme.colorScheme.foreground, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(LucideIcons.bot, color: theme.colorScheme.background, size: 22),
          ),
        ],
      ),
    );
  }
}

BoxConstraints? _desktopConfigureAgentDialogConstraints(BuildContext context, BoxConstraints constraints) {
  if (powerboardsUsesNativeMobileDialogLayout(context)) {
    return null;
  }

  final maxViewportHeight = constraints.maxHeight;
  final maxHeight = maxViewportHeight.isFinite ? (maxViewportHeight * 0.7).clamp(0.0, 860.0).toDouble() : 620.0;
  return BoxConstraints(maxWidth: 500.0, maxHeight: maxHeight);
}

Widget _desktopConfigureDialogBodyViewport({required Widget child}) {
  return Padding(padding: powerboardsDialogScrollViewportPadding, child: child);
}

class ConfigureServiceTemplateDialog extends StatefulWidget {
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
  final Widget? description;

  @override
  State<ConfigureServiceTemplateDialog> createState() => _ConfigureServiceTemplateDialogState();
}

class _ConfigureServiceTemplateDialogState extends State<ConfigureServiceTemplateDialog> {
  final ValueNotifier<PowerboardsDialogChrome> _mobileChrome = ValueNotifier((
    signature: 'initial',
    actions: const <Widget>[],
    onBack: null,
  ));

  @override
  void dispose() {
    _mobileChrome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInstalled = widget.serviceId != null;
    final displayManifest = powerboardsDisplayServiceTemplateSpec(widget.manifest);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = powerboardsUsesNativeMobileDialogLayout(context);
        final content = ConfigureServiceTemplate(
          template: widget.template,
          header: [
            PowerboardsServiceNameCard(manifest: displayManifest),
            if (!isInstalled && !isMobile) ...[
              SizedBox(height: isMobile ? _mobileConfigureFlowSectionGap : 12),
              dev.ServiceInfoCard(manifest: displayManifest, desktopContentGroupGap: isMobile ? null : 24),
            ],
          ],
          projectId: widget.projectId,
          serviceId: widget.serviceId,
          manifest: widget.manifest,
          roomName: widget.roomName,
          prefilledVars: widget.prefilledVars,
          mobileDialogChrome: _mobileChrome,
          onDone: (context, _) {
            Navigator.of(context).pop(true);
          },
        );

        return ValueListenableBuilder<PowerboardsDialogChrome>(
          valueListenable: _mobileChrome,
          builder: (context, chrome, _) {
            return PowerboardsShadDialog(
              scrollable: false,
              constraints: _desktopConfigureAgentDialogConstraints(context, constraints),
              expandDesktopActions: true,
              stackActionsOnMobile: true,
              gap: isMobile ? 8 : null,
              padding: isMobile ? powerboardsMobileFlowDialogCompactPadding : null,
              mobilePresentation: PowerboardsDialogMobilePresentation.flowSheet,
              mobileFlowBodyBehavior: isMobile
                  ? PowerboardsDialogMobileFlowBodyBehavior.formScrollable
                  : PowerboardsDialogMobileFlowBodyBehavior.fill,
              mobileKeyboardBehavior: PowerboardsDialogMobileKeyboardBehavior.avoid,
              title: Text(widget.title),
              description: widget.description,
              actions: chrome.actions,
              onBack: isMobile ? chrome.onBack : null,
              child: isMobile ? content : _desktopConfigureDialogBodyViewport(child: content),
            );
          },
        );
      },
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
    this.mobileDialogChrome,
    this.mobileOnBack,
    this.dialogChromeSignaturePrefix,
  });

  final ServiceTemplateSpec manifest;
  final Map<String, String>? prefilledVars;
  final String? serviceId;
  final String projectId;
  final String? roomName;
  final List<Widget> customActions;
  final List<Widget> header;
  final String template;
  final ConfigureServiceTemplateDone onDone;
  final ValueNotifier<PowerboardsDialogChrome>? mobileDialogChrome;
  final VoidCallback? mobileOnBack;
  final String? dialogChromeSignaturePrefix;

  @override
  State<ConfigureServiceTemplate> createState() => _ConfigureServiceTemplateState();
}

class _ConfigureServiceTemplateState extends State<ConfigureServiceTemplate> with SingleTickerProviderStateMixin {
  bool _saving = false;
  bool _removing = false;
  String? _error;
  Map<String, String> _latestFormVars = const <String, String>{};
  bool Function()? _latestFormValidate;
  String? _lastPublishedMobileChromeSignature;
  late final AnimationController _loaderController;

  @override
  void initState() {
    super.initState();
    _loaderController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _loaderController.dispose();
    super.dispose();
  }

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
        protocolFactory: WebSocketClientProtocol.createFactory(url: roomConnection.roomUrl, token: roomConnection.jwt),
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
          final datasetAnnotation = agent.annotations['meshagent.agent.dataset.schema'];
          if (datasetAnnotation == null) {
            continue;
          }

          final datasetDef = jsonDecode(datasetAnnotation);
          if (datasetDef is! Map<String, dynamic>) {
            continue;
          }
          final tables = datasetDef['tables'];
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

      final savedService = widget.serviceId != null
          ? await client.updateRoomServiceFromTemplate(
              projectId: projectId,
              serviceId: widget.serviceId!,
              template: widget.template,
              values: vars,
              roomName: roomName,
            )
          : await client.createRoomServiceFromTemplate(projectId: projectId, template: widget.template, values: vars, roomName: roomName);

      final savedServiceId = savedService.metadata.annotations['meshagent.service.id']?.trim();
      final resolvedServiceId = savedServiceId != null && savedServiceId.isNotEmpty ? savedServiceId : serviceId;

      if (resolvedServiceId.isEmpty) {
        throw RoomServerException('saved service is missing meshagent.service.id annotation');
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
          if (schedule is! String || schedule.trim().isEmpty || queue is! String || queue.trim().isEmpty) {
            continue;
          }
          if (payload != null && payload is! Map) {
            continue;
          }

          final annotations = <String, String>{'meshagent.agent.name': agent.name};
          if (name is String && name.trim().isNotEmpty) {
            annotations['meshagent.agent.task.name'] = name;
          }

          await client.createScheduledTask(
            projectId: projectId,
            roomName: roomName,
            spec: ScheduledTaskSpec(
              schedule: schedule,
              metadata: ScheduledTaskMetadata(annotations: annotations),
              queue: ScheduledTaskQueueSpec(name: queue.trim(), payload: (payload as Map?)?.cast<String, dynamic>()),
            ),
          );
        }
      } catch (_) {
        _showError('The service was installed but there was an error creating its scheduled tasks');
        return;
      }

      if (!mounted) {
        return;
      }
      widget.onDone(context, resolvedServiceId);
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
    final room = await client.getRoom(projectId: widget.projectId, name: roomName);
    final tasks = await client.listScheduledTasks(projectId: widget.projectId, roomId: room.id);

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
        final confirmed = await showPowerboardsAlertDialog<bool>(
          context: context,
          builder: (context) => PowerboardsShadDialog.compactAlert(
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
      widget.onDone(context, serviceId);
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

  Widget? _buildError(BuildContext context) {
    final error = _error;
    if (error == null) {
      return null;
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

  bool _validateMobileForm() => _latestFormValidate?.call() ?? true;

  List<Widget> _actions(BuildContext context) {
    final isInstalled = widget.serviceId != null;
    final progressLabel = isInstalled ? 'Updating' : 'Installing';

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
        leading: _saving
            ? RotationTransition(turns: _loaderController, child: const Icon(LucideIcons.loaderCircle))
            : const Icon(LucideIcons.download),
        onPressed: _saving
            ? null
            : () {
                if (!_removing && !_saving) {
                  _saveOrUpdate(_latestFormVars, _validateMobileForm);
                }
              },
        child: Text(_saving ? progressLabel : (isInstalled ? 'Update' : 'Install')),
      ),
    ];
  }

  void _publishDialogChrome() {
    final notifier = widget.mobileDialogChrome;
    if (notifier == null) {
      return;
    }

    final chrome = (
      signature:
          '${widget.dialogChromeSignaturePrefix ?? ''}service:${widget.serviceId != null}:saving:$_saving:removing:$_removing:error:${_error != null}:back:${widget.mobileOnBack != null}',
      actions: [...widget.customActions, ..._actions(context)],
      onBack: powerboardsUsesNativeMobileDialogLayout(context) ? widget.mobileOnBack : null,
    );

    if (_lastPublishedMobileChromeSignature == chrome.signature) {
      return;
    }

    _lastPublishedMobileChromeSignature = chrome.signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      notifier.value = chrome;
    });
  }

  @override
  Widget build(BuildContext context) {
    _publishDialogChrome();
    final routeDomains = MeshagentConfig.current?.domains ?? const <String>[];
    final errorAlert = _buildError(context);
    return dev.ConfigureServiceTemplate(
      spec: widget.manifest,
      prefilledVars: widget.prefilledVars,
      routeDomains: routeDomains,
      meshagentMailDomain: MeshagentConfig.current?.meshagentMailDomain,
      desktopHorizontalPadding: 0,
      desktopSectionSpacing: 20,
      desktopHeaderBottomSpacing: 44,
      customActions: widget.customActions,
      header: [?errorAlert, ...widget.header],
      showActionRow: widget.mobileDialogChrome == null,
      onFormStateChanged: (vars, validate) {
        _latestFormVars = vars;
        _latestFormValidate = validate;
      },
      actionsBuilder: (context, vars, validate) {
        _latestFormVars = vars;
        _latestFormValidate = validate;
        return _actions(context);
      },
    );
  }
}
