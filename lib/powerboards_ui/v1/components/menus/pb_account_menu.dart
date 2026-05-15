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
    this.onLogoutPressed,
  });

  final String initials;
  final String email;
  final VoidCallback? onManageAccountPressed;
  final VoidCallback? onLogoutPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 496),
      child: IntrinsicWidth(
        child: PbMenuCard(
          child: PbMenuList(
            children: [
              PbMenuOption(
                title: email,
                subtitle: 'Signed in as',
                leadingInitials: initials,
                info: true,
                infoSelected: true,
              ),
              PbMenuOption(
                title: 'Manage account',
                singleLine: true,
                leadingIconAssetName: 'settings',
                onPressed: onManageAccountPressed,
              ),
              const PbMenuDivider(),
              PbMenuOption(
                title: 'Logout of account',
                singleLine: true,
                leadingIconAssetName: 'power',
                onPressed: onLogoutPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
