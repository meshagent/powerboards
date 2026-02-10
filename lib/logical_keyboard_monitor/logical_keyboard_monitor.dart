import 'package:flutter/services.dart';

class LogicalKeyboardMonitor {
  static void start() {
    ServicesBinding.instance.keyboard.addHandler(_onKey);
  }

  static void stop() {
    ServicesBinding.instance.keyboard.addHandler(_onKey);
  }

  static bool get isShiftPressed {
    return keys.contains(LogicalKeyboardKey.shift) ||
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
  }
}

bool _onKey(KeyEvent event) {
  if (event is KeyDownEvent) {
    keys.add(event.logicalKey);
  } else if (event is KeyUpEvent) {
    keys.remove(event.logicalKey);
  }
  return false;
}

Set<LogicalKeyboardKey> keys = {};
