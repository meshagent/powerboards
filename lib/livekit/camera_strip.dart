import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'package:powerboards/livekit/meeting_participants.dart';
import 'package:powerboards/ui/camera_box.dart';

import 'participant_track.dart';
import 'hover_builder.dart';

class CameraStrip extends StatelessWidget {
  const CameraStrip({
    super.key,
    required this.room,
    this.gap = 5,
    this.horizontal = false,
    this.participants,
  });

  final lk.Room room;
  final double gap;
  final bool horizontal;
  final List<lk.Participant>? participants;

  Widget displayWrapper(Object key, Widget child) {
    return Container(
      key: ObjectKey(key),
      margin: .only(bottom: horizontal ? 0 : gap, right: horizontal ? gap : 0),
      decoration: BoxDecoration(borderRadius: .circular(8)),
      clipBehavior: .antiAlias,
      child: AspectRatio(aspectRatio: 16 / 9, child: child),
    );
  }

  Widget videoDisplay(
    BuildContext context,
    lk.Participant participant,
    lk.TrackPublication videoTrack,
  ) {
    return displayWrapper(
      videoTrack,
      participant.hasVideo && videoTrack.track != null
          ? HoverBuilder(
              cursor: SystemMouseCursors.basic,
              builder: (hovered) {
                final track = videoTrack.track as lk.VideoTrack;

                return Container(
                  color: Colors.transparent,
                  child: ParticipantTrack(
                    showName: hovered,
                    participant: participant,
                    track: lk.VideoTrackRenderer(
                      track,
                      fit: videoTrack.source == lk.TrackSource.screenShareVideo
                          ? lk.VideoViewFit.contain
                          : lk.VideoViewFit.cover,
                    ),
                    interactive:
                        videoTrack.source != lk.TrackSource.screenShareVideo,
                  ),
                );
              },
            )
          : Container(
              color: const Color(0xFF222222),
              alignment: .center,
              child: participant.identity.contains(".agent")
                  ? const Text("audio stats")
                  : Text("avatar"),
            ),
    );
  }

  Widget audioDisplay(BuildContext context, lk.Participant participant) {
    return displayWrapper(
      participant,
      HoverBuilder(
        cursor: SystemMouseCursors.basic,
        builder: (hovered) {
          return CameraBox(
            participant: participant,
            showName: hovered,
            camera: Container(
              color: const Color(0xFF2A2A2A),
              alignment: Alignment.center,
              child: participant.identity.contains(".agent")
                  ? const Text(
                      "audio stats",
                      style: TextStyle(color: Colors.white70),
                    )
                  : const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        final stripParticipants =
            participants ?? uniqueMeetingParticipants(room);

        return ListenableBuilder(
          listenable: Listenable.merge(stripParticipants),
          builder: (context, _) => ListView(
            scrollDirection: horizontal ? .horizontal : .vertical,
            children: [
              for (final participant in stripParticipants)
                ...() {
                  final cameraTrack = activeVideoPublicationForSource(
                    participant,
                    lk.TrackSource.camera,
                  );

                  if (cameraTrack == null) {
                    return [audioDisplay(context, participant)];
                  }

                  return [videoDisplay(context, participant, cameraTrack)];
                }(),
            ],
          ),
        );
      },
    );
  }
}
