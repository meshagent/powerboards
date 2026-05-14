import 'package:flutter/material.dart';
import 'package:meshagent_flutter_desktop_updater/meshagent_flutter_desktop_updater.dart';
import 'package:powerboards/theme/theme.dart';

const _style = DesktopUpdateRestartBannerStyle(
  bannerBackground: Color(0xFF3A3A41),
  bannerBorder: Color(0xFF52525A),
  bannerMutedForeground: Color(0xFFD4D4D4),
  bannerControlHover: Color(0xFF474750),
  restartButtonForeground: Color(0xFF24242A),
  restartButtonHoverBackground: Color(0xFFE5E5E5),
  boxShadow: [BoxShadow(color: Color(0x44000000), blurRadius: 10, offset: Offset(0, 2))],
);

class PowerboardsDesktopUpdateBanner extends StatelessWidget {
  const PowerboardsDesktopUpdateBanner({super.key, required this.controller, required this.child});

  final DesktopUpdateController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DesktopUpdateRestartBanner(
      controller: controller,
      style: _style,
      textStyleBuilder: ({required color, required fontSize, required fontWeight}) {
        return powerboardsInterTextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color);
      },
      child: child,
    );
  }
}
