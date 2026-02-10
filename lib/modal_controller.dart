import 'dart:async';
import 'package:flutter/material.dart';
import 'package:powerboards/theme/theme.dart';

class MenuEntry<T> extends _DialogEntry<T> {
  final MenuController controller;
  const MenuEntry({
    super.key,
    required this.controller,
    required super.id,
    required super.completer,
    required super.child,
    required super.pop,
  });
}

class _DialogEntry<T> extends InheritedWidget {
  final int id;
  final void Function([T?]) pop;
  final Completer<T> completer;

  const _DialogEntry({super.key, required this.id, required super.child, required this.pop, required this.completer});

  static _DialogEntry<T>? maybeOf<T>(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_DialogEntry<T>>();
  }

  static _DialogEntry<T> of<T>(BuildContext context) {
    final _DialogEntry<T>? result = maybeOf<T>(context);
    assert(result != null, 'No DialogEntry of Type ${T.runtimeType} found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(_DialogEntry<T> oldWidget) {
    return false;
  }
}

class DismissibleBarrier extends StatelessWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final Color barrierColor;

  const DismissibleBarrier({super.key, required this.child, required this.onDismiss, this.barrierColor = Colors.black26});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: barrierColor,
        child: Center(child: child),
      ),
    );
  }
}

abstract class Modals {
  static ModalControllerState of(BuildContext context) {
    return context.findAncestorStateOfType<ModalControllerState>() as ModalControllerState;
  }

  static void pop<T>(BuildContext context, [T? result]) {
    _DialogEntry.of<T>(context).pop(result);
  }
}

class ModalController extends StatefulWidget {
  const ModalController({super.key, required this.child});

  final Widget child;
  @override
  State createState() => ModalControllerState();
}

class ModalControllerState extends State<ModalController> {
  @override
  void didUpdateWidget(ModalController oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      setState(() {});
    }
  }

  final List<_DialogEntry> _stack = [];
  int _nextDialogId = 0;

  void showMenu({required BuildContext context, required List<PowerboardsMenuItem> items, required Offset position}) {
    final CapturedThemes themes = InheritedTheme.capture(from: context, to: this.context);

    final MenuController controller = MenuController();
    Completer completer = Completer();
    final dialogId = _nextDialogId++;

    final entry = MenuEntry(
      controller: controller,
      completer: completer,
      id: dialogId,
      pop: ([dynamic]) {
        _remove(dialogId);
      },
      child: Builder(
        builder: (inner) {
          return DismissibleBarrier(
            barrierColor: Colors.transparent,
            onDismiss: () async {
              if (controller.isOpen) {
                controller.close();
              }
              _remove(dialogId);
            },
            // The GestureDetector prevents click-through when the user clicks on widgets in the dialog.
            child: GestureDetector(
              onTap: () {},
              child: themes.wrap(
                Align(
                  // Tricksy trick alert.
                  // The DismissibleBarrier will span the entire screen.
                  // Therefore, align the menu anchor to the bottom right because we will open
                  // the menu with the global position.
                  alignment: const Alignment(-1, -1),
                  child: MenuAnchor(
                    onClose: () {
                      _remove(dialogId);
                    },
                    style: createMenuStyle(),
                    controller: controller,
                    menuChildren: items,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    setState(() {
      _stack.add(entry);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.isOpen) {
        controller.close();
      }
      controller.open(position: position);
    });
  }

  void _remove<T>(int id, [T? result]) {
    if (_stack.isEmpty) {
      return;
    }
    int foundAtIndex = -1;
    for (var i = 0; i < _stack.length && foundAtIndex == -1; i++) {
      final item = _stack[i];
      if (item.id == id) {
        foundAtIndex = i;
        item.completer.complete(result);
      }
    }
    if (foundAtIndex == -1) {
      debugPrint('could not hide the dialog because it could not be found');
      return;
    }

    setState(() {
      _stack.removeAt(foundAtIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [widget.child];
    for (var i = 0; i < _stack.length; i++) {
      final item = _stack[i];
      children.add(item);
    }
    return Stack(children: children);
  }
}
