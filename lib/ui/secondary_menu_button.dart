import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:powerboards/ui/menu.dart";

class SecondaryMenuButton extends StatelessWidget {
  const SecondaryMenuButton({super.key, required this.buildMenu, this.enabled = true, required this.child});

  final bool enabled;
  final List<PopupMenuEntry> Function(BuildContext context, Offset localOffset) buildMenu;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _SecondaryMenuButtonData(
      enabled: enabled,
      buildMenu: buildMenu,
      child: Builder(
        builder: (context) => GestureDetector(
          onSecondaryTapDown: enabled
              ? (kIsWeb ? (details) => activate(context, details.globalPosition, details.localPosition) : null)
              : null,
          onForcePressStart: enabled
              ? (kIsWeb ? null : (details) => activate(context, details.globalPosition, details.localPosition))
              : null,
          onLongPressStart: enabled
              ? (kIsWeb ? null : (details) => activate(context, details.globalPosition, details.localPosition))
              : null,
          child: child,
        ),
      ),
    );
  }

  static bool activate(BuildContext context, Offset globalPosition, Offset localPosition) {
    final menu = context.dependOnInheritedWidgetOfExactType<_SecondaryMenuButtonData>();
    if (menu != null) {
      final items = menu.buildMenu(context, localPosition);
      if (items.isNotEmpty) {
        final position = getMenuPosition(context, globalPosition);
        showMenu(context: context, position: position, items: items);
        return true;
      }
    }
    return false;
  }
}

class _SecondaryMenuButtonData extends InheritedWidget {
  const _SecondaryMenuButtonData({required super.child, required this.enabled, required this.buildMenu});

  final bool enabled;
  final List<PopupMenuEntry> Function(BuildContext context, Offset localOffset) buildMenu;

  @override
  bool updateShouldNotify(_SecondaryMenuButtonData oldWidget) {
    return oldWidget.enabled != enabled || oldWidget.buildMenu != buildMenu;
  }
}
