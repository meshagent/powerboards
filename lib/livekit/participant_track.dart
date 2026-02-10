import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'package:powerboards/ui/camera_box.dart';

class ParticipantTrack extends StatelessWidget {
  const ParticipantTrack({super.key, required this.participant, required this.track, this.showName = true});

  final bool showName;
  final lk.Participant participant;
  final Widget track;

  @override
  Widget build(BuildContext context) {
    return CameraBox(
      decoration: null,
      camera: Positioned.fill(child: IgnorePointer(ignoring: true, child: track)),
      showName: showName,
      participantName: participant.name,
      muted: participant.isMuted,
    );
  }
}
