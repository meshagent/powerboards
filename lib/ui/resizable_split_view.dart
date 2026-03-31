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
const double _panelFractionEpsilon = 0.0001;

class ResizableSplitViewController extends ChangeNotifier {
  bool _collapsed = false;
  bool? _requestedCollapsed;

  bool get collapsed => _collapsed;

  void collapse() {
    _requestedCollapsed = true;
    notifyListeners();
  }

  void expand() {
    _requestedCollapsed = false;
    notifyListeners();
  }

  void toggle() {
    _requestedCollapsed = !_collapsed;
    notifyListeners();
  }

  bool? consumeRequestedCollapsed() {
    final requestedCollapsed = _requestedCollapsed;
    _requestedCollapsed = null;
    return requestedCollapsed;
  }

  void syncCollapsed(bool value) {
    _collapsed = value;
  }
}

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
    this.collapseArea1Width,
    this.controller,
    this.onCollapsedChanged,
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
  final double? collapseArea1Width;
  final ResizableSplitViewController? controller;
  final ValueChanged<bool>? onCollapsedChanged;
  final ValueChanged<double>? onArea2FractionChanged;

  @override
  State createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  final ShadResizableController resizeController = ShadResizableController();
  BoxConstraints? lastConstraints;
  Timer? resizeDebounceTimer;

  bool _collapsed = false;
  double? _area1Ratio;
  double? _lastReportedArea2Ratio;
  int _panelGroupVersion = 0;

  void _resetPanelGroupState() {
    resizeDebounceTimer?.cancel();
    lastConstraints = null;
    resizeController.clear();
    resizeController.totalAvailableWidth = 0;
    _panelGroupVersion++;
  }

  void _syncControllerCollapsed() {
    widget.controller?.syncCollapsed(_collapsed);
  }

  void _notifyCollapsedChanged() {
    widget.onCollapsedChanged?.call(_collapsed);
  }

  void _notifyCollapsedChangedDeferred() {
    if (widget.onCollapsedChanged == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      widget.onCollapsedChanged?.call(_collapsed);
    });
  }

  void _applyCollapsedState(bool collapsed) {
    if (_collapsed == collapsed) {
      return;
    }

    setState(() {
      _resetPanelGroupState();
      if (!collapsed) {
        _area1Ratio = _preferredArea1Ratio;
        _lastReportedArea2Ratio = null;
      }
      _collapsed = collapsed;
    });
    _syncControllerCollapsed();
    _notifyCollapsedChanged();
  }

  void _handleControllerChanged() {
    final requestedCollapsed = widget.controller?.consumeRequestedCollapsed();
    if (requestedCollapsed == null) {
      return;
    }

    _applyCollapsedState(requestedCollapsed);
  }

  double _sanitizePanelFraction(double? value, {required double fallback}) {
    final resolved = value;
    if (resolved == null || !resolved.isFinite || resolved.isNaN) {
      return fallback.clamp(0.0, 1.0).toDouble();
    }

    return resolved.clamp(0.0, 1.0).toDouble();
  }

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

  double _collapseThresholdFraction(double totalWidth) {
    if (!totalWidth.isFinite || totalWidth <= 0) {
      return 0;
    }

    final collapseWidth = widget.collapseArea1Width ?? _collapsedWidth;
    return (collapseWidth / totalWidth).clamp(0.0, 1.0);
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

  ({double minArea1Size, double minArea2Size, double maxArea1Size, double maxArea2Size}) _resolvePanelFractions(double size) {
    final minimums = _resolveMinimumWidths(size);
    var minArea1Size = _sanitizePanelFraction(minimums.area1 / size, fallback: 0.5);
    var minArea2Size = _sanitizePanelFraction(minimums.area2 / size, fallback: 0.5);

    final minimumTotal = minArea1Size + minArea2Size;
    if (minimumTotal.isFinite && minimumTotal > 1) {
      minArea1Size /= minimumTotal;
      minArea2Size /= minimumTotal;
    }

    final rawMaxArea1Size = _sanitizePanelFraction(
      _lockedArea1Fraction ?? math.min(1 - minArea2Size, widget.maxArea1Fraction ?? 1.0),
      fallback: 1.0,
    );
    final rawMaxArea2Size = _sanitizePanelFraction(
      _lockedArea2Fraction ?? math.min(1 - minArea1Size, widget.maxArea2Fraction ?? 1.0),
      fallback: 1.0,
    );
    final maxArea1Size = _sanitizePanelFraction(math.max(minArea1Size, rawMaxArea1Size), fallback: minArea1Size);
    final maxArea2Size = _sanitizePanelFraction(math.max(minArea2Size, rawMaxArea2Size), fallback: minArea2Size);

    return (minArea1Size: minArea1Size, minArea2Size: minArea2Size, maxArea1Size: maxArea1Size, maxArea2Size: maxArea2Size);
  }

  ({double area1, double area2}) _resolveDefaultPanelSizes({
    required double size,
    required double minArea1Size,
    required double minArea2Size,
    required double maxArea1Size,
    required double maxArea2Size,
  }) {
    final preferredArea1 = _sanitizePanelFraction(_area1Ratio ?? _preferredArea1Ratio ?? (_defaultWidth / size), fallback: 0.5);
    final safeMinArea1 = _sanitizePanelFraction(math.max(minArea1Size, 1 - maxArea2Size), fallback: minArea1Size);
    final safeMaxArea1 = _sanitizePanelFraction(math.min(maxArea1Size, 1 - minArea2Size), fallback: maxArea1Size);

    final clampedMinArea1 = _sanitizePanelFraction(safeMinArea1.clamp(_panelFractionEpsilon, 1 - _panelFractionEpsilon), fallback: 0.5);
    final clampedMaxArea1 = _sanitizePanelFraction(
      safeMaxArea1.clamp(clampedMinArea1, 1 - _panelFractionEpsilon),
      fallback: clampedMinArea1,
    );
    final area1 = _sanitizePanelFraction(preferredArea1.clamp(clampedMinArea1, clampedMaxArea1), fallback: clampedMinArea1);
    final area2 = _sanitizePanelFraction((1 - area1).clamp(_panelFractionEpsilon, 1 - _panelFractionEpsilon), fallback: 1 - area1);

    return (area1: area1, area2: area2);
  }

  void debounceResize(BoxConstraints constraints) {
    if (lastConstraints == null || lastConstraints!.maxWidth != constraints.maxWidth) {
      resizeDebounceTimer?.cancel();
      resizeDebounceTimer = Timer(const Duration(milliseconds: 30), () {
        if (!mounted) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          final pan1 = resizeController.panelsInfo.where((panel) => panel.id == _area1Id).firstOrNull;
          final pan2 = resizeController.panelsInfo.where((panel) => panel.id == _area2Id).firstOrNull;

          if (pan1 == null || pan2 == null) {
            return;
          }

          final size = constraints.maxWidth;
          if (!size.isFinite || size <= 0) {
            return;
          }
          final panelFractions = _resolvePanelFractions(size);
          final minArea1Size = panelFractions.minArea1Size;
          final minArea2Size = panelFractions.minArea2Size;
          final maxArea1Size = panelFractions.maxArea1Size;
          final maxArea2Size = panelFractions.maxArea2Size;

          final defaultPanelSizes = _resolveDefaultPanelSizes(
            size: size,
            minArea1Size: minArea1Size,
            minArea2Size: minArea2Size,
            maxArea1Size: maxArea1Size,
            maxArea2Size: maxArea2Size,
          );
          final defaultSize1 = defaultPanelSizes.area1;
          final defaultSize2 = defaultPanelSizes.area2;

          final unchanged =
              (pan1.minSize - minArea1Size).abs() < _panelFractionEpsilon &&
              (pan1.maxSize - maxArea1Size).abs() < _panelFractionEpsilon &&
              (pan1.defaultSize - defaultSize1).abs() < _panelFractionEpsilon &&
              (pan2.minSize - minArea2Size).abs() < _panelFractionEpsilon &&
              (pan2.maxSize - maxArea2Size).abs() < _panelFractionEpsilon &&
              (pan2.defaultSize - defaultSize2).abs() < _panelFractionEpsilon;
          if (unchanged) {
            lastConstraints = constraints;
            return;
          }

          final newPan1 = ShadPanelInfo(id: _area1Id, minSize: minArea1Size, maxSize: maxArea1Size, defaultSize: defaultSize1);
          final newPan2 = ShadPanelInfo(id: _area2Id, minSize: minArea2Size, maxSize: maxArea2Size, defaultSize: defaultSize2);

          lastConstraints = constraints;
          resizeController.update([newPan1, newPan2]);
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();

    resizeController.addListener(_storeArea1Ratio);
    widget.controller?.addListener(_handleControllerChanged);
    _syncControllerCollapsed();
  }

  @override
  void dispose() {
    resizeDebounceTimer?.cancel();
    widget.controller?.removeListener(_handleControllerChanged);
    resizeController.dispose();

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ResizableSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);

    var shouldResetPanelGroup = false;
    var collapsedChanged = false;

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);
    }

    if (oldWidget.split && !widget.split && _collapsed) {
      _collapsed = false;
      collapsedChanged = true;
      shouldResetPanelGroup = true;
    }

    if (!widget.allowCollapse && _collapsed) {
      _collapsed = false;
      collapsedChanged = true;
      shouldResetPanelGroup = true;
    }

    if (oldWidget.controller != widget.controller || collapsedChanged) {
      _syncControllerCollapsed();
    }

    if (collapsedChanged) {
      _notifyCollapsedChangedDeferred();
    }

    if (oldWidget.split != widget.split || oldWidget.allowCollapse != widget.allowCollapse) {
      shouldResetPanelGroup = true;
    }

    final sizingChanged =
        oldWidget.minArea1Width != widget.minArea1Width ||
        oldWidget.minArea2Width != widget.minArea2Width ||
        oldWidget.minArea1Fraction != widget.minArea1Fraction ||
        oldWidget.minArea2Fraction != widget.minArea2Fraction ||
        oldWidget.maxArea1Fraction != widget.maxArea1Fraction ||
        oldWidget.maxArea2Fraction != widget.maxArea2Fraction ||
        oldWidget.preferredArea1Fraction != widget.preferredArea1Fraction ||
        oldWidget.preferredArea2Fraction != widget.preferredArea2Fraction ||
        oldWidget.collapseArea1Width != widget.collapseArea1Width;

    if (sizingChanged) {
      _area1Ratio = null;
      _lastReportedArea2Ratio = null;
      shouldResetPanelGroup = true;
    }

    if (shouldResetPanelGroup) {
      _resetPanelGroupState();
    }
  }

  void _storeArea1Ratio() {
    if (resizeController.panelsInfo.length < 2) return;
    final area1Panel = resizeController.panelsInfo.first;

    if (area1Panel.id != _area1Id) return;
    final totalWidth = resizeController.totalAvailableWidth;
    final collapseThreshold = _collapseThresholdFraction(totalWidth);
    final shouldCollapse =
        widget.allowCollapse && widget.split && !_collapsed && totalWidth > 0 && area1Panel.size <= collapseThreshold + 0.0001;

    if (shouldCollapse) {
      _applyCollapsedState(true);
      return;
    }

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
      _applyCollapsedState(!_collapsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.split) {
      lastConstraints = null;
      return widget.area1;
    }

    if (widget.allowCollapse && _collapsed) {
      lastConstraints = null;
      return widget.area2;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        if (!size.isFinite || size <= 0) {
          lastConstraints = null;
          return const SizedBox.shrink();
        }
        final panelFractions = _resolvePanelFractions(size);
        final minArea1Size = panelFractions.minArea1Size;
        final minArea2Size = panelFractions.minArea2Size;
        final maxArea1Size = panelFractions.maxArea1Size;
        final maxArea2Size = panelFractions.maxArea2Size;

        final defaultPanelSizes = _resolveDefaultPanelSizes(
          size: size,
          minArea1Size: minArea1Size,
          minArea2Size: minArea2Size,
          maxArea1Size: maxArea1Size,
          maxArea2Size: maxArea2Size,
        );
        final defaultSize1 = defaultPanelSizes.area1;
        final defaultSize2 = defaultPanelSizes.area2;

        _area1Ratio ??= defaultSize1;

        // Debounce resize to avoid excessive rebuilds when resizing the window
        debounceResize(constraints);

        return ShadResizablePanelGroup(
          key: ValueKey('$_panelGroupVersion-${widget.split}-${widget.allowCollapse}'),
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
                        widget.area1,
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Tooltip(
                            message: 'Collapse',
                            child: ShadIconButton.ghost(icon: Icon(LucideIcons.panelLeftClose), onPressed: _toggleCollapsed),
                          ),
                        ),
                      ],
                    )
                  : widget.area1,
            ),
            ShadResizablePanel(id: _area2Id, defaultSize: defaultSize2, minSize: minArea2Size, maxSize: maxArea2Size, child: widget.area2),
          ],
        );
      },
    );
  }
}
