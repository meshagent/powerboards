import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_tokens.dart';
import '../../theme/pb_typography.dart';
import '../menus/pb_people_here_menu.dart';
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
    this.presenceMembers = const [],
    this.presenceSelected = false,
    this.projectMenu,
    this.roomMenu,
    this.presenceMenu,
    this.avatarMenu,
    this.trailingActions,
    this.onProjectPressed,
    this.onRoomPressed,
    this.onAvatarPressed,
    this.onPresencePressed,
    this.onProjectDismissRequested,
    this.onRoomDismissRequested,
    this.onAvatarDismissRequested,
    this.onPresenceDismissRequested,
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
  final List<PbPresenceMember> presenceMembers;
  final bool presenceSelected;
  final Widget? projectMenu;
  final Widget? roomMenu;
  final Widget? presenceMenu;
  final Widget? avatarMenu;
  final Widget? trailingActions;
  final VoidCallback? onProjectPressed;
  final VoidCallback? onRoomPressed;
  final VoidCallback? onAvatarPressed;
  final VoidCallback? onPresencePressed;
  final VoidCallback? onProjectDismissRequested;
  final VoidCallback? onRoomDismissRequested;
  final VoidCallback? onAvatarDismissRequested;
  final VoidCallback? onPresenceDismissRequested;
  final VoidCallback? onSharePressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actionGap = shellIconOnly ? 6.0 : 16.0;
        final shareGap = actionGap * 2;
        final roomMenuGap = shellIconOnly ? 2.0 : 8.0;
        final presenceMenuGap = shellIconOnly ? 14.0 : 18.0;
        final avatarMenuGap = shellIconOnly ? 5.0 : 15.0;

        return Container(
          constraints: const BoxConstraints(minHeight: PbSizes.workspaceTopbarHeight),
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
                        menuGap: roomMenuGap,
                        roomMenu: roomMenu,
                        onRoomPressed: onRoomPressed,
                        onRoomDismissRequested: onRoomDismissRequested,
                      ),
                    const Spacer(),
                    trailingActions ??
                        Row(
                          children: [
                            if (presenceMembers.isNotEmpty) ...[
                              PbMenuAnchor(
                                placement: PbMenuAnchorPlacement.bottomRight,
                                gap: presenceMenuGap,
                                triggerHeight: shellIconOnly ? 40 : 34,
                                panel: presenceMenu,
                                onDismiss: onPresenceDismissRequested,
                                child: _PresenceSummaryButton(
                                  members: presenceMembers,
                                  compact: shellIconOnly,
                                  selected: presenceSelected,
                                  onPressed: onPresencePressed,
                                ),
                              ),
                              SizedBox(width: onSharePressed != null ? shareGap : actionGap),
                            ],
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
                              gap: avatarMenuGap,
                              triggerHeight: shellIconOnly ? 48 : 34,
                              panel: avatarMenu,
                              onDismiss: onAvatarDismissRequested,
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

class _PresenceSummaryButton extends StatefulWidget {
  const _PresenceSummaryButton({required this.members, required this.compact, this.selected = false, this.onPressed});

  final List<PbPresenceMember> members;
  final bool compact;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  State<_PresenceSummaryButton> createState() => _PresenceSummaryButtonState();
}

class _PresenceSummaryButtonState extends State<_PresenceSummaryButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _lifted => _hovered && !_pressed;

  @override
  Widget build(BuildContext context) {
    final previewCount = widget.compact ? 2 : 3;
    final visibleMembers = widget.members.take(previewCount).toList(growable: false);
    final overflowCount = widget.members.length - visibleMembers.length;
    final avatarSize = widget.compact ? 30.0 : 34.0;
    final avatarOverlap = widget.compact ? 8.0 : 10.0;
    final avatarShadow = widget.selected
        ? PbShadows.avatarSelected
        : _pressed
        ? const [BoxShadow(color: Color.fromARGB(214, 199, 216, 255), blurRadius: 0, spreadRadius: 2)]
        : _hovered
        ? PbShadows.stateHover
        : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onPressed?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: Transform.translate(
          offset: Offset(0, _lifted ? -1 : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (visibleMembers.isNotEmpty)
                SizedBox(
                  width: avatarSize + ((visibleMembers.length - 1) * (avatarSize - avatarOverlap)),
                  height: avatarSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var index = 0; index < visibleMembers.length; index++)
                        Positioned(
                          left: index * (avatarSize - avatarOverlap),
                          child: PbPresenceAvatar(initials: visibleMembers[index].initials, size: avatarSize, boxShadow: avatarShadow),
                        ),
                    ],
                  ),
                ),
              if (overflowCount > 0) ...[
                SizedBox(width: widget.compact ? 8 : 10),
                Text(
                  '+$overflowCount',
                  style: PowerboardsTypography.badge.copyWith(color: PbColors.surfaceRailActive, fontWeight: FontWeight.w800),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomSwitcher extends StatelessWidget {
  const _RoomSwitcher({
    required this.roomValue,
    required this.roomSelected,
    required this.menuGap,
    this.roomMenu,
    this.onRoomPressed,
    this.onRoomDismissRequested,
  });

  final String roomValue;
  final bool roomSelected;
  final double menuGap;
  final Widget? roomMenu;
  final VoidCallback? onRoomPressed;
  final VoidCallback? onRoomDismissRequested;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      child: PbMenuAnchor(
        gap: menuGap,
        panel: roomMenu,
        onDismiss: onRoomDismissRequested,
        child: PbSwitcherField(eyebrow: 'Room', value: roomValue, selected: roomSelected, onPressed: onRoomPressed),
      ),
    );
  }
}
