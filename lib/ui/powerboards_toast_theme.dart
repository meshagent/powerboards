import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../powerboards_ui/v1/theme/pb_colors.dart';
import '../powerboards_ui/v1/theme/pb_tokens.dart';
import '../powerboards_ui/v1/theme/pb_typography.dart';
import '../settings/ui_mode.dart';
import 'powerboards_toasts.dart';

const _powerboardsV1ToastOffset = Offset(20, 20);
const _powerboardsV1ToastMaxWidth = 380.0;
const _powerboardsV1ToastShadows = [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.14), blurRadius: 40, offset: Offset(0, 18))];

bool _isMobileToastLayout(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  final screenWidth = mediaQuery?.size.width ?? 1024.0;
  return screenWidth < 600;
}

ShadToastTheme? powerboardsToastThemeForContext(BuildContext context, {bool destructive = false}) {
  if (powerboardsUsesDesktopUiPreview(context)) {
    return _powerboardsV1ToastTheme(context, destructive: destructive);
  }

  if (!_isMobileToastLayout(context)) {
    return null;
  }

  return const ShadToastTheme(alignment: Alignment.topCenter);
}

ShadToastTheme _powerboardsV1ToastTheme(BuildContext context, {required bool destructive}) {
  final titleColor = destructive ? PbColors.alert : PbColors.textPrimary;
  const descriptionColor = PbColors.textMuted;
  final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? _powerboardsV1ToastMaxWidth;
  final toastWidth = math.min(_powerboardsV1ToastMaxWidth, math.max(0.0, screenWidth - (_powerboardsV1ToastOffset.dx * 2)));

  return ShadToastTheme(
    alignment: Alignment.bottomLeft,
    offset: _powerboardsV1ToastOffset,
    backgroundColor: PbColors.surfacePanel,
    border: ShadBorder.all(color: PbColors.menuCardBorder, width: 1),
    radius: BorderRadius.circular(PbRadii.large),
    shadows: _powerboardsV1ToastShadows,
    padding: powerboardsToastPadding,
    closeIcon: const PowerboardsToastCloseButton(),
    closeIconPosition: powerboardsToastCloseIconPosition,
    constraints: BoxConstraints.tightFor(width: toastWidth),
    textDirection: TextDirection.ltr,
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.start,
    mainAxisSize: MainAxisSize.max,
    showCloseIconOnlyWhenHovered: false,
    titleStyle: PowerboardsTypography.label.copyWith(color: titleColor, backgroundColor: Colors.transparent),
    descriptionStyle: PowerboardsTypography.meta.copyWith(color: descriptionColor, backgroundColor: Colors.transparent),
  );
}
