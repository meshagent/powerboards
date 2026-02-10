// camera_box.dart

import 'package:flutter/material.dart';
import 'participant_overlay.dart';

class CameraBox extends StatelessWidget {
  final Widget camera;
  final String participantName;
  final bool muted;
  final bool showName;
  final Alignment overlayAlignment;
  final BoxDecoration? decoration;

  const CameraBox({
    super.key,
    required this.camera,
    required this.participantName,
    this.decoration = const BoxDecoration(
      border: Border(
        top: BorderSide(color: Colors.white, width: 2.0),
        bottom: BorderSide(color: Colors.white, width: 2.0),
        left: BorderSide(color: Colors.white, width: 2.0),
        right: BorderSide(color: Colors.white, width: 2.0),
      ),
      borderRadius: BorderRadius.all(Radius.circular(8.0)),
      boxShadow: [BoxShadow(blurRadius: 5, color: Color.fromARGB(50, 0, 0, 0))],
    ),
    this.overlayAlignment = Alignment.bottomLeft,
    this.showName = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: decoration,
      child: ClipRRect(
        child: Stack(
          children: [
            camera,
            Align(
              alignment: overlayAlignment,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: IntrinsicWidth(
                  child: ParticipantOverlay(name: participantName, muted: muted, showName: showName),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
