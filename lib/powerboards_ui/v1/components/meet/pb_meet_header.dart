import 'package:flutter/material.dart';

import '../../theme/pb_typography.dart';
import '../layouts/pb_thread_header.dart';

class PbMeetHeader extends StatelessWidget {
  const PbMeetHeader({
    super.key,
    this.title = 'Get ready to meet',
    required this.roomPanelExpanded,
    required this.onRoomPanelToggle,
    required this.onOpenTranscripts,
    this.showRoomPanelControls = true,
    this.controls,
  });

  final String title;
  final bool roomPanelExpanded;
  final VoidCallback onRoomPanelToggle;
  final VoidCallback onOpenTranscripts;
  final bool showRoomPanelControls;
  final Widget? controls;

  @override
  Widget build(BuildContext context) {
    final controls = this.controls;

    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.fromLTRB(30, 19, 28, 19),
      child: Row(
        children: [
          Expanded(
            child: controls ?? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: PowerboardsTypography.h2),
          ),
          if (showRoomPanelControls) const SizedBox(width: 16),
          if (showRoomPanelControls)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!roomPanelExpanded) PbThreadHeaderQuaternaryButton(label: 'Recent transcripts', onPressed: onOpenTranscripts),
                if (!roomPanelExpanded) const SizedBox(width: 6),
                PbThreadPanelToggle(expanded: roomPanelExpanded, onPressed: onRoomPanelToggle),
              ],
            ),
        ],
      ),
    );
  }
}
