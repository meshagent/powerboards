import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/pane_header_action_scope.dart';

const double _desktopSidetrayHamburgerIconSize = 22;
const double _desktopSidetrayCloseIconSize = 20;

class DesktopSidetrayToggleScope extends InheritedWidget {
  const DesktopSidetrayToggleScope({
    super.key,
    required this.collapsed,
    required this.enabled,
    required this.onToggle,
    required this.onCollapse,
    required this.onExpand,
    required super.child,
  });

  final bool collapsed;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onCollapse;
  final VoidCallback onExpand;

  static DesktopSidetrayToggleScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DesktopSidetrayToggleScope>();
  }

  static DesktopSidetrayToggleScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DesktopSidetrayToggleScope>()!;
  }

  @override
  bool updateShouldNotify(DesktopSidetrayToggleScope oldWidget) {
    return collapsed != oldWidget.collapsed || enabled != oldWidget.enabled;
  }
}

class DesktopSidetrayToggleButton extends StatelessWidget {
  const DesktopSidetrayToggleButton({super.key, required this.collapsed, required this.onPressed});

  final bool collapsed;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final icon = collapsed ? LucideIcons.menu : LucideIcons.x;
    final iconSize = collapsed ? _desktopSidetrayHamburgerIconSize : _desktopSidetrayCloseIconSize;
    final iconWidget = Icon(icon, size: iconSize);

    return Tooltip(
      message: collapsed ? "Open navigation" : "Close navigation",
      child: collapsed
          ? ShadIconButton.outline(
              width: desktopPaneHeaderContentHeight,
              height: desktopPaneHeaderContentHeight,
              padding: EdgeInsets.zero,
              icon: iconWidget,
              decoration: powerboardsAdaptiveIconButtonDecoration(context),
              onPressed: onPressed,
            )
          : ShadIconButton.ghost(
              width: desktopPaneHeaderContentHeight,
              height: desktopPaneHeaderContentHeight,
              padding: EdgeInsets.zero,
              icon: iconWidget,
              decoration: powerboardsAdaptiveIconButtonDecoration(context),
              backgroundColor: Colors.transparent,
              hoverBackgroundColor: Colors.transparent,
              hoverForegroundColor: theme.colorScheme.foreground,
              pressedForegroundColor: theme.colorScheme.foreground,
              onPressed: onPressed,
            ),
    );
  }
}
