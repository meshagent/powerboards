import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_typography.dart';
import '../primitives/pb_avatar.dart';
import 'pb_menu_card.dart';
import 'pb_menu_divider.dart';
import 'pb_menu_list.dart';
import 'pb_menu_option.dart';

class PbAccountMenu extends StatelessWidget {
  const PbAccountMenu({
    super.key,
    this.initials = 'JP',
    this.email = 'jesse.park@acme.com',
    this.projectLabel = 'Browsing project: ACME',
    this.width,
    this.onSelectProjectPressed,
    this.onManageAccountPressed,
    this.previewTitle,
    this.previewIconAssetName = 'rotate-ccw',
    this.onPreviewPressed,
    this.onLogoutPressed,
  });

  final String initials;
  final String email;
  final String projectLabel;
  final double? width;
  final VoidCallback? onSelectProjectPressed;
  final VoidCallback? onManageAccountPressed;
  final String? previewTitle;
  final String previewIconAssetName;
  final VoidCallback? onPreviewPressed;
  final VoidCallback? onLogoutPressed;

  @override
  Widget build(BuildContext context) {
    final resolvedPreviewTitle = previewTitle?.trim();
    final showPreviewOption = resolvedPreviewTitle != null && resolvedPreviewTitle.isNotEmpty && onPreviewPressed != null;
    final showManageAccountOption = onManageAccountPressed != null;

    return SizedBox(
      width: width ?? 284,
      child: PbMenuCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PbMenuList(
              children: [
                _AccountSummaryCard(initials: initials, email: email, projectLabel: projectLabel),
                PbMenuOption(
                  title: 'Select a Project',
                  singleLine: true,
                  leadingIconAssetName: 'book-copy',
                  onPressed: onSelectProjectPressed,
                ),
                if (showManageAccountOption)
                  PbMenuOption(
                    title: 'Manage account',
                    singleLine: true,
                    leadingIconAssetName: 'settings',
                    onPressed: onManageAccountPressed,
                  ),
                if (showPreviewOption)
                  PbMenuOption(
                    title: resolvedPreviewTitle,
                    singleLine: true,
                    leadingIconAssetName: previewIconAssetName,
                    onPressed: onPreviewPressed,
                  ),
              ],
            ),
            const PbMenuDivider(),
            PbMenuList(
              children: [
                PbMenuOption(title: 'Logout of account', singleLine: true, leadingIconAssetName: 'power', onPressed: onLogoutPressed),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSummaryCard extends StatelessWidget {
  const _AccountSummaryCard({required this.initials, required this.email, required this.projectLabel});

  final String initials;
  final String email;
  final String projectLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(color: PbColors.surfaceAccentSoft, borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PbAvatar(
            initials: initials,
            size: 52,
            textStyle: PowerboardsTypography.customAvatarInitials.copyWith(
              fontSize: PowerboardsTypography.customAvatarInitials.fontSize! * 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(email, maxLines: 1, softWrap: false, overflow: TextOverflow.clip, style: PowerboardsTypography.labelSmall),
              const SizedBox(height: 6),
              Text(projectLabel, textAlign: TextAlign.center, softWrap: true, style: PowerboardsTypography.textXSmall),
            ],
          ),
        ],
      ),
    );
  }
}
