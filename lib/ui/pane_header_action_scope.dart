import 'package:flutter/widgets.dart';

const double desktopPaneHeaderButtonGap = 8;
const double desktopPaneHeaderActionReserve = 72;
const double desktopPaneHeaderExpandedActionsWidthEstimate = 380;
const double desktopPaneHeaderContentHeight = 44;
const double desktopPaneSecondaryControlTopOffset = 16;
const double desktopPaneSecondaryControlHeight = 40;
const double desktopPaneSecondaryRowContentGap = 6;
const double desktopPaneHeaderToContentOffset =
    desktopPaneSecondaryControlTopOffset + desktopPaneSecondaryControlHeight + desktopPaneSecondaryRowContentGap;
const double desktopPaneHeaderToChatViewportOffset = desktopPaneSecondaryControlTopOffset;
const double desktopPaneChatHorizontalInset = 12;
const double desktopPaneBottomInset = desktopPaneSecondaryControlTopOffset;
const double desktopPaneSideHorizontalInset = 20;
const double desktopPaneSideHeaderSlotSize = 30;
const double desktopPaneSideHeaderGap = 16;
const double desktopPaneSideHeaderVisualInset = desktopPaneSideHeaderSlotSize + desktopPaneSideHeaderGap;
const double desktopPaneSideListItemLeadingInset = 12;

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
