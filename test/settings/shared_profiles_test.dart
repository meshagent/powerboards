import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meshagent_flutter_auth/meshagent_auth.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/settings/shared_profiles.dart';

void main() {
  MeshagentConfig testConfig() {
    return MeshagentConfig(
      serverUrl: Uri.parse('https://api.meshagent.com'),
      appUrl: Uri.parse('https://app.powerboards.com'),
      billingUrl: Uri.parse('https://accounts.meshagent.com'),
      oauthCallbackUrl: Uri.parse('powerboards:/mauth/callback'),
      oauthClientId: 'com-native-client',
      imageTagPrefix: 'us-central1-docker.pkg.dev/meshagent-public/images/',
      domains: const ['meshagent.app'],
      meshagentMailDomain: 'mail.meshagent.com',
    );
  }

  test('config override uses shared profile API URL without changing app OAuth config', () {
    final config = testConfig().withApiUrlOverride('https://api.meshagent.life/');

    expect(config.serverUrl.toString(), 'https://api.meshagent.life');
    expect(config.appUrl.toString(), 'https://app.powerboards.com');
    expect(config.billingUrl.toString(), 'https://accounts.meshagent.com');
    expect(config.oauthClientId, 'com-native-client');
    expect(config.oauthCallbackUrl.toString(), 'powerboards:/mauth/callback');
    expect(config.imageTagPrefix, 'us-central1-docker.pkg.dev/meshagent-public/images/');
    expect(config.domains, ['meshagent.app']);
    expect(config.meshagentMailDomain, 'mail.meshagent.com');
  });

  test('deployment config endpoint maps custom server domains', () async {
    final requests = <Uri>[];
    final config = await testConfig()
        .withApiUrlOverride('https://api.wayvia.example')
        .withDeploymentConfig(
          client: MockClient((request) async {
            requests.add(request.url);
            return http.Response(
              jsonEncode({
                'version': '0.44.0',
                'domains': {
                  'accounts': 'accounts.wayvia.example',
                  'api': 'api-config.wayvia.example',
                  'mail': 'mail.wayvia.example',
                  'pages': 'apps.wayvia.example',
                  'powerboards': 'powerboards.wayvia.example',
                  'registry': 'registry.wayvia.example',
                },
              }),
              200,
            );
          }),
        );

    expect(requests, [Uri.parse('https://api.wayvia.example/config')]);
    expect(config.serverUrl.toString(), 'https://api-config.wayvia.example');
    expect(config.appUrl.toString(), 'https://powerboards.wayvia.example');
    expect(config.billingUrl.toString(), 'https://accounts.wayvia.example');
    expect(config.domains, ['apps.wayvia.example']);
    expect(config.meshagentMailDomain, 'mail.wayvia.example');
    expect(config.registryHost, 'registry.wayvia.example');
  });

  test('deployment config endpoint failure preserves existing domains', () async {
    final baseConfig = testConfig().withApiUrlOverride('https://api.wayvia.example');
    final config = await baseConfig.withDeploymentConfig(
      client: MockClient((request) async {
        return http.Response('not found', 404);
      }),
    );

    expect(config.serverUrl.toString(), 'https://api.wayvia.example');
    expect(config.appUrl, baseConfig.appUrl);
    expect(config.billingUrl, baseConfig.billingUrl);
    expect(config.domains, baseConfig.domains);
    expect(config.meshagentMailDomain, baseConfig.meshagentMailDomain);
    expect(config.registryHost, baseConfig.registryHost);
  });

  test('startup profile config reads active shared profile once when supported', () async {
    MeshagentConfig.current = testConfig();
    var loadCount = 0;

    await applySharedProfileConfigIfSupported(
      supported: true,
      loadActiveProfile: () async {
        loadCount += 1;
        return const SharedProfile(userId: 'life-user', isActive: true, apiUrl: 'https://api.meshagent.life');
      },
    );

    expect(loadCount, 1);
    expect(MeshagentConfig.current?.serverUrl.toString(), 'https://api.meshagent.life');
    expect(MeshagentConfig.current?.appUrl.toString(), 'https://app.powerboards.com');
  });

  test('startup profile config skips shared profile loading when unsupported', () async {
    MeshagentConfig.current = testConfig();
    var loadCalled = false;

    await applySharedProfileConfigIfSupported(
      supported: false,
      loadActiveProfile: () async {
        loadCalled = true;
        return const SharedProfile(userId: 'life-user', isActive: true, apiUrl: 'https://api.meshagent.life');
      },
    );

    expect(loadCalled, isFalse);
    expect(MeshagentConfig.current?.serverUrl.toString(), 'https://api.meshagent.com');
  });

  test('Powerboards auth sync writes shared profile settings without touching other profiles', () async {
    final previousAuth = MeshagentAuth.current;
    final auth = _MemoryMeshagentAuth();
    MeshagentAuth.current = auth;
    addTearDown(() => MeshagentAuth.current = previousAuth);

    MeshagentConfig.current = testConfig().withApiUrlOverride('https://api.meshagent.life');
    MeshagentAuth.current.setUser({'id': 'powerboards-user', 'first_name': 'Power', 'last_name': 'User', 'email': 'power@example.com'});
    MeshagentAuth.current.setAccessToken('powerboards-access-token');
    MeshagentAuth.current.setRefreshToken('powerboards-refresh-token');
    MeshagentAuth.current.setExpiration(DateTime.utc(2026, 1, 2, 3, 4, 5));

    final temp = await Directory.systemTemp.createTemp('powerboards-shared-profile-sync-test-');
    addTearDown(() => temp.delete(recursive: true));
    final settingsFile = File('${temp.path}/settings.json');
    await settingsFile.writeAsString(
      jsonEncode({
        'active_user_id': 'other-user',
        'users': {
          '__local__': {'api_url': 'https://api.meshagent.com'},
          'other-user': {
            'api_url': 'https://api.meshagent.com',
            'profile': {'id': 'other-user', 'email': 'other@example.com'},
            'session': {'access_token': 'other-token'},
          },
        },
      }),
    );

    await syncPowerboardsAuthToSharedProfileSettingsFile(file: settingsFile, activeProject: 'project-456');
    final decoded = jsonDecode(await settingsFile.readAsString()) as Map<String, dynamic>;
    final users = decoded['users'] as Map<String, dynamic>;
    final powerboardsSettings = users['powerboards-user'] as Map<String, dynamic>;
    final powerboardsSession = powerboardsSettings['session'] as Map<String, dynamic>;
    final powerboardsProject = powerboardsSettings['project'] as Map<String, dynamic>;

    expect(decoded['active_user_id'], 'powerboards-user');
    expect(users.containsKey('__local__'), isFalse);
    expect(users.containsKey('other-user'), isTrue);
    expect(powerboardsSettings['api_url'], 'https://api.meshagent.life');
    expect(powerboardsSession['access_token'], 'powerboards-access-token');
    expect(powerboardsSession['refresh_token'], 'powerboards-refresh-token');
    expect(powerboardsSession['expires_at'], 1767323045);
    expect(powerboardsProject['active_project'], 'project-456');
  });
}

class _MemoryMeshagentAuth extends MeshagentAuth {
  String? accessToken;
  String? refreshToken;
  DateTime? storedExpiration;
  Map<String, dynamic>? storedUser;

  @override
  void setUser(Map<String, dynamic>? user) {
    storedUser = user;
  }

  @override
  Map<String, dynamic>? getUser() {
    return storedUser;
  }

  @override
  DateTime? get expiration => storedExpiration;

  @override
  String? getAccessToken() {
    return accessToken;
  }

  @override
  String? getRefreshToken() {
    return refreshToken;
  }

  @override
  void setAccessToken(String? token) {
    accessToken = token;
  }

  @override
  void setRefreshToken(String? token) {
    refreshToken = token;
  }

  @override
  void setExpiresIn(int? expiresIn) {
    storedExpiration = expiresIn == null ? null : DateTime.now().toUtc().add(Duration(seconds: expiresIn));
  }

  @override
  void setExpiration(DateTime? expiration) {
    storedExpiration = expiration;
  }
}
