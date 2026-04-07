import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
  final GlobalKey<ShadResizablePanelGroupState> _panelGroupKey = GlobalKey<ShadResizablePanelGroupState>();
  late ShadResizableController resizeController;
  BoxConstraints? lastConstraints;
  Timer? resizeDebounceTimer;
  int? _activePointer;

  bool _collapsed = false;
  double? _area1Ratio;
  double? _lastReportedArea2Ratio;
  bool _panelLayoutSyncScheduled = false;

  void _attachResizeController(ShadResizableController controller) {
    controller.addListener(_storeArea1Ratio);
  }

  void _stopActiveDrag() {
    final activePointer = _activePointer;
    if (activePointer != null) {
      GestureBinding.instance.cancelPointer(activePointer);
      _activePointer = null;
    }

    _panelGroupKey.currentState?.onHandleDragEnd();
  }

  void _syncPanelLayoutNow({required bool preserveCurrentArea1Size}) {
    final constraints = lastConstraints;
    if (constraints == null) {
      return;
    }

    _updatePanelLayout(constraints, preserveCurrentArea1Size: preserveCurrentArea1Size);
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

    if (collapsed) {
      _stopActiveDrag();
    }

    setState(() {
      if (!collapsed) {
        _area1Ratio = _preferredArea1Ratio;
        _lastReportedArea2Ratio = null;
      }
      _collapsed = collapsed;
    });
    _syncPanelLayoutNow(preserveCurrentArea1Size: false);
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
    final resolvedArea1 = _sanitizePanelFraction(preferredArea1.clamp(clampedMinArea1, clampedMaxArea1), fallback: clampedMinArea1);

    return _normalizeDefaultPanelSizes(area1: resolvedArea1, minArea1Size: clampedMinArea1, maxArea1Size: clampedMaxArea1);
  }

  ({double area1, double area2}) _normalizeDefaultPanelSizes({
    required double area1,
    required double minArea1Size,
    required double maxArea1Size,
  }) {
    final resolvedArea1 = _sanitizePanelFraction(area1, fallback: 0.5).clamp(minArea1Size, maxArea1Size).toDouble();
    final boundedArea1 = _sanitizePanelFraction(resolvedArea1.clamp(_panelFractionEpsilon, 1 - _panelFractionEpsilon), fallback: 0.5);
    final boundedArea2 = _sanitizePanelFraction(
      (1 - boundedArea1).clamp(_panelFractionEpsilon, 1 - _panelFractionEpsilon),
      fallback: 1 - boundedArea1,
    );

    return (area1: boundedArea1, area2: boundedArea2);
  }

  ({double minSize, double maxSize, double defaultSize}) _sanitizePanelConfig({
    required double minSize,
    required double maxSize,
    required double defaultSize,
    required double fallbackDefaultSize,
  }) {
    final safeMinSize = _sanitizePanelFraction(minSize, fallback: 0.0);
    final safeMaxSize = _sanitizePanelFraction(math.max(safeMinSize, maxSize), fallback: safeMinSize);
    final safeDefaultSize = _sanitizePanelFraction(defaultSize, fallback: fallbackDefaultSize).clamp(safeMinSize, safeMaxSize).toDouble();

    return (minSize: safeMinSize, maxSize: safeMaxSize, defaultSize: safeDefaultSize);
  }

  bool get _showsSplitPanels => widget.split && !_collapsed;

  ({double minSize, double maxSize, double defaultSize}) _fixedPanelConfig(double size) {
    return (minSize: size, maxSize: size, defaultSize: size);
  }

  ({({double minSize, double maxSize, double defaultSize}) area1, ({double minSize, double maxSize, double defaultSize}) area2})
  _resolvePanelLayout(double size) {
    if (!widget.split) {
      return (area1: _fixedPanelConfig(1), area2: _fixedPanelConfig(0));
    }

    if (_collapsed) {
      return (area1: _fixedPanelConfig(0), area2: _fixedPanelConfig(1));
    }

    final panelFractions = _resolvePanelFractions(size);
    final defaultPanelSizes = _resolveDefaultPanelSizes(
      size: size,
      minArea1Size: panelFractions.minArea1Size,
      minArea2Size: panelFractions.minArea2Size,
      maxArea1Size: panelFractions.maxArea1Size,
      maxArea2Size: panelFractions.maxArea2Size,
    );

    return (
      area1: _sanitizePanelConfig(
        minSize: panelFractions.minArea1Size,
        maxSize: panelFractions.maxArea1Size,
        defaultSize: defaultPanelSizes.area1,
        fallbackDefaultSize: 0.5,
      ),
      area2: _sanitizePanelConfig(
        minSize: panelFractions.minArea2Size,
        maxSize: panelFractions.maxArea2Size,
        defaultSize: defaultPanelSizes.area2,
        fallbackDefaultSize: 0.5,
      ),
    );
  }

  void _updatePanelLayout(BoxConstraints constraints, {required bool preserveCurrentArea1Size}) {
    final area1Panel = resizeController.panelsInfo.where((panel) => panel.id == _area1Id).firstOrNull;
    final area2Panel = resizeController.panelsInfo.where((panel) => panel.id == _area2Id).firstOrNull;

    if (area1Panel == null || area2Panel == null) {
      return;
    }

    final width = constraints.maxWidth;
    if (!width.isFinite || width <= 0) {
      return;
    }

    final panelLayout = _resolvePanelLayout(width);
    final nextArea1 = ShadPanelInfo(
      id: _area1Id,
      minSize: panelLayout.area1.minSize,
      maxSize: panelLayout.area1.maxSize,
      defaultSize: panelLayout.area1.defaultSize,
    );
    final nextArea2 = ShadPanelInfo(
      id: _area2Id,
      minSize: panelLayout.area2.minSize,
      maxSize: panelLayout.area2.maxSize,
      defaultSize: panelLayout.area2.defaultSize,
    );

    final unchanged =
        (area1Panel.minSize - nextArea1.minSize).abs() < _panelFractionEpsilon &&
        (area1Panel.maxSize - nextArea1.maxSize).abs() < _panelFractionEpsilon &&
        (area1Panel.defaultSize - nextArea1.defaultSize).abs() < _panelFractionEpsilon &&
        (area2Panel.minSize - nextArea2.minSize).abs() < _panelFractionEpsilon &&
        (area2Panel.maxSize - nextArea2.maxSize).abs() < _panelFractionEpsilon &&
        (area2Panel.defaultSize - nextArea2.defaultSize).abs() < _panelFractionEpsilon;
    if (unchanged) {
      lastConstraints = constraints;
      return;
    }

    if (preserveCurrentArea1Size && _showsSplitPanels) {
      final previousWidth = lastConstraints?.maxWidth;
      final scaledArea1Size = previousWidth == null || !previousWidth.isFinite || previousWidth <= 0
          ? null
          : (area1Panel.size * previousWidth) / width;
      if (scaledArea1Size != null &&
          scaledArea1Size.isFinite &&
          scaledArea1Size > nextArea1.minSize &&
          scaledArea1Size < nextArea1.maxSize) {
        nextArea1.size = scaledArea1Size;
      }
    }

    lastConstraints = constraints;
    resizeController.update([nextArea1, nextArea2]);
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
          _updatePanelLayout(constraints, preserveCurrentArea1Size: true);
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();

    resizeController = ShadResizableController();
    _attachResizeController(resizeController);
    widget.controller?.addListener(_handleControllerChanged);
    _syncControllerCollapsed();
  }

  @override
  void dispose() {
    resizeDebounceTimer?.cancel();
    widget.controller?.removeListener(_handleControllerChanged);
    resizeController.removeListener(_storeArea1Ratio);
    resizeController.dispose();

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ResizableSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);

    var collapsedChanged = false;
    var shouldSyncLayoutNow = false;

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);
    }

    if (oldWidget.split && !widget.split && _collapsed) {
      _collapsed = false;
      collapsedChanged = true;
      shouldSyncLayoutNow = true;
    }

    if (!widget.allowCollapse && _collapsed) {
      _collapsed = false;
      collapsedChanged = true;
      shouldSyncLayoutNow = true;
    }

    if (oldWidget.controller != widget.controller || collapsedChanged) {
      _syncControllerCollapsed();
    }

    if (collapsedChanged) {
      _notifyCollapsedChangedDeferred();
    }

    final sizingChanged =
        oldWidget.split != widget.split ||
        oldWidget.allowCollapse != widget.allowCollapse ||
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
      if (_showsSplitPanels) {
        _area1Ratio = null;
      }
      _lastReportedArea2Ratio = null;
      shouldSyncLayoutNow = true;
    }

    if (shouldSyncLayoutNow) {
      _syncPanelLayoutNow(preserveCurrentArea1Size: false);
    }
  }

  bool _panelConfigMatches(
    ({({double minSize, double maxSize, double defaultSize}) area1, ({double minSize, double maxSize, double defaultSize}) area2})
    panelLayout,
  ) {
    if (resizeController.panelsInfo.length < 2) {
      return false;
    }

    final area1Panel = resizeController.panelsInfo.where((panel) => panel.id == _area1Id).firstOrNull;
    final area2Panel = resizeController.panelsInfo.where((panel) => panel.id == _area2Id).firstOrNull;
    if (area1Panel == null || area2Panel == null) {
      return false;
    }

    return (area1Panel.minSize - panelLayout.area1.minSize).abs() < _panelFractionEpsilon &&
        (area1Panel.maxSize - panelLayout.area1.maxSize).abs() < _panelFractionEpsilon &&
        (area1Panel.defaultSize - panelLayout.area1.defaultSize).abs() < _panelFractionEpsilon &&
        (area2Panel.minSize - panelLayout.area2.minSize).abs() < _panelFractionEpsilon &&
        (area2Panel.maxSize - panelLayout.area2.maxSize).abs() < _panelFractionEpsilon &&
        (area2Panel.defaultSize - panelLayout.area2.defaultSize).abs() < _panelFractionEpsilon;
  }

  void _schedulePanelLayoutSyncForBuild(BoxConstraints constraints) {
    if (_panelLayoutSyncScheduled) {
      return;
    }

    _panelLayoutSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _panelLayoutSyncScheduled = false;
      if (!mounted) {
        return;
      }

      _updatePanelLayout(constraints, preserveCurrentArea1Size: false);
    });
  }

  void _storeArea1Ratio() {
    if (resizeController.panelsInfo.length < 2) return;
    if (!_showsSplitPanels) return;

    final area1Panel = resizeController.panelsInfo.first;

    if (area1Panel.id != _area1Id) return;
    final totalWidth = resizeController.totalAvailableWidth;
    final collapseThreshold = _collapseThresholdFraction(totalWidth);
    final isDragging = _panelGroupKey.currentState?.dragging.value ?? false;
    final shouldCollapse =
        isDragging &&
        widget.allowCollapse &&
        widget.split &&
        !_collapsed &&
        totalWidth > 0 &&
        area1Panel.size <= collapseThreshold + 0.0001;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        if (!size.isFinite || size <= 0) {
          lastConstraints = null;
          return const SizedBox.shrink();
        }
        final panelLayout = _resolvePanelLayout(size);

        if (_showsSplitPanels) {
          _area1Ratio ??= panelLayout.area1.defaultSize;
        }

        // Debounce resize to avoid excessive rebuilds when resizing the window
        debounceResize(constraints);
        if (!_panelConfigMatches(panelLayout)) {
          _schedulePanelLayoutSyncForBuild(constraints);
        }

        final showCollapseButton = widget.allowCollapse && widget.split && !_collapsed;
        final area1Hidden = widget.split && _collapsed;
        final area2Hidden = !widget.split;

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            _activePointer = event.pointer;
          },
          onPointerUp: (event) {
            if (_activePointer == event.pointer) {
              _activePointer = null;
            }
          },
          onPointerCancel: (event) {
            if (_activePointer == event.pointer) {
              _activePointer = null;
            }
          },
          child: ShadResizablePanelGroup(
            key: _panelGroupKey,
            axis: .horizontal,
            showHandle: _showsSplitPanels,
            dividerColor: Colors.transparent,
            controller: resizeController,
            children: [
              ShadResizablePanel(
                id: _area1Id,
                defaultSize: panelLayout.area1.defaultSize,
                minSize: panelLayout.area1.minSize,
                maxSize: panelLayout.area1.maxSize,
                child: IgnorePointer(
                  ignoring: area1Hidden,
                  child: Stack(
                    children: [
                      widget.area1,
                      if (showCollapseButton)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Tooltip(
                            message: 'Collapse',
                            child: ShadIconButton.ghost(icon: Icon(LucideIcons.panelLeftClose), onPressed: _toggleCollapsed),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ShadResizablePanel(
                id: _area2Id,
                defaultSize: panelLayout.area2.defaultSize,
                minSize: panelLayout.area2.minSize,
                maxSize: panelLayout.area2.maxSize,
                child: IgnorePointer(ignoring: area2Hidden, child: widget.area2),
              ),
            ],
          ),
        );
      },
    );
  }
}
