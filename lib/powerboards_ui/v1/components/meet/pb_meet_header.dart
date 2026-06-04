import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_typography.dart';
import '../layouts/pb_thread_header.dart';
import '../primitives/pb_svg_icon.dart';

class PbMeetHeader extends StatelessWidget {
  const PbMeetHeader({
    super.key,
    this.title = 'Get ready to meet',
    required this.roomPanelExpanded,
    required this.onRoomPanelToggle,
    required this.onOpenTranscripts,
    this.showRoomPanelControls = true,
    this.controls,
    this.meetingFullscreen = false,
    this.onMeetingFullscreenToggle,
  });

  final String title;
  final bool roomPanelExpanded;
  final VoidCallback onRoomPanelToggle;
  final VoidCallback onOpenTranscripts;
  final bool showRoomPanelControls;
  final Widget? controls;
  final bool meetingFullscreen;
  final VoidCallback? onMeetingFullscreenToggle;

  @override
  Widget build(BuildContext context) {
    final controls = this.controls;
    final hasControls = controls != null;

    return Container(
      constraints: BoxConstraints(minHeight: hasControls ? 65 : 76),
      padding: hasControls ? const EdgeInsets.fromLTRB(20, 11, 28, 10) : const EdgeInsets.fromLTRB(30, 19, 28, 19),
      child: Row(
        children: [
          Expanded(
            child: controls ?? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: PowerboardsTypography.h2),
          ),
          if (hasControls && onMeetingFullscreenToggle != null) ...[
            const SizedBox(width: 10),
            _MeetHeaderGhostIcon(
              assetName: meetingFullscreen ? 'minimize-2' : 'maximize-2',
              tooltip: meetingFullscreen ? 'Collapse meeting' : 'Expand meeting',
              onPressed: onMeetingFullscreenToggle,
            ),
          ],
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

class _MeetHeaderGhostIcon extends StatefulWidget {
  const _MeetHeaderGhostIcon({required this.assetName, required this.tooltip, this.onPressed});

  final String assetName;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  State<_MeetHeaderGhostIcon> createState() => _MeetHeaderGhostIconState();
}

class _MeetHeaderGhostIconState extends State<_MeetHeaderGhostIcon> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _interactive => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _pressed;
    final iconOpacity = active ? 1.0 : 0.3;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: _interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: _interactive ? (_) => setState(() => _hovered = true) : null,
        onExit: (_) {
          setState(() {
            _hovered = false;
            _pressed = false;
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _interactive ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _interactive
              ? (_) {
                  setState(() => _pressed = false);
                  widget.onPressed?.call();
                }
              : null,
          onTapCancel: _interactive ? () => setState(() => _pressed = false) : null,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 120),
                scale: _pressed ? 0.96 : 1,
                child: PbSvgIcon(
                  assetName: widget.assetName,
                  size: 18,
                  color: PbColors.customBrandInk.withValues(alpha: _interactive ? iconOpacity : 0.3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
