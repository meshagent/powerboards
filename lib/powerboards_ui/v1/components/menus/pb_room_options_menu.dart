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
    this.showRename = true,
    this.showPermissions = true,
    this.showManageAgents = true,
    this.showDeleteRoom = true,
    this.showKeychain = true,
    this.showConsoleToggle = true,
    this.showShutdown = true,
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
  final bool showRename;
  final bool showPermissions;
  final bool showManageAgents;
  final bool showDeleteRoom;
  final bool showKeychain;
  final bool showConsoleToggle;
  final bool showShutdown;
  final VoidCallback? onRenamePressed;
  final VoidCallback? onPermissionsPressed;
  final VoidCallback? onManageAgentsPressed;
  final VoidCallback? onDeleteRoomPressed;
  final VoidCallback? onKeychainPressed;
  final VoidCallback? onToggleConsolePressed;
  final VoidCallback? onShutdownPressed;

  @override
  Widget build(BuildContext context) {
    final hasPrimaryGroup = showRename || showPermissions || showManageAgents || showDeleteRoom;
    final hasSecondaryGroup = showKeychain || showConsoleToggle || showShutdown;

    return SizedBox(
      width: width,
      child: PbMenuCard(
        child: PbMenuList(
          children: [
            if (showRename)
              PbMenuOption(title: 'Rename', leadingIconAssetName: 'text-cursor', singleLine: true, onPressed: onRenamePressed),
            if (showPermissions)
              PbMenuOption(title: 'Permissions', leadingIconAssetName: 'user-plus', singleLine: true, onPressed: onPermissionsPressed),
            if (showManageAgents)
              PbMenuOption(
                title: 'Manage agents',
                leadingIconAssetName: 'grid-2x2-plus',
                singleLine: true,
                onPressed: onManageAgentsPressed,
              ),
            if (showDeleteRoom)
              PbMenuOption(
                title: 'Delete Room',
                leadingIconAssetName: 'trash',
                alert: true,
                singleLine: true,
                onPressed: onDeleteRoomPressed,
              ),
            if (hasPrimaryGroup && hasSecondaryGroup) const PbMenuDivider(),
            if (showKeychain)
              PbMenuOption(title: 'Keychain', leadingIconAssetName: 'key-round', singleLine: true, onPressed: onKeychainPressed),
            if (showConsoleToggle)
              PbMenuOption(title: consoleLabel, leadingIconAssetName: 'terminal', singleLine: true, onPressed: onToggleConsolePressed),
            if (showShutdown)
              PbMenuOption(title: 'Shutdown', leadingIconAssetName: 'circle-x', singleLine: true, onPressed: onShutdownPressed),
          ],
        ),
      ),
    );
  }
}
