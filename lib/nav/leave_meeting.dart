import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';

Future<bool> showLeaveMeeting(BuildContext context) async {
  final res = await showShadDialog<bool>(
    context: context,
    builder: (ctx) => PowerboardsShadDialog.compact(
      title: const Text("Meeting in progress"),
      description: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text("Are you sure you want to leave this meeting?")),
      actions: [
        ShadButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Stay')),
        ShadButton.destructive(
          onPressed: () {
            Navigator.of(ctx).pop(true);
          },
          child: const Text('Leave'),
        ),
      ],
    ),
  );

  return res ?? false;
}
