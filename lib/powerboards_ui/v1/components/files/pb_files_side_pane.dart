import 'package:flutter/material.dart';

import '../../models/pb_attachment_file_metadata.dart';
import '../../theme/pb_colors.dart';
import '../layouts/pb_room_panel.dart';
import 'pb_files_data.dart';
import 'pb_sidepane_file_list.dart';

class PbFilesSidePane extends StatelessWidget {
  const PbFilesSidePane({
    super.key,
    required this.files,
    required this.previewFile,
    required this.fullscreen,
    required this.resizing,
    required this.borderOnTop,
    required this.responsiveOverlay,
    required this.responsiveOverlayMobile,
    required this.onPreviewFile,
    this.previewBuilder,
    this.onAskAgent,
    this.onShare,
    this.onDownload,
    required this.onToggleFullscreen,
    required this.onClosePreview,
  });

  static const _emptyRecentFiles = PbSidepaneFileEmptyStateData(
    title: 'No file history yet',
    subtitle: 'Files you open will appear here.',
    fileType: PbAttachmentFileType.generic,
  );

  final List<PbFilesItemData> files;
  final PbFilesItemData? previewFile;
  final bool fullscreen;
  final bool resizing;
  final bool borderOnTop;
  final bool responsiveOverlay;
  final bool responsiveOverlayMobile;
  final ValueChanged<PbFilesItemData> onPreviewFile;
  final Widget Function(PbFilesItemData file)? previewBuilder;
  final ValueChanged<PbFilesItemData>? onAskAgent;
  final ValueChanged<PbFilesItemData>? onShare;
  final ValueChanged<PbFilesItemData>? onDownload;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onClosePreview;

  @override
  Widget build(BuildContext context) {
    final preview = previewFile;
    if (preview != null) {
      return PbFilePreviewPane(
        file: preview.toAttachmentData(),
        fullscreen: fullscreen,
        resizing: resizing,
        borderOnTop: borderOnTop,
        showInlineBorder: !responsiveOverlay,
        hideFullscreenToggle: responsiveOverlayMobile,
        onAskAgent: onAskAgent == null ? null : () => onAskAgent!(preview),
        onShare: onShare == null ? null : () => onShare!(preview),
        onDownload: onDownload == null ? null : () => onDownload!(preview),
        onToggleFullscreen: onToggleFullscreen,
        onClose: onClosePreview,
        child: previewBuilder?.call(preview),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.fromLTRB(22, responsiveOverlay ? 26 : 29, 22, 0),
      decoration: BoxDecoration(
        color: responsiveOverlay ? Colors.transparent : PbColors.surfacePanelWash,
        border: responsiveOverlay
            ? null
            : borderOnTop
            ? const Border(top: BorderSide(color: PbColors.borderSoft))
            : const Border(left: BorderSide(color: PbColors.borderSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PbStaticRoomTabs(label: 'Recently opened'),
          const SizedBox(height: 16),
          const PbRoomPanelDescription('Your file session history appears here.'),
          const SizedBox(height: 20),
          PbSidepaneFileList(
            files: [for (final file in files) PbSidepaneFileListItem(data: file.toAttachmentData(), onPressed: () => onPreviewFile(file))],
            emptyState: _emptyRecentFiles,
          ),
        ],
      ),
    );
  }
}

extension PbFilesSidePaneOverlay on PbFilesSidePane {
  Widget asOverlayFrame({required bool mobile, required VoidCallback onClose}) {
    return PbResponsiveRoomPanelOverlayFrame(
      mobile: mobile,
      onClose: onClose,
      preview: previewFile == null ? null : this,
      child: previewFile == null ? this : const SizedBox.shrink(),
    );
  }
}
