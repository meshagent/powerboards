import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/meetings/meetings.dart';
import 'package:meshagent_flutter_shadcn/storage/transcript_file_name.dart';

import 'package:powerboards/livekit/camera_grid.dart';
import 'package:powerboards/livekit/camera_strip.dart';
import 'package:powerboards/livekit/device_preview.dart';
import 'package:powerboards/livekit/expand_participant_controller.dart';
import 'package:powerboards/livekit/room.dart';
import 'package:powerboards/livekit/video_room_participants_builder.dart';
import 'package:powerboards/nav/nav.dart';
import 'package:powerboards/powerboards_controller/powerboards_controller.dart';
import 'package:powerboards/powerboards_ui/v1/components/chat/pb_voice_session_empty_state.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_tokens.dart';
import 'package:powerboards/settings/ui_mode.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/pane_empty_state.dart';
import 'package:powerboards/ui/pane_header_action_scope.dart';
import 'package:powerboards/ui/powerboards_breakpoints.dart';
import 'package:powerboards/ui/powerboards_toasts.dart';

const _railGap = 16.0;
const _compactControlWidth = 48.0;
const _mobileMeetingToolbarHorizontalPadding = 40.0;
const _mobileMeetingToolbarGap = 8.0;
const _mobileMeetingToolbarFixedControlCount = 4;
const _mobileTranscriptionButtonMaxWidth = 260.0;
const _mobileTranscriptionCompactThreshold = 110.0;
const _mobileTranscriptionShortLabelThreshold = 148.0;
const _desktopLobbyMaxWidth = 880.0;
const _desktopV1MeetingTileRadius = PbRadii.large;
const _desktopV1MeetingSmallTileRadius = PbRadii.large / 2;
const _desktopV1MeetingSmallTileRadiusBreakpoint = 240.0;

enum MeetingViewState { preview, joined }

class MeetingViewController extends Controller {
  MeetingViewState _state = MeetingViewState.preview;

  MeetingViewState get state => _state;

  void enterMeeting() {
    _state = MeetingViewState.joined;
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

  Widget _voiceSessionMeetingBlockedState(MeetingController? voiceSessionController) {
    if (powerboardsUsesDesktopUiPreview(context)) {
      return PbVoiceSessionEmptyState(
        iconAssetName: 'video-empty-state',
        title: 'End voice session to meet',
        subtitle: 'Starting a meeting ends the active voice session in chat.',
        primaryButtonLabel: 'Start meeting',
        showTranscribeToggle: false,
        onStartSessionPressed: voiceSessionController == null
            ? null
            : () => unawaited(() async {
                await voiceSessionController.disconnect();
                if (!mounted) {
                  return;
                }
                widget.joinMeeting();
              }()),
      );
    }

    return const PaneEmptyState(title: "End voice session to meet", titleScaleOverride: 0.72, verticalOffset: -28);
  }

  @override
  void dispose() {
    super.dispose();

    expandParticipantController.dispose();
  }

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
        if (hasShare && !expandParticipantController.hasExpanded)
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
    final voiceSessionController = MeetingController.maybeOf(context);

    Widget buildMeetingContent() {
      final videoRoom = VideoRoomModel.maybeOf(context)?.room;
      final voiceSessionActive = voiceSessionController?.isConnected == true;
      final inPreview =
          meetingViewController.state == MeetingViewState.preview ||
          (videoRoom == null && meetingViewController.state == MeetingViewState.joined);

      if (inPreview) {
        if (voiceSessionActive) {
          return _voiceSessionMeetingBlockedState(voiceSessionController);
        }

        final usesDesktopUiPreview = powerboardsUsesDesktopUiPreview(context);
        final devicePreview = DevicePreview(
          desktopV1Style: usesDesktopUiPreview,
          onJoin: ({required enableVideo, required enableAudio, required videoUnavailable, required audioUnavailable}) {
            final videoChatConnection = context.findAncestorStateOfType<VideoChatConnectionState>();
            final navController = Controller.ofType<NavController>(context);

            if (videoChatConnection != null) {
              videoChatConnection.setRoomFromDoc(
                "",
                widget.room,
                "",
                video: enableVideo,
                audio: enableAudio,
                videoUnavailable: videoUnavailable,
                audioUnavailable: audioUnavailable,
                agentID: null,
              );
            }

            meetingViewController.enterMeeting();
            navController.hideNav();
          },
          onCancel: widget.onCancel,
        );

        if (usesDesktopUiPreview) {
          return devicePreview;
        }

        return Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _desktopLobbyMaxWidth),
            child: Padding(padding: const .symmetric(horizontal: 20.0), child: devicePreview),
          ),
        );
      } else if (meetingViewController.state == MeetingViewState.joined) {
        final room = VideoRoomModel.maybeOf(context)?.room;
        if (room == null) return const SizedBox.shrink();
        final usesDesktopV1MeetingPadding = powerboardsUsesDesktopUiPreview(context);

        return Padding(
          padding: usesDesktopV1MeetingPadding ? const .fromLTRB(20, 10, 20, 20) : const .all(20),
          child: VideoRoomParticipantsBuilder(
            room: room,
            builder: (context, participants) {
              return ControllerBuilder<ExpandParticipantController>(
                controller: expandParticipantController,
                builder: (context) {
                  final usesDesktopV1MeetingStyle = powerboardsUsesDesktopUiPreview(context);
                  final isMobile = !usesDesktopV1MeetingStyle && ResponsiveBreakpoints.of(context).isMobile;
                  final hasShare = participants.any(_participantHasActiveShare);

                  if (isMobile) {
                    return _mobileLayout(room, participants, hasShare);
                  }

                  if (hasShare) {
                    return _DesktopShareLayout(room: room, participants: participants, desktopV1Style: usesDesktopV1MeetingStyle);
                  }

                  return ExpandableCameraGrid(
                    participants: participants,
                    largeBorderRadius: usesDesktopV1MeetingStyle ? _desktopV1MeetingTileRadius : 8,
                    smallBorderRadius: usesDesktopV1MeetingStyle ? _desktopV1MeetingSmallTileRadius : 8,
                    smallBorderRadiusBreakpoint: usesDesktopV1MeetingStyle ? _desktopV1MeetingSmallTileRadiusBreakpoint : 0,
                  );
                },
              );
            },
          ),
        );
      }

      return const Text("Unknown state");
    }

    return ControllerProvider<ExpandParticipantController>(
      controller: expandParticipantController,
      child: ControllerBuilder(
        controller: meetingViewController,
        builder: (BuildContext context) => voiceSessionController == null
            ? buildMeetingContent()
            : ListenableBuilder(listenable: voiceSessionController, builder: (context, _) => buildMeetingContent()),
      ),
    );
  }
}

class _DesktopShareLayout extends StatelessWidget {
  const _DesktopShareLayout({required this.room, required this.participants, this.desktopV1Style = false});

  final lk.Room room;
  final List<lk.Participant> participants;
  final bool desktopV1Style;

  static const double _leftStripWidth = 250.0;
  static const double _topStripHeight = 100.0;

  Iterable<lk.TrackPublication> getSharePublications(List<lk.Participant> participants) sync* {
    for (final participant in participants) {
      final publication = participant.getTrackPublicationBySource(lk.TrackSource.screenShareVideo);

      if (publication != null && !publication.muted && publication.track is lk.VideoTrack) {
        yield publication;
      }
    }
  }

  Size _fitAspect({required double aspectRatio, required double maxWidth, required double maxHeight}) {
    if (maxWidth <= 0 || maxHeight <= 0 || aspectRatio <= 0) {
      return Size.zero;
    }

    double width = maxWidth;
    double height = width / aspectRatio;

    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspectRatio;
    }

    return Size(width, height);
  }

  bool _shouldPutStripOnLeft({required BoxConstraints constraints, required double aspectRatio, required bool hasExpanded}) {
    if (hasExpanded) {
      return false;
    }

    final maxWidth = constraints.maxWidth;
    final maxHeight = constraints.maxHeight;

    final leftAvailableWidth = math.max(0.0, maxWidth - _leftStripWidth - _railGap);
    final leftAvailableHeight = maxHeight;

    final topAvailableWidth = maxWidth;
    final topAvailableHeight = math.max(0.0, maxHeight - _topStripHeight - _railGap);

    final leftFit = _fitAspect(aspectRatio: aspectRatio, maxWidth: leftAvailableWidth, maxHeight: leftAvailableHeight);

    final topFit = _fitAspect(aspectRatio: aspectRatio, maxWidth: topAvailableWidth, maxHeight: topAvailableHeight);

    final leftArea = leftFit.width * leftFit.height;
    final topArea = topFit.width * topFit.height;

    return leftArea >= topArea;
  }

  @override
  Widget build(BuildContext context) {
    final expandController = Controller.ofType<ExpandParticipantController>(context);
    final sharePublications = getSharePublications(participants).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        bool stripOnLeft = true;

        if (!expandController.hasExpanded && sharePublications.length == 1) {
          final track = sharePublications.first;
          final dimensions = track.dimensions;

          if (dimensions != null && dimensions.width > 0 && dimensions.height > 0) {
            final aspectRatio = dimensions.width / dimensions.height;

            stripOnLeft = _shouldPutStripOnLeft(
              constraints: constraints,
              aspectRatio: aspectRatio,
              hasExpanded: expandController.hasExpanded,
            );
          }
        }

        if (stripOnLeft) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ExpandableCameraGrid(
                  participants: participants,
                  largeBorderRadius: desktopV1Style ? _desktopV1MeetingTileRadius : 8,
                  smallBorderRadius: desktopV1Style ? _desktopV1MeetingSmallTileRadius : 8,
                  smallBorderRadiusBreakpoint: desktopV1Style ? _desktopV1MeetingSmallTileRadiusBreakpoint : 0,
                ),
              ),
              if (!expandController.hasExpanded) ...[
                const SizedBox(width: _railGap),
                SizedBox(
                  width: _leftStripWidth,
                  child: CameraStrip(
                    room: room,
                    horizontal: false,
                    participants: participants,
                    borderRadius: desktopV1Style ? _desktopV1MeetingTileRadius : 8,
                  ),
                ),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!expandController.hasExpanded) ...[
              SizedBox(
                height: _topStripHeight,
                child: CameraStrip(
                  room: room,
                  horizontal: true,
                  participants: participants,
                  borderRadius: desktopV1Style ? _desktopV1MeetingTileRadius : 8,
                ),
              ),
              const SizedBox(height: _railGap),
            ],
            Expanded(
              child: ExpandableCameraGrid(
                participants: participants,
                largeBorderRadius: desktopV1Style ? _desktopV1MeetingTileRadius : 8,
                smallBorderRadius: desktopV1Style ? _desktopV1MeetingSmallTileRadius : 8,
                smallBorderRadiusBreakpoint: desktopV1Style ? _desktopV1MeetingSmallTileRadiusBreakpoint : 0,
              ),
            ),
          ],
        );
      },
    );
  }
}

class MeetingToolkits extends StatefulWidget {
  const MeetingToolkits({super.key, required this.room, this.breakoutRoom = "", this.compact = false, this.desktopV1Style = false});

  final RoomClient room;
  final String breakoutRoom;
  final bool compact;
  final bool desktopV1Style;

  @override
  State createState() => _MeetingToolkitsState();
}

class _MeetingToolkitsState extends State<MeetingToolkits> {
  Timer? timer;

  late final toolkits = Resource<List<ToolkitDescription>>(() => widget.room.agents.listToolkits());

  bool _isLandscapePhoneViewport(BuildContext context) {
    return powerboardsIsLandscapePhoneViewport(context);
  }

  double _mobileTranscriptionButtonWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final usedWidth =
        (_mobileMeetingToolbarHorizontalPadding / 2) +
        (_mobileMeetingToolbarFixedControlCount * _compactControlWidth) +
        ((_mobileMeetingToolbarFixedControlCount - 1) * _mobileMeetingToolbarGap) +
        _mobileMeetingToolbarGap;
    final availableWidth = screenWidth - usedWidth;
    return availableWidth.clamp(_compactControlWidth, _mobileTranscriptionButtonMaxWidth).toDouble();
  }

  void _showTranscriptionToast(String message) {
    ShadToaster.maybeOf(
      context,
    )?.show(powerboardsToast(title: 'Transcription', description: message, duration: const Duration(seconds: 3)));
  }

  String _transcriptionButtonLabel({required bool transcribing, required bool shortLabel}) {
    if (!shortLabel) {
      return transcribing ? "Stop Transcription" : "Start Transcription";
    }

    return transcribing ? "Stop..." : "Start...";
  }

  Future<void> _invokeTranscriptionTool({
    required ToolkitDescription transcription,
    required String toolName,
    required Map<String, Object?> input,
    required String successMessage,
    required bool showToast,
  }) async {
    await widget.room.agents.invokeTool(
      toolkit: transcription.name,
      tool: toolName,
      input: ToolContentInput(JsonContent(json: input)),
    );

    if (showToast) {
      _showTranscriptionToast(successMessage);
    }
  }

  Widget _buildDesktopV1TranscriptionButton({
    required ToolkitDescription? transcription,
    required ToolDescription? startRecording,
    required ToolDescription? stopRecording,
    required bool transcribing,
  }) {
    final canToggle = transcription != null && ((transcribing && stopRecording != null) || (!transcribing && startRecording != null));
    final tooltip = transcribing ? "Stop transcription" : "Start transcription";

    return MeetV1ToolbarButton.secondary(
      label: transcribing ? "Stop transcribing" : "Transcribe",
      tooltip: canToggle ? tooltip : "Transcription unavailable",
      iconAssetName: transcribing ? "captions-off" : "captions",
      compact: widget.compact,
      active: transcribing,
      onPressed: !canToggle
          ? null
          : () async {
              if (transcribing) {
                await _invokeTranscriptionTool(
                  transcription: transcription,
                  toolName: stopRecording!.name,
                  input: {"breakout_room": ""},
                  successMessage: "Transcription stopped",
                  showToast: widget.compact,
                );
                return;
              }

              await _invokeTranscriptionTool(
                transcription: transcription,
                toolName: startRecording!.name,
                input: {"breakout_room": "", "path": "transcripts/meetings/${buildTranscriptFileName()}"},
                successMessage: "Transcription started",
                showToast: widget.compact,
              );
            },
    );
  }

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
    final isMobile = !widget.desktopV1Style && (ResponsiveBreakpoints.of(context).isMobile || _isLandscapePhoneViewport(context));

    return SignalBuilder(
      builder: (context, _) {
        if (!toolkits.state.isReady) {
          return widget.desktopV1Style
              ? MeetV1ToolbarButton.secondary(
                  label: "Transcribe",
                  tooltip: "Loading transcription",
                  iconAssetName: "captions",
                  compact: widget.compact,
                  loading: true,
                )
              : SizedBox();
        }
        final transcription = toolkits.state.value!.firstWhereOrNull((x) => x.name == "transcription");
        final startRecording = transcription?.tools.firstWhereOrNull((x) => x.name == "start_transcription");
        final stopRecording = transcription?.tools.firstWhereOrNull((x) => x.name == "stop_transcription");

        final transcribing =
            widget.room.messaging.remoteParticipants.firstWhereOrNull(
              (p) => p.getAttribute("transcribing.${widget.breakoutRoom}") == true,
            ) !=
            null;
        final mobileButtonWidth = isMobile ? _mobileTranscriptionButtonWidth(context) : _mobileTranscriptionButtonMaxWidth;
        final useCompactPresentation = widget.compact || (isMobile && mobileButtonWidth <= _mobileTranscriptionCompactThreshold);
        final useShortLabel = isMobile && !useCompactPresentation && mobileButtonWidth <= _mobileTranscriptionShortLabelThreshold;
        final useCompressedPresentation = isMobile && (useCompactPresentation || useShortLabel);

        if (widget.desktopV1Style) {
          return _buildDesktopV1TranscriptionButton(
            transcription: transcription,
            startRecording: startRecording,
            stopRecording: stopRecording,
            transcribing: transcribing,
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (startRecording != null && !transcribing)
              Tooltip(
                message: "Start Transcription",
                child: useCompactPresentation
                    ? ShadIconButton.outline(
                        icon: const Icon(LucideIcons.captions, size: paneHeaderIconButtonIconSize),
                        decoration: powerboardsAdaptiveMeetingControlButtonDecoration(context),
                        onPressed: () async {
                          await _invokeTranscriptionTool(
                            transcription: transcription!,
                            toolName: startRecording.name,
                            input: {"breakout_room": "", "path": "transcripts/meetings/${buildTranscriptFileName()}"},
                            successMessage: "Transcription started",
                            showToast: useCompressedPresentation,
                          );
                        },
                      )
                    : SizedBox(
                        width: isMobile ? mobileButtonWidth : null,
                        child: ShadButton.outline(
                          padding: isMobile ? const EdgeInsets.symmetric(horizontal: 12) : null,
                          leading: Icon(LucideIcons.captions),
                          onPressed: () async {
                            await _invokeTranscriptionTool(
                              transcription: transcription!,
                              toolName: startRecording.name,
                              input: {"breakout_room": "", "path": "transcripts/meetings/${buildTranscriptFileName()}"},
                              successMessage: "Transcription started",
                              showToast: useCompressedPresentation,
                            );
                          },
                          child: Text(
                            _transcriptionButtonLabel(transcribing: false, shortLabel: useShortLabel),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                      ),
              ),

            if (stopRecording != null && transcribing)
              Tooltip(
                message: "Stop Transcription",
                child: useCompactPresentation
                    ? ShadIconButton.outline(
                        icon: const Icon(LucideIcons.captionsOff, size: paneHeaderIconButtonIconSize),
                        decoration: powerboardsAdaptiveMeetingControlButtonDecoration(context),
                        onPressed: () async {
                          await _invokeTranscriptionTool(
                            transcription: transcription!,
                            toolName: stopRecording.name,
                            input: {"breakout_room": ""},
                            successMessage: "Transcription stopped",
                            showToast: useCompressedPresentation,
                          );
                        },
                      )
                    : SizedBox(
                        width: isMobile ? mobileButtonWidth : null,
                        child: ShadButton.outline(
                          padding: isMobile ? const EdgeInsets.symmetric(horizontal: 12) : null,
                          leading: Icon(LucideIcons.captionsOff),
                          onPressed: () async {
                            await _invokeTranscriptionTool(
                              transcription: transcription!,
                              toolName: stopRecording.name,
                              input: {"breakout_room": ""},
                              successMessage: "Transcription stopped",
                              showToast: useCompressedPresentation,
                            );
                          },
                          child: Text(
                            _transcriptionButtonLabel(transcribing: true, shortLabel: useShortLabel),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                      ),
              ),
          ],
        );
      },
    );
  }
}
