import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';

Future<bool> showLeaveMeeting(BuildContext context) async {
  final tt = ShadTheme.of(context).textTheme;

  final res = await showShadDialog<bool>(
    context: context,
    builder: (ctx) => PowerboardsShadDialog(
      useSafeArea: false,
      title: Text("Leave meeting in progress", style: tt.h3),
      description: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text("Are you sure you want to leave this meeting?")),
      actions: [
        ShadButton.outline(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        ShadButton(
          onPressed: () {
            Navigator.of(ctx).pop(true);
          },
          child: const Text('Continue'),
        ),
      ],
    ),
  );

  return res ?? false;
}
