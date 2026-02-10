import 'package:flutter/material.dart';

class KeyboardSafe extends StatelessWidget {
  const KeyboardSafe({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: child,
    );
  }
}
