import "package:flutter/material.dart";

abstract class Controller extends ChangeNotifier {
  static T ofType<T extends Controller>(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ControllerModel<T>>()!.controller;
  }

  static T? maybeOfType<T extends Controller>(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ControllerModel<T>>()?.controller;
  }
}

class _ControllerModel<T> extends InheritedWidget {
  const _ControllerModel({super.key, required super.child, required this.controller});

  final T controller;

  @override
  bool updateShouldNotify(_ControllerModel<T> oldWidget) {
    return oldWidget.controller != controller;
  }
}

class ControllerBuilder<T extends Controller> extends StatelessWidget {
  const ControllerBuilder({super.key, required this.controller, required this.builder});

  final T controller;

  final Widget Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) {
    return _ControllerModel<T>(
      controller: controller,
      child: ListenableBuilder(listenable: controller, builder: (context, _) => builder(context)),
    );
  }
}

class ControllerProvider<T extends Controller> extends StatelessWidget {
  const ControllerProvider({super.key, required this.controller, required this.child});

  final Widget child;
  final T controller;

  @override
  Widget build(BuildContext context) {
    return _ControllerModel<T>(controller: controller, child: child);
  }
}
