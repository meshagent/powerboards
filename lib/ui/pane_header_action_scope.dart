import 'dart:math' as math;

import 'package:flutter/widgets.dart';

const double desktopPaneHeaderButtonGap = 8;
const double paneHeaderIconButtonIconSize = 20;
const double desktopPaneHeaderCompactButtonWidth = 48;
const double desktopPaneHeaderFilesButtonWidth = 96;
const double desktopPaneHeaderMeetButtonWidth = 96;
const double desktopPaneHeaderInviteButtonWidth = 104;
const double desktopPaneHeaderOptionsButtonWidth = 48;
const double desktopPaneHeaderAvatarButtonWidth = 56;
const double desktopPaneHeaderActionReserve = 72;
const double desktopPaneHeaderExpandedActionsWidthEstimate = 320;
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

class PaneHeaderActionState {
  const PaneHeaderActionState({this.compact = false, this.overflowCollapsed = false});

  final bool compact;
  final bool overflowCollapsed;

  static const expanded = PaneHeaderActionState();
  static const overflow = PaneHeaderActionState(overflowCollapsed: true);
  static const iconOnly = PaneHeaderActionState(compact: true);
  static const compactOverflow = PaneHeaderActionState(compact: true, overflowCollapsed: true);

  bool get isExpanded => !compact && !overflowCollapsed;

  @override
  bool operator ==(Object other) =>
      other is PaneHeaderActionState && other.compact == compact && other.overflowCollapsed == overflowCollapsed;

  @override
  int get hashCode => Object.hash(compact, overflowCollapsed);
}

PaneHeaderActionState resolvePaneHeaderActionState(
  BoxConstraints constraints, {
  required double leadingWidth,
  required List<Widget> actions,
  double minimumLeadingWidth = 0,
  double reserve = desktopPaneHeaderActionReserve,
  bool preferCompactBeforeOverflow = false,
}) {
  if (actions.isEmpty) {
    return PaneHeaderActionState.expanded;
  }

  final availableWidth = constraints.hasBoundedWidth ? constraints.maxWidth : constraints.minWidth;
  final normalizedLeadingWidth = math.max(0.0, leadingWidth);
  final normalizedMinimumLeadingWidth = minimumLeadingWidth.clamp(0.0, normalizedLeadingWidth).toDouble();
  final expandedThreshold =
      normalizedLeadingWidth + estimatedPaneHeaderActionsWidth(actions, compact: false, overflowCollapsed: false) + reserve;
  if (availableWidth >= expandedThreshold) {
    return PaneHeaderActionState.expanded;
  }

  final compactThreshold =
      normalizedMinimumLeadingWidth + estimatedPaneHeaderActionsWidth(actions, compact: true, overflowCollapsed: false) + reserve;
  if (preferCompactBeforeOverflow && availableWidth >= compactThreshold) {
    return PaneHeaderActionState.iconOnly;
  }

  final overflowThreshold =
      normalizedMinimumLeadingWidth + estimatedPaneHeaderActionsWidth(actions, compact: false, overflowCollapsed: true) + reserve;
  if (!preferCompactBeforeOverflow && availableWidth >= overflowThreshold) {
    return PaneHeaderActionState.overflow;
  }

  if (!preferCompactBeforeOverflow && availableWidth >= compactThreshold) {
    return PaneHeaderActionState.iconOnly;
  }

  final compactOverflowThreshold =
      normalizedMinimumLeadingWidth + estimatedPaneHeaderActionsWidth(actions, compact: true, overflowCollapsed: true) + reserve;

  if (availableWidth >= compactOverflowThreshold) {
    return PaneHeaderActionState.compactOverflow;
  }

  return PaneHeaderActionState.compactOverflow;
}

class CompactHeaderActions extends InheritedWidget {
  const CompactHeaderActions({super.key, required this.state, required super.child});

  final PaneHeaderActionState state;

  static bool compactOf(BuildContext context) {
    final item = context.dependOnInheritedWidgetOfExactType<CompactHeaderActions>();
    return item?.state.compact ?? false;
  }

  static bool overflowCollapsedOf(BuildContext context) {
    final item = context.dependOnInheritedWidgetOfExactType<CompactHeaderActions>();
    return item?.state.overflowCollapsed ?? false;
  }

  static bool iconOnlyOf(BuildContext context) {
    final item = context.dependOnInheritedWidgetOfExactType<CompactHeaderActions>();
    return item?.state.compact ?? false;
  }

  @override
  bool updateShouldNotify(CompactHeaderActions oldWidget) => state != oldWidget.state;
}

class CompactHeaderOverflowAction extends StatelessWidget {
  const CompactHeaderOverflowAction({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class PaneHeaderActionItem extends StatelessWidget {
  const PaneHeaderActionItem({
    super.key,
    required this.child,
    required this.expandedWidth,
    this.compactWidth = 56,
    this.overflowOnCompact = false,
  });

  final Widget child;
  final double expandedWidth;
  final double compactWidth;
  final bool overflowOnCompact;

  @override
  Widget build(BuildContext context) => child;
}

double estimatedPaneHeaderActionsWidth(List<Widget> actions, {required bool compact, required bool overflowCollapsed}) {
  final visible = visiblePaneHeaderActions(actions, overflowCollapsed: overflowCollapsed);
  if (visible.isEmpty) {
    return 0;
  }

  var width = 0.0;
  for (final action in visible) {
    if (action is PaneHeaderActionItem) {
      width += compact ? action.compactWidth : action.expandedWidth;
    } else {
      width += compact ? 56 : 140;
    }
  }

  width += desktopPaneHeaderButtonGap * (visible.length - 1);
  return width;
}

List<Widget> visiblePaneHeaderActions(List<Widget> actions, {required bool overflowCollapsed}) {
  if (!overflowCollapsed) {
    return actions;
  }

  return actions.where((action) => action is! PaneHeaderActionItem || !action.overflowOnCompact).toList(growable: false);
}
