import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class HoverBuilder extends StatefulWidget {
  const HoverBuilder({super.key, required this.builder, this.onHover, this.cursor = SystemMouseCursors.click});

  final MouseCursor cursor;
  final Widget Function(bool isHovered) builder;
  final void Function(bool isHovered)? onHover;

  @override
  State createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _isHovered = false;

  void _onHoverChanged({required bool enabled}) {
    if (widget.onHover != null) {
      widget.onHover!(enabled);
    }
    setState(() {
      _isHovered = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (PointerEnterEvent event) => _onHoverChanged(enabled: true),
      onExit: (PointerExitEvent event) => _onHoverChanged(enabled: false),
      child: widget.builder(_isHovered),
    );
  }
}
