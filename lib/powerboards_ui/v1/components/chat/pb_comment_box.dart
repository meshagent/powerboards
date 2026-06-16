import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_tokens.dart';
import '../../theme/pb_typography.dart';
import '../primitives/pb_svg_icon.dart';

class PbCommentBoxShell extends StatelessWidget {
  const PbCommentBoxShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

class PbCommentBox extends StatefulWidget {
  const PbCommentBox({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    this.dropPlaceholder = 'Drop files to attach',
    this.readOnly = false,
    this.dropActive = false,
    this.attachmentChips = const <Widget>[],
    this.leadingControls = const <Widget>[],
    this.trailingControl,
    this.status,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final String dropPlaceholder;
  final bool readOnly;
  final bool dropActive;
  final List<Widget> attachmentChips;
  final List<Widget> leadingControls;
  final Widget? trailingControl;
  final Widget? status;
  final ValueChanged<String>? onChanged;

  @override
  State<PbCommentBox> createState() => _PbCommentBoxState();
}

class _PbCommentBoxState extends State<PbCommentBox> {
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant PbCommentBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.dropActive || widget.focusNode.hasFocus;
    final placeholder = widget.dropActive && widget.controller.text.trim().isEmpty ? widget.dropPlaceholder : widget.placeholder;

    return CustomPaint(
      foregroundPainter: widget.dropActive
          ? const _DashedRoundRectPainter(color: PbColors.borderStateSelected, radius: PbRadii.medium)
          : null,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          key: const ValueKey('comment-box'),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PbRadii.medium),
            border: Border.all(color: focused ? PbColors.borderStateSelected : PbColors.borderSoft),
            gradient: LinearGradient(
              colors: widget.dropActive
                  ? const <Color>[PbColors.surfaceStateSelected, PbColors.surfaceStateSelected]
                  : const <Color>[PbColors.surfacePanel, PbColors.surfacePanelSoft],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: focused
                ? const <BoxShadow>[
                    BoxShadow(color: Color.fromRGBO(199, 216, 255, 0.36), blurRadius: 0, spreadRadius: 3),
                    ...PbShadows.card,
                  ]
                : _hovered
                ? PbShadows.stateHover
                : PbShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (widget.attachmentChips.isNotEmpty) ...<Widget>[
                Wrap(spacing: 12, runSpacing: 10, children: widget.attachmentChips),
                const SizedBox(height: 14),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 28, maxHeight: 168),
                child: Material(
                  type: MaterialType.transparency,
                  child: TextField(
                    key: const ValueKey('comment-box-input'),
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    minLines: 1,
                    maxLines: 6,
                    readOnly: widget.readOnly || widget.dropActive,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    cursorColor: PbColors.customBrandInk,
                    style: PowerboardsTypography.p.copyWith(color: PbColors.textBody),
                    decoration: InputDecoration.collapsed(
                      hintText: placeholder,
                      hintStyle: PowerboardsTypography.p.copyWith(color: PbColors.textMuted),
                    ),
                    onChanged: widget.onChanged,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  ...widget.leadingControls,
                  if (widget.trailingControl != null) const Spacer(),
                  if (widget.trailingControl != null) widget.trailingControl!,
                ],
              ),
              if (widget.status != null) ...<Widget>[const SizedBox(height: 12), widget.status!],
            ],
          ),
        ),
      ),
    );
  }
}

class PbComposerAttachmentChip extends StatelessWidget {
  const PbComposerAttachmentChip({
    super.key,
    required this.title,
    required this.iconAssetName,
    required this.iconColor,
    this.onPressed,
    this.onRemove,
    this.trailing,
  });

  final String title;
  final String iconAssetName;
  final Color iconColor;
  final VoidCallback? onPressed;
  final VoidCallback? onRemove;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final interactive = onPressed != null;
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 38, maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: PbColors.surfacePanel,
            borderRadius: BorderRadius.circular(PbRadii.small),
            border: Border.all(color: PbColors.borderSoft),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PbSvgIcon(assetName: iconAssetName, size: 20, color: iconColor),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PowerboardsTypography.smallStrong.copyWith(color: PbColors.textPrimary, fontWeight: FontWeight.w800),
                ),
              ),
              if (trailing != null) ...<Widget>[const SizedBox(width: 10), trailing!],
              if (onRemove != null) ...<Widget>[
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: Center(
                      child: PbSvgIcon(assetName: 'x', size: 15, color: PbColors.textSubtle),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PbComposerMcpPill extends StatelessWidget {
  const PbComposerMcpPill({super.key, required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30, maxWidth: 180),
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: PbColors.surfaceAccentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PbColors.borderStateSelected),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PowerboardsTypography.button.copyWith(color: PbColors.customBlue),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Remove MCP',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: Center(
                  child: PbSvgIcon(assetName: 'x', size: 14, color: PbColors.customBlue),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PbComposerSendButton extends StatelessWidget {
  const PbComposerSendButton({super.key, required this.active, this.onPressed, this.child});

  final bool active;
  final VoidCallback? onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return PbComposerActionSurface(
      tooltip: active ? 'Send' : 'Unable to send',
      width: 42,
      minHeight: 36,
      padding: EdgeInsets.zero,
      active: active,
      primary: true,
      onPressed: active ? onPressed : null,
      child: child ?? const PbSvgIcon(assetName: 'send-horizontal', size: 18, color: PbColors.textInverse),
    );
  }
}

class PbComposerIconButton extends StatelessWidget {
  const PbComposerIconButton({super.key, required this.tooltip, required this.child, this.onPressed, this.active = true});

  final String tooltip;
  final Widget child;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return PbComposerActionSurface(
      tooltip: tooltip,
      width: 38,
      minHeight: 38,
      padding: EdgeInsets.zero,
      active: active,
      onPressed: onPressed,
      child: child,
    );
  }
}

class PbComposerMenuButton extends StatelessWidget {
  const PbComposerMenuButton({
    super.key,
    required this.label,
    required this.iconAssetName,
    required this.open,
    this.onPressed,
    this.tooltip,
    this.active = true,
  });

  final String label;
  final String iconAssetName;
  final bool open;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return PbComposerActionSurface(
      tooltip: tooltip ?? label,
      minHeight: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      active: active,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PbSvgIcon(assetName: iconAssetName, size: 18, color: PbColors.customBrandInk),
          const SizedBox(width: 10),
          Text(label, style: PowerboardsTypography.button),
          const SizedBox(width: 8),
          AnimatedRotation(
            turns: open ? -0.5 : 0,
            duration: PbMotion.chevron,
            curve: Curves.easeOutCubic,
            child: const PbSvgIcon(assetName: 'chevron-down', size: 16, color: PbColors.customBrandInk),
          ),
        ],
      ),
    );
  }
}

class PbComposerActionSurface extends StatefulWidget {
  const PbComposerActionSurface({
    super.key,
    required this.tooltip,
    required this.child,
    required this.minHeight,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.active = true,
    this.primary = false,
    this.onPressed,
  });

  final String tooltip;
  final Widget child;
  final double minHeight;
  final double? width;
  final EdgeInsetsGeometry padding;
  final bool active;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  State<PbComposerActionSurface> createState() => _PbComposerActionSurfaceState();
}

class _PbComposerActionSurfaceState extends State<PbComposerActionSurface> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.active && widget.onPressed != null;
    final lifted = enabled && _hovered && !_pressed;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTapUp: enabled
              ? (_) {
                  setState(() => _pressed = false);
                  widget.onPressed?.call();
                }
              : null,
          child: AnimatedContainer(
            duration: _pressed ? Duration.zero : PbMotion.state,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, lifted ? -1 : 0, 0),
            width: widget.width,
            constraints: BoxConstraints(minHeight: widget.minHeight),
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PbRadii.small),
              border: Border.all(
                color: widget.primary
                    ? PbColors.surfaceActionPrimary
                    : _pressed
                    ? PbColors.borderStateSelected
                    : PbColors.borderSoft,
              ),
              gradient: widget.primary
                  ? const LinearGradient(
                      colors: <Color>[PbColors.surfaceRailActive, PbColors.surfaceActionPrimary],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : null,
              color: widget.primary
                  ? null
                  : _pressed
                  ? PbColors.surfaceStateSelected
                  : PbColors.surfacePanel,
              boxShadow: _pressed
                  ? PbShadows.statePressedInset
                  : lifted
                  ? PbShadows.stateHover
                  : null,
            ),
            alignment: Alignment.center,
            child: Opacity(opacity: widget.active ? 1 : 0.62, child: widget.child),
          ),
        ),
      ),
    );
  }
}

class _DashedRoundRectPainter extends CustomPainter {
  const _DashedRoundRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 6.0;
    const gap = 5.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1), Radius.circular(radius)));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
