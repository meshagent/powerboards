import "dart:math";

import "package:collection/collection.dart";
import "package:flutter/material.dart";

class TabDecoration {
  const TabDecoration({
    required this.borderRadius,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.hoverColor,
    this.topThickness = 5,
    this.bottomThickness = 1,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final double borderRadius;
  final Color hoverColor;
  final double bottomThickness;
  final double topThickness;
}

class _TabData extends InheritedWidget {
  const _TabData({required this.decoration, required this.selected, required super.child});

  final TabDecoration decoration;
  final bool selected;

  static _TabData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_TabData>()!;
  }

  @override
  bool updateShouldNotify(_TabData oldWidget) {
    return oldWidget.selected != selected;
  }
}

class CustomTab extends StatefulWidget {
  const CustomTab({super.key, required this.onTap, required this.child});

  final void Function() onTap;
  final Widget child;

  @override
  State createState() => _CustomTabState();
}

class _CustomTabState extends State<CustomTab> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final data = _TabData.of(context);
    final decoration = data.decoration;
    final selected = data.selected;

    return GestureDetector(
      onTapDown: (_) {
        widget.onTap();
      },
      child: MouseRegion(
        onEnter: (_) {
          setState(() {
            hovered = true;
          });
        },
        onExit: (_) {
          setState(() {
            hovered = false;
          });
        },
        child: Container(
          color: Colors.transparent,
          child: Container(
            margin: EdgeInsets.all(max(5, decoration.topThickness)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(decoration.borderRadius),
              color: (hovered && !selected) ? decoration.hoverColor : Colors.transparent,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class Tabs extends StatefulWidget {
  const Tabs({
    super.key,
    this.maxTabWidth = 250.0,
    this.selectedIndex = -1,
    required this.decoration,
    this.before = const [],
    this.after = const [],
    this.afterWidth = 50,
    required this.children,
  });

  final int selectedIndex;
  final TabDecoration decoration;

  final List<Widget> before;
  final List<Widget> after;
  final List<Widget> children;

  final double afterWidth;

  final double maxTabWidth;

  @override
  State createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  int hoverIndex = -1;

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration;

    final children = widget.children;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = children.isEmpty
            ? 0.0
            : min(widget.maxTabWidth, (constraints.maxWidth - widget.afterWidth - decoration.borderRadius * 2) / children.length);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomPaint(
              painter: _TabPainter(
                topThickness: decoration.topThickness,
                bottomThickness: decoration.bottomThickness,
                borderRadius: decoration.borderRadius,
                tabColor: decoration.foregroundColor,
                borderColor: decoration.borderColor,
                tabWidth: 100,
                selectedIndex: -1,
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [for (var widget in widget.before) widget]),
            ),
            ColoredBox(
              color: decoration.backgroundColor,
              child: SizedBox(
                width: tabWidth * children.length + decoration.borderRadius * 2,
                child: CustomPaint(
                  painter: _TabPainter(
                    topThickness: decoration.topThickness,
                    bottomThickness: decoration.bottomThickness,
                    borderRadius: decoration.borderRadius,
                    tabColor: decoration.foregroundColor,
                    borderColor: decoration.borderColor,
                    tabWidth: tabWidth,
                    selectedIndex: children.isNotEmpty ? widget.selectedIndex : -1,
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: decoration.borderRadius),
                      ...children.mapIndexed(
                        (index, c) => _TabData(
                          selected: index == widget.selectedIndex,
                          decoration: widget.decoration,
                          child: SizedBox(key: ObjectKey(c), width: tabWidth, child: c),
                        ),
                      ),
                      SizedBox(width: decoration.borderRadius),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: CustomPaint(
                painter: _TabPainter(
                  topThickness: decoration.topThickness,
                  bottomThickness: decoration.bottomThickness,
                  borderRadius: decoration.borderRadius,
                  tabColor: decoration.foregroundColor,
                  borderColor: decoration.borderColor,
                  tabWidth: 100,
                  selectedIndex: -1,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var widget in widget.after) widget,
                    Expanded(child: Container()),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TabPainter extends CustomPainter {
  const _TabPainter({
    required this.tabColor,
    required this.borderColor,
    required this.tabWidth,
    required this.borderRadius,
    required this.topThickness,
    required this.bottomThickness,
    required this.selectedIndex,
  });

  final Color borderColor;
  final Color tabColor;
  final double tabWidth;
  final double borderRadius;
  final double bottomThickness;
  final double topThickness;
  final int selectedIndex;

  @override
  bool shouldRepaint(_TabPainter widget) {
    return widget.tabWidth != tabWidth ||
        widget.selectedIndex != selectedIndex ||
        widget.borderRadius != borderRadius ||
        widget.borderColor != borderColor ||
        widget.tabColor != tabColor ||
        widget.bottomThickness != bottomThickness ||
        widget.topThickness != topThickness;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final bottom = size.height - bottomThickness;

    if (selectedIndex == -1) {
      path.moveTo(0, bottom);
      path.lineTo(0, bottom);
      path.lineTo(size.width, bottom);
      path.lineTo(size.width, bottom);
    } else {
      final tabStart = selectedIndex * tabWidth + borderRadius - (borderRadius == 0 && selectedIndex == 0 ? .5 : 0);

      path.moveTo(0, bottom);
      path.lineTo(0, bottom);
      path.lineTo(tabStart - borderRadius, bottom);
      path.relativeArcToPoint(Offset(borderRadius, -borderRadius), radius: Radius.circular(borderRadius), clockwise: false);
      path.lineTo(tabStart, topThickness + borderRadius);
      path.relativeArcToPoint(Offset(borderRadius, -borderRadius), radius: Radius.circular(borderRadius), clockwise: true);
      final tabEnd = tabStart + tabWidth;

      path.lineTo(tabEnd - borderRadius, topThickness);

      path.relativeArcToPoint(Offset(borderRadius, borderRadius), radius: Radius.circular(borderRadius), clockwise: true);

      path.lineTo(tabEnd, bottom - borderRadius);
      path.relativeArcToPoint(Offset(borderRadius, borderRadius), radius: Radius.circular(borderRadius), clockwise: false);

      path.lineTo(size.width, bottom);
      path.lineTo(size.width, bottom);
      //path.lineTo(0, size.height);

      final fill = Paint()
        ..color = tabColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fill);
    }
    final stroke = Paint()
      ..strokeWidth = bottomThickness
      ..color = borderColor
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, stroke);
  }
}
