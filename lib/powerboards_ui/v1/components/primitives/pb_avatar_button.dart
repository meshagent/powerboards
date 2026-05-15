import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import 'pb_avatar.dart';
import 'pb_svg_icon.dart';

class PbAvatarButton extends StatefulWidget {
  const PbAvatarButton({
    super.key,
    required this.initials,
    this.selected = false,
    this.avatarSize = 34,
    this.chevronColor = PbColors.textPrimary,
    this.idleBorderColor,
    this.onPressed,
  });

  final String initials;
  final bool selected;
  final double avatarSize;
  final Color chevronColor;
  final Color? idleBorderColor;
  final VoidCallback? onPressed;

  @override
  State<PbAvatarButton> createState() => _PbAvatarButtonState();
}

class _PbAvatarButtonState extends State<PbAvatarButton> {
  static const _chevronDuration = Duration(milliseconds: 180);
  bool _hovered = false;
  bool _pressed = false;

  bool get _lifted => _hovered && !_pressed;

  @override
  Widget build(BuildContext context) {
    final avatarShadow = widget.selected
        ? const [
            BoxShadow(
              color: Color.fromARGB(214, 199, 216, 255),
              blurRadius: 0,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Color.fromRGBO(15, 23, 42, 0.12),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ]
        : _pressed
        ? const [
            BoxShadow(
              color: Color.fromARGB(214, 199, 216, 255),
              blurRadius: 0,
              spreadRadius: 2,
            ),
          ]
        : _hovered
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PbAvatar(
                initials: widget.initials,
                size: widget.avatarSize,
                borderColor: widget.idleBorderColor,
                boxShadow: avatarShadow,
              ),
              const SizedBox(width: 3),
              AnimatedRotation(
                turns: widget.selected ? -0.5 : 0,
                duration: _chevronDuration,
                curve: Curves.easeOutCubic,
                child: PbSvgIcon(
                  assetName: 'chevron-down',
                  size: 16,
                  color: widget.chevronColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
