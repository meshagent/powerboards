import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:meshagent/agent.dart';
import 'package:meshagent/client.dart' as meshagent_client;
import 'package:meshagent/protocol.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_flutter_dev/meshagent_flutter_dev.dart' as dev;
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_svg_icon.dart';
import 'package:powerboards/meshagent/route_service_match.dart';
import 'package:powerboards/settings/ui_mode.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:powerboards/ui/powerboards_toasts.dart';

import 'package:powerboards/meshagent/meshagent.dart';

typedef ConfigureServiceTemplateDone = void Function(BuildContext context, String serviceId);

const double _mobileConfigureFlowSectionGap = powerboardsMobileFlowDialogContentSectionGap * 3;
const String powerboardsWebServerServiceId = 'meshagent.webserver';
const String powerboardsPublishedWebsiteServiceId = 'meshagent.published-website';
const String powerboardsWebServerIconAssetName = 'folder-code';
const String powerboardsWebServerFolderName = 'website';
const String powerboardsStorageFolderPlaceholderFileName = '.placeholder';
const String powerboardsWebServerDescription = "Preview this room's website from live files in its website folder.";
const int powerboardsV1WebServerRemovalStableObservations = 8;
const int powerboardsV1WebServerRemovalMaxAttempts = 40;

class PowerboardsWebServerResourceRemoval {
  const PowerboardsWebServerResourceRemoval({required this.wasInstalled, required this.removedDomains});

  final bool wasInstalled;
  final List<String> removedDomains;
}

Future<void> powerboardsDeleteRoutesThenService<T>({
  required Iterable<T> routes,
  required Future<void> Function(T route) deleteRoute,
  required Future<void> Function() deleteService,
  Future<bool> Function()? observeServiceDeleted,
}) async {
  for (final route in routes) {
    await deleteRoute(route);
  }
  await deleteService();
  final serviceDeleted = await observeServiceDeleted?.call();
  if (serviceDeleted == false) {
    throw StateError('The service deletion did not converge. Refresh and try again.');
  }
}

Future<bool> powerboardsWaitForRoomServiceRemoval({
  required String serviceKindId,
  required Future<Iterable<ServiceSpec>> Function() loadServices,
  Iterable<String> routeDomains = const <String>[],
  Future<Iterable<String>> Function()? loadRouteDomains,
  int maxAttempts = 20,
  int requiredConsecutiveAbsentObservations = 1,
  Duration retryDelay = const Duration(milliseconds: 250),
  Future<void> Function(Duration delay) wait = Future<void>.delayed,
}) async {
  final normalizedServiceKindId = serviceKindId.trim();
  final normalizedRouteDomains = routeDomains.map((domain) => domain.trim()).where((domain) => domain.isNotEmpty).toSet();
  if (normalizedServiceKindId.isEmpty ||
      maxAttempts <= 0 ||
      requiredConsecutiveAbsentObservations <= 0 ||
      requiredConsecutiveAbsentObservations > maxAttempts) {
    return false;
  }

  var consecutiveAbsentObservations = 0;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      final services = await loadServices();
      final stillPresent = services.any(
        (service) =>
            service.id?.trim() == normalizedServiceKindId ||
            service.metadata.annotations['meshagent.service.id']?.trim() == normalizedServiceKindId,
      );
      var routeStillPresent = false;
      if (normalizedRouteDomains.isNotEmpty && loadRouteDomains != null) {
        final currentRouteDomains = (await loadRouteDomains()).map((domain) => domain.trim()).toSet();
        routeStillPresent = normalizedRouteDomains.any(currentRouteDomains.contains);
      }
      if (!stillPresent && !routeStillPresent) {
        consecutiveAbsentObservations += 1;
        if (consecutiveAbsentObservations >= requiredConsecutiveAbsentObservations) {
          return true;
        }
      } else {
        consecutiveAbsentObservations = 0;
      }
    } catch (_) {
      return false;
    }

    if (attempt + 1 < maxAttempts) {
      await wait(retryDelay);
    }
  }
  return false;
}

Future<PowerboardsWebServerResourceRemoval> powerboardsUninstallV1WebServerResources({
  required meshagent_client.Meshagent client,
  required String projectId,
  required String roomName,
  String? serviceInstanceId,
}) async {
  final normalizedProjectId = projectId.trim();
  final normalizedRoomName = roomName.trim();
  if (normalizedProjectId.isEmpty || normalizedRoomName.isEmpty) {
    throw StateError('Web server room context is not available.');
  }

  final normalizedServiceInstanceId = serviceInstanceId?.trim();
  final services = await client.listRoomServices(projectId: normalizedProjectId, roomName: normalizedRoomName);
  ServiceSpec? webServer;
  ServiceSpec? firstWebServer;
  for (final service in services) {
    if (service.metadata.annotations['meshagent.service.id'] != powerboardsWebServerServiceId) {
      continue;
    }
    firstWebServer ??= service;
    if (normalizedServiceInstanceId == null || normalizedServiceInstanceId.isEmpty || service.id?.trim() == normalizedServiceInstanceId) {
      webServer = service;
      break;
    }
  }
  webServer ??= firstWebServer;
  if (webServer == null) {
    return const PowerboardsWebServerResourceRemoval(wasInstalled: false, removedDomains: <String>[]);
  }

  final serviceId = webServer.id?.trim();
  if (serviceId == null || serviceId.isEmpty) {
    throw StateError('The Web server service is missing its service id.');
  }

  final roomRoutes = await client.listRoomRoutes(projectId: normalizedProjectId, roomName: normalizedRoomName);
  final matchedRoutes = routesForService(routes: roomRoutes, service: webServer);
  final removedDomains = matchedRoutes.map((route) => route.domain.trim()).where((domain) => domain.isNotEmpty).toList(growable: false);

  await powerboardsDeleteRoutesThenService(
    routes: matchedRoutes,
    deleteRoute: (route) => client.deleteRoute(projectId: normalizedProjectId, domain: route.domain),
    deleteService: () => client.deleteRoomService(projectId: normalizedProjectId, serviceId: serviceId, roomName: normalizedRoomName),
    observeServiceDeleted: () {
      return powerboardsWaitForRoomServiceRemoval(
        serviceKindId: powerboardsWebServerServiceId,
        loadServices: () => client.listRoomServices(projectId: normalizedProjectId, roomName: normalizedRoomName),
        routeDomains: removedDomains,
        loadRouteDomains: () async {
          return (await client.listRoomRoutes(projectId: normalizedProjectId, roomName: normalizedRoomName)).map((route) => route.domain);
        },
        maxAttempts: powerboardsV1WebServerRemovalMaxAttempts,
        requiredConsecutiveAbsentObservations: powerboardsV1WebServerRemovalStableObservations,
      );
    },
  );

  return PowerboardsWebServerResourceRemoval(wasInstalled: true, removedDomains: removedDomains);
}

Future<bool> _powerboardsFolderIsEmptyOrPlaceholderOnly(StorageClient storage, String folderName) async {
  final entries = await storage.list(folderName);
  if (entries.isEmpty) {
    return true;
  }
  return entries.length == 1 && !entries.single.isFolder && entries.single.name == powerboardsStorageFolderPlaceholderFileName;
}

List<String> _powerboardsWebServerConfiguredDomains({List<String>? configuredDomains}) {
  final rawDomains = configuredDomains ?? MeshagentConfig.current?.domains ?? const <String>[];
  return [
    for (final domain in rawDomains)
      if (domain.trim().isNotEmpty) domain.trim(),
  ];
}

String powerboardsWebServerDisplayHost(String rawValue, {String fallback = powerboardsWebServerFolderName}) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) {
    return fallback;
  }

  final parsed = Uri.tryParse(trimmed.contains('://') ? trimmed : 'https://$trimmed');
  final host = parsed?.host.trim();
  if (host != null && host.isNotEmpty) {
    return host;
  }

  return trimmed;
}

Uri? powerboardsWebServerSiteUri(String rawValue) {
  final normalized = powerboardsWebServerDisplayHost(rawValue, fallback: '').trim();
  if (normalized.isEmpty) {
    return null;
  }

  return Uri.tryParse(normalized.contains('://') ? normalized : 'https://$normalized');
}

String? powerboardsWebServerRelativePath(String rawPath) {
  final normalized = rawPath.trim().replaceAll('\\', '/');
  if (normalized.isEmpty || normalized == powerboardsWebServerFolderName) {
    return null;
  }

  const prefix = '$powerboardsWebServerFolderName/';
  if (normalized.startsWith(prefix)) {
    final relative = normalized.substring(prefix.length).trim();
    return relative.isEmpty ? null : relative;
  }

  return normalized;
}

Uri? powerboardsWebServerEntryUri({required Uri? siteUri, required String? entryPath}) {
  if (siteUri == null) {
    return null;
  }

  final relativePath = entryPath == null ? null : powerboardsWebServerRelativePath(entryPath);
  if (relativePath == null || relativePath.isEmpty) {
    return siteUri;
  }

  final basePath = siteUri.path.isEmpty
      ? '/'
      : siteUri.path.endsWith('/')
      ? siteUri.path
      : '${siteUri.path}/';
  return siteUri.replace(path: basePath).resolve(relativePath);
}

String? powerboardsWebServerDomainSuffix(String host, {List<String>? configuredDomains}) {
  final normalizedHost = powerboardsWebServerDisplayHost(host, fallback: '').trim();
  if (normalizedHost.isEmpty) {
    return null;
  }

  final domains = _powerboardsWebServerConfiguredDomains(configuredDomains: configuredDomains)
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final domain in domains) {
    if (normalizedHost == domain || normalizedHost.endsWith('.$domain')) {
      return domain;
    }
  }

  final parts = normalizedHost.split('.');
  if (parts.length > 1) {
    return parts.skip(1).join('.');
  }

  return null;
}

String powerboardsWebServerSlugFromValue(
  String rawValue, {
  List<String>? configuredDomains,
  String fallback = powerboardsWebServerFolderName,
}) {
  final host = powerboardsWebServerDisplayHost(rawValue, fallback: fallback);
  final suffix = powerboardsWebServerDomainSuffix(host, configuredDomains: configuredDomains);
  if (suffix == null || suffix.isEmpty) {
    return host;
  }

  if (host == suffix) {
    return fallback;
  }

  final suffixWithDot = '.$suffix';
  if (host.endsWith(suffixWithDot)) {
    final slug = host.substring(0, host.length - suffixWithDot.length).trim();
    return slug.isEmpty ? fallback : slug;
  }

  return host;
}

String powerboardsArchivedWebServerFolderName(String rawValue, {String fallback = powerboardsWebServerFolderName}) {
  final host = powerboardsWebServerDisplayHost(rawValue, fallback: fallback).trim();
  final name = host.isEmpty ? fallback : host;
  return name.replaceAll(RegExp(r'[\\/]'), '-');
}

String powerboardsWebServerDomainFromSlug(String slug, {String? currentValue, List<String>? configuredDomains}) {
  final normalizedSlug = slug.trim().toLowerCase();
  final currentHost = currentValue == null ? '' : powerboardsWebServerDisplayHost(currentValue, fallback: '');
  final configured = _powerboardsWebServerConfiguredDomains(configuredDomains: configuredDomains);
  final suffix =
      powerboardsWebServerDomainSuffix(currentHost, configuredDomains: configuredDomains) ?? (configured.isEmpty ? null : configured.first);
  if (suffix == null || suffix.isEmpty) {
    return normalizedSlug;
  }

  return '$normalizedSlug.$suffix';
}

Future<String?> powerboardsPreserveFormerWebServerFolder({
  required meshagent_client.Meshagent client,
  required String projectId,
  required String roomName,
  required String preferredName,
}) async {
  final normalizedPreferredName = preferredName.trim().replaceAll(RegExp(r'[\\/]'), '-');
  final baseName = normalizedPreferredName.isEmpty ? powerboardsWebServerFolderName : normalizedPreferredName;
  final roomConnection = await client.connectRoom(projectId: projectId, roomName: roomName);
  final roomClient = RoomClient(
    protocolFactory: WebSocketClientProtocol.createFactory(url: roomConnection.roomUrl, token: roomConnection.jwt),
  );

  try {
    roomClient.start();
    await roomClient.ready;
    return powerboardsPreserveFormerWebServerFolderInStorage(roomClient.storage, preferredName: baseName);
  } finally {
    roomClient.dispose();
  }
}

Future<String?> powerboardsPreserveFormerWebServerFolderInStorage(StorageClient storage, {required String preferredName}) async {
  final normalizedPreferredName = preferredName.trim().replaceAll(RegExp(r'[\\/]'), '-');
  final baseName = normalizedPreferredName.isEmpty ? powerboardsWebServerFolderName : normalizedPreferredName;
  if (!await storage.exists(powerboardsWebServerFolderName)) {
    return null;
  }

  if (baseName != powerboardsWebServerFolderName &&
      await storage.exists(baseName) &&
      await _powerboardsFolderIsEmptyOrPlaceholderOnly(storage, powerboardsWebServerFolderName)) {
    await storage.delete(powerboardsWebServerFolderName, recursive: true);
    return baseName;
  }

  var candidate = baseName;
  var suffix = 2;
  while (candidate != powerboardsWebServerFolderName && await storage.exists(candidate)) {
    candidate = '$baseName $suffix';
    suffix += 1;
  }

  if (candidate == powerboardsWebServerFolderName) {
    return candidate;
  }

  await storage.move(powerboardsWebServerFolderName, candidate);
  return candidate;
}

Future<String> powerboardsRestoreArchivedWebServerFolder({
  required meshagent_client.Meshagent client,
  required String projectId,
  required String roomName,
  required String archivedFolderName,
}) async {
  final normalizedArchivedFolderName = archivedFolderName.trim().replaceAll(RegExp(r'[\\/]'), '-');
  final sourceFolderName = normalizedArchivedFolderName.isEmpty ? powerboardsWebServerFolderName : normalizedArchivedFolderName;
  final roomConnection = await client.connectRoom(projectId: projectId, roomName: roomName);
  final roomClient = RoomClient(
    protocolFactory: WebSocketClientProtocol.createFactory(url: roomConnection.roomUrl, token: roomConnection.jwt),
  );

  try {
    roomClient.start();
    await roomClient.ready;

    if (sourceFolderName != powerboardsWebServerFolderName && await roomClient.storage.exists(sourceFolderName)) {
      if (await roomClient.storage.exists(powerboardsWebServerFolderName)) {
        if (!await _powerboardsFolderIsEmptyOrPlaceholderOnly(roomClient.storage, powerboardsWebServerFolderName)) {
          return powerboardsWebServerFolderName;
        }
        await roomClient.storage.delete(powerboardsWebServerFolderName, recursive: true);
      }
      await roomClient.storage.move(sourceFolderName, powerboardsWebServerFolderName);
    }

    if (!await roomClient.storage.exists(powerboardsWebServerFolderName)) {
      await roomClient.storage.uploadStream(
        '$powerboardsWebServerFolderName/$powerboardsStorageFolderPlaceholderFileName',
        Stream<Uint8List>.value(Uint8List(0)),
        overwrite: true,
        size: 0,
      );
    }

    return powerboardsWebServerFolderName;
  } finally {
    roomClient.dispose();
  }
}

Future<String> powerboardsPrepareWebServerFolderForDomain({
  required meshagent_client.Meshagent client,
  required String projectId,
  required String roomName,
  required String? domain,
}) {
  return powerboardsRestoreArchivedWebServerFolder(
    client: client,
    projectId: projectId,
    roomName: roomName,
    archivedFolderName: powerboardsArchivedWebServerFolderName(domain ?? ''),
  );
}

Future<T> powerboardsSaveServiceAfterPreparingWebServerFolder<T>({
  required bool isWebServer,
  required Future<void> Function() prepareWebServerFolder,
  required Future<T> Function() saveService,
}) async {
  if (isWebServer) {
    await prepareWebServerFolder();
  }
  return saveService();
}

Future<void> powerboardsEnsureWebServerFolderExists({
  required meshagent_client.Meshagent client,
  required String projectId,
  required String roomName,
}) async {
  final roomConnection = await client.connectRoom(projectId: projectId, roomName: roomName);
  final roomClient = RoomClient(
    protocolFactory: WebSocketClientProtocol.createFactory(url: roomConnection.roomUrl, token: roomConnection.jwt),
  );

  try {
    roomClient.start();
    await roomClient.ready;

    if (await roomClient.storage.exists(powerboardsWebServerFolderName)) {
      return;
    }

    await roomClient.storage.uploadStream(
      '$powerboardsWebServerFolderName/$powerboardsStorageFolderPlaceholderFileName',
      Stream<Uint8List>.value(Uint8List(0)),
      overwrite: true,
      size: 0,
    );
  } finally {
    roomClient.dispose();
  }
}

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

String? powerboardsDisplayServiceDescription({String? serviceId, String? description, bool enableV1WebServerPresentation = false}) {
  final normalizedServiceId = serviceId?.trim() ?? '';
  if (enableV1WebServerPresentation && normalizedServiceId == powerboardsWebServerServiceId) {
    return powerboardsWebServerDescription;
  }

  final trimmedDescription = description?.trim();
  if (trimmedDescription == null || trimmedDescription.isEmpty) {
    return null;
  }

  return trimmedDescription;
}

String? powerboardsDisplayServiceDescriptionForService(ServiceSpec service, {bool enableV1WebServerPresentation = false}) {
  return powerboardsDisplayServiceDescription(
    serviceId: service.metadata.annotations['meshagent.service.id'],
    description: service.metadata.description,
    enableV1WebServerPresentation: enableV1WebServerPresentation,
  );
}

String? powerboardsDisplayServiceDescriptionForTemplate(ServiceTemplateSpec template, {bool enableV1WebServerPresentation = false}) {
  return powerboardsDisplayServiceDescription(
    serviceId: template.metadata.annotations['meshagent.service.id'],
    description: template.metadata.description,
    enableV1WebServerPresentation: enableV1WebServerPresentation,
  );
}

ServiceTemplateSpec powerboardsDisplayServiceTemplateSpec(ServiceTemplateSpec manifest, {bool enableV1WebServerPresentation = false}) {
  return ServiceTemplateSpec(
    version: manifest.version,
    kind: manifest.kind,
    variables: manifest.variables,
    metadata: ServiceTemplateMetadata(
      name: powerboardsDisplayServiceName(manifest.metadata.name),
      description: powerboardsDisplayServiceDescriptionForTemplate(manifest, enableV1WebServerPresentation: enableV1WebServerPresentation),
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

String? powerboardsServiceIconAssetName({ServiceSpec? service, ServiceTemplateSpec? template, bool enableV1WebServerPresentation = false}) {
  if (!enableV1WebServerPresentation) {
    return null;
  }

  final agentTypeIconAssetName = service == null
      ? (template == null ? null : serviceTemplateIconAssetName(template))
      : serviceIconAssetName(service);
  if (agentTypeIconAssetName != null) {
    return agentTypeIconAssetName;
  }

  final serviceId =
      service?.metadata.annotations['meshagent.service.id']?.trim() ?? template?.metadata.annotations['meshagent.service.id']?.trim() ?? '';
  if (serviceId == powerboardsWebServerServiceId) {
    return powerboardsWebServerIconAssetName;
  }

  return null;
}

class PowerboardsServiceNameCard extends StatelessWidget {
  const PowerboardsServiceNameCard({super.key, required this.manifest});

  final ServiceTemplateSpec manifest;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final descriptionStyle = powerboardsAgentCardDescriptionTextStyle(context);
    final titleStyle = powerboardsAgentCardTitleTextStyle(context);
    final enableV1WebServerPresentation = powerboardsUsesDesktopUiPreview(context);
    final iconAssetName = powerboardsServiceIconAssetName(template: manifest, enableV1WebServerPresentation: enableV1WebServerPresentation);
    final useV1VoiceIcon =
        !powerboardsUsesNativeMobileDialogLayout(context) &&
        powerboardsUsesDesktopUiPreview(context) &&
        serviceTemplateUsesVoiceAgent(manifest);

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
            child: iconAssetName != null
                ? PbSvgIcon(assetName: iconAssetName, size: 22, color: theme.colorScheme.background)
                : useV1VoiceIcon
                ? PbSvgIcon(assetName: 'audio-lines', size: 22, color: theme.colorScheme.background)
                : Icon(LucideIcons.bot, color: theme.colorScheme.background, size: 22),
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
    this.showServiceHeader = true,
    this.showUninstallAction = true,
    this.primaryActionLabel,
    this.primaryProgressLabel,
  });

  final String template;
  final Map<String, String>? prefilledVars;
  final String projectId;
  final String? serviceId;
  final ServiceTemplateSpec manifest;
  final String? roomName;
  final String title;
  final Widget? description;
  final bool showServiceHeader;
  final bool showUninstallAction;
  final String? primaryActionLabel;
  final String? primaryProgressLabel;

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
    final displayManifest = powerboardsDisplayServiceTemplateSpec(
      widget.manifest,
      enableV1WebServerPresentation: powerboardsUsesDesktopUiPreview(context),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = powerboardsUsesNativeMobileDialogLayout(context);
        final header = <Widget>[
          if (widget.showServiceHeader) PowerboardsServiceNameCard(manifest: displayManifest),
          if (widget.showServiceHeader && !isInstalled && !isMobile) ...[
            SizedBox(height: isMobile ? _mobileConfigureFlowSectionGap : 12),
            dev.ServiceInfoCard(manifest: displayManifest, desktopContentGroupGap: isMobile ? null : 24),
          ],
        ];
        final content = ConfigureServiceTemplate(
          template: widget.template,
          header: header,
          projectId: widget.projectId,
          serviceId: widget.serviceId,
          manifest: widget.manifest,
          roomName: widget.roomName,
          prefilledVars: widget.prefilledVars,
          mobileDialogChrome: _mobileChrome,
          showUninstallAction: widget.showUninstallAction,
          primaryActionLabel: widget.primaryActionLabel,
          primaryProgressLabel: widget.primaryProgressLabel,
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
    this.showUninstallAction = true,
    this.primaryActionLabel,
    this.primaryProgressLabel,
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
  final bool showUninstallAction;
  final String? primaryActionLabel;
  final String? primaryProgressLabel;

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
    final enableV1WebServerFlow = powerboardsUsesDesktopUiPreview(context);

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

      final existingServiceRoutes = widget.serviceId == null
          ? const <meshagent_client.Route>[]
          : routesForService(
              routes: await client.listRoomRoutes(projectId: projectId, roomName: roomName),
              service: service,
            );
      final requestedRouteDomains = {for (final route in routeRequests) route.domain};

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

      final domain = routeRequests.isEmpty ? null : routeRequests.first.domain;
      final savedService = await powerboardsSaveServiceAfterPreparingWebServerFolder(
        isWebServer: enableV1WebServerFlow && serviceId == powerboardsWebServerServiceId,
        prepareWebServerFolder: () async {
          // Restore archived files before the container can create a fresh empty website folder.
          await powerboardsPrepareWebServerFolderForDomain(client: client, projectId: projectId, roomName: roomName, domain: domain);
        },
        saveService: () => widget.serviceId != null
            ? client.updateRoomServiceFromTemplate(
                projectId: projectId,
                serviceId: widget.serviceId!,
                template: widget.template,
                values: vars,
                roomName: roomName,
              )
            : client.createRoomServiceFromTemplate(projectId: projectId, template: widget.template, values: vars, roomName: roomName),
      );

      for (final route in existingServiceRoutes) {
        if (requestedRouteDomains.contains(route.domain)) {
          continue;
        }
        await client.deleteRoute(projectId: projectId, domain: route.domain);
      }

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
              powerboardsToast(
                title: 'Unable to check for existing scheduled tasks',
                description: 'You may not have permission to modify scheduled tasks.',
                destructive: true,
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
      final serviceKindId = widget.manifest.metadata.annotations['meshagent.service.id']?.trim();
      final enableV1WebServerFlow = powerboardsUsesDesktopUiPreview(context);
      final preservedFolderName = enableV1WebServerFlow && serviceKindId == powerboardsWebServerServiceId
          ? powerboardsArchivedWebServerFolderName(widget.prefilledVars?['url'] ?? '')
          : null;

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

      if (preservedFolderName != null) {
        await powerboardsUninstallV1WebServerResources(
          client: client,
          projectId: widget.projectId,
          roomName: roomName,
          serviceInstanceId: serviceId,
        );
      } else {
        await powerboardsDeleteRoutesThenService(
          routes: domainsToDelete,
          deleteRoute: (domain) => client.deleteRoute(projectId: widget.projectId, domain: domain.domain),
          deleteService: () => client.deleteRoomService(projectId: widget.projectId, serviceId: serviceId, roomName: roomName),
          observeServiceDeleted: () async {
            return powerboardsWaitForRoomServiceRemoval(
              serviceKindId: serviceKindId ?? serviceId,
              loadServices: () => client.listRoomServices(projectId: widget.projectId, roomName: roomName),
              routeDomains: domainsToDelete.map((route) => route.domain),
              loadRouteDomains: () async =>
                  (await client.listRoomRoutes(projectId: widget.projectId, roomName: roomName)).map((route) => route.domain),
            );
          },
        );
      }

      String? preservedFolderPath;
      if (preservedFolderName != null) {
        try {
          preservedFolderPath = await powerboardsPreserveFormerWebServerFolder(
            client: client,
            projectId: widget.projectId,
            roomName: roomName,
            preferredName: preservedFolderName,
          );
        } catch (_) {
          if (mounted) {
            ShadToaster.of(context).show(
              powerboardsToast(
                title: 'Website removed',
                description: 'The service was removed, but the website folder could not be renamed.',
                destructive: true,
              ),
            );
          }
        }
      }

      if (widget.manifest.agents.any((agent) => agent.annotations['meshagent.agent.schedule'] != null)) {
        try {
          await _deleteExistingTasks();
        } catch (_) {
          if (mounted) {
            ShadToaster.of(context).show(
              powerboardsToast(
                title: 'Unable to delete existing scheduled tasks',
                description: 'You may not have permission to modify scheduled tasks.',
                destructive: true,
              ),
            );
          }
        }
      }

      if (!mounted) {
        return;
      }
      if (preservedFolderPath != null && preservedFolderPath != powerboardsWebServerFolderName) {
        ShadToaster.of(
          context,
        ).show(powerboardsToast(title: 'Website removed', description: 'The website files were kept as folder `$preservedFolderPath`.'));
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
    final progressLabel = widget.primaryProgressLabel ?? (isInstalled ? 'Updating' : 'Installing');
    final primaryLabel = widget.primaryActionLabel ?? (isInstalled ? 'Update' : 'Install');

    return [
      if (isInstalled && widget.showUninstallAction)
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
        child: Text(_saving ? progressLabel : primaryLabel),
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
