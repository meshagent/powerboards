import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/agent.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_agents/meshagent_agents.dart' as agent_sessions;
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
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
      expect(tool.inputSchema['required'], ['site_name', 'domain', 'intent']);

      final result = await tool.execute(const ToolContext(), {'site_name': 'sunrise', 'domain': '', 'intent': 'install_only'});
      await Future<void>.delayed(Duration.zero);

      expect(request?.projectId, 'project-1');
      expect(request?.roomName, 'room-1');
      expect(request?.siteName, 'sunrise');
      expect(request?.domain, isNull);
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

  group('SaveWebServerSiteFilesTool', () {
    test('returns only the canonical website reply after saving files', () async {
      SaveWebServerSiteFilesRequest? request;
      final tool = SaveWebServerSiteFilesTool(
        projectId: 'project-1',
        roomName: 'room-1',
        save: (input) async {
          request = input;
          return const SaveWebServerSiteFilesResult(
            status: 'saved',
            folderPath: 'website/',
            siteLabel: 'sunrise.meshagent.dev',
            createdFiles: ['index.html'],
            domain: 'sunrise.meshagent.dev',
            message: 'Created 1 website file.',
          );
        },
      );

      expect(tool.inputSchema['additionalProperties'], isFalse);
      expect(tool.inputSchema['required'], ['files']);

      final result = await tool.execute(const ToolContext(), {
        'files': [
          {'path': 'index.html', 'content': '<!doctype html><title>Sunrise</title>'},
        ],
      });

      expect(request?.projectId, 'project-1');
      expect(request?.roomName, 'room-1');
      expect(request?.files.single.path, 'index.html');
      expect(request?.files.single.content, contains('Sunrise'));
      expect(result, isA<JsonContent>());
      expect((result as JsonContent).json['status'], 'saved');
      expect(result.json.keys, {'status', 'assistant_reply'});
      expect(result.json['assistant_reply'], contains('Created the website in `sunrise.meshagent.dev`.'));
      expect(result.json['assistant_reply'], isNot(contains('- `index.html`')));
      expect(
        result.json['assistant_reply'],
        contains('- Domain: [sunrise.meshagent.dev](https://sunrise.meshagent.dev/index.html) - [Copy]'),
      );
      expect(result.json['assistant_reply'], contains('- Location: [Go to files](powerboards://files/webserver)'));
      expect(result.json['assistant_reply'], contains('- Preview: [Open to view](powerboards://preview/webserver)'));
    });

    test('returns failed JSON instead of throwing when saver fails', () async {
      final tool = SaveWebServerSiteFilesTool(projectId: 'project-1', roomName: 'room-1', save: (_) async => throw StateError('boom'));

      final result =
          await tool.execute(const ToolContext(), {
                'files': [
                  {'path': 'index.html', 'content': '<html></html>'},
                ],
              })
              as JsonContent;

      expect(result.json['status'], 'failed');
      expect(result.json.keys, {'status', 'assistant_reply'});
      expect(result.json['assistant_reply'], contains('boom'));
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
      await Future<void>.delayed(Duration.zero);

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

    test('returns tool output before service refresh callback completes', () async {
      final refreshCompleter = Completer<void>();
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
        onUninstalled: (_) => refreshCompleter.future,
      );

      final result = await tool.execute(const ToolContext(), {}).timeout(const Duration(milliseconds: 100)) as JsonContent;
      refreshCompleter.complete();

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
    test('keeps room webserver tools behind the V1 UI flag', () {
      final legacyToolkit = powerboardsRoomUiToolkit(
        context: _FakeBuildContext(),
        enableV1WebServerTools: false,
        projectId: 'project-1',
        roomName: 'room-1',
      );
      final v1Toolkit = powerboardsRoomUiToolkit(
        context: _FakeBuildContext(),
        enableV1WebServerTools: true,
        projectId: 'project-1',
        roomName: 'room-1',
      );

      expect(
        legacyToolkit.tools.map((tool) => tool.name),
        isNot(
          contains(
            anyOf(
              installWebServerServiceToolName,
              saveWebServerSiteFilesToolName,
              openWebServerFileToolName,
              uninstallWebServerServiceToolName,
            ),
          ),
        ),
      );
      expect(
        v1Toolkit.tools.map((tool) => tool.name),
        containsAll([
          installWebServerServiceToolName,
          saveWebServerSiteFilesToolName,
          openWebServerFileToolName,
          uninstallWebServerServiceToolName,
        ]),
      );
    });

    test('registers webserver tools only when room context and the V1 flag are present', () {
      final toolkit = UIToolkit(
        context: _FakeBuildContext(),
        enableV1WebServerTools: true,
        projectId: 'project-1',
        roomName: 'room-1',
        installWebServerService: (_) async {
          return const InstallWebServerServiceResult(
            status: 'installed',
            serviceId: 'meshagent.webserver',
            folderPath: 'website/',
            message: 'installed',
          );
        },
      );

      expect(
        toolkit.tools.map((tool) => tool.name),
        containsAll([
          installWebServerServiceToolName,
          saveWebServerSiteFilesToolName,
          openWebServerFileToolName,
          uninstallWebServerServiceToolName,
        ]),
      );
    });

    test('does not register install_webserver_service without room context', () {
      final toolkit = UIToolkit(context: _FakeBuildContext());

      expect(toolkit.tools.map((tool) => tool.name), isNot(contains(installWebServerServiceToolName)));
      expect(toolkit.tools.map((tool) => tool.name), isNot(contains(saveWebServerSiteFilesToolName)));
    });

    test('does not register webserver tools for a legacy room context', () {
      final toolkit = UIToolkit(context: _FakeBuildContext(), projectId: 'project-1', roomName: 'room-1');

      expect(toolkit.tools.map((tool) => tool.name), isNot(contains(installWebServerServiceToolName)));
      expect(toolkit.tools.map((tool) => tool.name), isNot(contains(saveWebServerSiteFilesToolName)));
      expect(toolkit.tools.map((tool) => tool.name), isNot(contains(openWebServerFileToolName)));
      expect(toolkit.tools.map((tool) => tool.name), isNot(contains(uninstallWebServerServiceToolName)));
    });
  });

  group('InstallWebServerServiceToolkit', () {
    test('executes client tool requests through one toolkit and refreshes mutating UI state', () async {
      final refreshes = <String>[];
      final controller = ChatThreadController(room: null);
      addTearDown(controller.dispose);
      controller.addClientToolkit(
        InstallWebServerServiceToolkit(
          projectId: 'project-1',
          roomName: 'room-1',
          enableV1WebServerTools: true,
          install: (_) async => const InstallWebServerServiceResult(
            status: 'installed',
            serviceId: powerboardsWebServerServiceId,
            folderPath: 'website/',
            message: 'installed',
          ),
          saveSiteFiles: (_) async => const SaveWebServerSiteFilesResult(
            status: 'saved',
            folderPath: 'website/',
            siteLabel: 'site.meshagent.dev',
            createdFiles: ['index.html'],
            message: 'saved',
          ),
          openFile: (_) async => const OpenWebServerFileResult(status: 'opened', path: 'website/index.html', message: 'opened'),
          uninstall: (_) async => const UninstallWebServerServiceResult(
            status: 'removed',
            folderPath: 'website/',
            siteLabel: 'site.meshagent.dev',
            message: 'removed',
          ),
          onInstalled: (_) => refreshes.add('installed'),
          onSaved: (_) => refreshes.add('saved'),
          onUninstalled: (_) => refreshes.add('uninstalled'),
        ),
      );

      Future<Content> execute(String tool, Map<String, dynamic> arguments) {
        return controller.executeClientToolCall(
          agent_sessions.AgentClientToolCallRequested(
            threadId: 'thread-1',
            turnId: 'turn-1',
            requestId: 'request-$tool',
            toolkit: 'powerboards',
            tool: tool,
            arguments: arguments,
          ),
        );
      }

      await execute(installWebServerServiceToolName, {'site_name': 'site', 'domain': '', 'intent': 'install_only'});
      await execute(saveWebServerSiteFilesToolName, {
        'files': [
          {'path': 'index.html', 'content': '<html></html>'},
        ],
      });
      final opened = await execute(openWebServerFileToolName, {'path': 'index.html'});
      await execute(uninstallWebServerServiceToolName, const {});
      await Future<void>.delayed(Duration.zero);

      expect(opened, isA<LinkContent>());
      expect(refreshes, ['installed', 'saved', 'uninstalled']);
    });

    test('exposes webserver install and site file actions for chat turns', () {
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
        saveWebServerSiteFilesToolName,
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
        saveWebServerSiteFilesToolName,
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
