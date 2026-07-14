import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/agent.dart';
import 'package:meshagent/room_server_client.dart';
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
    test('uses strict-safe file arguments and returns structured JSON', () async {
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
      expect(result.json['created_files'], ['index.html']);
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
      expect(result.json['message'], contains('boom'));
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
            preservedFolderPath: 'website/',
            removedDomains: ['sunrise.meshagent.dev'],
            message: 'Removed the Web server service from this room.',
          );
        },
        onUninstalled: (result) => refreshed = result,
      );

      expect(tool.inputSchema['additionalProperties'], isFalse);
      expect(tool.inputSchema['properties'], isEmpty);

      final result = await tool.execute(const ToolContext(), {});

      expect(request?.projectId, 'project-1');
      expect(request?.roomName, 'room-1');
      expect(refreshed?.status, 'removed');
      expect(result, isA<JsonContent>());
      expect((result as JsonContent).json, {
        'status': 'removed',
        'folder_path': 'website/',
        'site_label': 'sunrise.meshagent.dev',
        'preserved_folder_path': 'website/',
        'removed_domains': ['sunrise.meshagent.dev'],
        'message': 'Removed the Web server service from this room.',
        'assistant_reply': ['Removed the webserver service from this room.', '', 'Files were kept in Files at `sunrise.meshagent.dev`.'].join('\n'),
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

  group('UIToolkit', () {
    test('registers install_webserver_service when room context is present', () {
      final toolkit = UIToolkit(
        context: _FakeBuildContext(),
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

      expect(toolkit.tools.map((tool) => tool.name), contains(installWebServerServiceToolName));
      expect(toolkit.tools.map((tool) => tool.name), contains(saveWebServerSiteFilesToolName));
    });

    test('does not register install_webserver_service without room context', () {
      final toolkit = UIToolkit(context: _FakeBuildContext());

      expect(toolkit.tools.map((tool) => tool.name), isNot(contains(installWebServerServiceToolName)));
      expect(toolkit.tools.map((tool) => tool.name), isNot(contains(saveWebServerSiteFilesToolName)));
    });
  });

  group('InstallWebServerServiceToolkit', () {
    test('exposes webserver install and site file actions for chat turns', () {
      final toolkit = InstallWebServerServiceToolkit(
        projectId: 'project-1',
        roomName: 'room-1',
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
      expect(toolkit.tools.map((tool) => tool.name), [installWebServerServiceToolName, saveWebServerSiteFilesToolName]);
    });

    test('keeps uninstall action behind V1 flag', () {
      final defaultToolkit = InstallWebServerServiceToolkit(projectId: 'project-1', roomName: 'room-1');
      final v1Toolkit = InstallWebServerServiceToolkit(projectId: 'project-1', roomName: 'room-1', enableV1Actions: true);

      expect(defaultToolkit.tools.map((tool) => tool.name), isNot(contains(uninstallWebServerServiceToolName)));
      expect(v1Toolkit.tools.map((tool) => tool.name), [
        installWebServerServiceToolName,
        saveWebServerSiteFilesToolName,
        uninstallWebServerServiceToolName,
      ]);
    });
  });
}

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
