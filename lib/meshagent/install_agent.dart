import 'package:collection/collection.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:http/http.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_dev/meshagent_flutter_dev.dart' as dev;
import 'package:powerboards/meshagent/agent_containers.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/powerboards_adaptive_input.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:powerboards/ui/powerboards_toasts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum _InstallerStep { url, review, selectProject, selectRoom, confirm }

enum ServiceType { any, mcp }

const double _mobileInstallFlowSectionGap = powerboardsMobileFlowDialogContentSectionGap * 3;
const double _desktopInstallDialogCardBodyGap = 44;

BoxConstraints? _desktopInstallServiceDialogConstraints(BuildContext context, BoxConstraints constraints) {
  if (powerboardsUsesNativeMobileDialogLayout(context)) {
    return null;
  }

  final maxViewportHeight = constraints.maxHeight;
  final maxHeight = maxViewportHeight.isFinite ? (maxViewportHeight * 0.7).clamp(0.0, 860.0).toDouble() : 620.0;
  return BoxConstraints(maxWidth: 500.0, maxHeight: maxHeight);
}

Widget _desktopInstallDialogBodyViewport({required Widget child}) {
  return Padding(padding: powerboardsDialogScrollViewportPadding, child: child);
}

String powerboardsInstalledServiceRoute({required String projectId, required String roomName, required String serviceId}) {
  if (serviceId == powerboardsWebServerServiceId) {
    return Uri(
      path: "/p/${fromUUID(projectId)}/r/$roomName",
      queryParameters: {'pane': 'files', 'p': '$powerboardsWebServerFolderName/'},
    ).toString();
  }

  return "/p/${fromUUID(projectId)}/r/$roomName/a/$serviceId";
}

Widget _desktopInstallDialogDescriptionForStep(BuildContext context, String signature, ServiceType type) {
  final theme = ShadTheme.of(context);

  if (signature == 'url') {
    final description = switch (type) {
      ServiceType.mcp => 'The link must point to a valid MCP server URL.',
      ServiceType.any => 'The link must point to a valid service template YAML or an MCP server URL.',
    };

    return Text(description);
  }

  if (signature == 'review') {
    return const Text('Review details');
  }

  if (signature.startsWith('confirm:')) {
    final encodedRoomName = signature.substring('confirm:'.length).split('|').first;
    final roomName = Uri.decodeComponent(encodedRoomName);
    final baseStyle = theme.textTheme.muted.copyWith(color: theme.colorScheme.mutedForeground);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'Confirm and install into '),
          TextSpan(
            text: roomName,
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  final description = switch (type) {
    ServiceType.mcp => 'Add this MCP service by reviewing its details and configuration.',
    ServiceType.any => 'Install this agent by reviewing its details and configuration.',
  };

  return Text(description);
}

Widget _installConfirmDescription(BuildContext context, String roomName) {
  final theme = ShadTheme.of(context);
  final baseStyle = theme.textTheme.muted.copyWith(color: theme.colorScheme.mutedForeground);
  return Text.rich(
    TextSpan(
      style: baseStyle,
      children: [
        const TextSpan(text: 'Confirm and install into '),
        TextSpan(
          text: roomName,
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class InstallServiceDialog extends StatefulWidget {
  const InstallServiceDialog({
    super.key,
    this.template,
    this.type = ServiceType.any,
    this.initialUrl,
    this.allowUrlEditing = true,
    required this.projectId,
    required this.roomName,
    this.onInstalled,
  });

  final String? template;
  final ServiceType type;
  final Uri? initialUrl;
  final bool allowUrlEditing;
  final String projectId;
  final String? roomName;
  final void Function(BuildContext context, String projectId, String roomName, String serviceId)? onInstalled;

  @override
  State<InstallServiceDialog> createState() => _InstallServiceDialogState();
}

class _InstallServiceDialogState extends State<InstallServiceDialog> {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = powerboardsUsesNativeMobileDialogLayout(context);
        if (isMobile && widget.template == null && widget.initialUrl == null) {
          return _InstallServiceUrlDialog(
            type: widget.type,
            projectId: widget.projectId,
            roomName: widget.roomName,
            onInstalled: widget.onInstalled,
          );
        }

        final installer = AgentInstaller(
          initialUrl: widget.initialUrl,
          template: widget.template,
          type: widget.type,
          allowUrlEditing: widget.allowUrlEditing,
          initialProjectId: widget.projectId,
          initialRoomName: widget.roomName,
          onInstalled: widget.onInstalled,
          mobileDialogChrome: _mobileChrome,
        );

        return ValueListenableBuilder<PowerboardsDialogChrome>(
          valueListenable: _mobileChrome,
          builder: (context, chrome, _) {
            return PowerboardsShadDialog(
              scrollable: false,
              constraints: _desktopInstallServiceDialogConstraints(context, constraints),
              expandDesktopActions: true,
              stackActionsOnMobile: true,
              gap: isMobile ? 8 : null,
              padding: isMobile ? powerboardsMobileFlowDialogCompactPadding : null,
              mobilePresentation: PowerboardsDialogMobilePresentation.flowSheet,
              mobileFlowBodyBehavior: isMobile
                  ? PowerboardsDialogMobileFlowBodyBehavior.formScrollable
                  : PowerboardsDialogMobileFlowBodyBehavior.fill,
              mobileKeyboardBehavior: PowerboardsDialogMobileKeyboardBehavior.avoid,
              mobileKeyboardInsetScale: isMobile ? 0.75 : 1.0,
              mobileHideActionsWhenKeyboardVisible: false,
              title: Text(widget.type == ServiceType.mcp ? "Add MCP service" : "Install"),
              description: switch ((isMobile, chrome.signature)) {
                (true, 'review') => const Text('Review details'),
                (false, _) => _desktopInstallDialogDescriptionForStep(context, chrome.signature, widget.type),
                _ => null,
              },
              actions: chrome.actions,
              onBack: isMobile ? chrome.onBack : null,
              child: isMobile ? installer : _desktopInstallDialogBodyViewport(child: installer),
            );
          },
        );
      },
    );
  }
}

class AgentInstaller extends StatefulWidget {
  const AgentInstaller({
    super.key,
    this.initialUrl,
    this.template,
    this.type = ServiceType.any,
    this.allowUrlEditing = true,
    this.initialProjectId,
    this.initialRoomName,
    this.onInstalled,
    this.mobileDialogChrome,
  });

  final Uri? initialUrl;
  final String? template;
  final ServiceType type;
  final bool allowUrlEditing;
  final String? initialProjectId;
  final String? initialRoomName;
  final void Function(BuildContext context, String projectId, String roomName, String serviceId)? onInstalled;
  final ValueNotifier<PowerboardsDialogChrome>? mobileDialogChrome;

  @override
  State createState() => _AgentInstaller();
}

class _AgentInstaller extends State<AgentInstaller> {
  Uri? _url;
  late final Resource<ServiceTemplateSpec?> _spec;
  late final Resource<List<Project>?> _projects;
  late final Resource<List<Room>?> _rooms;
  late final Resource<List<ServiceSpec>?> _services;

  String? _projectId;
  String? _roomName;
  bool _confirmed = false;
  bool _collectingUrl = false;

  late final TextEditingController _urlController;
  String? _urlError;
  String? _lastPublishedMobileChromeSignature;
  bool _mobileConfirmPresentationPending = false;

  bool get _hasValidUrl => _url != null && _url!.host.isNotEmpty;
  bool get _mcpOnly => widget.type == ServiceType.mcp;

  _InstallerStep get _step {
    if (_collectingUrl && widget.template == null) return _InstallerStep.url;
    if (!_confirmed) return _InstallerStep.review;
    if (_projectId == null && widget.template == null) {
      return _InstallerStep.selectProject;
    }
    if (_roomName == null && widget.template == null) {
      return _InstallerStep.selectRoom;
    }
    return _InstallerStep.confirm;
  }

  TextStyle get _labelStyle => Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold);
  TextStyle get _mobileSectionTitleStyle => powerboardsInterTextStyle(
    textStyle: DefaultTextStyle.of(context).style,
    color: ShadTheme.of(context).colorScheme.foreground,
    fontWeight: FontWeight.w600,
  );
  TextStyle get _mobileSectionDescriptionStyle =>
      ShadTheme.of(context).textTheme.muted.copyWith(color: ShadTheme.of(context).colorScheme.mutedForeground);

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
            final client = getMeshagentClient();
            if (_mcpOnly) {
              final discovered = await client.discoverMcpServiceTemplate(url: _url.toString());
              _template = jsonEncode(discovered.toJson());
              return discovered;
            }
            try {
              final res = await get(_url!);
              if (res.statusCode < 200 || res.statusCode >= 300) {
                throw Exception("Failed to download template URL: ${res.statusCode}");
              }
              _template = res.body;
              return await client.renderTemplate(template: res.body, values: {});
            } catch (_) {
              final discovered = await client.discoverMcpServiceTemplate(url: _url.toString());
              _template = jsonEncode(discovered.toJson());
              return discovered;
            }
          })
        : Resource<ServiceTemplateSpec?>(() async {
            final client = getMeshagentClient();

            return await client.renderTemplate(template: widget.template!, values: {});
          });

    _projects = Resource<List<Project>?>(() => fetchProjects());

    _rooms = Resource<List<Room>?>(() async {
      if (_projectId == null) {
        return null;
      }
      return await listMeshagentRooms(_projectId!);
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

  Future<void> _handleInstalled(BuildContext context, String serviceId) async {
    final projectId = _projectId!;
    final roomName = _roomName!;

    if (serviceId == powerboardsWebServerServiceId) {
      try {
        await powerboardsEnsureWebServerFolderExists(client: getMeshagentClient(), projectId: projectId, roomName: roomName);
      } catch (error) {
        if (context.mounted) {
          ShadToaster.of(context).show(
            powerboardsToast(
              title: 'Website installed',
              description: 'The service was installed, but the website folder could not be created: $error',
              destructive: true,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    }

    if (!context.mounted) {
      return;
    }

    if (widget.onInstalled != null) {
      widget.onInstalled!(context, projectId, roomName, serviceId);
    } else {
      context.go(powerboardsInstalledServiceRoute(projectId: projectId, roomName: roomName, serviceId: serviceId));
    }
  }

  Widget _backButton({required VoidCallback onPressed, String label = 'Back'}) {
    return ShadButton.outline(
      leading: _usesMobileFlowLayout ? const Icon(LucideIcons.arrowLeft) : null,
      onPressed: onPressed,
      child: Text(label),
    );
  }

  Widget _continueButton({required VoidCallback onPressed, String label = 'Continue'}) {
    return ShadButton(
      trailing: _usesMobileFlowLayout ? const Icon(LucideIcons.arrowRight) : null,
      onPressed: onPressed,
      child: Text(label),
    );
  }

  Widget _mobileBodyIntro({required String title, String? description}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: _mobileSectionTitleStyle),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(description, style: _mobileSectionDescriptionStyle),
        ],
      ],
    );
  }

  bool get _usesMobileFlowLayout => powerboardsUsesNativeMobileDialogLayout(context);

  void _publishDialogChrome(PowerboardsDialogChrome chrome) {
    final notifier = widget.mobileDialogChrome;
    if (notifier == null || _lastPublishedMobileChromeSignature == chrome.signature) {
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

  void _clearDialogChrome() {
    final notifier = widget.mobileDialogChrome;
    if (notifier == null || _lastPublishedMobileChromeSignature == 'none') {
      return;
    }

    _lastPublishedMobileChromeSignature = 'none';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      notifier.value = (signature: 'none', actions: const <Widget>[], onBack: null);
    });
  }

  void _publishDialogChromeForStep(_InstallerStep step) {
    if (widget.mobileDialogChrome == null) {
      _clearDialogChrome();
      return;
    }

    final specState = _spec.state;
    if (step != _InstallerStep.url && !specState.isReady) {
      _publishDialogChrome((
        signature: 'loading:$step',
        actions: const <Widget>[],
        onBack: _usesMobileFlowLayout && widget.template == null && widget.allowUrlEditing ? _backToUrlInput : null,
      ));
      return;
    }

    if (step != _InstallerStep.url && specState.value == null) {
      _publishDialogChrome((
        signature: 'error:$step',
        actions: !_usesMobileFlowLayout && widget.template == null && widget.allowUrlEditing
            ? [_backButton(onPressed: _backToUrlInput, label: "Change URL")]
            : const <Widget>[],
        onBack: _usesMobileFlowLayout && widget.template == null && widget.allowUrlEditing ? _backToUrlInput : null,
      ));
      return;
    }

    switch (step) {
      case _InstallerStep.url:
        _publishDialogChrome((signature: 'url', actions: [_continueButton(onPressed: _onUrlContinue)], onBack: null));
        return;
      case _InstallerStep.review:
        _publishDialogChrome((
          signature: 'review',
          actions: [
            if (!_usesMobileFlowLayout && widget.template == null && widget.allowUrlEditing)
              _backButton(onPressed: _backToUrlInput, label: "Change URL"),
            _continueButton(
              onPressed: () {
                setState(() {
                  _confirmed = true;
                });
              },
            ),
          ],
          onBack: _usesMobileFlowLayout && widget.template == null && widget.allowUrlEditing ? _backToUrlInput : null,
        ));
        return;
      case _InstallerStep.selectProject:
        _publishDialogChrome((
          signature: 'project',
          actions: !_usesMobileFlowLayout
              ? [
                  _backButton(
                    onPressed: () {
                      setState(() {
                        _confirmed = false;
                      });
                    },
                  ),
                ]
              : const <Widget>[],
          onBack: _usesMobileFlowLayout
              ? () {
                  setState(() {
                    _confirmed = false;
                  });
                }
              : null,
        ));
        return;
      case _InstallerStep.selectRoom:
        _publishDialogChrome((
          signature: 'room',
          actions: !_usesMobileFlowLayout
              ? [
                  _backButton(
                    onPressed: () {
                      setState(() {
                        _roomName = null;
                        _projectId = null;
                      });
                      _services.refresh();
                    },
                  ),
                ]
              : const <Widget>[],
          onBack: _usesMobileFlowLayout
              ? () {
                  setState(() {
                    _roomName = null;
                    _projectId = null;
                  });
                  _services.refresh();
                }
              : null,
        ));
        return;
      case _InstallerStep.confirm:
        final roomLabel = (_roomDisplayName?.trim().isNotEmpty ?? false) ? _roomDisplayName!.trim() : (_roomName ?? '').trim();
        _publishDialogChrome((
          signature: 'confirm:${Uri.encodeComponent(roomLabel)}',
          actions: const <Widget>[],
          onBack: _usesMobileFlowLayout
              ? () {
                  if (widget.initialRoomName != null) {
                    setState(() {
                      _confirmed = false;
                    });
                  } else {
                    setState(() {
                      _roomName = null;
                    });
                    _services.refresh();
                  }
                }
              : null,
        ));
        return;
    }
  }

  void _scheduleMobileConfirmPresentation() {
    if (_mobileConfirmPresentationPending || !_usesMobileFlowLayout) {
      return;
    }

    final spec = _spec.state.value;
    final template = _template;
    final projectId = _projectId;
    final roomName = _roomName;

    if (spec == null || template == null || projectId == null || roomName == null) {
      return;
    }

    _mobileConfirmPresentationPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _step != _InstallerStep.confirm) {
        _mobileConfirmPresentationPending = false;
        return;
      }

      final changed = await showPowerboardsFlowDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final roomLabel = (_roomDisplayName?.trim().isNotEmpty ?? false) ? _roomDisplayName!.trim() : roomName;
          return ConfigureServiceTemplateDialog(
            template: template,
            projectId: projectId,
            serviceId: _currentServiceForSpec()?.id,
            manifest: spec,
            roomName: roomName,
            prefilledVars: const <String, String>{},
            title: 'Install agent',
            description: _installConfirmDescription(dialogContext, roomLabel),
          );
        },
      );

      _mobileConfirmPresentationPending = false;

      if (!mounted) {
        return;
      }

      if (changed == true) {
        Navigator.of(context).pop(true);
        return;
      }

      setState(() {
        if (widget.initialRoomName != null) {
          _confirmed = false;
        } else {
          _roomName = null;
        }
      });

      _services.refresh();
    });
  }

  Widget _urlStep() {
    final title = _mcpOnly ? "Enter the URL of an MCP server" : "Enter the URL of an agent or MCP server";
    final description = _mcpOnly
        ? "The link must point to a valid MCP server URL."
        : "The link must point to a valid service template YAML or an MCP server URL.";
    final usesMobileFlowLayout = _usesMobileFlowLayout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: usesMobileFlowLayout ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (usesMobileFlowLayout) _mobileBodyIntro(title: title, description: description),
        if (usesMobileFlowLayout) const SizedBox(height: _mobileInstallFlowSectionGap),
        PowerboardsAdaptiveInput(
          controller: _urlController,
          placeholder: const Text("https://mcp.notion.com/mcp"),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          mobileFlowDialogInset: usesMobileFlowLayout,
          mobileFlowDialogInsetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          onSubmitted: (_) => _onUrlContinue(),
        ),
        if (_urlError != null) ...[const SizedBox(height: 12), ShadAlert.destructive(description: Text(_urlError!))],
      ],
    );
  }

  Widget _specError(String message) {
    final subject = _mcpOnly ? "MCP service" : "agent";
    final usesMobileFlowLayout = _usesMobileFlowLayout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: usesMobileFlowLayout ? MainAxisSize.min : MainAxisSize.max,
      spacing: 16,
      children: [
        Text("Unable to load $subject spec", style: _labelStyle, textAlign: TextAlign.center),
        ShadAlert.destructive(description: Text(message)),
      ],
    );
  }

  Widget _loadingStep() {
    final theme = ShadTheme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _usesMobileFlowLayout ? 12 : 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Loading agent details", style: _labelStyle, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            "Preparing agent details for the next step.",
            textAlign: TextAlign.center,
            style: theme.textTheme.muted.copyWith(color: theme.colorScheme.mutedForeground),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3.5)),
          ),
        ],
      ),
    );
  }

  Widget _reviewStep() {
    final usesMobileFlowLayout = _usesMobileFlowLayout;
    final displaySpec = powerboardsDisplayServiceTemplateSpec(_spec.state.value!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: usesMobileFlowLayout ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (usesMobileFlowLayout)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              PowerboardsServiceNameCard(manifest: displaySpec),
              const SizedBox(height: _mobileInstallFlowSectionGap),
              dev.ServiceInfoCard(manifest: displaySpec),
            ],
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 15),
              children: [
                PowerboardsServiceNameCard(manifest: displaySpec),
                const SizedBox(height: _desktopInstallDialogCardBodyGap),
                dev.ServiceInfoCard(manifest: displaySpec, desktopContentGroupGap: 24),
              ],
            ),
          ),
      ],
    );
  }

  Widget _projectStep() {
    final usesMobileFlowLayout = _usesMobileFlowLayout;
    final state = _projects.state;

    Widget body;
    if (state.hasError && !state.isRefreshing) {
      body = Center(child: ShadAlert.destructive(description: Text('Failed to load projects: ${state.error}')));
    } else if (!state.isReady) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final list = state.value ?? const <Project>[];
      final children = <Widget>[
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
              ShadToaster.of(context).show(powerboardsToast(title: 'Create project failed', description: '$e', destructive: true));
            }
          },
          leading: const Icon(LucideIcons.plus, size: 16),
          child: const Text("New Project"),
        ),
      ];

      body = usesMobileFlowLayout
          ? Padding(
              padding: const EdgeInsets.all(15),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
            )
          : ListView(padding: const EdgeInsets.only(bottom: 15), children: children);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: usesMobileFlowLayout ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (usesMobileFlowLayout)
          _mobileBodyIntro(
            title: 'Choose a project',
            description: _mcpOnly ? 'Select where this MCP service should be added.' : 'Select where this agent should be installed.',
          )
        else ...[
          Text(
            _mcpOnly ? "Select a project to add this MCP service to" : "Select a project to install this agent into",
            style: _labelStyle,
            textAlign: TextAlign.center,
          ),
          ShadSeparator.horizontal(margin: EdgeInsets.zero),
        ],
        if (usesMobileFlowLayout) body else Expanded(child: body),
      ],
    );
  }

  String? _roomDisplayName;

  Widget _roomStep() {
    final usesMobileFlowLayout = _usesMobileFlowLayout;
    final state = _rooms.state;

    Widget body;
    if (state.hasError && !state.isRefreshing) {
      body = Center(child: ShadAlert.destructive(description: Text('Failed to load rooms: ${state.error}')));
    } else if (state.isRefreshing || !state.isReady) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final list = state.value ?? const <Room>[];
      final children = <Widget>[
        for (final room in list)
          ShadButton.ghost(
            onPressed: () {
              setState(() {
                _roomName = room.name;
                _roomDisplayName = room.metadata["displayName"];
              });
              _services.refresh();
            },
            child: Text(room.metadata["displayName"] ?? room.name),
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
              ShadToaster.of(context).show(powerboardsToast(title: 'Create room failed', description: '$e', destructive: true));
            }
          },
          leading: const Icon(LucideIcons.plus, size: 16),
          child: const Text("New Room"),
        ),
      ];

      body = usesMobileFlowLayout
          ? Padding(
              padding: const EdgeInsets.all(15),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
            )
          : ListView(padding: const EdgeInsets.only(bottom: 15), children: children);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: usesMobileFlowLayout ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (usesMobileFlowLayout)
          _mobileBodyIntro(
            title: 'Choose a room',
            description: _mcpOnly ? 'Pick a room for this MCP service.' : 'Pick a room for this agent.',
          )
        else ...[
          Text(
            _mcpOnly ? "Pick a room to add this MCP service to" : "Pick a room to install this agent into",
            style: _labelStyle,
            textAlign: TextAlign.center,
          ),
          ShadSeparator.horizontal(margin: EdgeInsets.zero),
        ],
        if (usesMobileFlowLayout) body else Expanded(child: body),
      ],
    );
  }

  Widget _confirmStep() {
    final usesMobileFlowLayout = _usesMobileFlowLayout;
    final servicesState = _services.state;

    if ((!servicesState.isReady || servicesState.isRefreshing) && !servicesState.hasError) {
      return const Center(child: CircularProgressIndicator());
    }

    final existingService = _currentServiceForSpec();
    final existingServiceId = existingService?.id;
    final displaySpec = powerboardsDisplayServiceTemplateSpec(_spec.state.value!);

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
      mainAxisSize: usesMobileFlowLayout ? MainAxisSize.min : MainAxisSize.max,
      spacing: 16,
      children: [
        if (usesMobileFlowLayout)
          ConfigureServiceTemplate(
            template: _template!,
            header: [
              Text(
                _mcpOnly
                    ? "Confirm and Add to ${_roomName ?? _roomDisplayName}"
                    : "Confirm and Install into ${_roomName ?? _roomDisplayName}",
                style: _labelStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: _mobileInstallFlowSectionGap),
              PowerboardsServiceNameCard(manifest: displaySpec),
            ],
            serviceId: existingServiceId,
            projectId: _projectId!,
            roomName: _roomName,
            manifest: _spec.state.value!,
            prefilledVars: prefill,
            onDone: _handleInstalled,
            mobileDialogChrome: widget.mobileDialogChrome,
            mobileOnBack: () {
              if (widget.initialRoomName != null) {
                setState(() {
                  _confirmed = false;
                });
              } else {
                setState(() {
                  _roomName = null;
                });
                _services.refresh();
              }
            },
          )
        else
          Expanded(
            child: ConfigureServiceTemplate(
              template: _template!,
              header: [PowerboardsServiceNameCard(manifest: displaySpec)],
              serviceId: existingServiceId,
              projectId: _projectId!,
              roomName: _roomName,
              manifest: _spec.state.value!,
              prefilledVars: prefill,
              onDone: _handleInstalled,
              mobileDialogChrome: widget.mobileDialogChrome,
              dialogChromeSignaturePrefix:
                  'confirm:${Uri.encodeComponent((_roomDisplayName?.trim().isNotEmpty ?? false) ? _roomDisplayName!.trim() : (_roomName ?? '').trim())}|',
              customActions: [
                _backButton(
                  onPressed: () {
                    if (widget.initialRoomName != null) {
                      setState(() {
                        _confirmed = false;
                      });
                    } else {
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
        _publishDialogChromeForStep(step);

        if (step != _InstallerStep.url) {
          if (!_spec.state.isReady) {
            if (_spec.state.hasError && !_spec.state.isRefreshing) {
              return _specError("${_spec.state.error}");
            }
            return _usesMobileFlowLayout ? _loadingStep() : const Center(child: CircularProgressIndicator());
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
            if (_usesMobileFlowLayout) {
              _scheduleMobileConfirmPresentation();
              return const Center(child: CircularProgressIndicator());
            }
            return _confirmStep();
        }
      },
    );
  }
}

class _InstallServiceUrlDialog extends StatefulWidget {
  const _InstallServiceUrlDialog({required this.type, required this.projectId, required this.roomName, this.onInstalled});

  final ServiceType type;
  final String projectId;
  final String? roomName;
  final void Function(BuildContext context, String projectId, String roomName, String serviceId)? onInstalled;

  @override
  State<_InstallServiceUrlDialog> createState() => _InstallServiceUrlDialogState();
}

class _InstallServiceUrlDialogState extends State<_InstallServiceUrlDialog> {
  late final TextEditingController _urlController;
  String? _urlError;

  bool get _mcpOnly => widget.type == ServiceType.mcp;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
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
    });

    final changed = await showPowerboardsFlowDialog<bool>(
      context: context,
      builder: (_) => InstallServiceDialog(
        initialUrl: uri,
        allowUrlEditing: false,
        type: widget.type,
        projectId: widget.projectId,
        roomName: widget.roomName,
        onInstalled: widget.onInstalled,
      ),
    );

    if (!mounted || changed != true) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final description = _mcpOnly
        ? "The link must point to a valid MCP server URL."
        : "The link must point to a valid service template YAML or an MCP server URL.";

    return PowerboardsShadDialog(
      scrollable: false,
      expandDesktopActions: true,
      stackActionsOnMobile: true,
      gap: powerboardsUsesNativeMobileDialogLayout(context) ? 8 : null,
      padding: powerboardsUsesNativeMobileDialogLayout(context) ? powerboardsMobileFlowDialogCompactPadding : null,
      mobilePresentation: PowerboardsDialogMobilePresentation.flowSheet,
      mobileFlowBodyBehavior: PowerboardsDialogMobileFlowBodyBehavior.formScrollable,
      mobileKeyboardBehavior: PowerboardsDialogMobileKeyboardBehavior.avoid,
      mobileKeyboardInsetScale: 1.0,
      mobileHideActionsWhenKeyboardVisible: false,
      title: Text(widget.type == ServiceType.mcp ? "Add MCP service" : "Install"),
      description: Text(description),
      actions: [ShadButton(onPressed: _continue, child: const Text('Continue'))],
      child: powerboardsUsesNativeMobileDialogLayout(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                PowerboardsAdaptiveInput(
                  controller: _urlController,
                  placeholder: const Text("https://mcp.notion.com/mcp"),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                  mobileFlowDialogInset: powerboardsUsesNativeMobileDialogLayout(context),
                  mobileFlowDialogInsetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  onSubmitted: (_) => _continue(),
                ),
                if (_urlError != null) ...[const SizedBox(height: 12), ShadAlert.destructive(description: Text(_urlError!))],
              ],
            )
          : _desktopInstallDialogBodyViewport(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PowerboardsAdaptiveInput(
                    controller: _urlController,
                    placeholder: const Text("https://mcp.notion.com/mcp"),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                    mobileFlowDialogInset: false,
                    mobileFlowDialogInsetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    onSubmitted: (_) => _continue(),
                  ),
                  if (_urlError != null) ...[const SizedBox(height: 12), ShadAlert.destructive(description: Text(_urlError!))],
                ],
              ),
            ),
    );
  }
}
