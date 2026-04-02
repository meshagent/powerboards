import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/pane_header_action_scope.dart';

class PowerboardsBackIconButton extends StatelessWidget {
  const PowerboardsBackIconButton({super.key, required this.onPressed, this.tooltip = "Back", this.icon = LucideIcons.chevronLeft});

  final VoidCallback? onPressed;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ShadIconButton.outline(
        icon: Icon(icon, size: paneHeaderIconButtonIconSize),
        onPressed: onPressed,
      ),
    );
  }
}
