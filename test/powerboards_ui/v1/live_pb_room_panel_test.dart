import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_agents/meshagent_agents.dart';
import 'package:powerboards/chat/meshagent_room.dart';
import 'package:uuid/uuid.dart';

class _TracingMessagingChatClient extends MessagingChatClient {
  _TracingMessagingChatClient({required super.room, super.agentName});

  @override
  Future<void> sendAgentMessage(AgentMessage message, {Uint8List? attachment, bool ignoreOffline = false}) async {
    // ignore: avoid_print
    print(
      '[TRACE sendAgentMessage] type=${message.type} id=${message.messageId} '
      'json=${jsonEncode(message.toJson())}',
    );
    return super.sendAgentMessage(message, attachment: attachment, ignoreOffline: ignoreOffline);
  }
}

class _PowerboardsTestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final file = File(key).existsSync() ? File(key) : File('powerboards/$key');
    if (!file.existsSync()) {
      throw FlutterError('Unable to load test asset: $key');
    }
    final bytes = await file.readAsBytes();
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

String? get _liveSkipReason {
  final missing = <String>[if ((Platform.environment['MESHAGENT_API_URL'] ?? '').isEmpty) 'MESHAGENT_API_URL'];
  if (missing.isEmpty) {
    return null;
  }
  return 'Live Powerboards thread panel tests require ${missing.join(', ')}.';
}

String get _liveRoomName => (Platform.environment['MESHAGENT_LIVE_AGENT_ROOM'] ?? '').trim().isNotEmpty
    ? Platform.environment['MESHAGENT_LIVE_AGENT_ROOM']!.trim()
    : 'jesse';

String get _liveAgentName => (Platform.environment['MESHAGENT_LIVE_AGENT_NAME'] ?? '').trim().isNotEmpty
    ? Platform.environment['MESHAGENT_LIVE_AGENT_NAME']!.trim()
    : 'assistant';

Future<RoomClient> _newRoomClient({required String roomName, required String participantName}) async {
  final envToken = Platform.environment['MESHAGENT_TOKEN'];
  if (envToken != null && envToken.trim().isNotEmpty) {
    final baseUrl = Platform.environment['MESHAGENT_API_URL']!;
    final url = Uri.parse('${baseUrl.replaceFirst(RegExp(r'^http'), 'ws')}/rooms/$roomName');
    return RoomClient(
      protocolFactory: WebSocketClientProtocol.createFactory(url: url, token: envToken.trim()),
      reconnectTimeout: Duration.zero,
    );
  }

  final connection = await _connectRoomFromLocalSettings(roomName: roomName, participantName: participantName);
  return RoomClient(
    protocolFactory: WebSocketClientProtocol.createFactory(url: Uri.parse(connection.roomUrl), token: connection.jwt),
    reconnectTimeout: Duration.zero,
  );
}

Future<({String jwt, String roomUrl})> _connectRoomFromLocalSettings({required String roomName, required String participantName}) async {
  final settingsFile = File('${Platform.environment['HOME']}/.meshagent/settings.json');
  if (!settingsFile.existsSync()) {
    fail('MESHAGENT_TOKEN is not set and ~/.meshagent/settings.json does not exist.');
  }

  final settings = jsonDecode(await settingsFile.readAsString()) as Map<String, dynamic>;
  final users = settings['users'];
  if (users is! Map || users.isEmpty) {
    fail('MESHAGENT_TOKEN is not set and ~/.meshagent/settings.json has no users.');
  }

  final activeUserId = settings['active_user_id'];
  final user = activeUserId is String && users[activeUserId] is Map
      ? Map<String, dynamic>.from(users[activeUserId] as Map)
      : Map<String, dynamic>.from(users.values.first as Map);
  final session = user['session'] is Map ? Map<String, dynamic>.from(user['session'] as Map) : const <String, dynamic>{};
  final project = user['project'] is Map ? Map<String, dynamic>.from(user['project'] as Map) : const <String, dynamic>{};
  final accessToken = session['access_token'];
  final projectId = Platform.environment['MESHAGENT_PROJECT_ID'] ?? project['active_project'];
  final baseUrl = Platform.environment['MESHAGENT_API_URL'] ?? user['api_url'];

  if (accessToken is! String || accessToken.trim().isEmpty) {
    fail('MESHAGENT_TOKEN is not set and the active MeshAgent CLI session has no access token.');
  }
  if (projectId is! String || projectId.trim().isEmpty) {
    fail('MESHAGENT_PROJECT_ID is not set and the active MeshAgent CLI settings have no active project.');
  }
  if (baseUrl is! String || baseUrl.trim().isEmpty) {
    fail('MESHAGENT_API_URL is not set and the active MeshAgent CLI settings have no api_url.');
  }

  final uri = Uri.parse(
    '${baseUrl.trim().replaceFirst(RegExp(r'/$'), '')}/accounts/projects/${Uri.encodeComponent(projectId.trim())}/rooms/${Uri.encodeComponent(roomName)}/connect',
  );
  final response = await http
      .post(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer ${accessToken.trim()}',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{'client': participantName}),
      )
      .timeout(const Duration(seconds: 15));
  if (response.statusCode >= 400) {
    fail('Failed to connect room $roomName in project $projectId. Status ${response.statusCode}: ${response.body}');
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  final jwt = json['jwt'];
  final roomUrl = json['room_url'];
  if (jwt is! String || jwt.trim().isEmpty || roomUrl is! String || roomUrl.trim().isEmpty) {
    fail('Room connect response did not include jwt and room_url.');
  }
  return (jwt: jwt.trim(), roomUrl: roomUrl.trim());
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
  String description = 'condition',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('$description was not met before timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

Future<void> _waitForWidget(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(milliseconds: 900),
  String description = 'widget',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('$description was not found before timeout');
    }
    await tester.pump(const Duration(milliseconds: 25));
  }
}

Future<T> _liveStep<T>(String label, Future<T> future, {Duration timeout = const Duration(seconds: 15)}) async {
  try {
    return await future.timeout(timeout);
  } on TimeoutException {
    fail('$label did not complete within ${timeout.inMilliseconds}ms');
  }
}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('live Powerboards desktop preview thread panel', skip: _liveSkipReason, () {
    testWidgets('shows a newly-created dataset thread without remounting the threads panel', (tester) async {
      final roomName = _liveRoomName;
      final agentName = _liveAgentName;
      final participantName = 'powerboards-live-panel-${const Uuid().v4()}';
      final room = (await tester.runAsync(
        () => _liveStep(
          'connect room $roomName',
          _newRoomClient(roomName: roomName, participantName: participantName),
          timeout: const Duration(seconds: 20),
        ),
      ))!;
      final chatClient = _TracingMessagingChatClient(room: room, agentName: agentName);
      final traceSubscriptions = <StreamSubscription<dynamic>>[];
      addTearDown(() async {
        for (final subscription in traceSubscriptions) {
          await subscription.cancel();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await chatClient.stop().catchError((_) {});
        room.dispose();
      });

      await tester.runAsync(() async {
        await _liveStep('room.start for $roomName', room.start(), timeout: const Duration(seconds: 15));
        room.messaging.start();
        await _liveStep('room.messaging.enable for $roomName', room.messaging.enable(), timeout: const Duration(seconds: 10));
        await _waitUntil(
          () => room.messaging.remoteParticipants.any(
            (participant) => participant.getAttribute('name') == agentName && participant.getAttribute('supports_agent_messages') == true,
          ),
          timeout: const Duration(seconds: 30),
          description: 'agent participant $agentName in room $roomName',
        );
        await _liveStep('chatClient.start for $agentName', chatClient.start(), timeout: const Duration(seconds: 10));
      });

      traceSubscriptions.add(
        room.listen((event) {
          if (event is! RoomMessageEvent) {
            return;
          }
          if (event.message.type != agentRoomMessageType) {
            return;
          }
          final raw = event.message.message;
          Object? type;
          if (raw is Map) {
            type = raw['type'];
            final payload = raw['payload'];
            if (type == null && payload is Map) {
              type = payload['type'];
            }
          }
          // ignore: avoid_print
          print(
            '[TRACE room agent-message] from=${event.message.fromParticipantId} '
            'type=$type raw=${jsonEncode(raw)}',
          );
        }),
      );
      traceSubscriptions.add(
        chatClient.events.listen((event) {
          final message = event.message;
          String details = '';
          if (message is ThreadCreated) {
            details = ' path=${message.thread.path} name=${message.thread.name}';
          } else if (message is ThreadUpdated) {
            details = ' path=${message.thread.path} name=${message.thread.name}';
          } else if (message is ThreadDeleted) {
            details = ' path=${message.path}';
          } else if (message is ThreadsListed) {
            details = ' source=${message.sourceMessageId} count=${message.threads.length}';
          } else if (message is ThreadStarted) {
            details = ' source=${message.sourceMessageId} thread=${message.threadId}';
          }
          // ignore: avoid_print
          print('[TRACE chatClient event] type=${message.type}$details');
        }),
      );

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _PowerboardsTestAssetBundle(),
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 360,
                  height: 720,
                  child: PowerboardsDesktopPreviewThreadListHarness(
                    client: room,
                    agentName: agentName,
                    threadListPath: 'agent://threads',
                    chatClientFactory: (_, _) => chatClient,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _waitForWidget(
        tester,
        find.text('Threads'),
        timeout: const Duration(seconds: 5),
        description: 'initial Powerboards threads panel',
      );

      final expectedThreadTitle = 'Live Powerboards Generated ${DateTime.now().microsecondsSinceEpoch}';
      expect(find.text(expectedThreadTitle), findsNothing);

      final result = await tester.runAsync(
        () => _liveStep(
          'chatClient.startThread for $expectedThreadTitle',
          chatClient.startThread(
            messageId: 'powerboards-live-panel-${DateTime.now().millisecondsSinceEpoch}',
            message: '$expectedThreadTitle.',
            attachments: const <AgentFileContent>[],
            outputModalities: const ['text'],
            senderName: participantName,
          ),
          timeout: const Duration(seconds: 45),
        ),
      );
      expect(result, isNotNull);

      await _waitForWidget(
        tester,
        find.text(expectedThreadTitle),
        timeout: const Duration(milliseconds: 900),
        description: 'Powerboards thread panel entry for ${result!.threadPath} less than one second after startThread returned',
      );
      await tester.pump();

      expect(find.text('Agents'), findsOneWidget);
      expect(find.text('Threads'), findsOneWidget);
      expect(find.text(expectedThreadTitle), findsOneWidget);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
