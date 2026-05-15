import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_typography.dart';
import 'pb_svg_icon.dart';

enum PbButtonVariant { primary, secondary }

class PbButton extends StatefulWidget {
  const PbButton({
    super.key,
    required this.iconAssetName,
    required this.label,
    required this.variant,
    this.iconOnly = false,
  });

  final String iconAssetName;
  final String label;
  final PbButtonVariant variant;
  final bool iconOnly;

  @override
  State<PbButton> createState() => _PbButtonState();
}

class _PbButtonState extends State<PbButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _isPrimary => widget.variant == PbButtonVariant.primary;
  bool get _lifted => _hovered && !_pressed;

  @override
  Widget build(BuildContext context) {
    final borderColor = _pressed
        ? (_isPrimary
              ? PbColors.surfaceActionPrimary
              : PbColors.borderStateSelected)
        : (_isPrimary ? PbColors.surfaceActionPrimary : PbColors.borderSoft);
    final gradientColors = _pressed
        ? (_isPrimary
              ? const [
                  PbColors.surfaceActionPrimary,
                  PbColors.surfaceActionPrimary,
                ]
              : const [
                  PbColors.surfaceStateSelected,
                  PbColors.surfaceStateSelected,
                ])
        : (_isPrimary
              ? const [
                  PbColors.surfaceRailActive,
                  PbColors.surfaceActionPrimary,
                ]
              : const [PbColors.surfacePanel, PbColors.surfacePanelSoft]);
    final boxShadow = _pressed
        ? const [
            BoxShadow(
              color: Color.fromRGBO(15, 23, 42, 0.08),
              blurRadius: 2,
              offset: Offset(0, 1),
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
        : null;
    final textColor = _isPrimary ? PbColors.textInverse : PbColors.textPrimary;

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
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: Transform.translate(
          offset: Offset(0, _lifted ? -1 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: widget.iconOnly ? 48 : 40,
            constraints: BoxConstraints(minWidth: widget.iconOnly ? 48 : 0),
            padding: EdgeInsets.symmetric(horizontal: widget.iconOnly ? 0 : 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.iconOnly ? 14 : 10),
              border: Border.all(color: borderColor),
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: boxShadow,
            ),
            child: Row(
              mainAxisSize: widget.iconOnly
                  ? MainAxisSize.min
                  : MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PbSvgIcon(
                  assetName: widget.iconAssetName,
                  size: widget.iconOnly ? 20 : 18,
                  color: textColor,
                ),
                if (!widget.iconOnly) ...[
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style:
                        (_isPrimary
                                ? PowerboardsTypography.buttonPrimary
                                : PowerboardsTypography.buttonSecondary)
                            .copyWith(color: textColor),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
