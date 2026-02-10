import 'package:flutter/material.dart';

class ChromeVisibility extends StatefulWidget {
  const ChromeVisibility({super.key, required this.child});

  final Widget child;

  @override
  State createState() => ChromeVisibilityState();
}

class ChromeVisibilityState extends State<ChromeVisibility> {
  bool _visible = true;

  bool get visible => _visible;

  set visible(bool value) {
    _visible = value;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChromeVisibilityModel(visible: visible, child: widget.child);
  }

  static ChromeVisibilityState of(BuildContext context) {
    return context.findAncestorStateOfType<ChromeVisibilityState>()!;
  }

  static ChromeVisibilityState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<ChromeVisibilityState>();
  }
}

class ChromeVisibilityModel extends InheritedWidget {
  const ChromeVisibilityModel({required this.visible, super.key, required super.child});

  final bool visible;

  @override
  bool updateShouldNotify(ChromeVisibilityModel oldWidget) {
    return visible != oldWidget.visible;
  }

  static ChromeVisibilityModel of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ChromeVisibilityModel>()!;
  }

  static ChromeVisibilityModel? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ChromeVisibilityModel>();
  }
}
