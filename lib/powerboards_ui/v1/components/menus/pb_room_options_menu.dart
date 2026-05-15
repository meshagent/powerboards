import 'package:flutter/material.dart';

import 'pb_menu_card.dart';
import 'pb_menu_divider.dart';
import 'pb_menu_list.dart';
import 'pb_menu_option.dart';

class PbRoomOptionsMenu extends StatelessWidget {
  const PbRoomOptionsMenu({
    super.key,
    this.consoleLabel = 'Show console',
    this.width = 240,
    this.onRenamePressed,
    this.onPermissionsPressed,
    this.onManageAgentsPressed,
    this.onDeleteRoomPressed,
    this.onKeychainPressed,
    this.onToggleConsolePressed,
    this.onShutdownPressed,
  });

  final String consoleLabel;
  final double width;
  final VoidCallback? onRenamePressed;
  final VoidCallback? onPermissionsPressed;
  final VoidCallback? onManageAgentsPressed;
  final VoidCallback? onDeleteRoomPressed;
  final VoidCallback? onKeychainPressed;
  final VoidCallback? onToggleConsolePressed;
  final VoidCallback? onShutdownPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: PbMenuCard(
        child: PbMenuList(
          children: [
            PbMenuOption(
              title: 'Rename',
              leadingIconAssetName: 'text-cursor',
              singleLine: true,
              onPressed: onRenamePressed,
            ),
            PbMenuOption(
              title: 'Permissions',
              leadingIconAssetName: 'user-plus',
              singleLine: true,
              onPressed: onPermissionsPressed,
            ),
            PbMenuOption(
              title: 'Manage agents',
              leadingIconAssetName: 'grid-2x2-plus',
              singleLine: true,
              onPressed: onManageAgentsPressed,
            ),
            PbMenuOption(
              title: 'Delete Room',
              leadingIconAssetName: 'trash',
              alert: true,
              singleLine: true,
              onPressed: onDeleteRoomPressed,
            ),
            const PbMenuDivider(),
            PbMenuOption(
              title: 'Keychain',
              leadingIconAssetName: 'key-round',
              singleLine: true,
              onPressed: onKeychainPressed,
            ),
            PbMenuOption(
              title: consoleLabel,
              leadingIconAssetName: 'terminal',
              singleLine: true,
              onPressed: onToggleConsolePressed,
            ),
            PbMenuOption(
              title: 'Shutdown',
              leadingIconAssetName: 'circle-x',
              singleLine: true,
              onPressed: onShutdownPressed,
            ),
          ],
        ),
      ),
    );
  }
}
