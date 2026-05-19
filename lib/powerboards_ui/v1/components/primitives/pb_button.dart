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
    this.onPressed,
  });

  final String iconAssetName;
  final String label;
  final PbButtonVariant variant;
  final bool iconOnly;
  final VoidCallback? onPressed;

  @override
  State<PbButton> createState() => _PbButtonState();
}

class _PbButtonState extends State<PbButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _isPrimary => widget.variant == PbButtonVariant.primary;
  bool get _lifted => _hovered && !_pressed;
  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final borderColor = _pressed
        ? (_isPrimary ? PbColors.surfaceActionPrimary : PbColors.borderStateSelected)
        : (_isPrimary ? PbColors.surfaceActionPrimary : PbColors.borderSoft);
    final gradientColors = _pressed
        ? (_isPrimary
              ? const [PbColors.surfaceActionPrimary, PbColors.surfaceActionPrimary]
              : const [PbColors.surfaceStateSelected, PbColors.surfaceStateSelected])
        : (_isPrimary
              ? const [PbColors.surfaceRailActive, PbColors.surfaceActionPrimary]
              : const [PbColors.surfacePanel, PbColors.surfacePanelSoft]);
    final boxShadow = _pressed
        ? const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.08), blurRadius: 2, offset: Offset(0, 1))]
        : _lifted
        ? const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.12), blurRadius: 30, offset: Offset(0, 14))]
        : null;
    final textColor = _isPrimary ? PbColors.textInverse : PbColors.textPrimary;

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: _enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: _enabled
          ? (_) => setState(() {
              _hovered = false;
              _pressed = false;
            })
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        child: Transform.translate(
          offset: Offset(0, _lifted ? -1 : 0),
          child: Opacity(
            opacity: _enabled ? 1 : 0.42,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              height: widget.iconOnly ? 48 : 40,
              constraints: BoxConstraints(minWidth: widget.iconOnly ? 48 : 0),
              padding: EdgeInsets.symmetric(horizontal: widget.iconOnly ? 0 : 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.iconOnly ? 14 : 10),
                border: Border.all(color: borderColor),
                gradient: LinearGradient(colors: gradientColors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
                boxShadow: boxShadow,
              ),
              child: Row(
                mainAxisSize: widget.iconOnly ? MainAxisSize.min : MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PbSvgIcon(assetName: widget.iconAssetName, size: widget.iconOnly ? 20 : 18, color: textColor),
                  if (!widget.iconOnly) ...[
                    const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: (_isPrimary ? PowerboardsTypography.buttonPrimary : PowerboardsTypography.buttonSecondary).copyWith(
                        color: textColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
