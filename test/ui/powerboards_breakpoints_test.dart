import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/ui/powerboards_breakpoints.dart';
import 'package:responsive_framework/responsive_framework.dart';

void main() {
  testWidgets('native mobile platforms keep landscape breakpoint support', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 700);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    late ResponsiveBreakpointsData data;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: powerboardsResponsiveBreakpoints(
          child: Builder(
            builder: (context) {
              data = ResponsiveBreakpoints.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(data.smallerOrEqualTo("chromebook"), isTrue);
    expect(data.isMobile, isFalse);
  });

  testWidgets('non-mobile platforms stay width based in landscape viewports', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 700);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    late ResponsiveBreakpointsData data;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: powerboardsResponsiveBreakpoints(
          child: Builder(
            builder: (context) {
              data = ResponsiveBreakpoints.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(data.smallerOrEqualTo("chromebook"), isFalse);
    expect(data.isMobile, isFalse);
  });
}
