import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_typography.dart';
import '../primitives/pb_avatar_button.dart';
import '../primitives/pb_icon_button.dart';
import '../primitives/pb_svg_icon.dart';
import '../menus/pb_menu_anchor.dart';

enum PbSideRailDestination { recent, chat, files, meet }

class PbSideRail extends StatelessWidget {
  const PbSideRail({
    super.key,
    this.showRecent = true,
    this.selectedDestination = PbSideRailDestination.chat,
    this.onRecentPressed,
    this.onChatPressed,
    this.onFilesPressed,
    this.onMeetPressed,
    this.moreSelected = false,
    this.moreMenu,
    this.onMorePressed,
    this.onMoreDismissRequested,
    this.accountSelected = false,
    this.accountMenu,
    this.onAccountPressed,
    this.onAccountDismissRequested,
  });

  final bool showRecent;
  final PbSideRailDestination selectedDestination;
  final VoidCallback? onRecentPressed;
  final VoidCallback? onChatPressed;
  final VoidCallback? onFilesPressed;
  final VoidCallback? onMeetPressed;
  final bool moreSelected;
  final Widget? moreMenu;
  final VoidCallback? onMorePressed;
  final VoidCallback? onMoreDismissRequested;
  final bool accountSelected;
  final Widget? accountMenu;
  final VoidCallback? onAccountPressed;
  final VoidCallback? onAccountDismissRequested;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth > constraints.maxHeight;
        return Container(
          padding: mobile ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12) : const EdgeInsets.fromLTRB(0, 20, 0, 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [PbColors.surfaceActionPrimary, PbColors.surfaceRail, PbColors.brandInk],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.54, 1.0],
            ),
            border: Border(right: BorderSide(color: Color.fromARGB(15, 255, 255, 255))),
          ),
          child: mobile
              ? _MobileRail(
                  showRecent: showRecent,
                  selectedDestination: selectedDestination,
                  onRecentPressed: onRecentPressed,
                  onChatPressed: onChatPressed,
                  onFilesPressed: onFilesPressed,
                  onMeetPressed: onMeetPressed,
                  moreSelected: moreSelected,
                  moreMenu: moreMenu,
                  onMorePressed: onMorePressed,
                  onMoreDismissRequested: onMoreDismissRequested,
                  accountSelected: accountSelected,
                  accountMenu: accountMenu,
                  onAccountPressed: onAccountPressed,
                  onAccountDismissRequested: onAccountDismissRequested,
                )
              : _DesktopRail(
                  showRecent: showRecent,
                  selectedDestination: selectedDestination,
                  onRecentPressed: onRecentPressed,
                  onChatPressed: onChatPressed,
                  onFilesPressed: onFilesPressed,
                  onMeetPressed: onMeetPressed,
                  moreSelected: moreSelected,
                  moreMenu: moreMenu,
                  onMorePressed: onMorePressed,
                  onMoreDismissRequested: onMoreDismissRequested,
                ),
        );
      },
    );
  }
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({
    required this.showRecent,
    required this.selectedDestination,
    required this.onRecentPressed,
    required this.onChatPressed,
    required this.onFilesPressed,
    required this.onMeetPressed,
    required this.moreSelected,
    required this.moreMenu,
    required this.onMorePressed,
    required this.onMoreDismissRequested,
  });

  final bool showRecent;
  final PbSideRailDestination selectedDestination;
  final VoidCallback? onRecentPressed;
  final VoidCallback? onChatPressed;
  final VoidCallback? onFilesPressed;
  final VoidCallback? onMeetPressed;
  final bool moreSelected;
  final Widget? moreMenu;
  final VoidCallback? onMorePressed;
  final VoidCallback? onMoreDismissRequested;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _BrandMark(size: 36),
        const SizedBox(height: 38),
        _RailNav(
          vertical: true,
          showLabels: true,
          showRecent: showRecent,
          selectedDestination: selectedDestination,
          onRecentPressed: onRecentPressed,
          onChatPressed: onChatPressed,
          onFilesPressed: onFilesPressed,
          onMeetPressed: onMeetPressed,
          moreSelected: moreSelected,
          moreMenu: moreMenu,
          onMorePressed: onMorePressed,
          onMoreDismissRequested: onMoreDismissRequested,
        ),
      ],
    );
  }
}

class _MobileRail extends StatelessWidget {
  static const double _sideSlotWidth = 68;

  const _MobileRail({
    required this.showRecent,
    required this.selectedDestination,
    required this.onRecentPressed,
    required this.onChatPressed,
    required this.onFilesPressed,
    required this.onMeetPressed,
    required this.moreSelected,
    required this.moreMenu,
    required this.onMorePressed,
    required this.onMoreDismissRequested,
    required this.accountSelected,
    required this.accountMenu,
    required this.onAccountPressed,
    required this.onAccountDismissRequested,
  });

  final bool showRecent;
  final PbSideRailDestination selectedDestination;
  final VoidCallback? onRecentPressed;
  final VoidCallback? onChatPressed;
  final VoidCallback? onFilesPressed;
  final VoidCallback? onMeetPressed;
  final bool moreSelected;
  final Widget? moreMenu;
  final VoidCallback? onMorePressed;
  final VoidCallback? onMoreDismissRequested;
  final bool accountSelected;
  final Widget? accountMenu;
  final VoidCallback? onAccountPressed;
  final VoidCallback? onAccountDismissRequested;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: _sideSlotWidth,
          child: Align(alignment: Alignment.centerLeft, child: _BrandMark(size: 48)),
        ),
        Expanded(
          child: _RailNav(
            vertical: false,
            showLabels: false,
            showRecent: showRecent,
            selectedDestination: selectedDestination,
            onRecentPressed: onRecentPressed,
            onChatPressed: onChatPressed,
            onFilesPressed: onFilesPressed,
            onMeetPressed: onMeetPressed,
            moreSelected: moreSelected,
            moreMenu: moreMenu,
            onMorePressed: onMorePressed,
            onMoreDismissRequested: onMoreDismissRequested,
          ),
        ),
        SizedBox(
          width: _sideSlotWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: PbMenuAnchor(
              placement: PbMenuAnchorPlacement.bottomRight,
              gap: 10,
              triggerHeight: 48,
              panel: accountMenu,
              onDismissRequested: onAccountDismissRequested,
              child: PbAvatarButton(
                initials: 'JP',
                avatarSize: 48,
                selected: accountSelected,
                idleBorderColor: const Color.fromARGB(56, 248, 250, 252),
                chevronColor: const Color.fromARGB(209, 248, 250, 252),
                onPressed: onAccountPressed,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  static const double _logoWidth = 19;
  static const double _logoHeight = 22.35;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: PbSvgIcon(assetName: 'powerboards-symbol-logo', width: _logoWidth, height: _logoHeight, color: PbColors.textInverse),
      ),
    );
  }
}

class _RailNav extends StatelessWidget {
  const _RailNav({
    required this.vertical,
    required this.showLabels,
    required this.showRecent,
    required this.selectedDestination,
    this.onRecentPressed,
    this.onChatPressed,
    this.onFilesPressed,
    this.onMeetPressed,
    this.moreSelected = false,
    this.moreMenu,
    this.onMorePressed,
    this.onMoreDismissRequested,
  });

  final bool vertical;
  final bool showLabels;
  final bool showRecent;
  final PbSideRailDestination selectedDestination;
  final VoidCallback? onRecentPressed;
  final VoidCallback? onChatPressed;
  final VoidCallback? onFilesPressed;
  final VoidCallback? onMeetPressed;
  final bool moreSelected;
  final Widget? moreMenu;
  final VoidCallback? onMorePressed;
  final VoidCallback? onMoreDismissRequested;

  @override
  Widget build(BuildContext context) {
    final items = <_RailItemData>[
      if (showRecent)
        _RailItemData(
          label: 'Recent',
          iconAssetName: 'history',
          destination: PbSideRailDestination.recent,
          active: selectedDestination == PbSideRailDestination.recent,
          onPressed: onRecentPressed,
        ),
      _RailItemData(
        label: 'Chat',
        iconAssetName: 'messages-square',
        destination: PbSideRailDestination.chat,
        active: selectedDestination == PbSideRailDestination.chat,
        onPressed: onChatPressed,
      ),
      _RailItemData(
        label: 'Files',
        iconAssetName: 'folder',
        destination: PbSideRailDestination.files,
        active: selectedDestination == PbSideRailDestination.files,
        onPressed: onFilesPressed,
      ),
      _RailItemData(
        label: 'Meet',
        iconAssetName: 'video',
        destination: PbSideRailDestination.meet,
        active: selectedDestination == PbSideRailDestination.meet,
        onPressed: onMeetPressed,
      ),
      _RailItemData(label: 'More', iconAssetName: 'ellipsis', active: false, menuOpen: moreSelected, onPressed: onMorePressed),
    ];

    final children = items
        .map(
          (item) => _RailItem(
            label: item.label,
            iconAssetName: item.iconAssetName,
            active: item.active,
            showLabel: showLabels,
            menuOpen: item.menuOpen,
            menuPanel: item.label == 'More' ? moreMenu : null,
            onPressed: item.onPressed,
            onDismissRequested: item.label == 'More' ? onMoreDismissRequested : null,
            menuGap: item.label == 'More' && !vertical ? 12 : 4,
            menuPlacement: vertical ? PbMenuAnchorPlacement.rightTop : PbMenuAnchorPlacement.bottomRight,
          ),
        )
        .toList();

    return vertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[children[i], if (i != children.length - 1) const SizedBox(height: 18)],
            ],
          )
        : Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < children.length; i++) ...[children[i], if (i != children.length - 1) const SizedBox(width: 8)],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.label,
    required this.iconAssetName,
    required this.active,
    required this.showLabel,
    this.menuOpen = false,
    this.menuPanel,
    this.onPressed,
    this.onDismissRequested,
    this.menuGap = 4,
    this.menuPlacement = PbMenuAnchorPlacement.rightTop,
  });

  final String label;
  final String iconAssetName;
  final bool active;
  final bool showLabel;
  final bool menuOpen;
  final Widget? menuPanel;
  final VoidCallback? onPressed;
  final VoidCallback? onDismissRequested;
  final double menuGap;
  final PbMenuAnchorPlacement menuPlacement;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PbMenuAnchor(
          placement: menuPlacement,
          gap: menuGap,
          triggerWidth: 44,
          panel: menuPanel,
          onDismissRequested: onDismissRequested,
          child: PbIconButton(
            iconAssetName: iconAssetName,
            variant: active ? PbRailIconButtonVariant.selected : PbRailIconButtonVariant.outlineInverse,
            menuOpen: menuOpen,
            onPressed: onPressed,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Text(label, style: PowerboardsTypography.railLabel.copyWith(color: active ? PbColors.textInverse : const Color(0xBDF8FAFC))),
        ],
      ],
    );
  }
}

class _RailItemData {
  const _RailItemData({
    required this.label,
    required this.iconAssetName,
    required this.active,
    this.destination,
    this.menuOpen = false,
    this.onPressed,
  });

  final String label;
  final String iconAssetName;
  final bool active;
  final PbSideRailDestination? destination;
  final bool menuOpen;
  final VoidCallback? onPressed;
}
