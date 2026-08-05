import 'package:flutter/material.dart';

import '../dialogs/pb_dialog.dart';
import '../menus/pb_menu_filter_field.dart';

class PbCommentSaveCopyDialog extends StatelessWidget {
  const PbCommentSaveCopyDialog({
    super.key,
    required this.subtitle,
    required this.namePlaceholder,
    required this.nameController,
    required this.fileBrowser,
    required this.canSave,
    required this.saving,
    required this.onNameChanged,
    required this.onCopyAndSave,
    required this.onClose,
  });

  final String subtitle;
  final String namePlaceholder;
  final TextEditingController nameController;
  final Widget fileBrowser;
  final bool canSave;
  final bool saving;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onCopyAndSave;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return PbDialogShell(
      title: 'Save a copy as...',
      subtitle: subtitle,
      bodyExpanded: true,
      onClose: saving ? () {} : onClose,
      surfacePadding: EdgeInsets.zero,
      headerPadding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      actionsPadding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
      headerBodySpacing: 24,
      bodyActionsSpacing: 0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            child: Material(
              type: MaterialType.transparency,
              child: PbMenuFilterField(
                key: const ValueKey('pb-comment-save-copy-name-field'),
                controller: nameController,
                placeholder: namePlaceholder,
                margin: EdgeInsets.zero,
                enabled: !saving,
                onChanged: onNameChanged,
              ),
            ),
          ),
          Expanded(child: fileBrowser),
        ],
      ),
      actions: PbDialogActions(
        secondaryLabel: 'Cancel',
        primaryLabel: saving ? 'Saving...' : 'Save to Files',
        onSecondaryPressed: saving ? () {} : onClose,
        onPrimaryPressed: canSave && !saving ? onCopyAndSave : null,
      ),
    );
  }
}
