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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final switcherGap = shellIconOnly ? 8.0 : 12.0;
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
                    PbMenuAnchor(
                      panel: projectMenu,
                      onDismissRequested: onProjectDismissRequested,
                      child: PbSwitcherField(
                        eyebrow: 'Project',
                        value: projectValue,
                        selected: projectSelected,
                        onPressed: onProjectPressed,
                      ),
                    ),
                    const SizedBox(height: 12),
                    PbMenuAnchor(
                      panel: roomMenu,
                      onDismissRequested: onRoomDismissRequested,
                      child: PbSwitcherField(eyebrow: 'Room', value: roomValue, selected: roomSelected, onPressed: onRoomPressed),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _SwitcherRow(
                      gap: switcherGap,
                      showRoomSwitcher: showRoomSwitcher,
                      projectValue: projectValue,
                      roomValue: roomValue,
                      projectSelected: projectSelected,
                      roomSelected: roomSelected,
                      projectMenu: projectMenu,
                      roomMenu: roomMenu,
                      onProjectPressed: onProjectPressed,
                      onRoomPressed: onRoomPressed,
                      onProjectDismissRequested: onProjectDismissRequested,
                      onRoomDismissRequested: onRoomDismissRequested,
                    ),
                    const Spacer(),
                    trailingActions ??
                        Row(
                          children: [
                            PbButton(iconAssetName: 'user-plus', label: 'Share', variant: PbButtonVariant.primary, iconOnly: shellIconOnly),
                            SizedBox(width: actionGap),
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

class _SwitcherRow extends StatelessWidget {
  const _SwitcherRow({
    required this.gap,
    required this.showRoomSwitcher,
    required this.projectValue,
    required this.roomValue,
    required this.projectSelected,
    required this.roomSelected,
    this.projectMenu,
    this.roomMenu,
    this.onProjectPressed,
    this.onRoomPressed,
    this.onProjectDismissRequested,
    this.onRoomDismissRequested,
  });

  final double gap;
  final bool showRoomSwitcher;
  final String projectValue;
  final String roomValue;
  final bool projectSelected;
  final bool roomSelected;
  final Widget? projectMenu;
  final Widget? roomMenu;
  final VoidCallback? onProjectPressed;
  final VoidCallback? onRoomPressed;
  final VoidCallback? onProjectDismissRequested;
  final VoidCallback? onRoomDismissRequested;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 196,
          child: PbMenuAnchor(
            panel: projectMenu,
            onDismissRequested: onProjectDismissRequested,
            child: PbSwitcherField(eyebrow: 'Project', value: projectValue, selected: projectSelected, onPressed: onProjectPressed),
          ),
        ),
        if (showRoomSwitcher) ...[
          SizedBox(width: gap),
          SizedBox(
            width: 196,
            child: PbMenuAnchor(
              panel: roomMenu,
              onDismissRequested: onRoomDismissRequested,
              child: PbSwitcherField(eyebrow: 'Room', value: roomValue, selected: roomSelected, onPressed: onRoomPressed),
            ),
          ),
        ],
      ],
    );
  }
}
