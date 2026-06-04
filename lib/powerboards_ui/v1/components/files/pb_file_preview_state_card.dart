import 'package:flutter/material.dart';

import '../../models/pb_attachment_file_metadata.dart';
import '../../theme/pb_colors.dart';
import '../../theme/pb_typography.dart';
import '../primitives/pb_svg_icon.dart';

class PbFilePreviewStateCard extends StatelessWidget {
  const PbFilePreviewStateCard({super.key, required this.file, required this.state, this.label});

  final PbAttachmentListItemData file;
  final PbAttachmentPreviewState state;
  final String? label;

  String get _label {
    final customLabel = label;
    if (customLabel != null) {
      return customLabel;
    }

    return switch (state) {
      PbAttachmentPreviewState.unavailable => 'No preview available',
      PbAttachmentPreviewState.unsupported => 'File preview not supported',
      PbAttachmentPreviewState.none => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: PbColors.surfacePanel,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(17, 24, 39, 0.03), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PbSvgIcon(assetName: file.iconAssetName, size: 28, color: PbColors.textSubtle),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              _label,
              style: PowerboardsTypography.labelSmall.copyWith(color: PbColors.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
