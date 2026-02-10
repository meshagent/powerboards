import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PresentButton extends StatelessWidget {
  const PresentButton({super.key, required this.onPressed, required this.on});

  final VoidCallback? onPressed;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return (on ? ShadButton.new : ShadButton.outline)(
      onPressed: onPressed,
      leading: Icon(LucideIcons.screenShare),
      child: Text(on ? 'Stop Sharing' : 'Share Screen'),
    );
  }
}
