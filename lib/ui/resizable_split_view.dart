import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ResizableSplitView extends StatefulWidget {
  final Widget area1;
  final Widget area2;
  final bool split;
  final bool allowCollapse;

  const ResizableSplitView({super.key, required this.area1, required this.area2, required this.split, required this.allowCollapse});

  @override
  State createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  double? _area1Width;
  bool _dragging = false;
  bool _collapsed = false;

  static const double _collapsedWidth = 58;
  static const double _minAreaWidth = 450;
  static const double _dragWidth = 10;

  void _toggleCollapsed() {
    setState(() {
      _collapsed = !_collapsed;
      _dragging = false;
    });
  }

  @override
  void didUpdateWidget(covariant ResizableSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.split && !widget.split) {
      _collapsed = false;
      _dragging = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ShadTheme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;

        final bool split = widget.split;
        final bool collapsed = split && _collapsed && widget.allowCollapse;

        final double dragW = (split && !collapsed) ? _dragWidth : 0.0;

        double area1W;
        if (!split) {
          area1W = maxW;
        } else if (collapsed) {
          area1W = _collapsedWidth;
        } else {
          area1W = _area1Width ?? _minAreaWidth;
          final maxArea1 = (maxW - _minAreaWidth - dragW).clamp(_minAreaWidth, maxW);
          area1W = area1W.clamp(_minAreaWidth, maxArea1);
        }

        double area2W;
        if (!split) {
          area2W = 0.0;
        } else {
          area2W = maxW - area1W - dragW;
          final minArea2 = _minAreaWidth - dragW;
          if (area2W < minArea2) {
            area2W = minArea2;
            final minArea1 = collapsed ? _collapsedWidth : _minAreaWidth;
            area1W = (maxW - dragW - area2W).clamp(minArea1, maxW);
          }
        }

        final area1 = SizedBox(
          width: area1W,
          child: Stack(
            children: [
              ClipRect(
                child: Align(alignment: Alignment.centerLeft, child: widget.area1),
              ),
              if (collapsed)
                Positioned.fill(
                  child: AbsorbPointer(child: Container(color: colorScheme.background)),
                ),
              if (split && widget.allowCollapse)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Tooltip(
                    message: collapsed ? "Expand" : "Collapse",
                    child: ShadIconButton.ghost(
                      icon: Icon(collapsed ? LucideIcons.chevronsRight : LucideIcons.chevronsLeft),
                      onPressed: _toggleCollapsed,
                    ),
                  ),
                ),
            ],
          ),
        );

        final handle = SizedBox(
          width: dragW,
          child: (split && !collapsed)
              ? MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (_) => setState(() => _dragging = true),
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        final next = (_area1Width ?? area1W) + details.delta.dx;
                        final maxArea1 = (maxW - _minAreaWidth - dragW).clamp(_minAreaWidth, maxW);
                        _area1Width = next.clamp(_minAreaWidth, maxArea1);
                      });
                    },
                    onHorizontalDragEnd: (_) => setState(() => _dragging = false),
                    child: Container(color: _dragging ? colorScheme.border : Colors.transparent),
                  ),
                )
              : const SizedBox.shrink(),
        );

        final area2 = SizedBox(
          width: area2W,
          child: area2W == 0
              ? const SizedBox.shrink()
              : Container(
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: colorScheme.border)),
                  ),
                  child: widget.area2,
                ),
        );

        return Row(children: [area1, handle, area2]);
      },
    );
  }
}
