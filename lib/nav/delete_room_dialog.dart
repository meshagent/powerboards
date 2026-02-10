import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<bool?> showDeleteRoomDialog(
  BuildContext context, {
  String title = 'Are you sure?',
  String? description,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  bool destructive = false,
  bool barrierDismissible = true,
}) {
  return showShadDialog<bool?>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => ShadDialog(
      useSafeArea: false,
      title: Text(title),
      description: description != null ? Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(description)) : null,
      // Content area can be left null for a plain confirm
      actions: [
        ShadButton.outline(onPressed: () => Navigator.of(ctx).pop(false), child: Text(cancelText)),
        (destructive
            ? ShadButton.destructive(onPressed: () => Navigator.of(ctx).pop(true), child: Text(confirmText))
            : ShadButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(confirmText))),
      ],
      child: const SizedBox.shrink(),
    ),
  );
}
