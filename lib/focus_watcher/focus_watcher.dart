import 'package:flutter/material.dart';

import 'focus_watcher_none.dart' // Stub implementation
    if (dart.library.io) 'focus_watcher_app.dart' // dart:io implementation
    if (dart.library.js_interop) 'focus_watcher_web.dart';

Widget platformFocusWatcher({Key? key, required Widget child}) {
  return FocusWatcherImpl(key: key, child: child);
}

class AppVisibilityProvider extends InheritedWidget {
  const AppVisibilityProvider({super.key, required this.isVisible, required super.child});

  final bool isVisible;

  @override
  bool updateShouldNotify(AppVisibilityProvider oldWidget) {
    return oldWidget.isVisible != isVisible;
  }

  static AppVisibilityProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppVisibilityProvider>()!;
  }

  static AppVisibilityProvider? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppVisibilityProvider>();
  }
}
