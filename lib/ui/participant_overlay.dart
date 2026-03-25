import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:powerboards/powerboards_controller/powerboards_controller.dart';
import 'package:powerboards/livekit/expand_participant_controller.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';

const audioIconSize = 16.0;
const audioIconColor = Colors.white;
const textStyle = TextStyle(color: audioIconColor, fontSize: 11, fontWeight: .w500);

class ParticipantOverlay extends StatefulWidget {
  const ParticipantOverlay({super.key, required this.participant, this.showName = true});

  final lk.Participant participant;
  final bool showName;

  @override
  State createState() => _ParticipantOverlayState();
}

class _ParticipantOverlayState extends State<ParticipantOverlay> with SingleTickerProviderStateMixin {
  final _menuController = ShadContextMenuController();

  late AnimationController _animationController;
  late Animation<double> _animation;

  List<ShadContextMenuItem> _getMenuItems() {
    final expandController = Controller.ofType<ExpandParticipantController>(context);
    final expanded = expandController.isExpanded(widget.participant.identity);

    return [
      ShadContextMenuItem(
        height: 40.0,
        leading: Icon(expanded ? LucideIcons.minimize2 : LucideIcons.expand, size: 16),
        onPressed: () {
          expandController.toggle(widget.participant.identity);
          _menuController.hide();
        },
        child: Text(expanded ? "Collapse" : "Expand"),
      ),
    ];
  }

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
    _menuController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = widget.participant.isMuted;
    final name = widget.participant.name;

    final menuItems = _getMenuItems();

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0x992f2d57)),
      padding: const .symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: .min,
        mainAxisAlignment: .start,
        crossAxisAlignment: .center,
        children: [
          Icon(muted ? LucideIcons.micOff : LucideIcons.mic, color: audioIconColor, size: audioIconSize),

          if (name.isNotEmpty)
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
                child: Text(name, style: textStyle, overflow: .ellipsis),
              ),
            ),

          Padding(
            padding: const .only(left: 2),
            child: AdaptiveShadContextMenu(
              controller: _menuController,
              boundaryContext: context,
              estimatedMenuWidth: 128,
              estimatedMenuHeight: menuItems.length * 40.0 + 8.0,
              items: menuItems,
              child: ShadIconButton.ghost(
                width: 20.0,
                height: 20.0,
                hoverBackgroundColor: Colors.transparent,
                icon: const Icon(LucideIcons.ellipsis, color: audioIconColor, size: 14),
                onPressed: () {
                  _menuController.toggle();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
