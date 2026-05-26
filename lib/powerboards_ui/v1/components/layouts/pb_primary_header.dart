import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../primitives/pb_avatar_button.dart';
import '../primitives/pb_button.dart';
import '../primitives/pb_switcher_field.dart';
import '../menus/pb_menu_anchor.dart';

class PbPrimaryHeader extends StatelessWidget {
  const PbPrimaryHeader({
    super.key,
    required this.shellMobile,
    required this.shellIconOnly,
    this.showRoomSwitcher = true,
    this.projectValue = 'Project Name',
    this.roomValue = 'Room Name',
    this.projectSelected = false,
    this.roomSelected = false,
    this.avatarSelected = false,
    this.avatarInitials = 'JP',
    this.projectMenu,
    this.roomMenu,
    this.avatarMenu,
    this.trailingActions,
    this.onProjectPressed,
    this.onRoomPressed,
    this.onAvatarPressed,
    this.onProjectDismissRequested,
    this.onRoomDismissRequested,
    this.onAvatarDismissRequested,
    this.onSharePressed,
  });

  final bool shellMobile;
  final bool shellIconOnly;
  final bool showRoomSwitcher;
  final String projectValue;
  final String roomValue;
  final bool projectSelected;
  final bool roomSelected;
  final bool avatarSelected;
  final String avatarInitials;
  final Widget? projectMenu;
  final Widget? roomMenu;
  final Widget? avatarMenu;
  final Widget? trailingActions;
  final VoidCallback? onProjectPressed;
  final VoidCallback? onRoomPressed;
  final VoidCallback? onAvatarPressed;
  final VoidCallback? onProjectDismissRequested;
  final VoidCallback? onRoomDismissRequested;
  final VoidCallback? onAvatarDismissRequested;
  final VoidCallback? onSharePressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actionGap = shellIconOnly ? 6.0 : 16.0;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          decoration: BoxDecoration(
            color: PbColors.surfacePanel.withValues(alpha: 0.86),
            border: const Border(bottom: BorderSide(color: PbColors.borderSoft)),
          ),
          child: shellMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showRoomSwitcher)
                      PbMenuAnchor(
                        panel: roomMenu,
                        onDismissRequested: onRoomDismissRequested,
                        child: PbSwitcherField(eyebrow: 'Room', value: roomValue, selected: roomSelected, onPressed: onRoomPressed),
                      ),
                  ],
                )
              : Row(
                  children: [
                    if (showRoomSwitcher)
                      _RoomSwitcher(
                        roomValue: roomValue,
                        roomSelected: roomSelected,
                        roomMenu: roomMenu,
                        onRoomPressed: onRoomPressed,
                        onRoomDismissRequested: onRoomDismissRequested,
                      ),
                    const Spacer(),
                    trailingActions ??
                        Row(
                          children: [
                            if (onSharePressed != null) ...[
                              PbButton(
                                iconAssetName: 'user-plus',
                                label: 'Share',
                                variant: PbButtonVariant.primary,
                                iconOnly: shellIconOnly,
                                onPressed: onSharePressed,
                              ),
                              SizedBox(width: actionGap),
                            ],
                            PbMenuAnchor(
                              placement: PbMenuAnchorPlacement.bottomRight,
                              gap: shellIconOnly ? 10 : 21,
                              triggerHeight: shellIconOnly ? 48 : 34,
                              panel: avatarMenu,
                              onDismissRequested: onAvatarDismissRequested,
                              child: shellIconOnly
                                  ? PbAvatarButton(
                                      initials: avatarInitials,
                                      avatarSize: 48,
                                      selected: avatarSelected,
                                      onPressed: onAvatarPressed,
                                    )
                                  : PbAvatarButton(
                                      initials: avatarInitials,
                                      avatarSize: 40,
                                      selected: avatarSelected,
                                      onPressed: onAvatarPressed,
                                    ),
                            ),
                          ],
                        ),
                  ],
                ),
        );
      },
    );
  }
}

class _RoomSwitcher extends StatelessWidget {
  const _RoomSwitcher({
    required this.roomValue,
    required this.roomSelected,
    this.roomMenu,
    this.onRoomPressed,
    this.onRoomDismissRequested,
  });

  final String roomValue;
  final bool roomSelected;
  final Widget? roomMenu;
  final VoidCallback? onRoomPressed;
  final VoidCallback? onRoomDismissRequested;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      child: PbMenuAnchor(
        panel: roomMenu,
        onDismissRequested: onRoomDismissRequested,
        child: PbSwitcherField(eyebrow: 'Room', value: roomValue, selected: roomSelected, onPressed: onRoomPressed),
      ),
    );
  }
}
