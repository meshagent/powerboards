import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const audioIconSize = 16.0;
const audioIconColor = Colors.white;
const textStyle = TextStyle(color: audioIconColor, fontSize: 11, fontWeight: .w500);

class ParticipantOverlay extends StatefulWidget {
  const ParticipantOverlay({super.key, required this.name, required this.muted, this.showName = true});

  final String name;
  final bool muted;
  final bool showName;

  @override
  ParticipantOverlayState createState() => ParticipantOverlayState();
}

class ParticipantOverlayState extends State<ParticipantOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    const begin = 0.0;
    const end = 1.0;

    _animationController = AnimationController(
      value: widget.showName ? end : begin,
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(covariant ParticipantOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showName != oldWidget.showName) {
      widget.showName ? _animationController.forward() : _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0x992f2d57)),
      padding: const .symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: .min,
        mainAxisAlignment: .start,
        crossAxisAlignment: .center,
        children: [
          Icon(widget.muted ? LucideIcons.micOff : LucideIcons.mic, color: audioIconColor, size: audioIconSize),

          if (widget.name.isNotEmpty)
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Flexible(
                  child: SizedBox(
                    height: audioIconSize,
                    child: ClipRect(
                      child: Align(alignment: .centerLeft, widthFactor: _animation.value, child: child),
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const .only(left: 1, right: 3),
                child: Text(widget.name, style: textStyle, overflow: .ellipsis),
              ),
            ),
        ],
      ),
    );
  }
}
