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
  State createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  final ShadResizableController _resizeController = ShadResizableController();
  final keyArea1 = GlobalKey();
  final keyArea2 = GlobalKey();

  bool _collapsed = false;
  double? _area1Ratio;
  String? _panelKeyToken;

  Widget get _area1 => KeyedSubtree(key: keyArea1, child: widget.area1);
  Widget get _area2 => KeyedSubtree(key: keyArea2, child: widget.area2);

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

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;

    if (!widget.split) {
      return _area1;
    }

    if (widget.allowCollapse && _collapsed) {
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
              child: _area2,
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
              child: widget.allowCollapse
                  ? Stack(
                      children: [
                        _area1,
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
                  : _area1,
            ),
            ShadResizablePanel(id: _area2Id, defaultSize: 1 - defaultArea1Ratio, minSize: minRatio, maxSize: maxRatio, child: _area2),
          ],
        );
      },
    );
  }
}
