import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'participant_track.dart';
import 'hover_builder.dart';

class CameraStrip extends StatelessWidget {
  const CameraStrip({super.key, required this.room, this.gap = 5});

  final lk.Room room;
  final double gap;

  Widget displayWrapper(Object key, bool selected, Widget child) {
    return Container(
      key: ObjectKey(key),
      margin: EdgeInsets.only(bottom: gap),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      foregroundDecoration: selected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(width: 3, color: Colors.blue),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: child),
      ),
    );
  }

  Widget videoDisplay(BuildContext context, lk.Participant participant, lk.TrackPublication videoTrack) {
    return displayWrapper(
      videoTrack,
      false, //widget.meetingDoc.activeVideoTrack?.matches(participant, videoTrack.track as lk.VideoTrack?) == true,
      participant.hasVideo && videoTrack.track != null
          ? GestureDetector(
              onTap: () {
                // widget.controller.previewLayer = null;
                // widget.controller.selectedLayer = null;
                // final part = ParticipantIdentity.parse(participant.identity);
                // (widget.controller.document as ChatDocument).setActiveVideoTrack(
                //   ActiveVideoTrack(
                //     participant: part.url,
                //     source: switch (videoTrack.source) {
                //       lk.TrackSource.camera => "camera",
                //       lk.TrackSource.screenShareVideo => "screen",
                //       lk.TrackSource.unknown => "unknown",
                //       _ => "unknown",
                //     },
                //     device: part.device,
                //   ),
                // );
              },
              child: HoverBuilder(
                builder: (hovered) {
                  final track = videoTrack.track as lk.VideoTrack;
                  return Container(
                    color: Colors.transparent,
                    child: IgnorePointer(
                      ignoring: true,
                      child: ParticipantTrack(
                        showName: hovered,
                        participant: participant,
                        track: lk.VideoTrackRenderer(
                          track,
                          fit: videoTrack.source == lk.TrackSource.screenShareVideo ? lk.VideoViewFit.contain : lk.VideoViewFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          : Container(
              color: Colors.grey,
              alignment: Alignment.center,
              child: participant.identity.contains(".agent")
                  ? GestureDetector(
                      onTap: () {
                        // widget.meetingDoc.setActiveVideoTrack(
                        //   ActiveVideoTrack(
                        //     participant: ParticipantIdentity.parse(participant.identity).url,
                        //     source: "agentTasks",
                        //     device: null,
                        //   ),
                        // );
                      },
                      child: const Text("audio stats"), //AudioStats(room: widget.room, participant: participant),
                    )
                  : Text("avatar"),

              // TimuObjectBuilder(
              //   url: '/api/graph/core:user/${participant.identity}',
              //   builder: (context, user) {
              //     return ProfileAvatar(profile: user as User, size: 100);
              //   },
              // ),
            ),
    );
  }

  Widget audioDisplay(BuildContext context, lk.Participant participant) {
    return displayWrapper(
      participant,
      false, //widget.meetingDoc.activeVideoTrack?.matches(participant) == true,
      participant.identity.contains(".agent")
          ? GestureDetector(
              onTap: () {
                // widget.meetingDoc.setActiveVideoTrack(
                //   ActiveVideoTrack(participant: ParticipantIdentity.parse(participant.identity).url, source: "agentTasks", device: null),
                // );

                // widget.controller.previewLayer = null;
                // widget.controller.selectedLayer = null;
              },
              child: const Text("audio stats"), // AudioStats(room: VideoRoomModel.of(context).room, participant: participant),
            )
          : HoverBuilder(
              builder: (hovered) {
                return Container(
                  color: Colors.transparent,
                  child: IgnorePointer(
                    ignoring: true,
                    child: ParticipantTrack(showName: hovered, participant: participant, track: SizedBox.shrink()),
                  ),
                );
              },
            ),
      //  TimuObjectBuilder(
      //    url: '/api/graph/core:user/${participant.name}',
      //    error: (_, _) => const Icon(LucideIcons.user, size: 100, color: Colors.grey),
      //    builder: (context, user) {
      //      return ProfileAvatar(profile: user as User, size: 100);
      //    },
      //  ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        return ListView(
          children: [
            for (final participant in <lk.Participant>[
              ...(room.remoteParticipants.values),
              if (room.localParticipant != null) room.localParticipant!,
            ])
              if (participant.trackPublications.isEmpty)
                audioDisplay(context, participant)
              else
                for (lk.TrackPublication track in participant.trackPublications.values.where(
                  (t) => t.source != lk.TrackSource.screenShareVideo,
                ))
                  switch (track.kind) {
                    lk.TrackType.AUDIO when !participant.hasVideo => audioDisplay(context, participant),
                    lk.TrackType.VIDEO => videoDisplay(context, participant, track),
                    (_) => SizedBox.shrink(),
                  },
          ],
        );
      },
    );
  }
}
