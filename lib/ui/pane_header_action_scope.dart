import 'package:flutter/widgets.dart';

const double desktopPaneHeaderButtonGap = 8;

bool shouldCompactPaneHeaderActions(double maxWidth) => maxWidth < 760;

class PaneHeaderActionScope extends InheritedWidget {
  const PaneHeaderActionScope({super.key, required this.compact, required super.child});

  final bool compact;

  static bool compactOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PaneHeaderActionScope>();
    return scope?.compact ?? false;
  }

  @override
  bool updateShouldNotify(PaneHeaderActionScope oldWidget) => compact != oldWidget.compact;
}
