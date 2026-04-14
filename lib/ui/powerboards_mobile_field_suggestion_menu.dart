import 'package:flutter/material.dart';

class PowerboardsMobileFieldSuggestionMenu<T> extends StatelessWidget {
  const PowerboardsMobileFieldSuggestionMenu({
    super.key,
    required this.items,
    required this.width,
    required this.groupId,
    required this.itemBuilder,
    this.maxHeight = 280,
    this.decoration,
    this.padding = EdgeInsets.zero,
    this.separatorBuilder,
    this.physics = const ClampingScrollPhysics(),
  });

  final List<T> items;
  final double width;
  final Object groupId;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final double maxHeight;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry padding;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final ScrollPhysics physics;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFieldTapRegion(
        groupId: groupId,
        child: DecoratedBox(
          decoration: decoration ?? const BoxDecoration(),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView.separated(
              primary: false,
              shrinkWrap: true,
              physics: physics,
              padding: padding.resolve(Directionality.of(context)),
              itemCount: items.length,
              itemBuilder: (context, index) => itemBuilder(context, items[index], index),
              separatorBuilder: (context, index) => separatorBuilder?.call(context, index) ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
