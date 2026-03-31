import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'package:powerboards/ui/camera_box.dart';

class ParticipantTrack extends StatelessWidget {
  const ParticipantTrack({super.key, required this.participant, required this.track, this.showName = true, this.interactive = true});

  final lk.Participant participant;
  final Widget track;
  final bool showName;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return CameraBox(
      camera: IgnorePointer(ignoring: true, child: track),
      participant: participant,
      showName: showName,
      interactive: interactive,
    );
  }
}
