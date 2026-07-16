import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:meshagent/agent.dart';
import 'package:meshagent/meshagent.dart' as meshagent;
import 'package:meshagent/room_server_client.dart';
import 'package:powerboards/meshagent/agent_config.dart';
import 'package:powerboards/meshagent/agent_containers.dart';
import 'package:powerboards/meshagent/meshagent.dart';

const String installWebServerServiceToolName = 'install_webserver_service';
const String listWebServerFilesToolName = 'list_webserver_files';
const String openWebServerFileToolName = 'open_webserver_file';
const String uninstallWebServerServiceToolName = 'uninstall_webserver_service';

const Map<String, dynamic> installWebServerServiceInputSchema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['site_name', 'domain', 'intent'],
  'properties': {
    'site_name': {'type': 'string', 'description': 'Optional short site name or slug. Use an empty string when omitted.'},
    'domain': {'type': 'string', 'description': 'Optional full domain for the website route. Use an empty string when omitted.'},
    'intent': {
      'type': 'string',
      'enum': ['install_only', 'create_website'],
      'description':
          'Use install_only when the user only asks to install or prepare hosting. Use create_website when the user asks to make, create, build, or edit a website.',
    },
  },
};

const Map<String, dynamic> installWebServerServiceOutputSchema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['status', 'service_id', 'folder_path', 'storage_path', 'site_label', 'entry_file_path', 'message', 'assistant_reply'],
  'properties': {
    'status': {
      'type': 'string',
      'enum': ['installed', 'already_installed', 'needs_input', 'blocked', 'failed'],
    },
    'service_id': {'type': 'string'},
    'folder_path': {'type': 'string'},
    'storage_path': {
      'type': 'string',
      'description': 'Room storage folder where website files must be written, including the trailing slash.',
    },
    'site_label': {'type': 'string'},
    'entry_file_path': {'type': 'string', 'description': 'Room storage path for the website entry file.'},
    'domain': {'type': 'string'},
    'public_url_status': {'type': 'string'},
    'message': {'type': 'string'},
    'assistant_reply': {'type': 'string'},
  },
};

const Map<String, dynamic> uninstallWebServerServiceInputSchema = {'type': 'object', 'additionalProperties': false, 'properties': {}};

const Map<String, dynamic> openWebServerFileInputSchema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['path'],
  'properties': {
    'path': {
      'type': 'string',
      'description': 'The requested file name or path relative to the webserver root, such as index.html or assets/logo.svg.',
    },
  },
};

const Map<String, dynamic> listWebServerFilesInputSchema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['path'],
  'properties': {
    'path': {
      'type': 'string',
      'description': 'Optional folder path relative to the webserver root. Use an empty string to list the webserver root.',
    },
  },
};

const Map<String, dynamic> listWebServerFilesOutputSchema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['status', 'folder_path', 'folder_link', 'entries', 'message', 'assistant_reply'],
  'properties': {
    'status': {
      'type': 'string',
      'enum': ['listed', 'not_installed', 'not_found', 'failed'],
    },
    'folder_path': {'type': 'string'},
    'folder_link': {'type': 'string'},
    'entries': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['name', 'path', 'type', 'link'],
        'properties': {
          'name': {'type': 'string'},
          'path': {'type': 'string'},
          'type': {
            'type': 'string',
            'enum': ['file', 'folder'],
          },
          'link': {'type': 'string'},
        },
      },
    },
    'message': {'type': 'string'},
    'assistant_reply': {'type': 'string'},
  },
};

const Map<String, dynamic> uninstallWebServerServiceOutputSchema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['status', 'folder_path', 'site_label', 'message', 'assistant_reply'],
  'properties': {
    'status': {
      'type': 'string',
      'enum': ['removed', 'not_installed', 'blocked', 'failed'],
    },
    'folder_path': {'type': 'string'},
    'site_label': {'type': 'string'},
    'preserved_folder_path': {'type': 'string'},
    'removed_domains': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'message': {'type': 'string'},
    'assistant_reply': {'type': 'string'},
  },
};

class InstallWebServerServiceRequest {
  const InstallWebServerServiceRequest({
    required this.projectId,
    required this.roomName,
    this.siteName,
    this.domain,
    this.intent = 'install_only',
  });

  final String projectId;
  final String roomName;
  final String? siteName;
  final String? domain;
  final String intent;
}

class InstallWebServerServiceResult {
  const InstallWebServerServiceResult({
    required this.status,
    required this.serviceId,
    required this.folderPath,
    required this.message,
    this.siteLabel,
    this.entryFilePath = '$powerboardsWebServerFolderName/index.html',
    this.publicUrlStatus = 'unknown',
    this.domain,
    this.intent = 'install_only',
  });

  final String status;
  final String serviceId;
  final String folderPath;
  final String? siteLabel;
  final String entryFilePath;
  final String publicUrlStatus;
  final String? domain;
  final String message;
  final String intent;

  Map<String, dynamic> toJson() {
    final normalizedFolderPath = folderPath.trim().isEmpty ? '$powerboardsWebServerFolderName/' : folderPath.trim();
    final normalizedDomain = domain?.trim();
    final normalizedSiteLabel = siteLabel?.trim();
    final resolvedSiteLabel = normalizedSiteLabel != null && normalizedSiteLabel.isNotEmpty
        ? normalizedSiteLabel
        : normalizedDomain != null && normalizedDomain.isNotEmpty
        ? normalizedDomain
        : normalizedFolderPath;
    return {
      'status': status,
      'service_id': serviceId,
      'folder_path': normalizedFolderPath,
      'storage_path': normalizedFolderPath,
      'site_label': resolvedSiteLabel,
      'entry_file_path': entryFilePath,
      if (normalizedDomain != null && normalizedDomain.isNotEmpty) 'domain': normalizedDomain,
      'public_url_status': publicUrlStatus,
      'message': message,
      'assistant_reply': _assistantReply(siteLabel: resolvedSiteLabel, domain: normalizedDomain, storagePath: normalizedFolderPath),
    };
  }

  String _assistantReply({required String siteLabel, required String? domain, required String storagePath}) {
    if (status == 'installed' || status == 'already_installed') {
      if (intent == 'create_website') {
        return [
          'I set up the webserver service for this room so we can publish the website here.',
          '',
          'What kind of website would you like to create?',
          '',
          'You can describe the site you want, or add your own files to the webserver folder. [Go to folder](powerboards://files/webserver)',
        ].join('\n');
      }
      return [
        'The web service has been successfully installed in this room.',
        '',
        'Your webserver URL',
        _webServerDomainLinkLine(domain, entryFilePath: entryFilePath),
        '- Location: [Go to files](powerboards://files/webserver)',
        '- Preview: [Open to view](powerboards://preview/webserver)',
        '',
        'Would you like to create or edit an HTML page or site?',
      ].join('\n');
    }
    return message;
  }
}

class UninstallWebServerServiceRequest {
  const UninstallWebServerServiceRequest({required this.projectId, required this.roomName});

  final String projectId;
  final String roomName;
}

class ListWebServerFilesRequest {
  const ListWebServerFilesRequest({required this.projectId, required this.roomName, required this.path});

  final String projectId;
  final String roomName;
  final String path;
}

class ListWebServerFilesEntry {
  const ListWebServerFilesEntry({required this.name, required this.path, required this.isFolder});

  final String name;
  final String path;
  final bool isFolder;

  String get link => isFolder ? powerboardsV1WebServerFolderLink(path) : powerboardsV1WebServerFileLink(path);

  Map<String, dynamic> toJson() => {'name': name, 'path': path, 'type': isFolder ? 'folder' : 'file', 'link': link};
}

class ListWebServerFilesResult {
  const ListWebServerFilesResult({required this.status, required this.folderPath, required this.entries, required this.message});

  final String status;
  final String folderPath;
  final List<ListWebServerFilesEntry> entries;
  final String message;

  Map<String, dynamic> toJson() {
    final folderLink = powerboardsV1WebServerFolderLink(folderPath);
    return {
      'status': status,
      'folder_path': folderPath,
      'folder_link': folderLink,
      'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
      'message': message,
      'assistant_reply': _assistantReply(folderLink),
    };
  }

  String _assistantReply(String folderLink) {
    if (status != 'listed') {
      return message;
    }
    if (entries.isEmpty) {
      return 'The [webserver folder]($folderLink) has no visible files.';
    }
    return [
      'Files in the [webserver folder]($folderLink):',
      '',
      for (final entry in entries) '- [${entry.name}](${entry.link})${entry.isFolder ? ' (folder)' : ''}',
    ].join('\n');
  }
}

class OpenWebServerFileRequest {
  const OpenWebServerFileRequest({required this.projectId, required this.roomName, required this.path});

  final String projectId;
  final String roomName;
  final String path;
}

class OpenWebServerFileResult {
  const OpenWebServerFileResult({required this.status, required this.path, required this.message});

  final String status;
  final String path;
  final String message;

  Map<String, dynamic> toJson() => {'status': status, 'path': path, 'message': message};
}

class UninstallWebServerServiceResult {
  const UninstallWebServerServiceResult({
    required this.status,
    required this.folderPath,
    required this.siteLabel,
    required this.message,
    this.preservedFolderPath,
    this.removedDomains = const <String>[],
  });

  final String status;
  final String folderPath;
  final String siteLabel;
  final String message;
  final String? preservedFolderPath;
  final List<String> removedDomains;

  Map<String, dynamic> toJson() {
    final normalizedPreservedFolderPath = preservedFolderPath?.trim();
    final displayedFolderPath = normalizedPreservedFolderPath == null || normalizedPreservedFolderPath.isEmpty
        ? siteLabel
        : normalizedPreservedFolderPath.replaceFirst(RegExp(r'/+$'), '');
    return {
      'status': status,
      'folder_path': folderPath,
      'site_label': siteLabel,
      if (normalizedPreservedFolderPath != null && normalizedPreservedFolderPath.isNotEmpty)
        'preserved_folder_path': normalizedPreservedFolderPath,
      'removed_domains': removedDomains,
      'message': message,
      'assistant_reply': status == 'removed'
          ? ['Removed the webserver service from this room.', '', 'Files were kept in Files at `$displayedFolderPath`.'].join('\n')
          : message,
    };
  }
}

typedef InstallWebServerServiceRunner = Future<InstallWebServerServiceResult> Function(InstallWebServerServiceRequest request);
typedef ListWebServerFilesRunner = Future<ListWebServerFilesResult> Function(ListWebServerFilesRequest request);
typedef OpenWebServerFileRunner = Future<OpenWebServerFileResult> Function(OpenWebServerFileRequest request);
typedef UninstallWebServerServiceRunner = Future<UninstallWebServerServiceResult> Function(UninstallWebServerServiceRequest request);

mixin _PowerboardsToolResponseSentCallback on FunctionTool implements ToolResponseSentListener {
  final Expando<FutureOr<void> Function()> _responseSentCallbacks = Expando<FutureOr<void> Function()>();

  void deferCallbackUntilResponseSent<T>(Content response, FutureOr<void> Function(T value)? callback, T value) {
    if (callback != null) {
      _responseSentCallbacks[response] = () => callback(value);
    }
  }

  @override
  Future<void> onToolResponseSent(ToolContext context, Content response) async {
    final callback = _responseSentCallbacks[response];
    _responseSentCallbacks[response] = null;
    if (callback != null) {
      await callback();
    }
  }
}

List<BaseTool> powerboardsWebServerTools({
  required String projectId,
  required String roomName,
  required bool enableV1WebServerTools,
  InstallWebServerServiceRunner install = installPowerboardsWebServerService,
  ListWebServerFilesRunner listFiles = listPowerboardsWebServerFiles,
  OpenWebServerFileRunner openFile = openPowerboardsWebServerFile,
  UninstallWebServerServiceRunner uninstall = uninstallPowerboardsWebServerService,
  FutureOr<void> Function(InstallWebServerServiceResult result)? onInstalled,
  FutureOr<void> Function(UninstallWebServerServiceResult result)? onUninstalled,
}) {
  if (!enableV1WebServerTools) {
    return const <BaseTool>[];
  }

  return [
    InstallWebServerServiceTool(projectId: projectId, roomName: roomName, install: install, onInstalled: onInstalled),
    ListWebServerFilesTool(projectId: projectId, roomName: roomName, listFiles: listFiles),
    OpenWebServerFileTool(projectId: projectId, roomName: roomName, openFile: openFile),
    UninstallWebServerServiceTool(projectId: projectId, roomName: roomName, uninstall: uninstall, onUninstalled: onUninstalled),
  ];
}

class InstallWebServerServiceToolkit extends Toolkit {
  InstallWebServerServiceToolkit({
    required String projectId,
    required String roomName,
    required bool enableV1WebServerTools,
    InstallWebServerServiceRunner install = installPowerboardsWebServerService,
    ListWebServerFilesRunner listFiles = listPowerboardsWebServerFiles,
    OpenWebServerFileRunner openFile = openPowerboardsWebServerFile,
    UninstallWebServerServiceRunner uninstall = uninstallPowerboardsWebServerService,
    FutureOr<void> Function(InstallWebServerServiceResult result)? onInstalled,
    FutureOr<void> Function(UninstallWebServerServiceResult result)? onUninstalled,
  }) : super(
         name: 'powerboards',
         title: 'PowerBoards actions',
         description: 'Product actions for the current PowerBoards room.',
         tools: powerboardsWebServerTools(
           projectId: projectId,
           roomName: roomName,
           enableV1WebServerTools: enableV1WebServerTools,
           install: install,
           listFiles: listFiles,
           openFile: openFile,
           uninstall: uninstall,
           onInstalled: onInstalled,
           onUninstalled: onUninstalled,
         ),
         rules: const [],
       );
}

class InstallWebServerServiceTool extends FunctionTool with _PowerboardsToolResponseSentCallback {
  InstallWebServerServiceTool({required this.projectId, required this.roomName, required this.install, this.onInstalled})
    : super(
        name: installWebServerServiceToolName,
        title: 'Install Web server service',
        description:
            'Install the PowerBoards Web server service in the current room and return storage_path, the writable room storage folder '
            'where the website files belong, plus entry_file_path for the main page. '
            'Use this when the user asks to install web hosting, install a web server service, create a web server, '
            'or prepare the room for a website. This is a PowerBoards product action, not a Linux package install. '
            'Do not use shell, apt, nginx, systemd, container-local ports, or private container URLs for this request. '
            'For install-only requests, send assistant_reply exactly once as the full user-facing response. Do not prepend, append, '
            'summarize, repeat, list service_id, or include implementation details unless the user asks for debugging details. '
            'Keep the powerboards:// links exactly as provided in assistant_reply so PowerBoards can open the Files folder and preview. '
            'This only installs website hosting; it does not create site files. If the user asked to create or edit a website and supplied enough '
            'details, use the room storage write_file tool to write files directly under storage_path after this tool succeeds. Do not end the turn '
            'after installation and do not ask the user to copy or upload files that can be written with the room storage tools.',
        inputSchema: installWebServerServiceInputSchema,
        outputSchema: installWebServerServiceOutputSchema,
      );

  final String projectId;
  final String roomName;
  final InstallWebServerServiceRunner install;
  final FutureOr<void> Function(InstallWebServerServiceResult result)? onInstalled;

  @override
  Future<Content> execute(ToolContext context, Map<String, dynamic> arguments) async {
    try {
      final result = await install(
        InstallWebServerServiceRequest(
          projectId: projectId,
          roomName: roomName,
          siteName: _trimmedOrNull(arguments['site_name']),
          domain: _trimmedOrNull(arguments['domain']),
          intent: _webServerInstallIntent(arguments['intent']),
        ),
      );

      final response = JsonContent(json: result.toJson());
      if (result.status == 'installed' || result.status == 'already_installed') {
        deferCallbackUntilResponseSent(response, onInstalled, result);
      }

      return response;
    } catch (error) {
      return JsonContent(
        json: InstallWebServerServiceResult(
          status: 'failed',
          serviceId: powerboardsWebServerServiceId,
          folderPath: '$powerboardsWebServerFolderName/',
          message: 'Unable to install the Web server service: $error',
          intent: _webServerInstallIntent(arguments['intent']),
        ).toJson(),
      );
    }
  }
}

class ListWebServerFilesTool extends FunctionTool {
  ListWebServerFilesTool({required this.projectId, required this.roomName, required this.listFiles})
    : super(
        name: listWebServerFilesToolName,
        title: 'List Web server files',
        description:
            'List the visible direct contents of the current room webserver folder using PowerBoards room storage. '
            'Use this when the user asks what files are in the webserver folder. Hidden entries, including .placeholder, are omitted. '
            'Use an empty path for the webserver root. When reporting success, send assistant_reply exactly once and keep its '
            'powerboards:// links unchanged so every listed file or folder remains clickable.',
        inputSchema: listWebServerFilesInputSchema,
        outputSchema: listWebServerFilesOutputSchema,
      );

  final String projectId;
  final String roomName;
  final ListWebServerFilesRunner listFiles;

  @override
  Future<Content> execute(ToolContext context, Map<String, dynamic> arguments) async {
    try {
      final result = await listFiles(
        ListWebServerFilesRequest(projectId: projectId, roomName: roomName, path: (arguments['path'] ?? '').toString()),
      );
      return JsonContent(json: result.toJson());
    } catch (error) {
      return JsonContent(
        json: ListWebServerFilesResult(
          status: 'failed',
          folderPath: powerboardsWebServerFolderName,
          entries: const <ListWebServerFilesEntry>[],
          message: 'Unable to list the webserver folder: $error',
        ).toJson(),
      );
    }
  }
}

class OpenWebServerFileTool extends FunctionTool {
  OpenWebServerFileTool({required this.projectId, required this.roomName, required this.openFile})
    : super(
        name: openWebServerFileToolName,
        title: 'Provide Web server file',
        description:
            'Find and provide a file from the current room webserver root. Use this when the user asks to find, get, open, show, attach, or provide '
            'a website file such as index.html. Pass the requested name or path relative to the webserver root. A successful result is displayed '
            'automatically as a clickable file attachment in chat; briefly confirm it is attached and do not replace it with a text-only path or link.',
        inputSchema: openWebServerFileInputSchema,
        outputSpec: ToolContentSpec(types: [ToolContentType.link, ToolContentType.json]),
      );

  final String projectId;
  final String roomName;
  final OpenWebServerFileRunner openFile;

  @override
  Future<Content> execute(ToolContext context, Map<String, dynamic> arguments) async {
    try {
      final result = await openFile(
        OpenWebServerFileRequest(projectId: projectId, roomName: roomName, path: (arguments['path'] ?? '').toString()),
      );
      if (result.status == 'opened') {
        final name = result.path.split('/').where((segment) => segment.isNotEmpty).last;
        return LinkContent(url: 'room:///${result.path}', name: name);
      }
      return JsonContent(json: result.toJson());
    } catch (error) {
      return JsonContent(json: {'status': 'failed', 'path': '', 'message': 'Unable to provide the webserver file: $error'});
    }
  }
}

class UninstallWebServerServiceTool extends FunctionTool with _PowerboardsToolResponseSentCallback {
  UninstallWebServerServiceTool({required this.projectId, required this.roomName, required this.uninstall, this.onUninstalled})
    : super(
        name: uninstallWebServerServiceToolName,
        title: 'Uninstall Web server service',
        description:
            'Uninstall the current room Web server service, remove its published routes, and keep website files as a regular Files folder when possible. '
            'Use this only when the user explicitly asks to uninstall, remove, or turn off the webserver service. '
            'When reporting success, send assistant_reply exactly once as the full user-facing response.',
        inputSchema: uninstallWebServerServiceInputSchema,
        outputSchema: uninstallWebServerServiceOutputSchema,
      );

  final String projectId;
  final String roomName;
  final UninstallWebServerServiceRunner uninstall;
  final FutureOr<void> Function(UninstallWebServerServiceResult result)? onUninstalled;

  @override
  Future<Content> execute(ToolContext context, Map<String, dynamic> arguments) async {
    try {
      final result = await uninstall(UninstallWebServerServiceRequest(projectId: projectId, roomName: roomName));
      final response = JsonContent(json: result.toJson());
      if (result.status == 'removed') {
        deferCallbackUntilResponseSent(response, onUninstalled, result);
      }
      return response;
    } catch (error) {
      return JsonContent(
        json: UninstallWebServerServiceResult(
          status: 'failed',
          folderPath: '$powerboardsWebServerFolderName/',
          siteLabel: powerboardsWebServerFolderName,
          message: 'Unable to uninstall the Web server service: $error',
        ).toJson(),
      );
    }
  }
}

Future<InstallWebServerServiceResult> installPowerboardsWebServerService(InstallWebServerServiceRequest request) async {
  final projectId = request.projectId.trim();
  final roomName = request.roomName.trim();
  if (projectId.isEmpty || roomName.isEmpty) {
    return const InstallWebServerServiceResult(
      status: 'blocked',
      serviceId: powerboardsWebServerServiceId,
      folderPath: '$powerboardsWebServerFolderName/',
      message: 'I need a current PowerBoards room before I can install the Web server service.',
    );
  }

  final client = getMeshagentClient();
  final existing = await client.listRoomServices(projectId: projectId, roomName: roomName);
  final existingWebServer = existing.firstWhereOrNull(_isWebServerService);
  if (existingWebServer != null) {
    final existingDomain = _webServerTemplateValues(existingWebServer)['url'];
    await powerboardsPrepareWebServerFolderForDomain(client: client, projectId: projectId, roomName: roomName, domain: existingDomain);
    return InstallWebServerServiceResult(
      status: 'already_installed',
      serviceId: powerboardsWebServerServiceId,
      folderPath: '$powerboardsWebServerFolderName/',
      domain: existingDomain,
      publicUrlStatus: existingDomain == null || existingDomain.trim().isEmpty ? 'unknown' : 'configured_unverified',
      message: 'The Web server service is already installed and the website folder is ready.',
      intent: request.intent,
    );
  }

  final template = await _loadWebServerTemplate();
  if (template == null) {
    return const InstallWebServerServiceResult(
      status: 'blocked',
      serviceId: powerboardsWebServerServiceId,
      folderPath: '$powerboardsWebServerFolderName/',
      message: 'The Web server service template is not available right now.',
    );
  }

  final values = _webServerInstallValues(template.parsed, roomName: roomName, siteName: request.siteName, domain: request.domain);
  final routeValue = values['url'];
  if (routeValue == null || routeValue.trim().isEmpty) {
    return const InstallWebServerServiceResult(
      status: 'needs_input',
      serviceId: powerboardsWebServerServiceId,
      folderPath: '$powerboardsWebServerFolderName/',
      message: 'I need a site name or domain before I can install the Web server service.',
    );
  }

  final renderedTemplate = await client.renderTemplate(template: template.template, values: values);
  final routeRequests = _routeRequestsForTemplate(renderedTemplate, values);
  if (routeRequests.isNotEmpty) {
    final room = await client.getRoom(projectId: projectId, name: roomName);
    for (final route in routeRequests) {
      try {
        final existingRoute = await client.getRoute(projectId: projectId, domain: route.domain);
        if (existingRoute.roomName != room.name) {
          return InstallWebServerServiceResult(
            status: 'blocked',
            serviceId: powerboardsWebServerServiceId,
            folderPath: '$powerboardsWebServerFolderName/',
            domain: route.domain,
            message: 'The domain ${route.domain} is already assigned to another room.',
          );
        }
        await client.updateRoute(
          projectId: projectId,
          domain: route.domain,
          roomName: room.name,
          port: route.port,
          annotations: const {'meshagent.service.id': powerboardsWebServerServiceId},
        );
      } on meshagent.NotFoundException {
        await client.createRoute(
          projectId: projectId,
          domain: route.domain,
          roomName: room.name,
          port: route.port,
          annotations: const {'meshagent.service.id': powerboardsWebServerServiceId},
        );
      }
    }
  }

  await powerboardsSaveServiceAfterPreparingWebServerFolder(
    isWebServer: true,
    prepareWebServerFolder: () async {
      // Restore archived files before the container can create a fresh empty website folder.
      await powerboardsPrepareWebServerFolderForDomain(client: client, projectId: projectId, roomName: roomName, domain: routeValue);
    },
    saveService: () =>
        client.createRoomServiceFromTemplate(projectId: projectId, roomName: roomName, template: template.template, values: values),
  );

  return InstallWebServerServiceResult(
    status: 'installed',
    serviceId: powerboardsWebServerServiceId,
    folderPath: '$powerboardsWebServerFolderName/',
    domain: routeValue,
    publicUrlStatus: 'configured_unverified',
    message: 'The Web server service is installed and the website folder is ready.',
    intent: request.intent,
  );
}

Future<UninstallWebServerServiceResult> uninstallPowerboardsWebServerService(
  UninstallWebServerServiceRequest request, {
  StorageClient? storage,
}) async {
  final projectId = request.projectId.trim();
  final roomName = request.roomName.trim();
  if (projectId.isEmpty || roomName.isEmpty) {
    return const UninstallWebServerServiceResult(
      status: 'blocked',
      folderPath: '$powerboardsWebServerFolderName/',
      siteLabel: powerboardsWebServerFolderName,
      message: 'I need a current PowerBoards room before I can uninstall the Web server service.',
    );
  }

  final client = getMeshagentClient();
  final services = await client.listRoomServices(projectId: projectId, roomName: roomName);
  final webServer = services.firstWhereOrNull(_isWebServerService);
  if (webServer == null) {
    return const UninstallWebServerServiceResult(
      status: 'not_installed',
      folderPath: '$powerboardsWebServerFolderName/',
      siteLabel: powerboardsWebServerFolderName,
      message: 'The Web server service is not installed in this room.',
    );
  }

  final domain = _webServerTemplateValues(webServer)['url']?.trim();
  final siteLabel = domain == null || domain.isEmpty ? powerboardsWebServerFolderName : domain;
  final archivedFolderName = powerboardsArchivedWebServerFolderName(siteLabel);
  final removal = await powerboardsUninstallV1WebServerResources(
    client: client,
    projectId: projectId,
    roomName: roomName,
    serviceInstanceId: webServer.id,
  );

  String? preservedFolderPath;
  try {
    preservedFolderPath = storage == null
        ? await powerboardsPreserveFormerWebServerFolder(
            client: client,
            projectId: projectId,
            roomName: roomName,
            preferredName: archivedFolderName,
          )
        : await powerboardsPreserveFormerWebServerFolderInStorage(storage, preferredName: archivedFolderName);
  } catch (_) {
    preservedFolderPath = null;
  }

  return UninstallWebServerServiceResult(
    status: 'removed',
    folderPath: '$powerboardsWebServerFolderName/',
    siteLabel: siteLabel,
    preservedFolderPath: preservedFolderPath,
    removedDomains: removal.removedDomains,
    message: 'Removed the Web server service from this room.',
  );
}

String powerboardsV1WebServerFolderLink(String storagePath) {
  final normalizedPath = storagePath.trim().replaceFirst(RegExp(r'/+$'), '');
  return Uri(
    scheme: 'powerboards',
    host: 'files',
    pathSegments: const ['webserver'],
    queryParameters: normalizedPath.isEmpty || normalizedPath == powerboardsWebServerFolderName ? null : {'path': normalizedPath},
  ).toString();
}

String powerboardsV1WebServerFileLink(String storagePath) {
  return Uri(
    scheme: 'powerboards',
    host: 'preview',
    pathSegments: const ['webserver'],
    queryParameters: {'path': storagePath.trim()},
  ).toString();
}

List<ListWebServerFilesEntry> powerboardsVisibleWebServerEntries({required String folderPath, required Iterable<StorageEntry> entries}) {
  return entries
      .where((entry) => !entry.name.startsWith('.'))
      .map((entry) => ListWebServerFilesEntry(name: entry.name, path: '$folderPath/${entry.name}', isFolder: entry.isFolder))
      .toList(growable: false);
}

Future<ListWebServerFilesResult> listPowerboardsWebServerFiles(ListWebServerFilesRequest request, {StorageClient? storage}) async {
  final projectId = request.projectId.trim();
  final roomName = request.roomName.trim();
  if (projectId.isEmpty || roomName.isEmpty) {
    return const ListWebServerFilesResult(
      status: 'failed',
      folderPath: powerboardsWebServerFolderName,
      entries: <ListWebServerFilesEntry>[],
      message: 'I need a current PowerBoards room before I can list the webserver folder.',
    );
  }

  final relativePath = _normalizeRequestedWebServerFolderPath(request.path);
  if (relativePath == null) {
    return const ListWebServerFilesResult(
      status: 'not_found',
      folderPath: powerboardsWebServerFolderName,
      entries: <ListWebServerFilesEntry>[],
      message: 'I could not find that folder in the webserver folder.',
    );
  }
  final folderPath = relativePath.isEmpty ? powerboardsWebServerFolderName : '$powerboardsWebServerFolderName/$relativePath';

  final client = getMeshagentClient();
  final services = await client.listRoomServices(projectId: projectId, roomName: roomName);
  if (!services.any(_isWebServerService)) {
    return ListWebServerFilesResult(
      status: 'not_installed',
      folderPath: folderPath,
      entries: const <ListWebServerFilesEntry>[],
      message: 'The Web server service is not installed in this room.',
    );
  }

  Future<ListWebServerFilesResult> listFrom(StorageClient activeStorage) async {
    if (!await activeStorage.exists(folderPath)) {
      return ListWebServerFilesResult(
        status: 'not_found',
        folderPath: folderPath,
        entries: const <ListWebServerFilesEntry>[],
        message: 'I could not find `$folderPath` in the webserver folder.',
      );
    }
    final entries = powerboardsVisibleWebServerEntries(folderPath: folderPath, entries: await activeStorage.list(folderPath));
    return ListWebServerFilesResult(
      status: 'listed',
      folderPath: folderPath,
      entries: entries,
      message: 'Listed ${entries.length} visible webserver ${entries.length == 1 ? 'entry' : 'entries'}.',
    );
  }

  if (storage != null) {
    return listFrom(storage);
  }

  final roomConnection = await client.connectRoom(projectId: projectId, roomName: roomName);
  final roomClient = RoomClient(
    protocolFactory: meshagent.WebSocketClientProtocol.createFactory(url: roomConnection.roomUrl, token: roomConnection.jwt),
  );
  try {
    roomClient.start();
    await roomClient.ready;
    return await listFrom(roomClient.storage);
  } finally {
    roomClient.dispose();
  }
}

Future<OpenWebServerFileResult> openPowerboardsWebServerFile(OpenWebServerFileRequest request, {StorageClient? storage}) async {
  final projectId = request.projectId.trim();
  final roomName = request.roomName.trim();
  if (projectId.isEmpty || roomName.isEmpty) {
    return const OpenWebServerFileResult(
      status: 'failed',
      path: '',
      message: 'I need a current PowerBoards room before I can provide a file.',
    );
  }

  final requestedPath = _normalizeRequestedWebServerFilePath(request.path);
  if (requestedPath == null) {
    return const OpenWebServerFileResult(status: 'not_found', path: '', message: 'Tell me which webserver file you want.');
  }

  final client = getMeshagentClient();
  final services = await client.listRoomServices(projectId: projectId, roomName: roomName);
  if (!services.any(_isWebServerService)) {
    return const OpenWebServerFileResult(
      status: 'not_installed',
      path: '',
      message: 'The Web server service is not installed in this room.',
    );
  }

  if (storage != null) {
    final match = await _findWebServerFilePath(storage, requestedPath);
    if (match == null) {
      return OpenWebServerFileResult(
        status: 'not_found',
        path: '$powerboardsWebServerFolderName/$requestedPath',
        message: 'I could not find `$requestedPath` in the webserver folder.',
      );
    }
    return OpenWebServerFileResult(status: 'opened', path: match, message: 'Attached `${match.split('/').last}`.');
  }

  final roomConnection = await client.connectRoom(projectId: projectId, roomName: roomName);
  final roomClient = RoomClient(
    protocolFactory: meshagent.WebSocketClientProtocol.createFactory(url: roomConnection.roomUrl, token: roomConnection.jwt),
  );
  try {
    roomClient.start();
    await roomClient.ready;
    final match = await _findWebServerFilePath(roomClient.storage, requestedPath);
    if (match == null) {
      return OpenWebServerFileResult(
        status: 'not_found',
        path: '$powerboardsWebServerFolderName/$requestedPath',
        message: 'I could not find `$requestedPath` in the webserver folder.',
      );
    }
    return OpenWebServerFileResult(status: 'opened', path: match, message: 'Attached `${match.split('/').last}`.');
  } finally {
    roomClient.dispose();
  }
}

bool _isWebServerService(meshagent.ServiceSpec service) {
  return service.metadata.annotations['meshagent.service.id'] == powerboardsWebServerServiceId;
}

String? _trimmedOrNull(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _webServerInstallIntent(Object? value) {
  final normalized = value is String ? value.trim() : '';
  return normalized == 'create_website' ? 'create_website' : 'install_only';
}

String? _normalizeRequestedWebServerFilePath(String rawPath) {
  var normalized = rawPath.trim().replaceAll('\\', '/');
  while (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  if (normalized.startsWith('$powerboardsWebServerFolderName/')) {
    normalized = normalized.substring(powerboardsWebServerFolderName.length + 1);
  }
  final segments = normalized.split('/').map((segment) => segment.trim()).where((segment) => segment.isNotEmpty).toList(growable: false);
  if (segments.isEmpty || segments.any((segment) => segment == '.' || segment == '..' || segment.startsWith('.'))) {
    return null;
  }
  return segments.join('/');
}

String? _normalizeRequestedWebServerFolderPath(String rawPath) {
  var normalized = rawPath.trim().replaceAll('\\', '/');
  while (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  if (normalized == powerboardsWebServerFolderName) {
    normalized = '';
  } else if (normalized.startsWith('$powerboardsWebServerFolderName/')) {
    normalized = normalized.substring(powerboardsWebServerFolderName.length + 1);
  }
  final segments = normalized.split('/').map((segment) => segment.trim()).where((segment) => segment.isNotEmpty).toList(growable: false);
  if (segments.any((segment) => segment == '.' || segment == '..' || segment.startsWith('.'))) {
    return null;
  }
  return segments.join('/');
}

Future<List<String>> _listWebServerFilePaths(StorageClient storage, String folderPath) async {
  final paths = <String>[];
  for (final entry in await storage.list(folderPath)) {
    if (entry.name.startsWith('.')) {
      continue;
    }
    final path = '$folderPath/${entry.name}';
    if (entry.isFolder) {
      paths.addAll(await _listWebServerFilePaths(storage, path));
    } else {
      paths.add(path);
    }
  }
  return paths;
}

Future<String?> _findWebServerFilePath(StorageClient storage, String requestedPath) async {
  final exactPath = '$powerboardsWebServerFolderName/$requestedPath';
  if (await storage.exists(exactPath)) {
    return exactPath;
  }

  final paths = await _listWebServerFilePaths(storage, powerboardsWebServerFolderName);
  final requestedLower = requestedPath.toLowerCase();
  final requestedName = requestedLower.split('/').last;
  final requestedStem = requestedName.contains('.') ? requestedName.substring(0, requestedName.lastIndexOf('.')) : requestedName;

  final exactCaseInsensitive = paths.firstWhereOrNull(
    (path) => path.substring(powerboardsWebServerFolderName.length + 1).toLowerCase() == requestedLower,
  );
  if (exactCaseInsensitive != null) {
    return exactCaseInsensitive;
  }

  final sameName = paths.firstWhereOrNull((path) => path.split('/').last.toLowerCase() == requestedName);
  if (sameName != null) {
    return sameName;
  }

  final sameStem =
      paths
          .where((path) {
            final name = path.split('/').last.toLowerCase();
            final stem = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
            return stem == requestedStem;
          })
          .toList(growable: false)
        ..sort((left, right) {
          final leftHtml = left.toLowerCase().endsWith('.html') || left.toLowerCase().endsWith('.htm');
          final rightHtml = right.toLowerCase().endsWith('.html') || right.toLowerCase().endsWith('.htm');
          if (leftHtml != rightHtml) {
            return leftHtml ? -1 : 1;
          }
          return left.toLowerCase().compareTo(right.toLowerCase());
        });
  return sameStem.firstOrNull;
}

Map<String, String> _webServerTemplateValues(meshagent.ServiceSpec service) {
  final raw = service.metadata.annotations['meshagent.service.template.values'];
  if (raw == null || raw.trim().isEmpty) {
    return const <String, String>{};
  }
  try {
    return (jsonDecode(raw) as Map).map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''));
  } catch (_) {
    return const <String, String>{};
  }
}

String _webServerDomainLinkLine(String? domain, {String? entryFilePath}) {
  final normalizedDomain = domain?.trim();
  if (normalizedDomain == null || normalizedDomain.isEmpty) {
    return '- Domain: `Not published yet`';
  }

  final uri =
      powerboardsWebServerEntryUri(siteUri: powerboardsWebServerSiteUri(normalizedDomain), entryPath: entryFilePath) ??
      Uri(scheme: 'https', host: normalizedDomain);
  return '- Domain: [$normalizedDomain]($uri) - [Copy](powerboards://copy?text=${Uri.encodeComponent(normalizedDomain)})';
}

Future<ServiceDirectoryEntry?> _loadWebServerTemplate() async {
  final serverUrl = MeshagentConfig.current?.serverUrl;
  if (serverUrl == null) {
    return null;
  }

  final response = await http.get(serverUrl.resolve('/directory'));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    return null;
  }

  final directory = await ServiceDirectoryPage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  return directory.templates.firstWhereOrNull(
    (entry) => entry.parsed.metadata.annotations['meshagent.service.id'] == powerboardsWebServerServiceId,
  );
}

Map<String, String> _webServerInstallValues(
  meshagent.ServiceTemplateSpec template, {
  required String roomName,
  String? siteName,
  String? domain,
}) {
  final routeVariables =
      template.variables?.where((variable) => variable.type == 'route').toList() ?? const <meshagent.ServiceTemplateVariable>[];
  if (routeVariables.isEmpty) {
    return const <String, String>{};
  }

  final routeVariable = routeVariables.first;
  final requestedDomain = _normalizeDomain(domain);
  final slug = _slugForSite(siteName ?? roomName);
  final resolvedDomain = requestedDomain ?? (slug == null ? null : powerboardsWebServerDomainFromSlug(slug));

  if (resolvedDomain == null || resolvedDomain.trim().isEmpty) {
    return const <String, String>{};
  }

  return {routeVariable.name: resolvedDomain};
}

String? _normalizeDomain(String? value) {
  final trimmed = value?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final parsed = Uri.tryParse(trimmed.contains('://') ? trimmed : 'https://$trimmed');
  final host = parsed?.host.trim();
  return host == null || host.isEmpty ? trimmed : host;
}

String? _slugForSite(String value) {
  final slug = value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) {
    return null;
  }
  return slug.length <= 40 ? slug : slug.substring(0, 40).replaceAll(RegExp(r'-+$'), '');
}

List<({String domain, String port})> _routeRequestsForTemplate(meshagent.ServiceTemplateSpec template, Map<String, String> values) {
  final inputVariables = template.variables ?? const <meshagent.ServiceTemplateVariable>[];
  final routeRequests = <({String domain, String port})>[];
  for (final variable in inputVariables) {
    if (variable.type != 'route') {
      continue;
    }
    final domain = (values[variable.name] ?? '').trim();
    if (domain.isEmpty) {
      continue;
    }

    final port = variable.annotations?['meshagent.route.port']?.trim();
    if (port == null || port.isEmpty) {
      throw meshagent.RoomServerException('meshagent.route.port is missing for ${variable.name}');
    }

    routeRequests.add((domain: domain, port: port));
  }
  return routeRequests;
}
