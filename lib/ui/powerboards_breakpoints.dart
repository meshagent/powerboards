import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

const powerboardsBreakpoints = [
  Breakpoint(start: 0, end: 600, name: MOBILE),
  Breakpoint(start: 601, end: 960, name: TABLET),
  Breakpoint(start: 961, end: 1250, name: "chromebook"),
  Breakpoint(start: 961, end: 1920, name: DESKTOP),
  Breakpoint(start: 1921, end: double.infinity, name: '4K'),
];

const powerboardsBreakpointsLandscape = [
  Breakpoint(start: 0, end: 960, name: MOBILE),
  Breakpoint(start: 961, end: 1920, name: TABLET),
  Breakpoint(start: 1366, end: 1600, name: "chromebook"),
  Breakpoint(start: 1601, end: 2560, name: DESKTOP),
  Breakpoint(start: 2561, end: double.infinity, name: '4K'),
];

Widget powerboardsResponsiveBreakpoints({required Widget child}) {
  return ResponsiveBreakpoints.builder(
    breakpoints: powerboardsBreakpoints,
    breakpointsLandscape: powerboardsBreakpointsLandscape,
    landscapePlatforms: kIsWeb ? const <ResponsiveTargetPlatform>[] : null,
    child: child,
  );
}

bool powerboardsIsMobileTargetPlatform(BuildContext context) {
  return switch (Theme.of(context).platform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => false,
  };
}

bool powerboardsIsLandscapePhoneViewport(BuildContext context) {
  if (kIsWeb || !powerboardsIsMobileTargetPlatform(context)) {
    return false;
  }

  final size = MediaQuery.sizeOf(context);
  return size.width > size.height && size.shortestSide < 600;
}
