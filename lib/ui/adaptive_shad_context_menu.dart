import 'dart:ui';

export 'package:meshagent_flutter_shadcn/ui/coordinated_context_menu.dart' show ShadMenuHorizontalPosition, ShadMenuVerticalPosition;

import 'package:flutter/widgets.dart';
import 'package:meshagent_flutter_shadcn/ui/coordinated_context_menu.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AdaptiveShadContextMenu extends StatelessWidget {
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
    this.centerHorizontallyInBoundary = false,
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
  final bool centerHorizontallyInBoundary;

  @override
  Widget build(BuildContext context) {
    return CoordinatedShadContextMenu(
      anchor: anchor,
      visible: visible,
      constraints: constraints,
      onHoverArea: onHoverArea,
      padding: padding,
      groupId: groupId,
      shadows: shadows,
      decoration: decoration,
      filter: filter,
      controller: controller,
      onTapOutside: onTapOutside,
      onTapInside: onTapInside,
      onTapUpInside: onTapUpInside,
      onTapUpOutside: onTapUpOutside,
      popoverReverseDuration: popoverReverseDuration,
      horizontalPosition: horizontalPosition,
      verticalPosition: verticalPosition,
      boundaryContext: boundaryContext,
      estimatedMenuWidth: estimatedMenuWidth,
      estimatedMenuHeight: estimatedMenuHeight,
      anchorGap: anchorGap,
      viewportVerticalSplit: viewportVerticalSplit,
      viewportEdgePadding: viewportEdgePadding,
      centerHorizontallyInBoundary: centerHorizontallyInBoundary,
      items: items,
      child: child,
    );
  }
}
