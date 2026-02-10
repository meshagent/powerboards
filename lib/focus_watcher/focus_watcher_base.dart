import 'package:flutter/material.dart';
import 'package:powerboards/focus_watcher/focus_watcher.dart';

abstract class FocusWatcher extends StatefulWidget {
  const FocusWatcher.base({super.key, required this.child});

  final Widget child;

  @override
  State createState() => FocusWatcherState();

  void onBlur() {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}

class FocusWatcherState extends State<FocusWatcher> {
  bool hasFocus = true;

  @override
  Widget build(BuildContext context) {
    return AppVisibilityProvider(
      isVisible: hasFocus,
      child: GestureDetector(
        onTap: () {
          widget.onBlur();
        },
        child: widget.child,
      ),
    );
  }
}
