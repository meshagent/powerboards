import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_auth/meshagent_flutter_auth.dart';
import 'package:powerboards/meshagent/meshagent.dart';

class _FakeMeshagentAuth extends MeshagentAuth {
  @override
  String? getAccessToken() => 'test-token';

  @override
  DateTime? get expiration => DateTime.now().add(const Duration(days: 1));

  @override
  String? getRefreshToken() => 'refresh-token';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('project role helper uses granular access checks', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    Map<String, dynamic>? body;

    unawaited(
      server.forEach((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.method == 'POST' && request.uri.path == '/accounts/projects/project-1/access:test') {
          body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
          request.response.write(jsonEncode({'allowed': true}));
        } else {
          request.response.statusCode = 404;
          request.response.write(jsonEncode({'error': 'not found'}));
        }
        await request.response.close();
      }),
    );

    final previousAuth = MeshagentAuth.current;
    final previousConfig = MeshagentConfig.current;
    MeshagentAuth.current = _FakeMeshagentAuth();
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

    final allowed = await testCurrentUserProjectRole('project-1', ProjectRole.roomCreator);

    expect(allowed, isTrue);
    expect(body, {
      'subject': {'type': 'user', 'id': 'me'},
      'resource': {'type': 'project', 'id': 'project-1'},
      'relation': 'room_creator',
    });
  });
}
