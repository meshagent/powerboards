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
  BoxConstraints constraints, {
  double leadingWidth = 0,
  double reserve = desktopPaneHeaderActionReserve,
  double expandedActionsWidth = desktopPaneHeaderExpandedActionsWidthEstimate,
}) {
  final availableWidth = constraints.hasBoundedWidth ? constraints.maxWidth : constraints.minWidth;
  final minimumExpandedWidth = leadingWidth + expandedActionsWidth + reserve;
  return availableWidth < minimumExpandedWidth;
}

class CompactHeaderActions extends InheritedWidget {
  const CompactHeaderActions({super.key, required this.compact, required super.child});

  final bool compact;

  static bool compactOf(BuildContext context) {
    final item = context.dependOnInheritedWidgetOfExactType<CompactHeaderActions>();
    return item?.compact ?? false;
  }

  static bool iconOnlyOf(BuildContext context) {
    final item = context.dependOnInheritedWidgetOfExactType<CompactHeaderActions>();
    return item?.compact ?? false;
  }

  @override
  bool updateShouldNotify(CompactHeaderActions oldWidget) => compact != oldWidget.compact;
}
