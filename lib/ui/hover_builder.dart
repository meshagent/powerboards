import 'package:flutter/material.dart';

typedef HoverWidgetBuilder = Widget Function(BuildContext context, bool hovered, bool focused);

class HoverBuilder extends StatefulWidget {
  const HoverBuilder({super.key, required this.builder, this.behavior = HitTestBehavior.deferToChild});

  final HoverWidgetBuilder builder;
  final HitTestBehavior behavior;

  @override
  State createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onFocusChange: (f) => setState(() => _focused = f),
      child: MouseRegion(
        opaque: widget.behavior == HitTestBehavior.opaque,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: widget.builder(context, _hovered, _focused),
      ),
    );
  }
}
