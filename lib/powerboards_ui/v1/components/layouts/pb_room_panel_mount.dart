import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/pb_colors.dart';
import 'pb_room_panel.dart';

const double _roomPanelDefaultWidth = 348;
const double _roomPanelMinWidth = 348;
const double _roomPanelResizeHandleWidth = 16;
const double _roomPanelDefaultMaxViewportRatio = 1 / 3;
const double _roomPanelFilePreviewDefaultThreadViewportRatio = 2 / 3;
const double _roomPanelFilesMaxViewportRatio = 0.5;
const double _roomPanelMinThreadWidth = 420;
const double _roomPanelKeyboardStep = 16;

class PbRoomPanelMount extends StatefulWidget {
  const PbRoomPanelMount({
    super.key,
    required this.threadPanel,
    this.roomPanel,
    this.roomPanelBuilder,
    this.activeTab = PbRoomPanelTab.agents,
    this.filePreviewOpen = false,
    this.filePreviewFullscreen = false,
    this.roomPanelCollapsed = false,
  }) : assert(roomPanel != null || roomPanelBuilder != null, 'Either roomPanel or roomPanelBuilder must be provided.');

  final Widget threadPanel;
  final Widget? roomPanel;
  final Widget Function(BuildContext context, bool resizing)? roomPanelBuilder;
  final PbRoomPanelTab activeTab;
  final bool filePreviewOpen;
  final bool filePreviewFullscreen;
  final bool roomPanelCollapsed;

  @override
  State<PbRoomPanelMount> createState() => _PbRoomPanelMountState();
}

class _PbRoomPanelMountState extends State<PbRoomPanelMount> {
  double _panelWidth = _roomPanelDefaultWidth;
  bool _resizing = false;
  bool _hovered = false;
  bool _focused = false;

  double _maxWidth(double workspaceWidth) {
    final viewportRatio = switch (widget.activeTab) {
      PbRoomPanelTab.files => _roomPanelFilesMaxViewportRatio,
      PbRoomPanelTab.agents => _roomPanelDefaultMaxViewportRatio,
    };
    final viewportMax = workspaceWidth * viewportRatio;
    final boundedMax = math.min(viewportMax, workspaceWidth - _roomPanelMinThreadWidth);

    return math.max(_roomPanelMinWidth, boundedMax);
  }

  double _clampWidth(double workspaceWidth, double proposedWidth) {
    return proposedWidth.clamp(_roomPanelMinWidth, _maxWidth(workspaceWidth));
  }

  double _filePreviewDefaultWidth(double workspaceWidth) {
    return _clampWidth(workspaceWidth, workspaceWidth * (1 - _roomPanelFilePreviewDefaultThreadViewportRatio));
  }

  void _setWidth(double workspaceWidth, double proposedWidth) {
    setState(() => _panelWidth = _clampWidth(workspaceWidth, proposedWidth));
  }

  Widget _buildRoomPanel(BuildContext context) {
    return widget.roomPanelBuilder?.call(context, _resizing) ?? widget.roomPanel!;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event, double width) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _setWidth(width, _panelWidth + _roomPanelKeyboardStep);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _setWidth(width, _panelWidth - _roomPanelKeyboardStep);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.home) {
      _setWidth(width, _roomPanelMinWidth);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.end) {
      _setWidth(width, _maxWidth(width));
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(covariant PbRoomPanelMount oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.filePreviewOpen && widget.filePreviewOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        final box = context.findRenderObject();

        if (box is! RenderBox || !box.hasSize) {
          return;
        }

        final workspaceWidth = box.size.width;
        _setWidth(workspaceWidth, math.max(_panelWidth, _filePreviewDefaultWidth(workspaceWidth)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final workspaceWidth = constraints.maxWidth;
        final panelWidth = _clampWidth(workspaceWidth, _panelWidth);
        final roomPanel = _buildRoomPanel(context);

        if (widget.filePreviewFullscreen) {
          return SizedBox.expand(child: roomPanel);
        }

        if (widget.roomPanelCollapsed) {
          return SizedBox.expand(child: widget.threadPanel);
        }

        if (panelWidth != _panelWidth) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _panelWidth = panelWidth);
            }
          });
        }

        return Row(
          children: [
            Expanded(child: widget.threadPanel),
            SizedBox(
              width: panelWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: roomPanel),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: -(_roomPanelResizeHandleWidth / 2),
                    width: _roomPanelResizeHandleWidth,
                    child: _RoomPanelResizer(
                      active: _resizing || _hovered || _focused,
                      value: panelWidth,
                      min: _roomPanelMinWidth,
                      max: _maxWidth(workspaceWidth),
                      onFocusChanged: (focused) => setState(() => _focused = focused),
                      onHoverChanged: (hovered) => setState(() => _hovered = hovered),
                      onKeyEvent: (node, event) => _handleKeyEvent(node, event, workspaceWidth),
                      onDragStart: () => setState(() => _resizing = true),
                      onDragEnd: () => setState(() => _resizing = false),
                      onDragUpdate: (delta) => _setWidth(workspaceWidth, _panelWidth - delta),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RoomPanelResizer extends StatelessWidget {
  const _RoomPanelResizer({
    required this.active,
    required this.value,
    required this.min,
    required this.max,
    required this.onFocusChanged,
    required this.onHoverChanged,
    required this.onKeyEvent,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onDragUpdate,
  });

  final bool active;
  final double value;
  final double min;
  final double max;
  final ValueChanged<bool> onFocusChanged;
  final ValueChanged<bool> onHoverChanged;
  final FocusOnKeyEventCallback onKeyEvent;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<double> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final handleColor = active
        ? Color.lerp(PbColors.surfacePanel, PbColors.customRailSelectedSurface, 0.52)!
        : PbColors.textSubtle.withValues(alpha: 0.44);

    return Semantics(
      label: 'Resize side panel',
      value: '${value.round()} pixels',
      increasedValue: '${(value + _roomPanelKeyboardStep).clamp(min, max).round()} pixels',
      decreasedValue: '${(value - _roomPanelKeyboardStep).clamp(min, max).round()} pixels',
      child: Focus(
        onFocusChange: onFocusChanged,
        onKeyEvent: onKeyEvent,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          onEnter: (_) => onHoverChanged(true),
          onExit: (_) => onHoverChanged(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => onDragStart(),
            onHorizontalDragCancel: onDragEnd,
            onHorizontalDragEnd: (_) => onDragEnd(),
            onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Center(child: Container(width: 1, color: PbColors.borderSoft.withValues(alpha: 0.82))),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: active ? 1 : 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 4,
                    height: 72,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: active
                          ? [BoxShadow(color: PbColors.customRailSelectedSurface.withValues(alpha: 0.10), spreadRadius: 4)]
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
