import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/agent.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:powerboards/meshagent/agent_containers.dart';
import 'package:powerboards/meshagent/tools/install_webserver_service.dart';
import 'package:powerboards/meshagent/tools/ui_toolkit.dart';

void main() {
  group('InstallWebServerServiceTool', () {
    test('uses strict-safe string arguments and returns structured JSON', () async {
      InstallWebServerServiceRequest? request;
      InstallWebServerServiceResult? refreshed;
      final tool = InstallWebServerServiceTool(
        projectId: 'project-1',
        roomName: 'room-1',
        install: (input) async {
          request = input;
          return const InstallWebServerServiceResult(
            status: 'installed',
            serviceId: 'meshagent.webserver',
            folderPath: 'website/',
            domain: 'sunrise.meshagent.dev',
            message: 'The Web server service is installed and the website folder is ready.',
          );
        },
        onInstalled: (result) => refreshed = result,
      );

      expect(tool.inputSchema['additionalProperties'], isFalse);
      expect(tool.name, 'install_live_website_preview');
      expect(tool.inputSchema['required'], ['site_name', 'domain', 'access', 'intent']);
      expect(tool.description, startsWith('Install the PowerBoards live website preview in the current room and return storage_path'));
      expect(tool.description, contains('write_file'));

      final result = await tool.execute(const ToolContext(), {
        'site_name': 'sunrise',
        'domain': '',
        'access': 'public',
        'intent': 'install_only',
      });
      expect(refreshed, isNull);
      await tool.onToolResponseSent(const ToolContext(), result);

      expect(request?.projectId, 'project-1');
      expect(request?.roomName, 'room-1');
      expect(request?.siteName, 'sunrise');
      expect(request?.domain, isNull);
      expect(request?.access, 'public');
      expect(request?.intent, 'install_only');
      expect(refreshed?.status, 'installed');
      expect(result, isA<JsonContent>());
      expect((result as JsonContent).json, {
        'status': 'installed',
        'service_id': 'meshagent.webserver',
        'folder_path': 'website/',
        'storage_path': 'website/',
        'site_label': 'sunrise.meshagent.dev',
        'entry_file_path': 'website/index.html',
        'domain': 'sunrise.meshagent.dev',
        'public_url_status': 'unknown',
        'message': 'The Web server service is installed and the website folder is ready.',
        'assistant_reply': [
          'The web service has been successfully installed in this room.',
          '',
          'Your webserver URL',
          '- Domain: [sunrise.meshagent.dev](https://sunrise.meshagent.dev/index.html) - [Copy](powerboards://copy?text=sunrise.meshagent.dev)',
          '- Location: [Go to files](powerboards://files/webserver)',
          '- Preview: [Open to view](powerboards://preview/webserver)',
          '',
          'Would you like to create or edit an HTML page or site?',
        ].join('\n'),
      });
    });

    test('uses create website intent for setup follow-up', () async {
      final tool = InstallWebServerServiceTool(
        projectId: 'project-1',
        roomName: 'room-1',
        install: (input) async {
          return InstallWebServerServiceResult(
            status: 'installed',
            serviceId: 'meshagent.webserver',
            folderPath: 'website/',
            domain: 'sunrise.meshagent.dev',
            message: 'The Web server service is installed and the website folder is ready.',
            intent: input.intent,
          );
        },
      );

      final result =
          await tool.execute(const ToolContext(), {'site_name': 'sunrise', 'domain': '', 'intent': 'create_website'}) as JsonContent;

      expect(result.json['assistant_reply'], contains('I set up the webserver service for this room so we can publish the website here.'));
      expect(result.json['assistant_reply'], contains('What kind of website would you like to create?'));
      expect(result.json['assistant_reply'], contains('[Go to folder](powerboards://files/webserver)'));
      expect(result.json['assistant_reply'], isNot(contains('Your webserver URL')));
      expect(result.json['assistant_reply'], isNot(contains('Would you like to create')));
    });

    test('does not refresh services for needs-input blockers', () async {
      var refreshed = false;
      final tool = InstallWebServerServiceTool(
        projectId: 'project-1',
        roomName: 'room-1',
        install: (_) async {
          return const InstallWebServerServiceResult(
            status: 'needs_input',
            serviceId: 'meshagent.webserver',
            folderPath: 'website/',
            message: 'I need a site name or domain before I can install the Web server service.',
          );
        },
        onInstalled: (_) => refreshed = true,
      );

      final result = await tool.execute(const ToolContext(), {'site_name': '', 'domain': '', 'intent': 'install_only'}) as JsonContent;

      expect(refreshed, isFalse);
      expect(result.json['status'], 'needs_input');
    });

    test('returns failed JSON instead of throwing when installer fails', () async {
      final tool = InstallWebServerServiceTool(projectId: 'project-1', roomName: 'room-1', install: (_) async => throw StateError('boom'));

      final result = await tool.execute(const ToolContext(), {'site_name': '', 'domain': '', 'intent': 'install_only'}) as JsonContent;

      expect(result.json['status'], 'failed');
      expect(result.json['service_id'], 'meshagent.webserver');
      expect(result.json['site_label'], 'website/');
      expect(result.json['message'], contains('boom'));
    });
  });

  group('PublishWebsiteTool', () {
    test('requires a domain, /data path, and access mode', () async {
      PublishWebsiteRequest? request;
      PublishWebsiteResult? refreshed;
      final tool = PublishWebsiteTool(
        projectId: 'project-1',
        roomName: 'room-1',
        publish: (input) async {
          request = input;
          return const PublishWebsiteResult(
            status: 'published',
            domain: 'release.meshagent.dev',
            path: '/data/releases/site.tar',
            access: 'private',
            message: 'Published the website.',
          );
        },
        onPublished: (result) => refreshed = result,
      );

      expect(tool.name, publishWebsiteToolName);
      expect(tool.inputSchema['required'], ['domain', 'path', 'access']);
      expect(tool.description, contains("mounted into the /data folder"));
      expect(tool.description, contains('unlike the live website preview'));
      expect(tool.description, contains('tar the website files from /website'));
      expect(tool.description, contains('/published/website-{MMDDYYHHMMSS}.tar'));
      expect(tool.description, contains('retain older archives'));

      final result = await tool.execute(const ToolContext(), {
        'domain': 'release.meshagent.dev',
        'path': '/data/releases/site.tar',
        'access': 'private',
      });
      expect(refreshed, isNull);
      await tool.onToolResponseSent(const ToolContext(), result);

      expect(request?.projectId, 'project-1');
      expect(request?.roomName, 'room-1');
      expect(request?.path, '/data/releases/site.tar');
      expect(request?.access, 'private');
      expect(refreshed?.status, 'published');
      expect((result as JsonContent).json['service_id'], powerboardsPublishedWebsiteServiceId);
      expect(result.json['assistant_reply'], contains('https://release.meshagent.dev'));
    });

    test('maps /data tar paths to room storage and rejects unsafe or non-tar paths', () {
      expect(powerboardsNormalizePublishedWebsitePath('/data/published/website-071726143005.tar'), (
        containerPath: '/data/published/website-071726143005.tar',
        storagePath: 'published/website-071726143005.tar',
      ));
      expect(powerboardsNormalizePublishedWebsitePath('/published/site.tar'), isNull);
      expect(powerboardsNormalizePublishedWebsitePath('/data/published/site.zip'), isNull);
      expect(powerboardsNormalizePublishedWebsitePath('/data/../site.tar'), isNull);
    });
  });

  group('UninstallWebServerServiceTool', () {
    test('uses room context and returns structured JSON', () async {
      UninstallWebServerServiceRequest? request;
      UninstallWebServerServiceResult? refreshed;
      final tool = UninstallWebServerServiceTool(
        projectId: 'project-1',
        roomName: 'room-1',
        uninstall: (input) async {
          request = input;
          return const UninstallWebServerServiceResult(
            status: 'removed',
            folderPath: 'website/',
            siteLabel: 'sunrise.meshagent.dev',
            preservedFolderPath: 'sunrise.meshagent.dev',
            removedDomains: ['sunrise.meshagent.dev'],
            message: 'Removed the Web server service from this room.',
          );
        },
        onUninstalled: (result) => refreshed = result,
      );

      expect(tool.inputSchema['additionalProperties'], isFalse);
      expect(tool.inputSchema['properties'], isEmpty);

      final result = await tool.execute(const ToolContext(), {});
      expect(refreshed, isNull);
      await tool.onToolResponseSent(const ToolContext(), result);

      expect(request?.projectId, 'project-1');
      expect(request?.roomName, 'room-1');
      expect(refreshed?.status, 'removed');
      expect(result, isA<JsonContent>());
      expect((result as JsonContent).json, {
        'status': 'removed',
        'folder_path': 'website/',
        'site_label': 'sunrise.meshagent.dev',
        'preserved_folder_path': 'sunrise.meshagent.dev',
        'removed_domains': ['sunrise.meshagent.dev'],
        'message': 'Removed the Web server service from this room.',
        'assistant_reply': [
          'Removed the webserver service from this room.',
          '',
          'Files were kept in Files at `sunrise.meshagent.dev`.',
        ].join('\n'),
      });
    });

    test('does not refresh services when webserver is not installed', () async {
      var refreshed = false;
      final tool = UninstallWebServerServiceTool(
        projectId: 'project-1',
        roomName: 'room-1',
        uninstall: (_) async {
          return const UninstallWebServerServiceResult(
            status: 'not_installed',
            folderPath: 'website/',
            siteLabel: 'website',
            message: 'The Web server service is not installed in this room.',
          );
        },
        onUninstalled: (_) => refreshed = true,
      );

      final result = await tool.execute(const ToolContext(), {}) as JsonContent;

      expect(refreshed, isFalse);
      expect(result.json['status'], 'not_installed');
      expect(result.json['assistant_reply'], 'The Web server service is not installed in this room.');
    });

    test('waits for response delivery before starting the service refresh callback', () async {
      final refreshCompleter = Completer<void>();
      var refreshStarted = false;
      final tool = UninstallWebServerServiceTool(
        projectId: 'project-1',
        roomName: 'room-1',
        uninstall: (_) async {
          return const UninstallWebServerServiceResult(
            status: 'removed',
            folderPath: 'website/',
            siteLabel: 'website',
            preservedFolderPath: 'website/',
            message: 'Removed the Web server service from this room.',
          );
        },
        onUninstalled: (_) {
          refreshStarted = true;
          return refreshCompleter.future;
        },
      );

      final result = await tool.execute(const ToolContext(), {}).timeout(const Duration(milliseconds: 100)) as JsonContent;
      expect(refreshStarted, isFalse);

      final notification = tool.onToolResponseSent(const ToolContext(), result);
      await Future<void>.delayed(Duration.zero);
      expect(refreshStarted, isTrue);
      refreshCompleter.complete();
      await notification;

      expect(result.json['status'], 'removed');
      expect(result.json['assistant_reply'], contains('Files were kept in Files at `website`.'));
    });
  });

  group('OpenWebServerFileTool', () {
    test('returns a native room link that chat renders as a separate attachment', () async {
      OpenWebServerFileRequest? request;
      final tool = OpenWebServerFileTool(
        projectId: 'project-1',
        roomName: 'room-1',
        openFile: (input) async {
          request = input;
          return const OpenWebServerFileResult(status: 'opened', path: 'website/index.html', message: 'Attached index.html.');
        },
      );

      final result = await tool.execute(const ToolContext(), {'path': 'index.file'});

      expect(request?.projectId, 'project-1');
      expect(request?.roomName, 'room-1');
      expect(request?.path, 'index.file');
      expect(result, isA<LinkContent>());
      expect((result as LinkContent).url, 'room:///website/index.html');
      expect(result.name, 'index.html');
    });

    test('returns structured not-found output instead of an inert link', () async {
      final tool = OpenWebServerFileTool(
        projectId: 'project-1',
        roomName: 'room-1',
        openFile: (_) async => const OpenWebServerFileResult(status: 'not_found', path: 'website/missing.html', message: 'File not found.'),
      );

      final result = await tool.execute(const ToolContext(), {'path': 'missing.html'});

      expect(result, isA<JsonContent>());
      expect((result as JsonContent).json['status'], 'not_found');
    });
  });

  group('ListWebServerFilesTool', () {
    test('returns visible entries with clickable Powerboards links', () async {
      ListWebServerFilesRequest? request;
      final tool = ListWebServerFilesTool(
        projectId: 'project-1',
        roomName: 'room-1',
        listFiles: (input) async {
          request = input;
          return const ListWebServerFilesResult(
            status: 'listed',
            folderPath: 'website',
            entries: [
              ListWebServerFilesEntry(name: 'assets', path: 'website/assets', isFolder: true),
              ListWebServerFilesEntry(name: 'index.html', path: 'website/index.html', isFolder: false),
            ],
            message: 'Listed 2 visible webserver entries.',
          );
        },
      );

      final result = await tool.execute(const ToolContext(), {'path': ''}) as JsonContent;

      expect(request?.projectId, 'project-1');
      expect(request?.roomName, 'room-1');
      expect(request?.path, isEmpty);
      expect(result.json['folder_link'], 'powerboards://files/webserver');
      expect(result.json['entries'], [
        {'name': 'assets', 'path': 'website/assets', 'type': 'folder', 'link': 'powerboards://files/webserver?path=website%2Fassets'},
        {
          'name': 'index.html',
          'path': 'website/index.html',
          'type': 'file',
          'link': 'powerboards://preview/webserver?path=website%2Findex.html',
        },
      ]);
      expect(result.json['assistant_reply'], contains('[index.html](powerboards://preview/webserver?path=website%2Findex.html)'));
    });

    test('filters every hidden direct child including the placeholder', () {
      final now = DateTime.utc(2026, 7, 14);
      final entries = powerboardsVisibleWebServerEntries(
        folderPath: 'website',
        entries: [
          StorageEntry(name: '.placeholder', isFolder: false, size: 0, createdAt: now, updatedAt: now),
          StorageEntry(name: '.drafts', isFolder: true, size: null, createdAt: now, updatedAt: now),
          StorageEntry(name: 'index.html', isFolder: false, size: 42, createdAt: now, updatedAt: now),
        ],
      );

      expect(entries.map((entry) => entry.name), ['index.html']);
    });
  });

  test('webserver lifecycle removes routes before deleting the service', () async {
    final operations = <String>[];

    await powerboardsDeleteRoutesThenService(
      routes: const ['first.example', 'second.example'],
      deleteRoute: (route) async => operations.add('route:$route'),
      deleteService: () async => operations.add('service'),
      observeServiceDeleted: () async {
        operations.add('observed-removed');
        return true;
      },
    );

    expect(operations, ['route:first.example', 'route:second.example', 'service', 'observed-removed']);
  });

  test('service removal observer waits for the API list to converge', () async {
    var loads = 0;
    var waits = 0;
    final webServer = ServiceSpec(
      metadata: ServiceMetadata(name: 'web server', annotations: const {'meshagent.service.id': powerboardsWebServerServiceId}),
    );

    final removed = await powerboardsWaitForRoomServiceRemoval(
      serviceKindId: powerboardsWebServerServiceId,
      loadServices: () async {
        loads += 1;
        return loads < 3 ? [webServer] : const <ServiceSpec>[];
      },
      wait: (_) async => waits += 1,
    );

    expect(removed, isTrue);
    expect(loads, 3);
    expect(waits, 2);
  });

  test('service removal observer waits for both service and route absence', () async {
    var serviceLoads = 0;
    var routeLoads = 0;
    final webServer = ServiceSpec(
      id: 'service-instance',
      metadata: ServiceMetadata(name: 'web server', annotations: const {'meshagent.service.id': powerboardsWebServerServiceId}),
    );

    final removed = await powerboardsWaitForRoomServiceRemoval(
      serviceKindId: powerboardsWebServerServiceId,
      routeDomains: const ['site.meshagent.dev'],
      loadServices: () async {
        serviceLoads += 1;
        return serviceLoads == 1 ? [webServer] : const <ServiceSpec>[];
      },
      loadRouteDomains: () async {
        routeLoads += 1;
        return routeLoads < 3 ? const ['site.meshagent.dev'] : const <String>[];
      },
      wait: (_) async {},
    );

    expect(removed, isTrue);
    expect(serviceLoads, 3);
    expect(routeLoads, 3);
  });

  test('V1 service removal observer rejects a transient absence before stable convergence', () async {
    var loads = 0;
    var waits = 0;
    final webServer = ServiceSpec(
      metadata: ServiceMetadata(name: 'web server', annotations: const {'meshagent.service.id': powerboardsWebServerServiceId}),
    );

    final removed = await powerboardsWaitForRoomServiceRemoval(
      serviceKindId: powerboardsWebServerServiceId,
      maxAttempts: 4,
      requiredConsecutiveAbsentObservations: 2,
      loadServices: () async {
        loads += 1;
        return switch (loads) {
          2 => [webServer],
          _ => const <ServiceSpec>[],
        };
      },
      wait: (_) async => waits += 1,
    );

    expect(removed, isTrue);
    expect(loads, 4);
    expect(waits, 3);
  });

  test('route and service deletion fails instead of reporting success before convergence', () async {
    expect(
      () => powerboardsDeleteRoutesThenService(
        routes: const <String>[],
        deleteRoute: (_) async {},
        deleteService: () async {},
        observeServiceDeleted: () async => false,
      ),
      throwsStateError,
    );
  });

  group('UIToolkit', () {
    test('keeps room-hosted UI tools separate from thread-owned webserver tools', () {
      final toolkit = UIToolkit(context: _FakeBuildContext());
      final names = toolkit.tools.map((tool) => tool.name);

      expect(names, isNot(contains(installWebServerServiceToolName)));
      expect(names, isNot(contains(listWebServerFilesToolName)));
      expect(names, isNot(contains(openWebServerFileToolName)));
      expect(names, isNot(contains(uninstallWebServerServiceToolName)));
    });
  });

  group('InstallWebServerServiceToolkit', () {
    test('exposes webserver service actions without a dedicated file writer', () {
      final toolkit = InstallWebServerServiceToolkit(
        projectId: 'project-1',
        roomName: 'room-1',
        enableV1WebServerTools: true,
        install: (_) async {
          return const InstallWebServerServiceResult(
            status: 'installed',
            serviceId: 'meshagent.webserver',
            folderPath: 'website/',
            message: 'installed',
          );
        },
      );

      expect(toolkit.name, 'powerboards');
      expect(toolkit.tools.map((tool) => tool.name), [
        installWebServerServiceToolName,
        publishWebsiteToolName,
        listWebServerFilesToolName,
        openWebServerFileToolName,
        uninstallWebServerServiceToolName,
      ]);
    });

    test('keeps every webserver action behind the V1 flag', () {
      final legacyToolkit = InstallWebServerServiceToolkit(projectId: 'project-1', roomName: 'room-1', enableV1WebServerTools: false);
      final v1Toolkit = InstallWebServerServiceToolkit(projectId: 'project-1', roomName: 'room-1', enableV1WebServerTools: true);

      expect(legacyToolkit.tools, isEmpty);
      expect(v1Toolkit.tools.map((tool) => tool.name), [
        installWebServerServiceToolName,
        publishWebsiteToolName,
        listWebServerFilesToolName,
        openWebServerFileToolName,
        uninstallWebServerServiceToolName,
      ]);
    });
  });
}

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
