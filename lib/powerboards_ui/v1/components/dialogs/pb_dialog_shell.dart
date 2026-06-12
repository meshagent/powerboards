import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_typography.dart';
import '../primitives/pb_svg_icon.dart';

class PbDialogShell extends StatelessWidget {
  const PbDialogShell({
    super.key,
    required this.title,
    this.description,
    required this.child,
    this.actions = const <Widget>[],
    required this.onClose,
    this.maxWidth = 425,
    this.minHeight,
    this.maxHeight,
    this.expandBody = false,
  });

  final String title;
  final String? description;
  final Widget child;
  final List<Widget> actions;
  final VoidCallback onClose;
  final double maxWidth;
  final double? minHeight;
  final double? maxHeight;
  final bool expandBody;

  static const double _overlayBlur = 14;
  static const double _overlayAlpha = 0.52;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final dialogMaxHeight = maxHeight ?? math.min(700.0, viewport.height - 120);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: _overlayBlur, sigmaY: _overlayBlur),
              child: Container(color: PbColors.surfaceRailActive.withValues(alpha: _overlayAlpha)),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: dialogMaxHeight),
                child: Container(
                  constraints: minHeight == null ? null : BoxConstraints(minHeight: minHeight!),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: PbColors.borderSoft),
                    gradient: const LinearGradient(
                      colors: [PbColors.surfacePanel, PbColors.surfacePanelSoft],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: const [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.08), blurRadius: 80, offset: Offset(0, 30))],
                  ),
                  child: Column(
                    mainAxisSize: expandBody ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      PbDialogHeader(title: title, description: description, onClose: onClose),
                      const SizedBox(height: 24),
                      if (expandBody) Expanded(child: child) else child,
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            for (final (index, action) in actions.indexed) ...[
                              Expanded(child: action),
                              if (index < actions.length - 1) const SizedBox(width: 12),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PbDialogHeader extends StatelessWidget {
  const PbDialogHeader({super.key, required this.title, this.description, required this.onClose});

  final String title;
  final String? description;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final resolvedDescription = description?.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: PowerboardsTypography.h2),
              if (resolvedDescription != null && resolvedDescription.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(resolvedDescription, style: PowerboardsTypography.meta.copyWith(color: PbColors.textMuted)),
              ],
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(6, -6),
          child: PbDialogCloseButton(onPressed: onClose),
        ),
      ],
    );
  }
}

class PbDialogCloseButton extends StatefulWidget {
  const PbDialogCloseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<PbDialogCloseButton> createState() => _PbDialogCloseButtonState();
}

class _PbDialogCloseButtonState extends State<PbDialogCloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.all(Radius.circular(10))),
          alignment: Alignment.center,
          child: Opacity(
            opacity: _hovered ? 1 : 0.3,
            child: const PbSvgIcon(assetName: 'x', size: 18, color: PbColors.textMuted),
          ),
        ),
      ),
    );
  }
}
