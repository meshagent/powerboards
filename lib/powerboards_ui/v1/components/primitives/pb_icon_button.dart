import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import 'pb_svg_icon.dart';

enum PbRailIconButtonVariant { outlineInverse, selected }

class PbIconButton extends StatefulWidget {
  const PbIconButton({
    super.key,
    required this.iconAssetName,
    required this.variant,
    this.compact = true,
    this.menuOpen = false,
    this.onPressed,
  });

  final String iconAssetName;
  final PbRailIconButtonVariant variant;
  final bool compact;
  final bool menuOpen;
  final VoidCallback? onPressed;

  @override
  State<PbIconButton> createState() => _PbIconButtonState();
}

class _PbIconButtonState extends State<PbIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _isSelected => widget.variant == PbRailIconButtonVariant.selected;
  bool get _isMenuOpen => widget.menuOpen && !_isSelected;
  bool get _lifted => (_hovered || _isMenuOpen) && !_pressed && !_isSelected;

  @override
  Widget build(BuildContext context) {
    final double size = widget.compact ? 44 : 48;
    final double radius = widget.compact ? 13 : 14;
    final borderColor = _isSelected
        ? PbColors.surfaceActionPrimary
        : _pressed
        ? const Color.fromARGB(92, 248, 250, 252)
        : (_hovered || _isMenuOpen)
        ? const Color.fromARGB(87, 248, 250, 252)
        : const Color.fromARGB(61, 248, 250, 252);
    final backgroundColor = _isSelected
        ? PbColors.surfaceRailSelected
        : _pressed
        ? const Color.fromARGB(26, 248, 250, 252)
        : (_hovered || _isMenuOpen)
        ? const Color.fromARGB(15, 248, 250, 252)
        : Colors.transparent;
    final boxShadow = _isSelected
        ? const [
            BoxShadow(
              color: Color.fromRGBO(15, 23, 42, 0.22),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ]
        : _pressed
        ? const [
            BoxShadow(
              color: Color.fromRGBO(15, 23, 42, 0.18),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ]
        : (_lifted || _isMenuOpen)
        ? const [
            BoxShadow(
              color: Color.fromRGBO(15, 23, 42, 0.12),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ]
        : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: Transform.translate(
          offset: Offset(0, _lifted ? -1 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: backgroundColor,
              border: Border.all(color: borderColor),
              boxShadow: boxShadow,
            ),
            alignment: Alignment.center,
            child: PbSvgIcon(
              assetName: widget.iconAssetName,
              size: widget.compact ? 21 : 22,
              color: const Color.fromARGB(240, 248, 250, 252),
            ),
          ),
        ),
      ),
    );
  }
}
