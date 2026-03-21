import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum ShadMenuHorizontalPosition { automatic, left, right }

enum ShadMenuVerticalPosition { automatic, down, up }

RenderBox? _safeRenderBox(BuildContext? context) {
  if (context == null || !context.mounted) {
    return null;
  }

  try {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached || !renderObject.hasSize) {
      return null;
    }

    return renderObject;
  } catch (_) {
    return null;
  }
}

ShadAnchor resolveAdaptiveShadMenuAnchor(
  BuildContext context, {
  BuildContext? boundaryContext,
  double viewportVerticalSplit = 2 / 3,
  double gap = 8,
  double? estimatedMenuWidth,
  double? estimatedMenuHeight,
  double viewportEdgePadding = 12,
  ShadMenuHorizontalPosition horizontalPosition = ShadMenuHorizontalPosition.automatic,
  ShadMenuVerticalPosition verticalPosition = ShadMenuVerticalPosition.automatic,
}) {
  const fallbackAnchor = ShadAnchor(childAlignment: Alignment.topLeft, overlayAlignment: Alignment.bottomLeft, offset: Offset(0, 8));
  final renderBox = _safeRenderBox(context);
  if (renderBox == null) {
    return fallbackAnchor;
  }

  final overlayRenderBox = _safeRenderBox(Overlay.maybeOf(context)?.context);
  final boundaryRenderBox = _safeRenderBox(boundaryContext) ?? overlayRenderBox;

  try {
    final viewportSize = boundaryRenderBox?.size ?? MediaQuery.sizeOf(context);
    final triggerOrigin = boundaryRenderBox != null
        ? renderBox.localToGlobal(Offset.zero, ancestor: boundaryRenderBox)
        : renderBox.localToGlobal(Offset.zero);
    final triggerBottom = triggerOrigin.dy + renderBox.size.height;
    final triggerRight = triggerOrigin.dx + renderBox.size.width;
    final triggerCenter = triggerOrigin + Offset(renderBox.size.width / 2, renderBox.size.height / 2);

    final alignLeft = _shouldAlignMenuLeft(
      triggerOriginX: triggerOrigin.dx,
      triggerRightX: triggerRight,
      triggerCenterX: triggerCenter.dx,
      viewportWidth: viewportSize.width,
      viewportEdgePadding: viewportEdgePadding,
      estimatedMenuWidth: estimatedMenuWidth,
      horizontalPosition: horizontalPosition,
    );

    final openDown = switch (verticalPosition) {
      ShadMenuVerticalPosition.down => true,
      ShadMenuVerticalPosition.up => false,
      ShadMenuVerticalPosition.automatic => _shouldOpenMenuDown(
        triggerOriginY: triggerOrigin.dy,
        triggerBottomY: triggerBottom,
        triggerCenterY: triggerCenter.dy,
        viewportHeight: viewportSize.height,
        viewportVerticalSplit: viewportVerticalSplit,
        estimatedMenuHeight: estimatedMenuHeight,
        viewportEdgePadding: viewportEdgePadding,
      ),
    };

    return ShadAnchor(
      childAlignment: Alignment(alignLeft ? -1 : 1, openDown ? -1 : 1),
      overlayAlignment: Alignment(alignLeft ? -1 : 1, openDown ? 1 : -1),
      offset: Offset(0, openDown ? gap : -gap),
    );
  } catch (_) {
    return fallbackAnchor;
  }
}

bool _shouldAlignMenuLeft({
  required double triggerOriginX,
  required double triggerRightX,
  required double triggerCenterX,
  required double viewportWidth,
  required double viewportEdgePadding,
  required ShadMenuHorizontalPosition horizontalPosition,
  double? estimatedMenuWidth,
}) {
  switch (horizontalPosition) {
    case ShadMenuHorizontalPosition.left:
      return true;
    case ShadMenuHorizontalPosition.right:
      return false;
    case ShadMenuHorizontalPosition.automatic:
      if (estimatedMenuWidth != null) {
        final availableRight = viewportWidth - triggerOriginX - viewportEdgePadding;
        final availableLeft = triggerRightX - viewportEdgePadding;
        final fitsLeftAligned = estimatedMenuWidth <= availableRight;
        final fitsRightAligned = estimatedMenuWidth <= availableLeft;

        if (fitsLeftAligned != fitsRightAligned) {
          return fitsLeftAligned;
        }

        if (!fitsLeftAligned && !fitsRightAligned) {
          return availableRight >= availableLeft;
        }
      }

      return triggerCenterX <= viewportWidth / 2;
  }
}

bool _shouldOpenMenuDown({
  required double triggerOriginY,
  required double triggerBottomY,
  required double triggerCenterY,
  required double viewportHeight,
  required double viewportVerticalSplit,
  required double viewportEdgePadding,
  double? estimatedMenuHeight,
}) {
  if (estimatedMenuHeight != null) {
    final availableBelow = viewportHeight - triggerBottomY - viewportEdgePadding;
    final availableAbove = triggerOriginY - viewportEdgePadding;
    final fitsBelow = estimatedMenuHeight <= availableBelow;
    final fitsAbove = estimatedMenuHeight <= availableAbove;

    if (fitsBelow != fitsAbove) {
      return fitsBelow;
    }

    if (!fitsBelow && !fitsAbove) {
      return availableBelow >= availableAbove;
    }
  }

  return triggerCenterY <= viewportHeight * viewportVerticalSplit;
}

class AdaptiveShadContextMenu extends StatefulWidget {
  const AdaptiveShadContextMenu({
    super.key,
    required this.child,
    required this.items,
    this.anchor,
    this.visible,
    this.constraints,
    this.onHoverArea,
    this.padding,
    this.groupId,
    this.shadows,
    this.decoration,
    this.filter,
    this.controller,
    this.onTapOutside,
    this.onTapInside,
    this.onTapUpInside,
    this.onTapUpOutside,
    this.popoverReverseDuration,
    this.horizontalPosition = ShadMenuHorizontalPosition.automatic,
    this.verticalPosition = ShadMenuVerticalPosition.automatic,
    this.boundaryContext,
    this.estimatedMenuWidth,
    this.estimatedMenuHeight,
    this.anchorGap = 8,
    this.viewportVerticalSplit = 2 / 3,
    this.viewportEdgePadding = 12,
  });

  final Widget child;
  final List<Widget> items;
  final ShadAnchorBase? anchor;
  final bool? visible;
  final BoxConstraints? constraints;
  final ValueChanged<bool>? onHoverArea;
  final EdgeInsetsGeometry? padding;
  final Object? groupId;
  final List<BoxShadow>? shadows;
  final ShadDecoration? decoration;
  final ImageFilter? filter;
  final ShadContextMenuController? controller;
  final TapRegionCallback? onTapOutside;
  final TapRegionCallback? onTapInside;
  final TapRegionUpCallback? onTapUpInside;
  final TapRegionUpCallback? onTapUpOutside;
  final Duration? popoverReverseDuration;
  final ShadMenuHorizontalPosition horizontalPosition;
  final ShadMenuVerticalPosition verticalPosition;
  final BuildContext? boundaryContext;
  final double? estimatedMenuWidth;
  final double? estimatedMenuHeight;
  final double anchorGap;
  final double viewportVerticalSplit;
  final double viewportEdgePadding;

  @override
  State<AdaptiveShadContextMenu> createState() => _AdaptiveShadContextMenuState();
}

class _AdaptiveShadContextMenuState extends State<AdaptiveShadContextMenu> {
  final GlobalKey _triggerKey = GlobalKey();
  ShadAnchorBase? _frozenAnchor;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_syncFrozenAnchor);
  }

  @override
  void didUpdateWidget(covariant AdaptiveShadContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_syncFrozenAnchor);
      widget.controller?.addListener(_syncFrozenAnchor);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_syncFrozenAnchor);
    super.dispose();
  }

  void _syncFrozenAnchor() {
    if (!mounted) {
      return;
    }

    final controller = widget.controller;
    if (controller == null) {
      return;
    }

    if (controller.isOpen) {
      final anchor = _resolveDynamicAnchor();
      if (_frozenAnchor != anchor) {
        setState(() {
          _frozenAnchor = anchor;
        });
      }
      return;
    }

    if (_frozenAnchor != null) {
      setState(() {
        _frozenAnchor = null;
      });
    }
  }

  ShadAnchorBase _resolveDynamicAnchor() {
    final explicitAnchor = widget.anchor;
    if (explicitAnchor != null) {
      return explicitAnchor;
    }

    final triggerContext = _triggerKey.currentContext;
    return resolveAdaptiveShadMenuAnchor(
      triggerContext ?? context,
      boundaryContext: widget.boundaryContext,
      gap: widget.anchorGap,
      estimatedMenuWidth: widget.estimatedMenuWidth,
      estimatedMenuHeight: widget.estimatedMenuHeight,
      horizontalPosition: widget.horizontalPosition,
      verticalPosition: widget.verticalPosition,
      viewportVerticalSplit: widget.viewportVerticalSplit,
      viewportEdgePadding: widget.viewportEdgePadding,
    );
  }

  ShadAnchorBase get _effectiveAnchor {
    return _frozenAnchor ?? _resolveDynamicAnchor();
  }

  @override
  Widget build(BuildContext context) {
    return ShadContextMenu(
      anchor: _effectiveAnchor,
      visible: widget.visible,
      constraints: widget.constraints,
      onHoverArea: widget.onHoverArea,
      padding: widget.padding,
      groupId: widget.groupId,
      shadows: widget.shadows,
      decoration: widget.decoration,
      filter: widget.filter,
      controller: widget.controller,
      onTapOutside: widget.onTapOutside,
      onTapInside: widget.onTapInside,
      onTapUpInside: widget.onTapUpInside,
      onTapUpOutside: widget.onTapUpOutside,
      popoverReverseDuration: widget.popoverReverseDuration,
      items: widget.items,
      child: KeyedSubtree(key: _triggerKey, child: widget.child),
    );
  }
}
