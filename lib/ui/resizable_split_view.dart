import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _collapsedWidth = 58;
const double _minAreaWidth = 300;
const double _defaultWidth = 450;
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
  final ShadResizableController resizeController = ShadResizableController();
  BoxConstraints? lastConstraints;
  Timer? resizeDebounceTimer;

  final keyArea1 = GlobalKey();
  final keyArea2 = GlobalKey();

  bool _collapsed = false;
  double? _area1Ratio;

  Widget get _area1 => KeyedSubtree(key: keyArea1, child: widget.area1);
  Widget get _area2 => KeyedSubtree(key: keyArea2, child: widget.area2);

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
        final minSize = _minAreaWidth / size;
        final maxSize = 1 - minSize;

        final defaultSize = (_area1Ratio ?? minSize).clamp(minSize, maxSize);

        final newPan1 = ShadPanelInfo(id: _area1Id, minSize: minSize, maxSize: maxSize, defaultSize: defaultSize);
        final newPan2 = ShadPanelInfo(id: _area2Id, minSize: minSize, maxSize: maxSize, defaultSize: 1 - defaultSize);

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
      return _area1;
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
              child: _area2,
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final minSize = _minAreaWidth / size;
        final maxSize = 1 - minSize;

        final defaultSize = (_defaultWidth / size).clamp(minSize, maxSize);

        _area1Ratio ??= defaultSize;

        // Debounce resize to avoid excessive rebuilds when resizing the window
        debounceResize(constraints);

        return ShadResizablePanelGroup(
          axis: .horizontal,
          showHandle: true,
          controller: resizeController,
          children: [
            ShadResizablePanel(
              id: _area1Id,
              defaultSize: defaultSize,
              minSize: minSize,
              maxSize: maxSize,
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
            ShadResizablePanel(id: _area2Id, defaultSize: 1 - defaultSize, minSize: minSize, maxSize: maxSize, child: _area2),
          ],
        );
      },
    );
  }
}
