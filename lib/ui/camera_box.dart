import 'package:flutter/material.dart';
import 'package:interactive_viewer_2/interactive_viewer_2.dart';
import 'participant_overlay.dart';

class CameraBox extends StatelessWidget {
  final Widget camera;
  final String participantName;
  final bool muted;
  final bool showName;
  final Alignment overlayAlignment;

  const CameraBox({
    super.key,
    required this.camera,
    required this.participantName,
    this.overlayAlignment = Alignment.bottomLeft,
    this.showName = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer2(minScale: 1, maxScale: 5, child: camera),
        Align(
          alignment: overlayAlignment,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: ParticipantOverlay(name: participantName, muted: muted, showName: showName),
          ),
        ),
      ],
    );
  }
}
