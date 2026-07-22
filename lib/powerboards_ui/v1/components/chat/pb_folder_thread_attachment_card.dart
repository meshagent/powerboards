import 'package:flutter/material.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_svg_icon.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_tokens.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_typography.dart';

class PbFolderThreadAttachmentCard extends StatefulWidget {
  const PbFolderThreadAttachmentCard({super.key, required this.title});

  final String title;

  @override
  State<PbFolderThreadAttachmentCard> createState() => _PbFolderThreadAttachmentCardState();
}

class _PbFolderThreadAttachmentCardState extends State<PbFolderThreadAttachmentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: PbMotion.state,
        constraints: const BoxConstraints(minHeight: 52, maxWidth: 312.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: _hovered ? PbColors.surfacePanelSoft : PbColors.surfacePanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PbColors.borderSoft),
          boxShadow: _hovered ? PbShadows.stateHover : const <BoxShadow>[],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: PbSvgIcon(assetName: 'folder', size: 24, color: PbColors.surfaceRailSelected),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PowerboardsTypography.smallStrong.copyWith(color: PbColors.textPrimary, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            const SizedBox(
              width: 18,
              height: 24,
              child: Center(
                child: PbSvgIcon(assetName: 'arrow-up-right', size: 17, color: PbColors.customBrandInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
