import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'package:powerboards/ui/camera_box.dart';
import 'package:powerboards/ui/participant_overlay.dart';

class ParticipantTrack extends StatelessWidget {
  const ParticipantTrack({super.key, required this.participant, required this.track, this.showName = true, this.overlayContextMenu});

  final bool showName;
  final lk.Participant participant;
  final Widget track;
  final ParticipantOverlayContextMenuConfig? overlayContextMenu;

  @override
  Widget build(BuildContext context) {
    return CameraBox(
      camera: IgnorePointer(ignoring: true, child: track),
      showName: showName,
      participantName: participant.name,
      muted: participant.isMuted,
      overlayContextMenu: overlayContextMenu,
    );
  }
}
