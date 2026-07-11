import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:meshagent/agent.dart';
import 'package:meshagent/meshagent.dart' as meshagent;
import 'package:meshagent/room_server_client.dart';
import 'package:powerboards/meshagent/agent_config.dart';
import 'package:powerboards/meshagent/agent_containers.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/route_service_match.dart';

const String installWebServerServiceToolName = 'install_webserver_service';
const String saveWebServerSiteFilesToolName = 'save_webserver_site_files';
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
    'storage_path': {'type': 'string'},
    'site_label': {'type': 'string'},
    'entry_file_path': {'type': 'string'},
    'domain': {'type': 'string'},
    'public_url_status': {'type': 'string'},
    'message': {'type': 'string'},
    'assistant_reply': {'type': 'string'},
  },
};

const Map<String, dynamic> saveWebServerSiteFilesInputSchema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['files'],
  'properties': {
    'files': {
      'type': 'array',
      'minItems': 1,
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['path', 'content'],
        'properties': {
          'path': {
            'type': 'string',
            'description': 'Path relative to the webserver root, such as index.html, styles.css, or assets/logo.svg.',
          },
          'content': {'type': 'string', 'description': 'UTF-8 file content to save.'},
        },
      },
    },
  },
};

const Map<String, dynamic> saveWebServerSiteFilesOutputSchema = {
  'type': 'object',
  'additionalProperties': false,
  'required': ['status', 'assistant_reply'],
  'properties': {
    'status': {
      'type': 'string',
      'enum': ['saved', 'blocked', 'failed'],
    },
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

class SaveWebServerSiteFile {
  const SaveWebServerSiteFile({required this.path, required this.content});

  final String path;
  final String content;
}

class SaveWebServerSiteFilesRequest {
  const SaveWebServerSiteFilesRequest({required this.projectId, required this.roomName, required this.files});

  final String projectId;
  final String roomName;
  final List<SaveWebServerSiteFile> files;
}

class SaveWebServerSiteFilesResult {
  const SaveWebServerSiteFilesResult({
    required this.status,
    required this.folderPath,
    required this.siteLabel,
    required this.createdFiles,
    required this.message,
    this.domain,
  });

  final String status;
  final String folderPath;
  final String siteLabel;
  final List<String> createdFiles;
  final String message;
  final String? domain;

  Map<String, dynamic> toJson() {
    final normalizedDomain = domain?.trim();
    return {
      'status': status,
      'folder_path': folderPath,
      'site_label': siteLabel,
      'created_files': createdFiles,
      if (normalizedDomain != null && normalizedDomain.isNotEmpty) 'domain': normalizedDomain,
      'message': message,
      'assistant_reply': _assistantReply(normalizedDomain),
    };
  }

  String _assistantReply(String? domain) {
    if (status != 'saved') {
      return message;
    }
    return [
      'Created the website in `$siteLabel`.',
      '',
      _webServerDomainLinkLine(domain, entryFilePath: '$powerboardsWebServerFolderName/index.html'),
      '- Location: [Go to files](powerboards://files/webserver)',
      '- Preview: [Open to view](powerboards://preview/webserver)',
    ].where((line) => line.isNotEmpty).join('\n');
  }
}

class UninstallWebServerServiceRequest {
  const UninstallWebServerServiceRequest({required this.projectId, required this.roomName});

  final String projectId;
  final String roomName;
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
typedef SaveWebServerSiteFilesRunner = Future<SaveWebServerSiteFilesResult> Function(SaveWebServerSiteFilesRequest request);
typedef OpenWebServerFileRunner = Future<OpenWebServerFileResult> Function(OpenWebServerFileRequest request);
typedef UninstallWebServerServiceRunner = Future<UninstallWebServerServiceResult> Function(UninstallWebServerServiceRequest request);

List<BaseTool> powerboardsWebServerTools({
  required String projectId,
  required String roomName,
  required bool enableV1WebServerTools,
  InstallWebServerServiceRunner install = installPowerboardsWebServerService,
  SaveWebServerSiteFilesRunner saveSiteFiles = savePowerboardsWebServerSiteFiles,
  OpenWebServerFileRunner openFile = openPowerboardsWebServerFile,
  UninstallWebServerServiceRunner uninstall = uninstallPowerboardsWebServerService,
  FutureOr<void> Function(InstallWebServerServiceResult result)? onInstalled,
  FutureOr<void> Function(SaveWebServerSiteFilesResult result)? onSaved,
  FutureOr<void> Function(UninstallWebServerServiceResult result)? onUninstalled,
}) {
  if (!enableV1WebServerTools) {
    return const <BaseTool>[];
  }

  return [
    InstallWebServerServiceTool(projectId: projectId, roomName: roomName, install: install, onInstalled: onInstalled),
    SaveWebServerSiteFilesTool(projectId: projectId, roomName: roomName, save: saveSiteFiles, onSaved: onSaved),
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
    SaveWebServerSiteFilesRunner saveSiteFiles = savePowerboardsWebServerSiteFiles,
    OpenWebServerFileRunner openFile = openPowerboardsWebServerFile,
    UninstallWebServerServiceRunner uninstall = uninstallPowerboardsWebServerService,
    FutureOr<void> Function(InstallWebServerServiceResult result)? onInstalled,
    FutureOr<void> Function(SaveWebServerSiteFilesResult result)? onSaved,
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
           saveSiteFiles: saveSiteFiles,
           openFile: openFile,
           uninstall: uninstall,
           onInstalled: onInstalled,
           onSaved: onSaved,
           onUninstalled: onUninstalled,
         ),
         rules: const [],
       );
}

class InstallWebServerServiceTool extends FunctionTool {
  InstallWebServerServiceTool({required this.projectId, required this.roomName, required this.install, this.onInstalled})
    : super(
        name: installWebServerServiceToolName,
        title: 'Install Web server service',
        description:
            'Install the PowerBoards Web server service in the current room and ensure the website folder exists. '
            'Use this when the user asks to install web hosting, install a web server service, create a web server, '
            'or prepare the room for a website. This is a PowerBoards product action, not a Linux package install. '
            'Do not use shell, apt, nginx, systemd, container-local ports, or private container URLs for this request. '
            'When reporting success, send assistant_reply exactly once as the full user-facing response. Do not prepend, append, '
            'summarize, repeat, list service_id, list mounted paths, or include implementation details unless the user asks for debugging details. '
            'Keep the powerboards:// links exactly as provided in assistant_reply so PowerBoards can open the Files folder and preview. '
            'This only installs website hosting; it does not create site files. If the user asked to create a website and supplied enough details, '
            'call save_webserver_site_files after this tool succeeds instead of ending the turn with the install-only follow-up.',
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

      if (result.status == 'installed' || result.status == 'already_installed') {
        _dispatchDeferredValueCallback(onInstalled, result);
      }

      return JsonContent(json: result.toJson());
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

class SaveWebServerSiteFilesTool extends FunctionTool {
  SaveWebServerSiteFilesTool({required this.projectId, required this.roomName, required this.save, this.onSaved})
    : super(
        name: saveWebServerSiteFilesToolName,
        title: 'Save Web server site files',
        description:
            'Create or update website files in the current room Web server root. Use this after install_webserver_service succeeds when the user asks '
            'to create, make, build, or edit a website. Save the main page as index.html unless the user asks for another entry file. '
            'Do not create nested roots like website/, public/, webserver/, sites/, or www/. Pass paths relative to the webserver root. '
            'When reporting success, send assistant_reply exactly once as the full user-facing response. Do not prepend, append, summarize, or repeat it.',
        inputSchema: saveWebServerSiteFilesInputSchema,
        outputSchema: saveWebServerSiteFilesOutputSchema,
      );

  final String projectId;
  final String roomName;
  final SaveWebServerSiteFilesRunner save;
  final FutureOr<void> Function(SaveWebServerSiteFilesResult result)? onSaved;

  @override
  Future<Content> execute(ToolContext context, Map<String, dynamic> arguments) async {
    try {
      final result = await save(
        SaveWebServerSiteFilesRequest(projectId: projectId, roomName: roomName, files: _siteFilesFromArguments(arguments['files'])),
      );
      if (result.status == 'saved') {
        _dispatchDeferredValueCallback(onSaved, result);
      }
      final json = result.toJson();
      return JsonContent(json: {'status': json['status'], 'assistant_reply': json['assistant_reply']});
    } catch (error) {
      final json = SaveWebServerSiteFilesResult(
        status: 'failed',
        folderPath: '$powerboardsWebServerFolderName/',
        siteLabel: powerboardsWebServerFolderName,
        createdFiles: const [],
        message: 'Unable to save the website files: $error',
      ).toJson();
      return JsonContent(json: {'status': json['status'], 'assistant_reply': json['assistant_reply']});
    }
  }
}

class UninstallWebServerServiceTool extends FunctionTool {
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
      if (result.status == 'removed') {
        _dispatchDeferredValueCallback(onUninstalled, result);
      }
      return JsonContent(json: result.toJson());
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

  final serviceId = webServer.id;
  if (serviceId == null || serviceId.trim().isEmpty) {
    return const UninstallWebServerServiceResult(
      status: 'blocked',
      folderPath: '$powerboardsWebServerFolderName/',
      siteLabel: powerboardsWebServerFolderName,
      message: 'The Web server service is missing its service id, so I cannot uninstall it safely.',
    );
  }

  final domain = _webServerTemplateValues(webServer)['url']?.trim();
  final siteLabel = domain == null || domain.isEmpty ? powerboardsWebServerFolderName : domain;
  final archivedFolderName = powerboardsArchivedWebServerFolderName(siteLabel);
  final routes = await client.listRoutes(projectId);
  final matchedRoutes = routesForService(routes: routes, service: webServer);

  await powerboardsDeleteRoutesThenService(
    routes: matchedRoutes,
    deleteRoute: (route) => client.deleteRoute(projectId: projectId, domain: route.domain),
    deleteService: () => client.deleteRoomService(projectId: projectId, serviceId: serviceId, roomName: roomName),
    observeServiceDeleted: () async {
      return powerboardsWaitForRoomServiceRemoval(
        serviceKindId: powerboardsWebServerServiceId,
        loadServices: () => client.listRoomServices(projectId: projectId, roomName: roomName),
        routeDomains: matchedRoutes.map((route) => route.domain),
        loadRouteDomains: () async => (await client.listRoomRoutes(projectId: projectId, roomName: roomName)).map((route) => route.domain),
      );
    },
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
    removedDomains: matchedRoutes.map((route) => route.domain).where((domain) => domain.trim().isNotEmpty).toList(growable: false),
    message: 'Removed the Web server service from this room.',
  );
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

Future<SaveWebServerSiteFilesResult> savePowerboardsWebServerSiteFiles(SaveWebServerSiteFilesRequest request) async {
  final projectId = request.projectId.trim();
  final roomName = request.roomName.trim();
  if (projectId.isEmpty || roomName.isEmpty) {
    return const SaveWebServerSiteFilesResult(
      status: 'blocked',
      folderPath: '$powerboardsWebServerFolderName/',
      siteLabel: powerboardsWebServerFolderName,
      createdFiles: [],
      message: 'I need a current PowerBoards room before I can create website files.',
    );
  }
  if (request.files.isEmpty) {
    return const SaveWebServerSiteFilesResult(
      status: 'blocked',
      folderPath: '$powerboardsWebServerFolderName/',
      siteLabel: powerboardsWebServerFolderName,
      createdFiles: [],
      message: 'I need at least one website file to save.',
    );
  }

  final client = getMeshagentClient();
  final services = await client.listRoomServices(projectId: projectId, roomName: roomName);
  final webServer = services.firstWhereOrNull(_isWebServerService);
  if (webServer == null) {
    return const SaveWebServerSiteFilesResult(
      status: 'blocked',
      folderPath: '$powerboardsWebServerFolderName/',
      siteLabel: powerboardsWebServerFolderName,
      createdFiles: [],
      message: 'The Web server service must be installed before I can create website files.',
    );
  }

  await powerboardsEnsureWebServerFolderExists(client: client, projectId: projectId, roomName: roomName);
  final domain = _webServerTemplateValues(webServer)['url'];
  final siteLabel = domain == null || domain.trim().isEmpty ? powerboardsWebServerFolderName : domain.trim();
  final roomConnection = await client.connectRoom(projectId: projectId, roomName: roomName);
  final roomClient = RoomClient(
    protocolFactory: meshagent.WebSocketClientProtocol.createFactory(url: roomConnection.roomUrl, token: roomConnection.jwt),
  );
  final createdFiles = <String>[];

  try {
    roomClient.start();
    await roomClient.ready;
    for (final file in request.files) {
      final relativePath = _normalizeWebServerSiteFilePath(file.path);
      final storagePath = '$powerboardsWebServerFolderName/$relativePath';
      final bytes = Uint8List.fromList(utf8.encode(file.content));
      await roomClient.storage.uploadStream(
        storagePath,
        Stream<Uint8List>.value(bytes),
        overwrite: true,
        size: bytes.length,
        mimeType: _mimeTypeForSiteFile(relativePath),
      );
      createdFiles.add(relativePath);
    }
  } finally {
    roomClient.dispose();
  }

  return SaveWebServerSiteFilesResult(
    status: 'saved',
    folderPath: '$powerboardsWebServerFolderName/',
    siteLabel: siteLabel,
    createdFiles: createdFiles,
    domain: domain,
    message: 'Created ${createdFiles.length} website file${createdFiles.length == 1 ? '' : 's'}.',
  );
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

List<SaveWebServerSiteFile> _siteFilesFromArguments(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((file) => SaveWebServerSiteFile(path: (file['path'] ?? '').toString(), content: (file['content'] ?? '').toString()))
      .toList(growable: false);
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
  if (segments.isEmpty || segments.any((segment) => segment == '.' || segment == '..')) {
    return null;
  }
  return segments.join('/');
}

Future<List<String>> _listWebServerFilePaths(StorageClient storage, String folderPath) async {
  final paths = <String>[];
  for (final entry in await storage.list(folderPath)) {
    final path = '$folderPath/${entry.name}';
    if (entry.isFolder) {
      paths.addAll(await _listWebServerFilePaths(storage, path));
    } else if (entry.name != powerboardsStorageFolderPlaceholderFileName) {
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

String _normalizeWebServerSiteFilePath(String rawPath) {
  var normalized = rawPath.trim().replaceAll('\\', '/');
  while (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  if (normalized.startsWith('$powerboardsWebServerFolderName/')) {
    normalized = normalized.substring(powerboardsWebServerFolderName.length + 1);
  }
  final segments = normalized.split('/').map((segment) => segment.trim()).where((segment) => segment.isNotEmpty).toList(growable: false);
  if (segments.isEmpty) {
    throw ArgumentError('Website file path must not be empty.');
  }
  if (segments.any((segment) => segment == '.' || segment == '..')) {
    throw ArgumentError('Website file path must stay inside the webserver root.');
  }
  const disallowedRootFolders = {'public', 'sites', 'webserver', 'www', powerboardsWebServerFolderName};
  if (segments.length > 1 && disallowedRootFolders.contains(segments.first.toLowerCase())) {
    throw ArgumentError('Save files directly in the existing webserver root, not in ${segments.first}/.');
  }
  return segments.join('/');
}

String? _mimeTypeForSiteFile(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.html') || lower.endsWith('.htm')) {
    return 'text/html; charset=utf-8';
  }
  if (lower.endsWith('.css')) {
    return 'text/css; charset=utf-8';
  }
  if (lower.endsWith('.js')) {
    return 'text/javascript; charset=utf-8';
  }
  if (lower.endsWith('.svg')) {
    return 'image/svg+xml';
  }
  if (lower.endsWith('.json')) {
    return 'application/json; charset=utf-8';
  }
  return null;
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

void _dispatchDeferredValueCallback<T>(FutureOr<void> Function(T value)? callback, T value) {
  if (callback == null) {
    return;
  }
  unawaited(
    Future<void>(() async {
      try {
        await callback(value);
      } catch (_) {}
    }),
  );
}
