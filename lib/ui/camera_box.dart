import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:interactive_viewer_2/interactive_viewer_2.dart';

import 'participant_overlay.dart';

class CameraBox extends StatelessWidget {
  const CameraBox({super.key, required this.camera, required this.participant, this.overlayAlignment = .topRight, this.showName = false});

  final Widget camera;
  final lk.Participant participant;
  final Alignment overlayAlignment;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer2(minScale: 1, maxScale: 5, child: camera),

        Align(
          alignment: overlayAlignment,
          child: Padding(
            padding: const .all(5),
            child: ParticipantOverlay(participant: participant, showName: showName),
          ),
        ),
      ],
    );
  }
}
