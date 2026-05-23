import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_typography.dart';
import 'pb_svg_icon.dart';

enum PbButtonVariant { primary, secondary }

class PbButton extends StatefulWidget {
  const PbButton({
    super.key,
    this.iconAssetName,
    required this.label,
    required this.variant,
    this.iconOnly = false,
    this.iconOnlySize = 48,
    this.height = 40,
    this.horizontalPadding = 18,
    this.iconSize = 18,
    this.iconGap = 10,
    this.onPressed,
  });

  final String? iconAssetName;
  final String label;
  final PbButtonVariant variant;
  final bool iconOnly;
  final double iconOnlySize;
  final double height;
  final double horizontalPadding;
  final double iconSize;
  final double iconGap;
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
              height: widget.iconOnly ? widget.iconOnlySize : widget.height,
              constraints: BoxConstraints(minWidth: widget.iconOnly ? widget.iconOnlySize : 0),
              padding: EdgeInsets.symmetric(horizontal: widget.iconOnly ? 0 : widget.horizontalPadding),
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
                  if (widget.iconAssetName != null)
                    PbSvgIcon(assetName: widget.iconAssetName!, size: widget.iconOnly ? 20 : widget.iconSize, color: textColor),
                  if (!widget.iconOnly) ...[
                    if (widget.iconAssetName != null) SizedBox(width: widget.iconGap),
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

class PbTertiaryButton extends StatelessWidget {
  const PbTertiaryButton({super.key, this.iconAssetName, required this.label, this.solid = false, this.onPressed});

  const PbTertiaryButton.solid({super.key, this.iconAssetName, required this.label, this.onPressed}) : solid = true;

  final String? iconAssetName;
  final String label;
  final bool solid;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return PbButton(
      iconAssetName: iconAssetName,
      label: label,
      variant: solid ? PbButtonVariant.primary : PbButtonVariant.secondary,
      height: 36,
      horizontalPadding: 14,
      iconSize: 16,
      iconGap: 8,
      onPressed: onPressed,
    );
  }
}
