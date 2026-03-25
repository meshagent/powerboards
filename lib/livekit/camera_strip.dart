import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'package:powerboards/ui/camera_box.dart';

import 'participant_track.dart';
import 'hover_builder.dart';

class CameraStrip extends StatelessWidget {
  const CameraStrip({super.key, required this.room, this.gap = 5, this.horizontal = false, this.participants});

  final lk.Room room;
  final double gap;
  final bool horizontal;
  final List<lk.Participant>? participants;

  Widget displayWrapper(Object key, bool selected, Widget child) {
    return Container(
      key: ObjectKey(key),
      margin: EdgeInsets.only(bottom: horizontal ? 0 : gap, right: horizontal ? gap : 0),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      foregroundDecoration: selected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(width: 3, color: Colors.blue),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(aspectRatio: 16 / 9, child: child),
    );
  }

  Widget videoDisplay(BuildContext context, lk.Participant participant, lk.TrackPublication videoTrack) {
    return displayWrapper(
      videoTrack,
      false,
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
                      fit: videoTrack.source == lk.TrackSource.screenShareVideo ? lk.VideoViewFit.contain : lk.VideoViewFit.cover,
                    ),
                  ),
                );
              },
            )
          : Container(
              color: const Color(0xFF222222),
              alignment: Alignment.center,
              child: participant.identity.contains(".agent") ? const Text("audio stats") : Text("avatar"),
            ),
    );
  }

  Widget audioDisplay(BuildContext context, lk.Participant participant) {
    return displayWrapper(
      participant,
      false,
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
                  ? const Text("audio stats", style: TextStyle(color: Colors.white70))
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
            participants ??
            <lk.Participant>[...(room.remoteParticipants.values), if (room.localParticipant != null) room.localParticipant!];

        return ListView(
          scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
          children: [
            for (final participant in stripParticipants)
              ...() {
                final nonShareVideoTracks = participant.trackPublications.values.where(
                  (track) =>
                      track.kind == lk.TrackType.VIDEO &&
                      track.source != lk.TrackSource.screenShareVideo &&
                      !track.muted &&
                      track.track != null,
                );

                if (nonShareVideoTracks.isEmpty) {
                  return [audioDisplay(context, participant)];
                }

                return nonShareVideoTracks.map((track) => videoDisplay(context, participant, track));
              }(),
          ],
        );
      },
    );
  }
}
