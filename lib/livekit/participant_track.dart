import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'package:powerboards/ui/camera_box.dart';

class ParticipantTrack extends StatelessWidget {
  const ParticipantTrack({
    super.key,
    required this.participant,
    required this.track,
    this.expandSource = lk.TrackSource.camera,
    this.overlayAlignment = .topRight,
    this.showName = true,
    this.interactive = true,
    this.borderRadius = 0,
  });

  final lk.Participant participant;
  final Widget track;
  final lk.TrackSource expandSource;
  final Alignment overlayAlignment;
  final bool showName;
  final bool interactive;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return CameraBox(
      camera: IgnorePointer(ignoring: true, child: track),
      participant: participant,
      expandSource: expandSource,
      overlayAlignment: overlayAlignment,
      showName: showName,
      interactive: interactive,
      borderRadius: borderRadius,
    );
  }
}
