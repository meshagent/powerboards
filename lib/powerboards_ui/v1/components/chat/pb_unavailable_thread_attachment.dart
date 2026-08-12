import 'package:flutter/material.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_svg_icon.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_button.dart';
import 'package:powerboards/powerboards_ui/v1/components/dialogs/pb_dialog_shell.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_typography.dart';

Future<void> showPbUnavailableAttachmentDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    useSafeArea: false,
    builder: (dialogContext) => Stack(
      children: [
        PbDialogShell(
          title: 'No longer available',
          description: 'This attachment was deleted or you no longer have permission to access it.',
          onClose: () => Navigator.of(dialogContext).pop(),
          actions: [PbButton(label: 'Close', variant: PbButtonVariant.primary, onPressed: () => Navigator.of(dialogContext).pop())],
          child: const SizedBox.shrink(),
        ),
      ],
    ),
  );
}

Future<bool> showPbRenamedFolderLinkDialog(BuildContext context, {required String previousName, required String currentName}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    useSafeArea: false,
    builder: (dialogContext) => Stack(
      children: [
        PbDialogShell(
          title: 'Folder renamed',
          description: '“$previousName” is now “$currentName”. Select OK to open the renamed folder.',
          onClose: () => Navigator.of(dialogContext).pop(false),
          actions: [PbButton(label: 'OK', variant: PbButtonVariant.primary, onPressed: () => Navigator.of(dialogContext).pop(true))],
          child: const SizedBox.shrink(),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class PbUnavailableThreadAttachment extends StatelessWidget {
  const PbUnavailableThreadAttachment({super.key, required this.fileName, required this.onPressed, this.fileType});

  final String fileName;
  final VoidCallback onPressed;
  final PbAttachmentFileType? fileType;

  @override
  Widget build(BuildContext context) {
    final metadata = PbResolvedAttachmentMetadata.resolve(title: fileName, explicitFileType: fileType);
    final content = metadata.fileType == PbAttachmentFileType.image
        ? _UnavailableImagePreview(fileName: fileName, iconAssetName: metadata.iconAssetName)
        : _UnavailableFileCard(fileName: fileName, iconAssetName: metadata.iconAssetName);

    return Semantics(
      button: true,
      label: '$fileName. No longer available.',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onPressed, child: content),
      ),
    );
  }
}

class _UnavailableImagePreview extends StatelessWidget {
  const _UnavailableImagePreview({required this.fileName, required this.iconAssetName});

  final String fileName;
  final String iconAssetName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 312.5,
      height: 312.5,
      decoration: BoxDecoration(
        color: PbColors.surfacePanelSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PbColors.borderSoft),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PbSvgIcon(assetName: iconAssetName, size: 36, color: PbColors.textSubtle),
          const SizedBox(height: 12),
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PowerboardsTypography.smallStrong.copyWith(color: PbColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _UnavailableFileCard extends StatelessWidget {
  const _UnavailableFileCard({required this.fileName, required this.iconAssetName});

  final String fileName;
  final String iconAssetName;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52, maxWidth: 312.5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: PbColors.surfacePanelSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PbColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: PbSvgIcon(assetName: iconAssetName, size: 24, color: PbColors.textSubtle),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PowerboardsTypography.smallStrong.copyWith(color: PbColors.textMuted, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
