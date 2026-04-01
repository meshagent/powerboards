import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'package:powerboards/ui/camera_box.dart';

class ParticipantTrack extends StatelessWidget {
  const ParticipantTrack({
    super.key,
    required this.participant,
    required this.track,
    this.overlayAlignment = .topRight,
    this.showName = true,
  });

  final lk.Participant participant;
  final Widget track;
  final Alignment overlayAlignment;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return CameraBox(
      camera: IgnorePointer(ignoring: true, child: track),
      participant: participant,
      overlayAlignment: overlayAlignment,
      showName: showName,
    );
  }
}
