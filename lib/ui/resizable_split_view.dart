import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _collapsedWidth = 58;
const double _minAreaWidth = 450;
const String _area1Id = 'area1';
const String _area2Id = 'area2';

class ResizableSplitView extends StatefulWidget {
  const ResizableSplitView({super.key, required this.area1, required this.area2, required this.split, required this.allowCollapse});

  final Widget area1;
  final Widget area2;
  final bool split;
  final bool allowCollapse;

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  final ShadResizableController _resizeController = ShadResizableController();

  bool _collapsed = false;
  double? _area1Ratio;
  String? _panelKeyToken;

  @override
  void initState() {
    super.initState();

    _resizeController.addListener(_storeArea1Ratio);
  }

  @override
  void dispose() {
    _resizeController
      ..removeListener(_storeArea1Ratio)
      ..dispose();

    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ResizableSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.split && !widget.split) {
      _collapsed = false;
      _clearController();
    }

    if (!widget.allowCollapse && _collapsed) {
      _collapsed = false;
    }
  }

  void _storeArea1Ratio() {
    if (_resizeController.panelsInfo.length < 2) return;
    final area1Panel = _resizeController.panelsInfo.first;
    if (area1Panel.id != _area1Id) return;
    _area1Ratio = area1Panel.size;
  }

  void _toggleCollapsed() {
    if (!widget.allowCollapse) return;
    setState(() {
      _collapsed = !_collapsed;
      if (_collapsed) _clearController();
    });
  }

  double _minRatioForWidth(double width) {
    if (width <= 0) return 0.5;
    return (_minAreaWidth / width).clamp(0.0, 0.5);
  }

  void _clearController() {
    _resizeController.clear();
    _panelKeyToken = null;
  }

  Widget _buildArea1Panel({required bool collapsed}) {
    final colorScheme = ShadTheme.of(context).colorScheme;

    return Stack(
      children: [
        ClipRect(
          child: Align(alignment: Alignment.centerLeft, child: widget.area1),
        ),
        if (collapsed)
          Positioned.fill(
            child: AbsorbPointer(child: ColoredBox(color: colorScheme.background)),
          ),
        if (widget.split && widget.allowCollapse)
          Positioned(
            top: 10,
            right: 10,
            child: Tooltip(
              message: collapsed ? 'Expand' : 'Collapse',
              child: ShadIconButton.ghost(
                icon: Icon(collapsed ? LucideIcons.chevronsRight : LucideIcons.chevronsLeft),
                onPressed: _toggleCollapsed,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ShadTheme.of(context).colorScheme;
    final collapsed = widget.split && widget.allowCollapse && _collapsed;

    if (!widget.split) {
      return _buildArea1Panel(collapsed: false);
    }

    if (collapsed) {
      return Row(
        children: [
          SizedBox(width: _collapsedWidth, child: _buildArea1Panel(collapsed: true)),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: colorScheme.border)),
              ),
              child: widget.area2,
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final minRatio = _minRatioForWidth(constraints.maxWidth);
        final maxRatio = 1 - minRatio;
        final defaultArea1Ratio = (_area1Ratio ?? minRatio).clamp(minRatio, maxRatio);
        final panelKeyToken = minRatio.toStringAsFixed(6);

        if (_panelKeyToken != panelKeyToken) {
          _resizeController.clear();
          _panelKeyToken = panelKeyToken;
        }

        return ShadResizablePanelGroup(
          key: ValueKey<String>('resizable-split-$panelKeyToken'),
          axis: .horizontal,
          showHandle: true,
          controller: _resizeController,
          children: [
            ShadResizablePanel(
              id: _area1Id,
              defaultSize: defaultArea1Ratio,
              minSize: minRatio,
              maxSize: maxRatio,
              child: _buildArea1Panel(collapsed: false),
            ),
            ShadResizablePanel(id: _area2Id, defaultSize: 1 - defaultArea1Ratio, minSize: minRatio, maxSize: maxRatio, child: widget.area2),
          ],
        );
      },
    );
  }
}
