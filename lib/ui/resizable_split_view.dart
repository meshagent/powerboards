import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _collapsedWidth = 58;
const double _defaultMinArea1Width = 300;
const double _defaultMinArea2Width = 300;
const double _defaultWidth = 450;
const String _area1Id = 'area1';
const String _area2Id = 'area2';

class ResizableSplitView extends StatefulWidget {
  const ResizableSplitView({
    super.key,
    required this.area1,
    required this.area2,
    required this.split,
    required this.allowCollapse,
    this.minArea1Width = _defaultMinArea1Width,
    this.minArea2Width = _defaultMinArea2Width,
  });

  final Widget area1;
  final Widget area2;
  final bool split;
  final bool allowCollapse;
  final double minArea1Width;
  final double minArea2Width;

  @override
  State createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  final ShadResizableController resizeController = ShadResizableController();
  BoxConstraints? lastConstraints;
  Timer? resizeDebounceTimer;

  bool _collapsed = false;
  double? _area1Ratio;

  ({double area1, double area2}) _resolveMinimumWidths(double totalWidth) {
    var area1 = widget.minArea1Width;
    var area2 = widget.minArea2Width;

    final availableWidth = math.max(totalWidth, _collapsedWidth * 2);
    if (area1 + area2 <= availableWidth) {
      return (area1: area1, area2: area2);
    }

    final scale = availableWidth / (area1 + area2);
    area1 = math.max(_collapsedWidth, area1 * scale);
    area2 = math.max(_collapsedWidth, area2 * scale);
    return (area1: area1, area2: area2);
  }

  void debounceResize(BoxConstraints constraints) {
    if (lastConstraints == null || lastConstraints!.maxWidth != constraints.maxWidth) {
      resizeDebounceTimer?.cancel();
      resizeDebounceTimer = Timer(const Duration(milliseconds: 30), () {
        final pan1 = resizeController.panelsInfo.where((panel) => panel.id == _area1Id).firstOrNull;
        final pan2 = resizeController.panelsInfo.where((panel) => panel.id == _area2Id).firstOrNull;

        if (pan1 == null || pan2 == null) {
          return;
        }

        final size = constraints.maxWidth;
        final minimums = _resolveMinimumWidths(size);
        final minArea1Size = minimums.area1 / size;
        final minArea2Size = minimums.area2 / size;
        final maxArea1Size = 1 - minArea2Size;
        final maxArea2Size = 1 - minArea1Size;

        final defaultSize = (_area1Ratio ?? (_defaultWidth / size)).clamp(minArea1Size, maxArea1Size);

        final newPan1 = ShadPanelInfo(id: _area1Id, minSize: minArea1Size, maxSize: maxArea1Size, defaultSize: defaultSize);
        final newPan2 = ShadPanelInfo(id: _area2Id, minSize: minArea2Size, maxSize: maxArea2Size, defaultSize: 1 - defaultSize);

        lastConstraints = constraints;
        resizeController.update([newPan1, newPan2]);
      });
    }
  }

  @override
  void initState() {
    super.initState();

    resizeController.addListener(_storeArea1Ratio);
  }

  @override
  void dispose() {
    resizeDebounceTimer?.cancel();
    resizeController.dispose();

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ResizableSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.split && !widget.split) {
      _collapsed = false;
    }

    if (!widget.allowCollapse && _collapsed) {
      _collapsed = false;
    }
  }

  void _storeArea1Ratio() {
    if (resizeController.panelsInfo.length < 2) return;
    final area1Panel = resizeController.panelsInfo.first;

    if (area1Panel.id != _area1Id) return;
    _area1Ratio = area1Panel.size;
  }

  void _toggleCollapsed() {
    if (widget.allowCollapse) {
      setState(() {
        _collapsed = !_collapsed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;

    if (!widget.split) {
      lastConstraints = null;
      return widget.area1;
    }

    if (widget.allowCollapse && _collapsed) {
      lastConstraints = null;
      return Row(
        crossAxisAlignment: .start,
        children: [
          SizedBox(
            width: _collapsedWidth,
            child: Padding(
              padding: const .all(10.0),
              child: Tooltip(
                message: 'Expand',
                child: ShadIconButton.ghost(icon: const Icon(LucideIcons.chevronsRight), onPressed: _toggleCollapsed),
              ),
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: cs.border)),
              ),
              child: widget.area2,
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final minimums = _resolveMinimumWidths(size);
        final minArea1Size = minimums.area1 / size;
        final minArea2Size = minimums.area2 / size;
        final maxArea1Size = 1 - minArea2Size;
        final maxArea2Size = 1 - minArea1Size;

        final defaultSize = (_defaultWidth / size).clamp(minArea1Size, maxArea1Size);

        _area1Ratio ??= defaultSize;

        // Debounce resize to avoid excessive rebuilds when resizing the window
        debounceResize(constraints);

        return ShadResizablePanelGroup(
          axis: .horizontal,
          showHandle: true,
          dividerColor: Colors.transparent,
          controller: resizeController,
          children: [
            ShadResizablePanel(
              id: _area1Id,
              defaultSize: defaultSize,
              minSize: minArea1Size,
              maxSize: maxArea1Size,
              child: widget.allowCollapse
                  ? Stack(
                      children: [
                        widget.area1,
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Tooltip(
                            message: 'Collapse',
                            child: ShadIconButton.ghost(icon: Icon(LucideIcons.chevronsLeft), onPressed: _toggleCollapsed),
                          ),
                        ),
                      ],
                    )
                  : widget.area1,
            ),
            ShadResizablePanel(
              id: _area2Id,
              defaultSize: 1 - defaultSize,
              minSize: minArea2Size,
              maxSize: maxArea2Size,
              child: widget.area2,
            ),
          ],
        );
      },
    );
  }
}
