import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_typography.dart';
import '../primitives/pb_avatar.dart';
import 'pb_menu_card.dart';
import 'pb_menu_list.dart';

final TextStyle _kPresenceAvatarTextStyle = PowerboardsTypography.badge.copyWith(
  color: PbColors.surfaceRailActive,
  fontWeight: FontWeight.w800,
);

String pbPresenceInitialsFromDisplayName(String displayName) {
  final trimmed = displayName.trim();
  if (trimmed.isEmpty) {
    return 'U';
  }

  final parts = trimmed.split(RegExp(r'[-._ ]+')).where((part) => part.isNotEmpty).toList(growable: false);
  if (parts.length >= 2) {
    return '${parts[0].characters.first}${parts[1].characters.first}'.toUpperCase();
  }

  return parts.first.characters.first.toUpperCase();
}

class PbPresenceMember {
  const PbPresenceMember({required this.displayName, required this.initials});

  final String displayName;
  final String initials;
}

class PbPresenceAvatar extends StatelessWidget {
  const PbPresenceAvatar({
    super.key,
    required this.initials,
    this.size = 40,
    this.boxShadow,
    this.textStyle,
    this.textOffset = Offset.zero,
  });

  final String initials;
  final double size;
  final List<BoxShadow>? boxShadow;
  final TextStyle? textStyle;
  final Offset textOffset;

  @override
  Widget build(BuildContext context) {
    final resolvedTextStyle =
        textStyle ??
        (size <= 26
            ? PowerboardsTypography.customAvatarInitials.copyWith(
                fontSize: 9.5,
                height: 1,
                fontWeight: FontWeight.w700,
                color: PbColors.surfaceRailActive,
              )
            : _kPresenceAvatarTextStyle);

    return PbAvatar(
      initials: initials,
      size: size,
      borderColor: PbColors.borderStateSelected,
      boxShadow: boxShadow,
      textStyle: resolvedTextStyle,
      textOffset: textOffset,
      backgroundColor: const LinearGradient(
        colors: [PbColors.surfaceAccentSoft, PbColors.surfaceAccentSoft],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
  }
}

class PbPresenceMemberList extends StatelessWidget {
  const PbPresenceMemberList({super.key, required this.members, this.avatarSize = 26});

  final List<PbPresenceMember> members;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return PbMenuList(
      gap: 8,
      children: [for (final member in members) _PbPresenceMemberRow(member: member, avatarSize: avatarSize)],
    );
  }
}

class PbPeopleHereMenu extends StatelessWidget {
  const PbPeopleHereMenu({super.key, required this.members, this.title = 'People here right now', this.minWidth = 240});

  final List<PbPresenceMember> members;
  final String title;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: minWidth,
      child: PbMenuCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: PbColors.statusOnline),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      style: PowerboardsTypography.textXSmall.copyWith(fontWeight: FontWeight.w500, color: PbColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PbPresenceMemberList(members: members),
            ],
          ),
        ),
      ),
    );
  }
}

class _PbPresenceMemberRow extends StatelessWidget {
  const _PbPresenceMemberRow({required this.member, required this.avatarSize});

  final PbPresenceMember member;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          PbPresenceAvatar(initials: member.initials, size: avatarSize, textOffset: const Offset(0, 0.25)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(member.displayName, style: PowerboardsTypography.labelSmall.copyWith(color: PbColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
