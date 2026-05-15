import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_typography.dart';
import 'pb_svg_icon.dart';

class PbSwitcherField extends StatefulWidget {
  const PbSwitcherField({
    super.key,
    required this.eyebrow,
    required this.value,
    this.selected = false,
    this.onPressed,
  });

  final String eyebrow;
  final String value;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  State<PbSwitcherField> createState() => _PbSwitcherFieldState();
}

class _PbSwitcherFieldState extends State<PbSwitcherField> {
  static const _chevronDuration = Duration(milliseconds: 180);
  bool _hovered = false;
  bool _pressed = false;

  bool get _lifted => _hovered && !_pressed;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selected && !_pressed;
    final selectedSurface = _pressed || isSelected;
    final borderColor = _pressed || isSelected
        ? PbColors.borderStateSelected
        : PbColors.borderSoft;
    final shadows = _pressed
        ? const [
            BoxShadow(
              color: Color.fromRGBO(15, 23, 42, 0.08),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ]
        : isSelected
        ? const [
            BoxShadow(
              color: Color.fromRGBO(102, 116, 142, 0.12),
              blurRadius: 18,
              offset: Offset(0, 4),
            ),
          ]
        : _lifted
        ? const [
            BoxShadow(
              color: Color.fromRGBO(15, 23, 42, 0.12),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ]
        : const [
            BoxShadow(
              color: Color.fromRGBO(102, 116, 142, 0.12),
              blurRadius: 18,
              offset: Offset(0, 4),
            ),
          ];

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
          child: Container(
            constraints: const BoxConstraints(minWidth: 196),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
              color: selectedSurface ? PbColors.surfaceStateSelected : null,
              gradient: selectedSurface
                  ? null
                  : const LinearGradient(
                      colors: [
                        PbColors.surfacePanel,
                        PbColors.surfacePanelSoft,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
              boxShadow: shadows,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.eyebrow,
                        style: PowerboardsTypography.fieldEyebrow,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.value,
                        style: PowerboardsTypography.fieldValue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                AnimatedRotation(
                  turns: widget.selected ? -0.5 : 0,
                  duration: _chevronDuration,
                  curve: Curves.easeOutCubic,
                  child: const PbSvgIcon(
                    assetName: 'chevron-down',
                    size: 20,
                    color: PbColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
