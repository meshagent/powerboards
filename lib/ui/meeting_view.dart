import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:meshagent/meshagent.dart';
import 'package:powerboards/powerboards_controller/powerboards_controller.dart';

import 'package:powerboards/nav/nav.dart';
import 'package:powerboards/livekit/camera_grid.dart';
import 'package:powerboards/livekit/camera_strip.dart';
import 'package:powerboards/livekit/device_preview.dart';
import 'package:powerboards/livekit/room.dart';
import 'package:powerboards/livekit/video_room_participants_builder.dart';

// import 'meeting_body.dart';

enum MeetingViewState { preview, joined, ended }

class MeetingViewController extends Controller {
  MeetingViewState _state = MeetingViewState.preview;

  MeetingViewState get state => _state;

  void enterMeeting() {
    _state = MeetingViewState.joined;
    notifyListeners();
  }

  void endMeeting() {
    _state = MeetingViewState.ended;
    notifyListeners();
  }

  void resetToLobby() {
    _state = MeetingViewState.preview;
    notifyListeners();
  }
}

class MeetingView extends StatelessWidget {
  const MeetingView({super.key, required this.room, required this.onCancel, required this.joinMeeting, this.agentName});

  final String? agentName;

  final RoomClient room;
  final VoidCallback onCancel;
  final void Function() joinMeeting;

  Widget _cameraStripBuilder(BuildContext context, bool horizontal) {
    final room = VideoRoomModel.maybeOf(context)?.room;
    if (room == null) return const SizedBox.shrink();

    return VideoRoomParticipantsBuilder(
      room: room,
      builder: (context, participants) {
        final hasShare = participants.any(
          (p) => p.videoTrackPublications.any((t) => t.source == lk.TrackSource.screenShareVideo && !t.muted && t.track != null),
        );

        if (!hasShare) return const SizedBox.shrink();

        return SizedBox(
          width: horizontal ? null : 250,
          height: horizontal ? 100 : null,
          child: Padding(
            padding: EdgeInsets.fromLTRB(5, 0, horizontal ? 0 : 5, horizontal ? 5 : 0),
            child: CameraStrip(room: room, horizontal: horizontal),
          ),
        );
      },
    );
  }

  Widget _mainBuilder(BuildContext context) {
    final room = VideoRoomModel.maybeOf(context)?.room;
    if (room == null) return const SizedBox();

    return VideoRoomParticipantsBuilder(room: room, builder: (context, participants) => cameraGridBuilder(context, participants));
  }

  @override
  Widget build(BuildContext context) {
    final meetingViewController = Controller.ofType<MeetingViewController>(context);

    return ControllerBuilder(
      controller: meetingViewController,
      builder: (BuildContext context) {
        final videoRoom = VideoRoomModel.maybeOf(context)?.room;
        final inPreview =
            meetingViewController.state == MeetingViewState.preview ||
            (videoRoom == null && meetingViewController.state == MeetingViewState.joined);

        if (inPreview) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: DevicePreview(
              onJoin: (enableVideo, enableAudio) {
                final videoChatConnection = context.findAncestorStateOfType<VideoChatConnectionState>();
                final navController = Controller.ofType<NavController>(context);

                if (videoChatConnection != null) {
                  videoChatConnection.setRoomFromDoc("", room, "", video: enableVideo, audio: enableAudio, agentID: null);
                }

                meetingViewController.enterMeeting();
                navController.hideNav();
              },
              onCancel: onCancel,
            ),
          );
        } else if (meetingViewController.state == MeetingViewState.joined) {
          final isMobile = ResponsiveBreakpoints.of(context).isMobile;
          return isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _cameraStripBuilder(context, true),
                    Expanded(child: _mainBuilder(context)),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _mainBuilder(context)),
                    _cameraStripBuilder(context, false),
                  ],
                );
        } else if (meetingViewController.state == MeetingViewState.ended) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Meeting ended", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 20),
                ShadButton(
                  onPressed: () {
                    meetingViewController.resetToLobby();
                  },
                  child: Text("Back to lobby"),
                ),
              ],
            ),
          );
        }

        return const Text("Unknown state");
      },
    );
  }
}

class MeetingToolkits extends StatefulWidget {
  const MeetingToolkits({super.key, required this.room, this.breakoutRoom = ""});

  final RoomClient room;
  final String breakoutRoom;

  @override
  State createState() => _MeetingActions();
}

class _MeetingActions extends State<MeetingToolkits> {
  late final toolkits = Resource<List<ToolkitDescription>>(() => widget.room.agents.listToolkits());
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(Duration(seconds: 10), (_) {
      toolkits.refresh();
    });
    widget.room.messaging.addListener(onRoomMessage);
  }

  void onRoomMessage() {
    setState(() {});
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.room.messaging.removeListener(onRoomMessage);
    super.dispose();
  }

  Timer? timer;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, _) {
        if (!toolkits.state.isReady) {
          return SizedBox();
        }
        final transcription = toolkits.state.value!.firstWhereOrNull((x) => x.name == "transcription");
        final startRecording = transcription?.tools.firstWhereOrNull((x) => x.name == "start_transcription");
        final stopRecording = transcription?.tools.firstWhereOrNull((x) => x.name == "stop_transcription");

        final transcribing =
            widget.room.messaging.remoteParticipants.firstWhereOrNull(
              (p) => p.getAttribute("transcribing.${widget.breakoutRoom}") == true,
            ) !=
            null;

        return Row(
          spacing: 8,
          children: [
            if (startRecording != null && !transcribing)
              ShadButton.outline(
                leading: Icon(LucideIcons.captions),

                onPressed: () async {
                  widget.room.agents.invokeTool(
                    toolkit: transcription!.name,
                    tool: startRecording.name,
                    input: ToolContentInput(
                      JsonContent(
                        json: {"breakout_room": "", "path": "transcripts/meetings/${DateTime.now().toIso8601String()}.transcript"},
                      ),
                    ),
                  );
                },
                child: Text("Start Transcription"),
              ),

            if (stopRecording != null && transcribing)
              ShadButton.outline(
                leading: Icon(LucideIcons.captionsOff),

                onPressed: () async {
                  widget.room.agents.invokeTool(
                    toolkit: transcription!.name,
                    tool: stopRecording.name,
                    input: ToolContentInput(JsonContent(json: {"breakout_room": ""})),
                  );
                },
                child: Text("Stop Transcription"),
              ),
          ],
        );
      },
    );
  }
}
