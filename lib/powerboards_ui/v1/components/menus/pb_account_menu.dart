import 'package:flutter/material.dart';

import 'pb_menu_card.dart';
import 'pb_menu_divider.dart';
import 'pb_menu_list.dart';
import 'pb_menu_option.dart';

class PbAccountMenu extends StatelessWidget {
  const PbAccountMenu({
    super.key,
    this.initials = 'JP',
    this.email = 'jesse.park@acme.com',
    this.onManageAccountPressed,
    this.previewTitle,
    this.previewIconAssetName = 'rotate-ccw',
    this.onPreviewPressed,
    this.onLogoutPressed,
  });

  final String initials;
  final String email;
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

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 496),
      child: IntrinsicWidth(
        child: PbMenuCard(
          child: PbMenuList(
            children: [
              PbMenuOption(title: email, subtitle: 'Signed in as', leadingInitials: initials, info: true, infoSelected: true),
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
              if (showManageAccountOption || showPreviewOption) const PbMenuDivider(),
              PbMenuOption(title: 'Logout of account', singleLine: true, leadingIconAssetName: 'power', onPressed: onLogoutPressed),
            ],
          ),
        ),
      ),
    );
  }
}
