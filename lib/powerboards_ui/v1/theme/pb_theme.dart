import 'package:flutter/material.dart';

import 'pb_colors.dart';

ThemeData pbTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: PbColors.surfaceApp,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.light(
      primary: PbColors.surfaceRailSelected,
      surface: PbColors.surfacePanel,
      onSurface: PbColors.textPrimary,
    ),
  );
}
