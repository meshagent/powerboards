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

const Color _meetingSurfaceColor = Color(0xFF222222);

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

  Widget _cameraStripBuilder(lk.Room room, bool horizontal, List<lk.Participant> participants) {
    final hasShare = participants.any(_participantHasActiveShare);

    if (!hasShare) return const SizedBox.shrink();

    return SizedBox(
      width: horizontal ? null : 250,
      height: horizontal ? 100 : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(5, 0, horizontal ? 0 : 5, horizontal ? 5 : 0),
        child: CameraStrip(room: room, horizontal: horizontal),
      ),
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
            return DevicePreview(
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
            );
          } else if (meetingViewController.state == MeetingViewState.joined) {
            final room = VideoRoomModel.maybeOf(context)?.room;
            if (room == null) return const SizedBox.shrink();

            return VideoRoomParticipantsBuilder(
              room: room,
              builder: (context, participants) {
                return ControllerBuilder<ExpandParticipantController>(
                  controller: expandParticipantController,
                  builder: (context) {
                    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
                    final hasShare = participants.any(_participantHasActiveShare);

                    if (hasShare && !isMobile) {
                      return _DesktopShareLayout(room: room, participants: participants);
                    }

                    return ColoredBox(
                      color: _meetingSurfaceColor,
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: .stretch,
                              children: [
                                _cameraStripBuilder(room, true, participants),
                                Expanded(child: ExpandableCameraGrid(participants: participants)),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: .stretch,
                              children: [
                                Expanded(child: ExpandableCameraGrid(participants: participants)),
                                _cameraStripBuilder(room, false, participants),
                              ],
                            ),
                    );
                  },
                );
              },
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

const _outerPadding = 24.0;
const _railWidth = 158.4;
const _railGap = 16.0;
const _shareAspectRatio = 16 / 9;
const _compactControlWidth = 48.0;

class _DesktopShareLayout extends StatelessWidget {
  const _DesktopShareLayout({required this.room, required this.participants});

  final lk.Room room;
  final List<lk.Participant> participants;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final expandController = Controller.ofType<ExpandParticipantController>(context);

        final maxContentWidth = (constraints.maxWidth - _outerPadding * 2).clamp(0.0, double.infinity);
        final maxContentHeight = (constraints.maxHeight - _outerPadding * 2).clamp(0.0, double.infinity);

        final maxShareWidth = (maxContentWidth - _railWidth - _railGap).clamp(0.0, double.infinity);
        final shareHeightFromWidth = maxShareWidth / _shareAspectRatio;
        final shareHeight = shareHeightFromWidth > maxContentHeight ? maxContentHeight : shareHeightFromWidth;
        final shareWidth = shareHeight * _shareAspectRatio;

        final expandedParticipants = participants.where((p) => expandController.isExpanded(p.identity)).toList();

        if (expandController.hasExpanded) {
          return ExpandableCameraGrid(participants: expandedParticipants);
        }

        return Center(
          child: Padding(
            padding: const .all(_outerPadding),
            child: SizedBox(
              width: shareWidth + _railGap + _railWidth,
              height: shareHeight,
              child: Row(
                crossAxisAlignment: .start,
                spacing: _railGap,
                children: [
                  SizedBox(
                    width: shareWidth,
                    height: shareHeight,
                    child: ExpandableCameraGrid(participants: participants),
                  ),
                  SizedBox(
                    width: _railWidth,
                    child: CameraStrip(room: room, horizontal: false, participants: participants),
                  ),
                ],
              ),
            ),
          ),
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
  State createState() => _MeetingActions();
}

class _MeetingActions extends State<MeetingToolkits> {
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
