import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_typography.dart';

class PbMenuFilterField extends StatefulWidget {
  const PbMenuFilterField({
    super.key,
    this.placeholder = 'Filter...',
    this.focused,
    this.hovered,
    this.height = 40,
    this.margin = const EdgeInsets.only(bottom: 4),
    this.controller,
    this.onChanged,
  });

  final String placeholder;
  final bool? focused;
  final bool? hovered;
  final double height;
  final EdgeInsetsGeometry margin;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  State<PbMenuFilterField> createState() => _PbMenuFilterFieldState();
}

class _PbMenuFilterFieldState extends State<PbMenuFilterField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.focused ?? _focusNode.hasFocus;
    final hovered = widget.hovered ?? _hovered;

    final boxShadow = focused
        ? const [
            BoxShadow(color: Color.fromRGBO(199, 216, 255, 0.36), blurRadius: 0, spreadRadius: 3),
            BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.06), blurRadius: 30, offset: Offset(0, 12)),
          ]
        : hovered
        ? const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.12), blurRadius: 30, offset: Offset(0, 14))]
        : null;

    return MouseRegion(
      cursor: SystemMouseCursors.text,
      onEnter: widget.hovered == null ? (_) => setState(() => _hovered = true) : null,
      onExit: widget.hovered == null ? (_) => setState(() => _hovered = false) : null,
      child: Transform.translate(
        offset: Offset(0, hovered && !focused ? -1 : 0),
        child: Container(
          height: widget.height,
          margin: widget.margin,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: focused ? PbColors.borderStateSelected : PbColors.borderSoft),
            color: PbColors.surfacePanel.withValues(alpha: 0.88),
            boxShadow: boxShadow,
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: widget.onChanged,
            cursorColor: PbColors.textPrimary,
            style: PowerboardsTypography.p.copyWith(fontSize: 14, height: 1.3, color: PbColors.textPrimary),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: widget.placeholder,
              hintStyle: PowerboardsTypography.p.copyWith(fontSize: 14, height: 1.3, color: PbColors.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}
