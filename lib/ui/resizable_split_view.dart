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
    this.minArea1Fraction,
    this.minArea2Fraction,
    this.maxArea1Fraction,
    this.maxArea2Fraction,
    this.preferredArea1Fraction,
    this.preferredArea2Fraction,
    this.onArea2FractionChanged,
  });

  final Widget area1;
  final Widget area2;
  final bool split;
  final bool allowCollapse;
  final double minArea1Width;
  final double minArea2Width;
  final double? minArea1Fraction;
  final double? minArea2Fraction;
  final double? maxArea1Fraction;
  final double? maxArea2Fraction;
  final double? preferredArea1Fraction;
  final double? preferredArea2Fraction;
  final ValueChanged<double>? onArea2FractionChanged;

  @override
  State createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  final ShadResizableController resizeController = ShadResizableController();
  final GlobalKey _area1Key = GlobalKey();
  BoxConstraints? lastConstraints;
  Timer? resizeDebounceTimer;

  bool _collapsed = false;
  double? _area1Ratio;
  double? _lastReportedArea2Ratio;

  double? get _lockedArea1Fraction {
    final minFraction = widget.minArea1Fraction;
    final maxFraction = widget.maxArea1Fraction;
    if (minFraction != null && maxFraction != null && (minFraction - maxFraction).abs() < 0.0001) {
      return minFraction;
    }
    return null;
  }

  double? get _lockedArea2Fraction {
    final minFraction = widget.minArea2Fraction;
    final maxFraction = widget.maxArea2Fraction;
    if (minFraction != null && maxFraction != null && (minFraction - maxFraction).abs() < 0.0001) {
      return minFraction;
    }
    return null;
  }

  double? get _preferredArea1Ratio {
    if (widget.preferredArea1Fraction != null) {
      return widget.preferredArea1Fraction;
    }

    if (widget.preferredArea2Fraction != null) {
      return 1 - widget.preferredArea2Fraction!;
    }

    final lockedArea1Fraction = _lockedArea1Fraction;
    if (lockedArea1Fraction != null) {
      return lockedArea1Fraction;
    }

    final lockedArea2Fraction = _lockedArea2Fraction;
    if (lockedArea2Fraction != null) {
      return 1 - lockedArea2Fraction;
    }

    return null;
  }

  ({double area1, double area2}) _resolveMinimumWidths(double totalWidth) {
    final lockedArea1Fraction = _lockedArea1Fraction;
    if (lockedArea1Fraction != null) {
      final area1 = totalWidth * lockedArea1Fraction;
      return (area1: area1, area2: totalWidth - area1);
    }

    final lockedArea2Fraction = _lockedArea2Fraction;
    if (lockedArea2Fraction != null) {
      final area2 = totalWidth * lockedArea2Fraction;
      return (area1: totalWidth - area2, area2: area2);
    }

    var area1 = widget.minArea1Width;
    var area2 = widget.minArea2Width;

    if (widget.minArea1Fraction != null) {
      area1 = math.max(area1, totalWidth * widget.minArea1Fraction!);
    }
    if (widget.minArea2Fraction != null) {
      area2 = math.max(area2, totalWidth * widget.minArea2Fraction!);
    }

    final availableWidth = math.max(totalWidth, _collapsedWidth * 2);
    if (area1 + area2 <= availableWidth) {
      return (area1: area1, area2: area2);
    }

    if (widget.minArea2Fraction != null) {
      area2 = math.min(area2, availableWidth - _collapsedWidth);
      area1 = math.max(_collapsedWidth, availableWidth - area2);
      return (area1: area1, area2: area2);
    }

    if (widget.minArea1Fraction != null) {
      area1 = math.min(area1, availableWidth - _collapsedWidth);
      area2 = math.max(_collapsedWidth, availableWidth - area1);
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
        if (!size.isFinite || size <= 0) {
          return;
        }
        final minimums = _resolveMinimumWidths(size);
        final minArea1Size = minimums.area1 / size;
        final minArea2Size = minimums.area2 / size;
        final rawMaxArea1Size = _lockedArea1Fraction ?? math.min(1 - minArea2Size, widget.maxArea1Fraction ?? 1.0);
        final rawMaxArea2Size = _lockedArea2Fraction ?? math.min(1 - minArea1Size, widget.maxArea2Fraction ?? 1.0);
        final maxArea1Size = math.max(minArea1Size, rawMaxArea1Size);
        final maxArea2Size = math.max(minArea2Size, rawMaxArea2Size);

        final defaultSize1 = (_area1Ratio ?? _preferredArea1Ratio ?? (_defaultWidth / size)).clamp(minArea1Size, maxArea1Size);
        final defaultSize2 = (1 - defaultSize1).clamp(minArea2Size, maxArea2Size);

        final newPan1 = ShadPanelInfo(id: _area1Id, minSize: minArea1Size, maxSize: maxArea1Size, defaultSize: defaultSize1);
        final newPan2 = ShadPanelInfo(id: _area2Id, minSize: minArea2Size, maxSize: maxArea2Size, defaultSize: defaultSize2);

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

    final sizingChanged =
        oldWidget.minArea1Width != widget.minArea1Width ||
        oldWidget.minArea2Width != widget.minArea2Width ||
        oldWidget.minArea1Fraction != widget.minArea1Fraction ||
        oldWidget.minArea2Fraction != widget.minArea2Fraction ||
        oldWidget.maxArea1Fraction != widget.maxArea1Fraction ||
        oldWidget.maxArea2Fraction != widget.maxArea2Fraction ||
        oldWidget.preferredArea1Fraction != widget.preferredArea1Fraction ||
        oldWidget.preferredArea2Fraction != widget.preferredArea2Fraction;

    if (sizingChanged) {
      lastConstraints = null;
      resizeDebounceTimer?.cancel();
    }
  }

  void _storeArea1Ratio() {
    if (resizeController.panelsInfo.length < 2) return;
    final area1Panel = resizeController.panelsInfo.first;

    if (area1Panel.id != _area1Id) return;
    _area1Ratio = area1Panel.size;

    final area2Ratio = 1 - area1Panel.size;
    final lastReportedArea2Ratio = _lastReportedArea2Ratio;
    if (lastReportedArea2Ratio != null && (lastReportedArea2Ratio - area2Ratio).abs() < 0.0001) {
      return;
    }

    _lastReportedArea2Ratio = area2Ratio;
    widget.onArea2FractionChanged?.call(area2Ratio);
  }

  void _toggleCollapsed() {
    if (widget.allowCollapse) {
      setState(() {
        _collapsed = !_collapsed;
      });
    }
  }

  Widget _stableArea1() {
    return KeyedSubtree(key: _area1Key, child: widget.area1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;

    if (!widget.split) {
      lastConstraints = null;
      return _stableArea1();
    }

    if (widget.allowCollapse && _collapsed) {
      lastConstraints = null;
      return Row(
        crossAxisAlignment: .start,
        children: [
          // Visibility(visible: false, maintainState: true, child: _stableArea1()),
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
        if (!size.isFinite || size <= 0) {
          lastConstraints = null;
          return const SizedBox.shrink();
        }
        final minimums = _resolveMinimumWidths(size);
        final minArea1Size = minimums.area1 / size;
        final minArea2Size = minimums.area2 / size;
        final rawMaxArea1Size = _lockedArea1Fraction ?? math.min(1 - minArea2Size, widget.maxArea1Fraction ?? 1.0);
        final rawMaxArea2Size = _lockedArea2Fraction ?? math.min(1 - minArea1Size, widget.maxArea2Fraction ?? 1.0);
        final maxArea1Size = math.max(minArea1Size, rawMaxArea1Size);
        final maxArea2Size = math.max(minArea2Size, rawMaxArea2Size);

        final defaultSize1 = (_area1Ratio ?? _preferredArea1Ratio ?? (_defaultWidth / size)).clamp(minArea1Size, maxArea1Size);
        final defaultSize2 = (1 - defaultSize1).clamp(minArea2Size, maxArea2Size);

        _area1Ratio ??= defaultSize1;

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
              defaultSize: defaultSize1,
              minSize: minArea1Size,
              maxSize: maxArea1Size,
              child: widget.allowCollapse
                  ? Stack(
                      children: [
                        _stableArea1(),
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
                  : _stableArea1(),
            ),
            ShadResizablePanel(id: _area2Id, defaultSize: defaultSize2, minSize: minArea2Size, maxSize: maxArea2Size, child: widget.area2),
          ],
        );
      },
    );
  }
}
