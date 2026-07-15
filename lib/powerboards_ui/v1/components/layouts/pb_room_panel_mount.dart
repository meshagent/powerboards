import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_tokens.dart';
import 'pb_room_panel.dart';

const double _roomPanelDefaultWidth = PbSizes.roomPanelDefault;
const double _roomPanelMinWidth = PbSizes.roomPanelDefault;
const double _roomPanelResizeHandleWidth = PbSizes.roomPanelResizeHandle;
const double _roomPanelFilePreviewDefaultThreadViewportRatio = 2 / 3;
const double _roomPanelMaxViewportRatio = 0.5;
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
    this.panelWidth,
    this.onPanelWidthChanged,
  }) : assert(roomPanel != null || roomPanelBuilder != null, 'Either roomPanel or roomPanelBuilder must be provided.');

  final Widget threadPanel;
  final Widget? roomPanel;
  final Widget Function(BuildContext context, bool resizing)? roomPanelBuilder;
  final PbRoomPanelTab activeTab;
  final bool filePreviewOpen;
  final bool filePreviewFullscreen;
  final bool roomPanelCollapsed;
  final double? panelWidth;
  final ValueChanged<double>? onPanelWidthChanged;

  @override
  State<PbRoomPanelMount> createState() => _PbRoomPanelMountState();
}

class _PbRoomPanelMountState extends State<PbRoomPanelMount> {
  double _panelWidth = _roomPanelDefaultWidth;
  double? _resizeStartX;
  double? _resizeStartWidth;
  bool _resizing = false;
  bool _hovered = false;
  bool _focused = false;

  double _maxWidth(double workspaceWidth) {
    final viewportMax = workspaceWidth * _roomPanelMaxViewportRatio;
    final boundedMax = math.min(viewportMax, workspaceWidth - _roomPanelMinThreadWidth);

    return math.max(_roomPanelMinWidth, boundedMax);
  }

  double _clampWidth(double workspaceWidth, double proposedWidth) {
    return proposedWidth.clamp(_roomPanelMinWidth, _maxWidth(workspaceWidth));
  }

  double _filePreviewDefaultWidth(double workspaceWidth) {
    return _clampWidth(workspaceWidth, workspaceWidth * (1 - _roomPanelFilePreviewDefaultThreadViewportRatio));
  }

  double get _effectivePanelWidth => widget.panelWidth ?? _panelWidth;

  void _commitWidth(double width) {
    if (widget.onPanelWidthChanged != null) {
      widget.onPanelWidthChanged!(width);
      return;
    }

    setState(() => _panelWidth = width);
  }

  void _setWidth(double workspaceWidth, double proposedWidth) {
    _commitWidth(_clampWidth(workspaceWidth, proposedWidth));
  }

  Widget _buildRoomPanel(BuildContext context) {
    return widget.roomPanelBuilder?.call(context, _resizing) ?? widget.roomPanel!;
  }

  void _startResize(double globalX, double panelWidth) {
    setState(() {
      _resizing = true;
      _hovered = false;
      _resizeStartX = globalX;
      _resizeStartWidth = panelWidth;
    });
  }

  void _stopResize() {
    setState(() {
      _resizing = false;
      _hovered = false;
      _resizeStartX = null;
      _resizeStartWidth = null;
    });
  }

  void _updateResize(double workspaceWidth, double globalX) {
    final startX = _resizeStartX;
    final startWidth = _resizeStartWidth;

    if (startX == null || startWidth == null) {
      return;
    }

    _setWidth(workspaceWidth, startWidth - (globalX - startX));
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event, double width) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _setWidth(width, _effectivePanelWidth + _roomPanelKeyboardStep);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _setWidth(width, _effectivePanelWidth - _roomPanelKeyboardStep);
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
        _setWidth(workspaceWidth, math.max(_effectivePanelWidth, _filePreviewDefaultWidth(workspaceWidth)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final workspaceWidth = constraints.maxWidth;
        final currentPanelWidth = _effectivePanelWidth;
        final panelWidth = _clampWidth(workspaceWidth, currentPanelWidth);
        final filePreviewFullscreen = widget.filePreviewFullscreen;
        final roomPanelVisible = !filePreviewFullscreen && !widget.roomPanelCollapsed;
        final roomPanel = filePreviewFullscreen || roomPanelVisible ? _buildRoomPanel(context) : null;

        if (roomPanelVisible && widget.panelWidth == null && panelWidth != currentPanelWidth) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _commitWidth(panelWidth);
            }
          });
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(top: 0, bottom: 0, left: 0, right: roomPanelVisible ? panelWidth : 0, child: widget.threadPanel),
            if (filePreviewFullscreen)
              Positioned.fill(child: roomPanel!)
            else if (roomPanelVisible)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: panelWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: roomPanel!),
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
                        onHoverChanged: (hovered) {
                          if (_resizing) {
                            return;
                          }

                          setState(() => _hovered = hovered);
                        },
                        onKeyEvent: (node, event) => _handleKeyEvent(node, event, workspaceWidth),
                        onDragStart: (globalX) => _startResize(globalX, panelWidth),
                        onDragEnd: _stopResize,
                        onDragUpdate: (globalX) => _updateResize(workspaceWidth, globalX),
                      ),
                    ),
                  ],
                ),
              ),
            if (_resizing && roomPanelVisible) const Positioned.fill(child: _RoomPanelResizeShield()),
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
  final ValueChanged<double> onDragStart;
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
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (event.buttons & kPrimaryButton == 0) {
                return;
              }

              onDragStart(event.position.dx);
            },
            onPointerMove: (event) {
              if (event.buttons & kPrimaryButton == 0) {
                return;
              }

              onDragUpdate(event.position.dx);
            },
            onPointerUp: (_) => onDragEnd(),
            onPointerCancel: (_) => onDragEnd(),
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
                    height: PbSizes.mobileRailHeight,
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

class _RoomPanelResizeShield extends StatelessWidget {
  const _RoomPanelResizeShield();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: AbsorbPointer(
        child: ColoredBox(color: Colors.transparent, child: SizedBox.expand()),
      ),
    );
  }
}
