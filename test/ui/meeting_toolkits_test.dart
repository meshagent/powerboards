import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/livekit/room.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:powerboards/ui/meeting_view.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _ProtocolPair {
  _ProtocolPair() {
    serverProtocol = Protocol(
      channel: StreamProtocolChannel(input: _clientToServer.stream, output: _serverToClient.sink),
    );
  }

  final _clientToServer = StreamController<Uint8List>();
  final _serverToClient = StreamController<Uint8List>();
  Protocol? _clientProtocol;
  late final Protocol serverProtocol;

  Protocol clientProtocolFactory() {
    final existing = _clientProtocol;
    if (existing != null) {
      throw ProtocolReconnectUnsupportedException('protocolFactory was not configured for reconnecting this protocol');
    }

    final protocol = Protocol(
      channel: StreamProtocolChannel(input: _serverToClient.stream, output: _clientToServer.sink),
    );
    _clientProtocol = protocol;
    return protocol;
  }

  Future<void> dispose() async {
    try {
      _clientProtocol?.dispose();
    } catch (_) {}
    try {
      serverProtocol.dispose();
    } catch (_) {}
    unawaited(_clientToServer.close());
    if (!_serverToClient.isClosed) {
      unawaited(_serverToClient.close());
    }
  }
}

class _ToolkitHarness {
  _ToolkitHarness({required this.pair, required this.room});

  final _ProtocolPair pair;
  final RoomClient room;
  final invokeRequests = <Map<String, dynamic>>[];
  Map<String, dynamic> toolkits = {};
  Completer<void>? pauseNextInvoke;

  Future<void> sendRoomReady() async {
    await pair.serverProtocol.send(
      'room_ready',
      packMessage({'room_name': 'test-room', 'room_url': 'ws://example/rooms/test-room', 'session_id': 'session-1'}),
    );
    await pair.serverProtocol.send(
      'connected',
      packMessage({
        'type': 'init',
        'participantId': 'self',
        'attributes': {'name': 'self'},
      }),
    );
  }

  Future<void> enableTranscriberParticipant({bool transcribing = false}) async {
    await sendIncomingMessage(
      type: 'messaging.enabled',
      fromParticipantId: 'transcriber',
      message: {
        'participants': [
          {
            'id': 'transcriber',
            'role': 'agent',
            'attributes': {'name': 'Transcriber', 'transcribing.': transcribing},
          },
        ],
      },
    );
  }

  Future<void> setTranscribing(bool transcribing) async {
    await sendIncomingMessage(
      type: 'participant.attributes',
      fromParticipantId: 'transcriber',
      message: {
        'attributes': {'transcribing.': transcribing},
      },
    );
  }

  Future<void> sendIncomingMessage({required String type, required String fromParticipantId, required Map<String, dynamic> message}) async {
    await pair.serverProtocol.send(
      'messaging.send',
      packMessage({'from_participant_id': fromParticipantId, 'type': type, 'message': message}),
    );
  }

  Future<void> dispose() async {
    room.dispose();
    await pair.dispose();
  }
}

Map<String, dynamic> _transcriptionToolkit() {
  return {
    'title': 'Transcription',
    'description': 'Meeting transcription',
    'tools': {
      'start_transcription': {'title': 'Start transcription', 'description': 'Start transcription'},
      'stop_transcription': {'title': 'Stop transcription', 'description': 'Stop transcription'},
    },
  };
}

Future<_ToolkitHarness> _startHarness() async {
  final pair = _ProtocolPair();
  final room = RoomClient(protocolFactory: pair.clientProtocolFactory);
  final harness = _ToolkitHarness(pair: pair, room: room);

  pair.serverProtocol.start(
    onMessage: (protocol, messageId, type, data) async {
      if (type == 'room.list_toolkits') {
        await protocol.send('__response__', JsonContent(json: {'tools': harness.toolkits}).pack(), id: messageId);
        return;
      }

      if (type == 'room.invoke_tool') {
        final request = Map<String, dynamic>.from(unpackMessage(data).header);
        if (request['toolkit'] == 'messaging') {
          await protocol.send('__response__', EmptyContent().pack(), id: messageId);
          return;
        }

        harness.invokeRequests.add(request);
        final pause = harness.pauseNextInvoke;
        harness.pauseNextInvoke = null;
        if (pause != null) {
          await pause.future;
        }
        await protocol.send('__response__', EmptyContent().pack(), id: messageId);
      }
    },
  );

  final startFuture = room.start();
  await harness.sendRoomReady();
  await startFuture;
  await room.messaging.enable();
  return harness;
}

Future<void> _pumpMeetingToolkits(
  WidgetTester tester,
  _ToolkitHarness harness, {
  bool canInstallTranscriber = true,
  bool transcriberInstalled = false,
}) async {
  await tester.pumpWidget(
    ShadApp(
      home: Scaffold(
        body: MeetingToolkits(
          room: harness.room,
          desktopV1Style: true,
          roomName: 'test-room',
          projectId: 'project',
          canInstallTranscriber: canInstallTranscriber,
          transcriberInstalled: transcriberInstalled,
        ),
      ),
    ),
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition, {Duration timeout = const Duration(seconds: 1)}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('condition was not met before timeout');
    }
    await tester.pump(const Duration(milliseconds: 10));
  }
}

MeetV1ToolbarButton _toolbarButton(WidgetTester tester) {
  return tester.widget<MeetV1ToolbarButton>(find.byType(MeetV1ToolbarButton));
}

void main() {
  testWidgets('hides v1 transcriber install control when toolkit is missing and user cannot install', (tester) async {
    final harness = await _startHarness();
    addTearDown(harness.dispose);

    await _pumpMeetingToolkits(tester, harness, canInstallTranscriber: false);
    await tester.pump();

    expect(find.byType(MeetV1ToolbarButton), findsNothing);
    expect(find.byTooltip('Enable transcription'), findsNothing);
  });

  testWidgets('shows v1 transcriber install control when toolkit is missing and user can install', (tester) async {
    final harness = await _startHarness();
    addTearDown(harness.dispose);

    await _pumpMeetingToolkits(tester, harness);
    await _pumpUntil(tester, () => find.byTooltip('Enable transcription').evaluate().isNotEmpty);

    expect(find.byType(MeetV1ToolbarButton), findsOneWidget);
    expect(find.byTooltip('Enable transcription'), findsOneWidget);
    final button = _toolbarButton(tester);
    expect(button.label, 'Enable transcription');
    expect(button.iconAssetName, 'grid-2x2-plus');
    expect(button.backgroundColor, PbColors.surfacePanel);
    expect(button.foregroundColor, PbColors.textPrimary);
    expect(button.borderColor, button.backgroundColor);
    expect(button.onPressed, isNotNull);
  });

  testWidgets('shows preparing state instead of install when transcriber is installed but toolkit is not ready', (tester) async {
    final harness = await _startHarness();
    addTearDown(harness.dispose);

    await _pumpMeetingToolkits(tester, harness, transcriberInstalled: true);
    await _pumpUntil(tester, () => find.byTooltip('Preparing transcriber agent').evaluate().isNotEmpty);

    expect(find.text('Transcribe'), findsNothing);
    expect(find.byTooltip('Preparing transcriber agent'), findsOneWidget);
  });

  testWidgets('serializes v1 transcribe start until room state catches up', (tester) async {
    final harness = await _startHarness();
    addTearDown(harness.dispose);
    harness.toolkits = {'transcription': _transcriptionToolkit()};
    final invokePause = Completer<void>();
    harness.pauseNextInvoke = invokePause;

    await harness.enableTranscriberParticipant();
    await _pumpMeetingToolkits(tester, harness, transcriberInstalled: true);
    await _pumpUntil(tester, () => find.byTooltip('Start transcription').evaluate().isNotEmpty);

    await tester.tap(find.byTooltip('Start transcription'));
    await tester.pump();
    await _pumpUntil(tester, () => harness.invokeRequests.length == 1);

    expect(harness.invokeRequests.single['tool'], 'start_transcription');
    expect(find.byTooltip('Stop transcription'), findsOneWidget);
    expect(_toolbarButton(tester).loading, isTrue);

    await tester.tap(find.byTooltip('Stop transcription'));
    await tester.pump();
    expect(harness.invokeRequests, hasLength(1));

    invokePause.complete();
    await tester.pump();
    await harness.setTranscribing(true);
    await tester.pump();

    expect(_toolbarButton(tester).loading, isFalse);
  });

  testWidgets('serializes v1 transcribe stop until room state catches up', (tester) async {
    final harness = await _startHarness();
    addTearDown(harness.dispose);
    harness.toolkits = {'transcription': _transcriptionToolkit()};
    final invokePause = Completer<void>();
    harness.pauseNextInvoke = invokePause;

    await harness.enableTranscriberParticipant(transcribing: true);
    await _pumpMeetingToolkits(tester, harness, transcriberInstalled: true);
    await _pumpUntil(tester, () => find.byTooltip('Stop transcription').evaluate().isNotEmpty);

    await tester.tap(find.byTooltip('Stop transcription'));
    await tester.pump();
    await _pumpUntil(tester, () => harness.invokeRequests.length == 1);

    expect(harness.invokeRequests.single['tool'], 'stop_transcription');
    expect(find.byTooltip('Start transcription'), findsOneWidget);
    expect(_toolbarButton(tester).loading, isTrue);

    await tester.tap(find.byTooltip('Start transcription'));
    await tester.pump();
    expect(harness.invokeRequests, hasLength(1));

    invokePause.complete();
    await tester.pump();
    await harness.setTranscribing(false);
    await tester.pump();

    expect(_toolbarButton(tester).loading, isFalse);
  });
}
