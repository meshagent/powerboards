import 'package:flutter/material.dart';

import 'popover_direction.dart';
import 'popover_transition.dart';
import 'popover_context.dart';
import 'popover_position_widget.dart';
import 'utils/build_context_extension.dart';

class PopoverItem extends StatefulWidget {
  final Color? backgroundColor;
  final WidgetBuilder bodyBuilder;
  final PopoverDirection? direction;
  final double? radius;
  final List<BoxShadow>? shadow;
  final double? arrowWidth;
  final double arrowHeight;
  final BoxConstraints? constraints;
  late final BoxConstraints? _constraints;
  final BuildContext context;
  final double arrowDxOffset;
  final double arrowDyOffset;
  final double contentDyOffset;
  final double contentDxOffset;
  final PopoverTransition transition;
  final double? width;
  final double? height;

  PopoverItem({
    required this.context,
    required this.bodyBuilder,
    this.direction = PopoverDirection.bottom,
    this.transition = PopoverTransition.scale,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.radius = 8,
    this.shadow = const [BoxShadow(color: Color(0x1F000000), blurRadius: 5)],
    this.arrowWidth = 24,
    this.arrowHeight = 12,
    this.arrowDxOffset = 0,
    this.arrowDyOffset = 0,
    this.contentDyOffset = 0,
    this.contentDxOffset = 0,
    this.width,
    this.height,
    this.constraints,
    super.key,
  }) {
    _constraints = (width != null || height != null)
        ? constraints?.tighten(width: width, height: height) ?? BoxConstraints.tightFor(width: width, height: height)
        : constraints;
  }

  @override
  State<StatefulWidget> createState() => _PopoverItemState();
}

class _PopoverItemState extends State<PopoverItem> with SingleTickerProviderStateMixin {
  late Rect _attachRect;
  late BoxConstraints _constraints;
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PopoverPositionWidget(
          attachRect: _attachRect,
          constraints: _constraints,
          direction: widget.direction,
          arrowHeight: widget.arrowHeight,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return PopoverContext(
                attachRect: _attachRect,
                animation: _animation,
                radius: widget.radius,
                backgroundColor: widget.backgroundColor,
                boxShadow: widget.shadow,
                direction: widget.direction,
                arrowWidth: widget.arrowWidth,
                arrowHeight: widget.arrowHeight,
                transition: widget.transition,
                child: child,
              );
            },
            child: Material(
              color: widget.backgroundColor,
              child: Builder(builder: widget.bodyBuilder),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void didChangeDependencies() {
    _configureConstraints();
    WidgetsBinding.instance.addPostFrameCallback((_) => setState(_configureRect));
    super.didChangeDependencies();
  }

  @override
  void initState() {
    _configureRect();
    _controller = AnimationController(duration: const Duration(milliseconds: 150), vsync: this)..forward();

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    super.initState();
  }

  void _configureConstraints() {
    final size = MediaQuery.of(context).size;
    var constraints = BoxConstraints.loose(size);

    if (widget._constraints != null) {
      constraints = constraints.copyWith(
        minWidth: widget._constraints!.minWidth.isFinite ? widget._constraints!.minWidth : null,
        minHeight: widget._constraints!.minHeight.isFinite ? widget._constraints!.minHeight : null,
        maxWidth: widget._constraints!.maxWidth.isFinite ? widget._constraints!.maxWidth : null,
        maxHeight: widget._constraints!.maxHeight.isFinite ? widget._constraints!.maxHeight : null,
      );
    }

    if (widget.direction == PopoverDirection.top || widget.direction == PopoverDirection.bottom) {
      final maxHeight = constraints.maxHeight + widget.arrowHeight;
      constraints = constraints.copyWith(maxHeight: maxHeight);
    } else {
      constraints = constraints.copyWith(
        maxHeight: constraints.maxHeight + widget.arrowHeight,
        maxWidth: constraints.maxWidth + widget.arrowWidth!,
      );
    }

    _constraints = constraints;
  }

  void _configureRect() {
    if (!widget.context.mounted) return;
    final offset = BuildContextExtension.getWidgetLocalToGlobal(widget.context);
    final bounds = BuildContextExtension.getWidgetBounds(widget.context);
    if (offset != null && bounds != null) {
      _attachRect = Rect.fromLTWH(
        offset.dx + (widget.arrowDxOffset),
        offset.dy + (widget.arrowDyOffset),
        bounds.width + (widget.contentDxOffset),
        bounds.height + (widget.contentDyOffset),
      );
    }
  }
}
