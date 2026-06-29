import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_auth/meshagent_flutter_auth.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/nav/update_room_perms_dialog.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _FakeMeshagentAuth extends MeshagentAuth {
  _FakeMeshagentAuth({required this.user});

  final Map<String, dynamic> user;

  @override
  String? getAccessToken() => 'test-token';

  @override
  DateTime? get expiration => DateTime.now().add(const Duration(days: 1));

  @override
  String? getRefreshToken() => 'refresh-token';

  @override
  Map<String, dynamic>? getUser() => user;
}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  testWidgets('room permissions dialog loads direct IAM policy rows and revokes through IAM', (tester) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    addTearDown(server.close);

    unawaited(
      server.forEach((request) async {
        requests.add('${request.method} ${request.uri.path}');
        request.response.headers.contentType = ContentType.json;

        if (request.method == 'GET' && request.uri.path == '/accounts/projects/project-1/iam/room/room-1/policy') {
          request.response.write(
            jsonEncode({
              'resource': {'type': 'room', 'id': 'room-1', 'name': 'demo'},
              'access_grants': [
                {
                  'resource': {'type': 'room', 'id': 'room-1', 'name': 'demo'},
                  'subject': {'type': 'user', 'id': 'user-me', 'email': 'me@example.test'},
                  'direct_roles': ['admin', 'list'],
                },
                {
                  'resource': {'type': 'room', 'id': 'room-1', 'name': 'demo'},
                  'subject': {'type': 'user', 'id': 'user-other', 'email': 'ada@example.test'},
                  'direct_roles': ['operator', 'list'],
                },
              ],
            }),
          );
        } else if (request.method == 'GET' && request.uri.path == '/accounts/profiles/user-me') {
          request.response.write(jsonEncode({'id': 'user-me', 'email': 'me@example.test', 'first_name': 'Current', 'last_name': 'User'}));
        } else if (request.method == 'GET' && request.uri.path == '/accounts/profiles/user-other') {
          request.response.write(
            jsonEncode({'id': 'user-other', 'email': 'ada@example.test', 'first_name': 'Ada', 'last_name': 'Lovelace'}),
          );
        } else if (request.method == 'POST' && request.uri.path == '/accounts/projects/project-1/iam/room/room-1/policy:revoke') {
          final body = await utf8.decoder.bind(request).join();
          expect(jsonDecode(body), {
            'subject': {'type': 'user', 'id': 'user-other'},
          });
          request.response.write(jsonEncode({}));
        } else {
          request.response.statusCode = 404;
          request.response.write(jsonEncode({'error': 'not found'}));
        }

        await request.response.close();
      }),
    );

    final previousAuth = MeshagentAuth.current;
    final previousConfig = MeshagentConfig.current;
    MeshagentAuth.current = _FakeMeshagentAuth(user: {'id': 'user-me'});
    MeshagentConfig.current = MeshagentConfig(
      serverUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      appUrl: Uri.parse('http://app.example.test'),
      billingUrl: Uri.parse('http://billing.example.test'),
      oauthCallbackUrl: Uri.parse('http://app.example.test/oauth'),
      oauthClientId: 'client-id',
      sentryEnabled: false,
      sentryDsn: '',
      sentryRelease: '',
      sentryEnvironment: 'test',
      imageTagPrefix: 'image:',
      domains: const [],
      meshagentMailDomain: 'mail.example.test',
    );
    addTearDown(() {
      MeshagentAuth.current = previousAuth;
      MeshagentConfig.current = previousConfig;
    });

    await tester.pumpWidget(
      ShadApp(
        home: Builder(
          builder: (context) => ShadButton(
            onPressed: () => showUpdateRoomPermsDialog(
              context,
              projectId: 'project-1',
              room: Room(id: 'room-1', name: 'demo', metadata: const {}, annotations: const {}),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('me@example.test'), findsOneWidget);
    expect(find.text('ada@example.test'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    expect(requests, contains('GET /accounts/projects/project-1/iam/room/room-1/policy'));

    await tester.tap(find.byIcon(LucideIcons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(requests, contains('POST /accounts/projects/project-1/iam/room/room-1/policy:revoke'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('add user dialog grants the selected room role with list permission', (tester) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Map<String, dynamic>? grantBody;
    addTearDown(server.close);

    unawaited(
      server.forEach((request) async {
        request.response.headers.contentType = ContentType.json;

        if (request.method == 'GET' && request.uri.path == '/accounts/projects/project-1/users') {
          request.response.write(
            jsonEncode({
              'users': [
                {
                  'id': 'user-me',
                  'email': 'me@example.test',
                  'direct_roles': ['member', 'admin'],
                },
                {
                  'id': 'user-add',
                  'email': 'ada@example.test',
                  'direct_roles': ['member'],
                },
              ],
            }),
          );
        } else if (request.method == 'GET' && request.uri.path == '/accounts/projects/project-1/iam/room/room-1/policy') {
          request.response.write(
            jsonEncode({
              'resource': {'type': 'room', 'id': 'room-1', 'name': 'demo'},
              'access_grants': [],
            }),
          );
        } else if (request.method == 'POST' && request.uri.path == '/accounts/projects/project-1/iam/room/room-1/policy:grant') {
          grantBody = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
          request.response.write(jsonEncode({}));
        } else {
          request.response.statusCode = 404;
          request.response.write(jsonEncode({'error': 'not found'}));
        }

        await request.response.close();
      }),
    );

    final previousAuth = MeshagentAuth.current;
    final previousConfig = MeshagentConfig.current;
    MeshagentAuth.current = _FakeMeshagentAuth(user: {'id': 'user-me'});
    MeshagentConfig.current = MeshagentConfig(
      serverUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      appUrl: Uri.parse('http://app.example.test'),
      billingUrl: Uri.parse('http://billing.example.test'),
      oauthCallbackUrl: Uri.parse('http://app.example.test/oauth'),
      oauthClientId: 'client-id',
      sentryEnabled: false,
      sentryDsn: '',
      sentryRelease: '',
      sentryEnvironment: 'test',
      imageTagPrefix: 'image:',
      domains: const [],
      meshagentMailDomain: 'mail.example.test',
    );
    addTearDown(() {
      MeshagentAuth.current = previousAuth;
      MeshagentConfig.current = previousConfig;
    });

    await tester.pumpWidget(
      ShadApp(
        home: Builder(
          builder: (context) => ShadButton(
            onPressed: () => showAddUserToRoomDialog(
              context,
              projectId: 'project-1',
              room: Room(id: 'room-1', name: 'demo', metadata: const {}, annotations: const {}),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    await tester.enterText(find.byType(EditableText).last, 'ada@example.test,');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(grantBody, {
      'subject': {'type': 'user', 'id': '', 'email': 'ada@example.test'},
      'roles': ['developer', 'list'],
      'invite_redirect_url': 'http://app.example.test',
    });
    expect(tester.takeException(), isNull);
  });
}
