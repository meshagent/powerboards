import 'package:flutter/material.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const audioIconSize = 16.0;
const audioIconColor = Colors.white;
const textStyle = TextStyle(color: audioIconColor, fontSize: 11, fontWeight: .w500);

class ParticipantOverlayContextMenuConfig {
  const ParticipantOverlayContextMenuConfig({required this.items, required this.controller, this.boundaryContext});

  final List<ShadContextMenuItem> items;
  final ShadContextMenuController controller;
  final BuildContext? boundaryContext;
}

class ParticipantOverlay extends StatefulWidget {
  const ParticipantOverlay({super.key, required this.name, required this.muted, this.showName = true, this.contextMenu});

  final String name;
  final bool muted;
  final bool showName;
  final ParticipantOverlayContextMenuConfig? contextMenu;

  @override
  State createState() => _ParticipantOverlayState();
}

class _ParticipantOverlayState extends State<ParticipantOverlay> with SingleTickerProviderStateMixin {
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
    final contextMenu = widget.contextMenu;

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

          if (contextMenu != null)
            Padding(
              padding: const .only(left: 2),
              child: AdaptiveShadContextMenu(
                controller: contextMenu.controller,
                boundaryContext: contextMenu.boundaryContext ?? context,
                estimatedMenuWidth: 128,
                estimatedMenuHeight: contextMenu.items.length * 40.0 + 8.0,
                items: contextMenu.items,
                child: ShadIconButton.ghost(
                  width: 20.0,
                  height: 20.0,
                  hoverBackgroundColor: Colors.transparent,
                  icon: const Icon(LucideIcons.ellipsis, color: audioIconColor, size: 14),
                  onPressed: contextMenu.controller.toggle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
