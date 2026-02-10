import 'package:flutter/material.dart';

import 'popover_direction.dart';
import 'popover_position_render_object.dart';

final class PopoverPositionWidget extends SingleChildRenderObjectWidget {
  final Rect attachRect;
  final double arrowHeight;
  final BoxConstraints? constraints;
  final PopoverDirection? direction;

  const PopoverPositionWidget({
    super.key,
    required this.arrowHeight,
    required this.attachRect,
    this.constraints,
    this.direction,
    super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return PopoverPositionRenderObject(attachRect: attachRect, direction: direction, constraints: constraints, arrowHeight: arrowHeight);
  }

  @override
  void updateRenderObject(BuildContext context, PopoverPositionRenderObject renderObject) {
    renderObject
      ..attachRect = attachRect
      ..direction = direction
      ..additionalConstraints = constraints;
  }
}
