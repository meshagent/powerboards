import 'package:flutter/material.dart';

import 'pb_colors.dart';

abstract final class PowerboardsTypography {
  static const String fontFamily = 'Inter';

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.16,
    color: PbColors.textPrimary,
  );

  static const TextStyle labelStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.18,
    color: PbColors.textPrimary,
  );

  static const TextStyle buttonPrimary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.14,
    color: PbColors.textInverse,
  );

  static const TextStyle buttonSecondary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.20,
    color: PbColors.textPrimary,
  );

  static const TextStyle fieldEyebrow = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.08,
    color: PbColors.textMuted,
  );

  static const TextStyle fieldValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.18,
    color: PbColors.textPrimary,
  );

  static const TextStyle railLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: Color(0xBDC9D2E1),
  );

  static const TextStyle avatarInitials = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.14,
    color: PbColors.textInverse,
  );

  static const TextStyle menuTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.12,
    color: PbColors.textPrimary,
  );

  static const TextStyle menuSubtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    color: PbColors.textMuted,
  );

  static const TextStyle menuFilterText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.18,
    color: PbColors.textPrimary,
  );

  static const TextStyle menuFilterPlaceholder = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.14,
    color: PbColors.textMuted,
  );
}
