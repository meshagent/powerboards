import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:http/http.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/agent_containers.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum _InstallerStep { url, review, selectProject, selectRoom, confirm }

class AgentInstaller extends StatefulWidget {
  const AgentInstaller({super.key, this.initialUrl, this.template, this.initialProjectId, this.initialRoomName, this.onInstalled});

  final Uri? initialUrl;
  final String? template;
  final String? initialProjectId;
  final String? initialRoomName;
  final void Function(BuildContext context, String projectId, String roomName, String serviceId)? onInstalled;

  @override
  State createState() => _AgentInstaller();
}

class _AgentInstaller extends State<AgentInstaller> {
  Uri? _url;
  late final Resource<ServiceTemplateSpec?> _spec;
  late final Resource<List<Project>?> _projects;
  late final Resource<List<ProjectRoomGrant>?> _rooms;
  late final Resource<List<ServiceSpec>?> _services;

  String? _projectId;
  String? _roomName;
  bool _confirmed = false;
  bool _collectingUrl = false;

  late final TextEditingController _urlController;
  String? _urlError;

  bool get _hasValidUrl => _url != null && _url!.host.isNotEmpty;

  _InstallerStep get _step {
    if (_collectingUrl && widget.template == null) return _InstallerStep.url;
    if (!_confirmed) return _InstallerStep.review;
    if (_projectId == null && widget.template == null) return _InstallerStep.selectProject;
    if (_roomName == null && widget.template == null) return _InstallerStep.selectRoom;
    return _InstallerStep.confirm;
  }

  TextStyle get _labelStyle => Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold);

  late String? _template = widget.template;

  @override
  void initState() {
    super.initState();

    _url = widget.initialUrl;
    _projectId = widget.initialProjectId;
    _roomName = widget.initialRoomName;

    _urlController = TextEditingController(text: widget.initialUrl?.toString() ?? "");
    _collectingUrl = !_hasValidUrl;

    _spec = widget.template == null
        ? Resource<ServiceTemplateSpec?>(() async {
            if (!_hasValidUrl) return null;
            final res = await get(_url!);
            _template = res.body;
            final client = getMeshagentClient();

            return await client.renderTemplate(template: res.body, values: {});
          })
        : Resource<ServiceTemplateSpec?>(() async {
            final client = getMeshagentClient();

            return await client.renderTemplate(template: widget.template!, values: {});
          });

    _projects = Resource<List<Project>?>(() => fetchProjects());

    _rooms = Resource<List<ProjectRoomGrant>?>(() async {
      if (_projectId == null) {
        return null;
      }
      final client = getMeshagentClient();
      return await client.listRoomGrantsByUser(projectId: _projectId!, userId: "me");
    });

    _services = Resource<List<ServiceSpec>?>(() async {
      if (_projectId == null || _roomName == null) {
        return null;
      }
      final client = getMeshagentClient();
      return await client.listRoomServices(projectId: _projectId!, roomName: _roomName!);
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  ServiceSpec? _currentServiceForSpec() {
    final services = _services.state.value;
    final spec = _spec.state.value;

    if (services == null || spec == null) return null;

    final desiredServiceId = spec.metadata.annotations["meshagent.service.id"];
    if (desiredServiceId == null) return null;

    return services.firstWhereOrNull((s) => s.metadata.annotations["meshagent.service.id"] == desiredServiceId);
  }

  void _onUrlContinue() {
    final text = _urlController.text.trim();
    final uri = Uri.tryParse(text);

    if (uri == null || uri.host.isEmpty) {
      setState(() {
        _urlError = "Please enter a valid URL";
      });
      return;
    }

    setState(() {
      _urlError = null;
      _url = uri;
      _collectingUrl = false;
      _confirmed = false;
    });

    _spec.refresh();
  }

  void _backToUrlInput() {
    setState(() {
      _collectingUrl = true;
      _urlError = null;
      _confirmed = false;
    });
  }

  void _handleInstalled(BuildContext context) {
    final projectId = _projectId!;
    final roomName = _roomName!;
    final serviceId = _spec.state.value!.metadata.annotations["meshagent.service.id"]!;

    if (widget.onInstalled != null) {
      widget.onInstalled!(context, projectId, roomName, serviceId);
    } else {
      context.go("/p/${fromUUID(projectId)}/r/$roomName/a/$serviceId");
    }
  }

  Widget _backButton({required VoidCallback onPressed, String label = 'Back'}) {
    return ShadButton.outline(leading: const Icon(LucideIcons.arrowLeft), onPressed: onPressed, child: Text(label));
  }

  Widget _continueButton({required VoidCallback onPressed, String label = 'Continue'}) {
    return ShadButton.outline(trailing: const Icon(LucideIcons.arrowRight), onPressed: onPressed, child: Text(label));
  }

  Widget _urlStep() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text("Enter the URL of your agent.yaml", style: _labelStyle, textAlign: TextAlign.center),
          ShadInput(controller: _urlController, placeholder: const Text("https://.../agent.yaml")),
          if (_urlError != null) ShadAlert.destructive(description: Text(_urlError!)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_continueButton(onPressed: _onUrlContinue)],
          ),
        ],
      ),
    );
  }

  Widget _specError(String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Text("Unable to load agent spec", style: _labelStyle, textAlign: TextAlign.center),
        ShadAlert.destructive(description: Text(message)),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [_backButton(onPressed: _backToUrlInput, label: "Change URL")],
        ),
      ],
    );
  }

  Widget _reviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(15),
            children: [
              Text("Review the agent details", style: _labelStyle, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ServiceNameCard(manifest: _spec.state.value!),
              const SizedBox(height: 20),
              ServiceInfoCard(manifest: _spec.state.value!),
            ],
          ),
        ),
        Row(
          children: [
            _backButton(onPressed: _backToUrlInput, label: "Change URL"),
            const Spacer(),
            _continueButton(
              onPressed: () {
                setState(() {
                  _confirmed = true;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _projectStep() {
    final state = _projects.state;

    Widget body;
    if (state.hasError && !state.isRefreshing) {
      body = Center(child: ShadAlert.destructive(description: Text('Failed to load projects: ${state.error}')));
    } else if (!state.isReady) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final list = state.value ?? const <Project>[];
      body = ListView(
        padding: EdgeInsets.all(15),
        children: [
          for (final p in list)
            ShadButton.ghost(
              onPressed: () {
                setState(() {
                  _projectId = p.id;
                  _roomName = null;
                });
                _rooms.refresh();
                _services.refresh();
              },
              child: Text(p.name),
            ),
          ShadButton.ghost(
            onPressed: () async {
              try {
                final p = await createMeshagentProject(context);
                if (!mounted) return;
                if (p != null) {
                  _projects.refresh();
                  _rooms.refresh();
                }
              } catch (e) {
                if (!mounted) return;
                ShadToaster.of(context).show(ShadToast.destructive(description: Text('Failed to create project: $e')));
              }
            },
            leading: const Icon(LucideIcons.plus, size: 16),
            child: const Text("New Project"),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Text("Select a project to install this agent into", style: _labelStyle, textAlign: TextAlign.center),
        ShadSeparator.horizontal(margin: EdgeInsets.zero),
        Expanded(child: body),
        ShadSeparator.horizontal(margin: EdgeInsets.zero),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _backButton(
              onPressed: () {
                setState(() {
                  _confirmed = false;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  String? _roomDisplayName;

  Widget _roomStep() {
    final state = _rooms.state;

    Widget body;
    if (state.hasError && !state.isRefreshing) {
      body = Center(child: ShadAlert.destructive(description: Text('Failed to load rooms: ${state.error}')));
    } else if (state.isRefreshing || !state.isReady) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final list = state.value ?? const <ProjectRoomGrant>[];
      body = ListView(
        padding: EdgeInsets.all(15),
        children: [
          for (final room in list)
            ShadButton.ghost(
              onPressed: () {
                setState(() {
                  _roomName = room.room.name;
                  _roomDisplayName = room.room.metadata["displayName"];
                });
                _services.refresh();
              },
              child: Text(room.room.metadata["displayName"] ?? room.room.name),
            ),
          ShadButton.ghost(
            onPressed: () async {
              try {
                final room = await createMeshagentRoom(context, _projectId!);
                if (room != null) {
                  _roomName = room.name;
                  _roomDisplayName = room.metadata["displayName"];
                  if (!mounted) return;
                  _rooms.refresh();
                }
              } catch (e) {
                if (!mounted) return;
                ShadToaster.of(context).show(ShadToast.destructive(description: Text('Failed to create room: $e')));
              }
            },
            leading: const Icon(LucideIcons.plus, size: 16),
            child: const Text("New Room"),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Text("Pick a room to install this agent into", style: _labelStyle, textAlign: TextAlign.center),
        ShadSeparator.horizontal(margin: EdgeInsets.zero),
        Expanded(child: body),
        ShadSeparator.horizontal(margin: EdgeInsets.zero),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _backButton(
              onPressed: () {
                setState(() {
                  _roomName = null;
                  _projectId = null;
                });
                _services.refresh();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _confirmStep() {
    final servicesState = _services.state;

    if ((!servicesState.isReady || servicesState.isRefreshing) && !servicesState.hasError) {
      return const Center(child: CircularProgressIndicator());
    }

    final existingService = _currentServiceForSpec();
    final existingServiceId = existingService?.id;

    Map<String, String> prefill = {};
    /*try {
      final vars = existing?.config.variables;
      if (vars is List) {
        for (final v in vars) {
          final name = v['name']?.toString();
          final value = v['value']?.toString() ?? '';
          if (name != null) prefill[name] = value;
        }
      }
    } catch (_) {}*/

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Expanded(
          child: ConfigureServiceTemplate(
            template: _template!,
            header: [
              Text("Confirm and Install into ${_roomName ?? _roomDisplayName}", style: _labelStyle, textAlign: TextAlign.center),
              ServiceNameCard(manifest: _spec.state.value!),
              SizedBox(height: 8),
            ],
            serviceId: existingServiceId,
            projectId: _projectId!,
            roomName: _roomName,
            manifest: _spec.state.value!,
            prefilledVars: prefill,
            onDone: _handleInstalled,
            customActions: [
              _backButton(
                onPressed: () {
                  if (widget.initialRoomName != null) {
                    // If we started with a room, go back to review step
                    setState(() {
                      _confirmed = false;
                    });
                  } else {
                    // Otherwise go back to room selection
                    setState(() {
                      _roomName = null;
                    });
                    _services.refresh();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, _) {
        final step = _step;

        if (step != _InstallerStep.url) {
          if (!_spec.state.isReady) {
            if (_spec.state.hasError && !_spec.state.isRefreshing) {
              return _specError("${_spec.state.error}");
            }
            return const Center(child: CircularProgressIndicator());
          }

          if (_spec.state.value == null) {
            return _specError("Unable to load agent spec from the provided URL.");
          }
        }

        switch (step) {
          case _InstallerStep.url:
            return _urlStep();
          case _InstallerStep.review:
            return _reviewStep();
          case _InstallerStep.selectProject:
            return _projectStep();
          case _InstallerStep.selectRoom:
            return _roomStep();
          case _InstallerStep.confirm:
            return _confirmStep();
        }
      },
    );
  }
}
