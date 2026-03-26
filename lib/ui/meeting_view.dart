import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:meshagent/meshagent.dart';

import 'package:powerboards/livekit/camera_grid.dart';
import 'package:powerboards/livekit/camera_strip.dart';
import 'package:powerboards/livekit/device_preview.dart';
import 'package:powerboards/livekit/expand_participant_controller.dart';
import 'package:powerboards/livekit/room.dart';
import 'package:powerboards/livekit/video_room_participants_builder.dart';
import 'package:powerboards/nav/nav.dart';
import 'package:powerboards/powerboards_controller/powerboards_controller.dart';

const _railGap = 16.0;
const _compactControlWidth = 48.0;

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

class MeetingView extends StatefulWidget {
  const MeetingView({super.key, required this.room, required this.onCancel, required this.joinMeeting, this.agentName});

  final String? agentName;

  final RoomClient room;
  final VoidCallback onCancel;
  final void Function() joinMeeting;

  @override
  State createState() => _MeetingViewState();
}

class _MeetingViewState extends State<MeetingView> {
  final expandParticipantController = ExpandParticipantController();

  lk.VideoTrack? _screenShareTrackFor(lk.Participant participant) {
    final publication = participant.getTrackPublicationBySource(lk.TrackSource.screenShareVideo);
    final track = publication?.track;

    if (publication == null || publication.muted || track is! lk.VideoTrack) {
      return null;
    }

    return track;
  }

  bool _participantHasActiveShare(lk.Participant participant) {
    return _screenShareTrackFor(participant) != null;
  }

  Widget _mobileLayout(lk.Room room, List<lk.Participant> participants, bool hasShare) {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        if (hasShare)
          SizedBox(
            height: 100,
            child: Padding(
              padding: .fromLTRB(5, 0, 0, 5),
              child: CameraStrip(room: room, horizontal: true),
            ),
          ),

        Expanded(child: ExpandableCameraGrid(participants: participants)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final meetingViewController = Controller.ofType<MeetingViewController>(context);

    return ControllerProvider<ExpandParticipantController>(
      controller: expandParticipantController,
      child: ControllerBuilder(
        controller: meetingViewController,
        builder: (BuildContext context) {
          final videoRoom = VideoRoomModel.maybeOf(context)?.room;
          final inPreview =
              meetingViewController.state == MeetingViewState.preview ||
              (videoRoom == null && meetingViewController.state == MeetingViewState.joined);

          if (inPreview) {
            return Padding(
              padding: const .symmetric(horizontal: 20.0),
              child: DevicePreview(
                onJoin: (enableVideo, enableAudio) {
                  final videoChatConnection = context.findAncestorStateOfType<VideoChatConnectionState>();
                  final navController = Controller.ofType<NavController>(context);

                  if (videoChatConnection != null) {
                    videoChatConnection.setRoomFromDoc("", widget.room, "", video: enableVideo, audio: enableAudio, agentID: null);
                  }

                  meetingViewController.enterMeeting();
                  navController.hideNav();
                },
                onCancel: widget.onCancel,
              ),
            );
          } else if (meetingViewController.state == MeetingViewState.joined) {
            final room = VideoRoomModel.maybeOf(context)?.room;
            if (room == null) return const SizedBox.shrink();

            return Padding(
              padding: const .all(20),
              child: VideoRoomParticipantsBuilder(
                room: room,
                builder: (context, participants) {
                  return ControllerBuilder<ExpandParticipantController>(
                    controller: expandParticipantController,
                    builder: (context) {
                      final isMobile = ResponsiveBreakpoints.of(context).isMobile;
                      final hasShare = participants.any(_participantHasActiveShare);

                      if (isMobile) {
                        return _mobileLayout(room, participants, hasShare);
                      }

                      if (hasShare) {
                        return _DesktopShareLayout(room: room, participants: participants);
                      }

                      return ExpandableCameraGrid(participants: participants);
                    },
                  );
                },
              ),
            );
          } else if (meetingViewController.state == MeetingViewState.ended) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 20,
                children: [
                  Text("Meeting ended", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      ),
    );
  }
}

class _DesktopShareLayout extends StatelessWidget {
  const _DesktopShareLayout({required this.room, required this.participants});

  final lk.Room room;
  final List<lk.Participant> participants;

  Iterable<lk.TrackPublication> getSharePublications(List<lk.Participant> participants) sync* {
    for (final participant in participants) {
      final publication = participant.getTrackPublicationBySource(lk.TrackSource.screenShareVideo);

      if (publication != null && !publication.muted && publication.track is lk.VideoTrack) {
        yield publication;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expandController = Controller.ofType<ExpandParticipantController>(context);
    final sharePublications = getSharePublications(participants).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        bool stripOnLeft = true;
        if (sharePublications.length == 1) {
          final track = sharePublications.first;
          final dimensions = track.dimensions;

          if (dimensions != null) {
            stripOnLeft = dimensions.width <= dimensions.height;
          }
        }

        if (stripOnLeft) {
          return Row(
            crossAxisAlignment: .start,
            spacing: _railGap,
            children: [
              Expanded(child: ExpandableCameraGrid(participants: participants)),

              if (!expandController.hasExpanded)
                SizedBox(
                  width: 250.0,
                  child: CameraStrip(room: room, horizontal: false, participants: participants),
                ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: .stretch,
          spacing: _railGap,
          children: [
            if (!expandController.hasExpanded)
              SizedBox(
                height: 100.0,
                child: CameraStrip(room: room, horizontal: true, participants: participants),
              ),

            Expanded(child: ExpandableCameraGrid(participants: participants)),
          ],
        );
      },
    );
  }
}

class MeetingToolkits extends StatefulWidget {
  const MeetingToolkits({super.key, required this.room, this.breakoutRoom = "", this.compact = false});

  final RoomClient room;
  final String breakoutRoom;
  final bool compact;

  @override
  State createState() => _MeetingToolkitsState();
}

class _MeetingToolkitsState extends State<MeetingToolkits> {
  Timer? timer;

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

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (startRecording != null && !transcribing)
              Tooltip(
                message: "Start Transcription",
                child: SizedBox(
                  width: widget.compact ? _compactControlWidth : null,
                  child: ShadButton.outline(
                    padding: widget.compact ? const EdgeInsets.symmetric(horizontal: 0) : null,
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
                    child: widget.compact ? null : Text("Start Transcription"),
                  ),
                ),
              ),

            if (stopRecording != null && transcribing)
              Tooltip(
                message: "Stop Transcription",
                child: SizedBox(
                  width: widget.compact ? _compactControlWidth : null,
                  child: ShadButton.outline(
                    padding: widget.compact ? const EdgeInsets.symmetric(horizontal: 0) : null,
                    leading: Icon(LucideIcons.captionsOff),
                    onPressed: () async {
                      widget.room.agents.invokeTool(
                        toolkit: transcription!.name,
                        tool: stopRecording.name,
                        input: ToolContentInput(JsonContent(json: {"breakout_room": ""})),
                      );
                    },
                    child: widget.compact ? null : Text("Stop Transcription"),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
