import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:interactive_viewer_2/interactive_viewer_2.dart';

import 'participant_overlay.dart';

class CameraBox extends StatelessWidget {
  const CameraBox({
    super.key,
    required this.camera,
    required this.participant,
    this.overlayAlignment = .topRight,
    this.showName = false,
    this.interactive = true,
  });

  final Widget camera;
  final lk.Participant participant;
  final Alignment overlayAlignment;
  final bool showName;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final content = ColoredBox(
      color: const Color(0xFF222222),
      child: interactive ? InteractiveViewer2(minScale: 1, maxScale: 5, child: camera) : camera,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        content,

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
