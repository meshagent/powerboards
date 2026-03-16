import 'package:flutter/widgets.dart';

const double desktopPaneHeaderButtonGap = 8;
const double desktopPaneHeaderActionReserve = 72;
const double desktopPaneHeaderExpandedActionsWidthEstimate = 380;

bool shouldCompactPaneHeaderActions(
  double maxWidth, {
  double leadingWidth = 0,
  double reserve = desktopPaneHeaderActionReserve,
  double expandedActionsWidth = desktopPaneHeaderExpandedActionsWidthEstimate,
}) {
  return maxWidth - leadingWidth < expandedActionsWidth + reserve;
}

class PaneHeaderActionScope extends InheritedWidget {
  const PaneHeaderActionScope({super.key, required this.compact, this.iconOnly = false, required super.child});

  final bool compact;
  final bool iconOnly;

  static bool compactOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PaneHeaderActionScope>();
    return scope?.compact ?? false;
  }

  static bool iconOnlyOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PaneHeaderActionScope>();
    return scope?.iconOnly ?? false;
  }

  @override
  bool updateShouldNotify(PaneHeaderActionScope oldWidget) => compact != oldWidget.compact || iconOnly != oldWidget.iconOnly;
}
