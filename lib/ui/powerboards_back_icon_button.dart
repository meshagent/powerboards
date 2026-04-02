import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PowerboardsBackIconButton extends StatelessWidget {
  const PowerboardsBackIconButton({super.key, required this.onPressed, this.tooltip = "Back"});

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ShadIconButton.outline(icon: const Icon(LucideIcons.chevronLeft), onPressed: onPressed),
    );
  }
}
