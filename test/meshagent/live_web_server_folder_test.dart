import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/client.dart' as meshagent_client;
import 'package:meshagent/protocol.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:powerboards/meshagent/agent_containers.dart';

const String _runLiveEnvVar = 'POWERBOARDS_RUN_LIVE_WEB_SERVER_FOLDER_TEST';

String? get _liveSkipReason {
  if (Platform.environment[_runLiveEnvVar] != 'true') {
    return 'Set $_runLiveEnvVar=true to run the live website folder regression test.';
  }

  try {
    _loadLiveSession();
    return null;
  } catch (error) {
    return '$error';
  }
}

({String apiUrl, String token, String projectId}) _loadLiveSession() {
  final envToken = (Platform.environment['MESHAGENT_TOKEN'] ?? '').trim();
  final envApiUrl = (Platform.environment['MESHAGENT_API_URL'] ?? '').trim();
  final envProjectId = (Platform.environment['MESHAGENT_PROJECT_ID'] ?? '').trim();
  if (envToken.isNotEmpty && envApiUrl.isNotEmpty && envProjectId.isNotEmpty) {
    return (apiUrl: envApiUrl, token: envToken, projectId: envProjectId);
  }

  final settingsFile = File('${Platform.environment['HOME']}/.meshagent/settings.json');
  if (!settingsFile.existsSync()) {
    throw StateError('Live test requires MESHAGENT_* env vars or ~/.meshagent/settings.json.');
  }

  final settings = jsonDecode(settingsFile.readAsStringSync()) as Map<String, dynamic>;
  final users = settings['users'];
  if (users is! Map || users.isEmpty) {
    throw StateError('~/.meshagent/settings.json does not contain any users.');
  }

  final activeUserId = settings['active_user_id'];
  final user = activeUserId is String && users[activeUserId] is Map
      ? Map<String, dynamic>.from(users[activeUserId] as Map)
      : Map<String, dynamic>.from(users.values.first as Map);
  final session = user['session'] is Map ? Map<String, dynamic>.from(user['session'] as Map) : const <String, dynamic>{};
  final project = user['project'] is Map ? Map<String, dynamic>.from(user['project'] as Map) : const <String, dynamic>{};

  final accessToken = (session['access_token'] as String?)?.trim() ?? '';
  final projectId = (Platform.environment['MESHAGENT_PROJECT_ID'] ?? project['active_project'] ?? '').toString().trim();
  final apiUrl = (Platform.environment['MESHAGENT_API_URL'] ?? user['api_url'] ?? '').toString().trim();

  if (accessToken.isEmpty) {
    throw StateError('The active Meshagent session does not include an access token.');
  }
  if (projectId.isEmpty) {
    throw StateError('The active Meshagent session does not include an active project.');
  }
  if (apiUrl.isEmpty) {
    throw StateError('The active Meshagent session does not include an API URL.');
  }

  return (apiUrl: apiUrl, token: accessToken, projectId: projectId);
}

void main() {
  group('live website folder lifecycle', skip: _liveSkipReason, () {
    test('creates the website folder placeholder when the web service is installed outside Files', () async {
      final session = _loadLiveSession();
      final client = meshagent_client.Meshagent(baseUrl: session.apiUrl, token: session.token);
      final roomName = 'pb-web-folder-${DateTime.now().millisecondsSinceEpoch}';
      meshagent_client.Room? room;
      RoomClient? roomClient;

      try {
        room = await client.createRoom(
          projectId: session.projectId,
          name: roomName,
          metadata: <String, dynamic>{'displayName': 'Powerboards live website folder test'},
        );

        await powerboardsEnsureWebServerFolderExists(client: client, projectId: session.projectId, roomName: roomName);

        final connection = await client.connectRoom(projectId: session.projectId, roomName: roomName);
        roomClient = RoomClient(
          protocolFactory: WebSocketClientProtocol.createFactory(url: connection.roomUrl, token: connection.jwt),
          reconnectTimeout: Duration.zero,
        );
        roomClient.start();
        await roomClient.ready.timeout(const Duration(seconds: 15));

        expect(await roomClient.storage.exists(powerboardsWebServerFolderName), isTrue);
        expect(await roomClient.storage.exists('$powerboardsWebServerFolderName/$powerboardsStorageFolderPlaceholderFileName'), isTrue);

        await powerboardsEnsureWebServerFolderExists(client: client, projectId: session.projectId, roomName: roomName);

        expect(await roomClient.storage.exists(powerboardsWebServerFolderName), isTrue);
        expect(await roomClient.storage.exists('$powerboardsWebServerFolderName/$powerboardsStorageFolderPlaceholderFileName'), isTrue);
      } finally {
        roomClient?.dispose();
        if (room != null) {
          await client.deleteRoom(projectId: session.projectId, roomId: room.id);
        }
        client.httpClient.close();
      }
    });
  });
}
