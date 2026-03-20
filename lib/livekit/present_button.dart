import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PresentButton extends StatelessWidget {
  const PresentButton({super.key, required this.onPressed, required this.on, this.compact = false});

  static const double compactWidth = 48;

  final VoidCallback? onPressed;
  final bool on;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: on ? 'Stop Sharing' : 'Share Screen',
      child: SizedBox(
        width: compact ? compactWidth : null,
        child: (on ? ShadButton.new : ShadButton.outline)(
          padding: compact ? const EdgeInsets.symmetric(horizontal: 0) : null,
          onPressed: onPressed,
          leading: Icon(LucideIcons.screenShare),
          child: compact ? null : Text(on ? 'Stop Sharing' : 'Share Screen'),
        ),
      ),
    );
  }
}
