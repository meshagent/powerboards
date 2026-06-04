import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/settings/ui_mode.dart';
import 'package:powerboards/ui/powerboards_breakpoints.dart';

void main() {
  group('defaultPowerboardsUiModeForPlatform', () {
    test('defaults to the new theme on web', () {
      expect(defaultPowerboardsUiModeForPlatform(isWeb: true), PowerboardsUiMode.v1);
    });

    test('defaults to the old theme off web', () {
      expect(defaultPowerboardsUiModeForPlatform(isWeb: false), PowerboardsUiMode.legacy);
    });
  });

  group('powerboardsUsesDesktopUiPreview', () {
    final originalMode = powerboardsUiModeSignal.value;

    tearDown(() {
      powerboardsUiModeSignal.value = originalMode;
    });

    Future<bool> pumpPreviewFlagProbe(WidgetTester tester, {required Size size, required TargetPlatform platform}) async {
      final previousPlatformOverride = debugDefaultTargetPlatformOverride;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      debugDefaultTargetPlatformOverride = platform;

      late bool usesDesktopUiPreview;
      powerboardsUiModeSignal.value = PowerboardsUiMode.v1;

      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: powerboardsResponsiveBreakpoints(
              child: Builder(
                builder: (context) {
                  usesDesktopUiPreview = powerboardsUsesDesktopUiPreview(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pump();

        return usesDesktopUiPreview;
      } finally {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        debugDefaultTargetPlatformOverride = previousPlatformOverride;
      }
    }

    testWidgets('stays on for narrow desktop widths', (tester) async {
      final usesDesktopUiPreview = await pumpPreviewFlagProbe(tester, size: const Size(390, 844), platform: TargetPlatform.macOS);

      expect(usesDesktopUiPreview, isTrue);
    });

    testWidgets('stays off for narrow native mobile widths', (tester) async {
      final usesDesktopUiPreview = await pumpPreviewFlagProbe(tester, size: const Size(390, 844), platform: TargetPlatform.iOS);

      expect(usesDesktopUiPreview, isFalse);
    });

    testWidgets('turns on for desktop widths', (tester) async {
      final usesDesktopUiPreview = await pumpPreviewFlagProbe(tester, size: const Size(1440, 960), platform: TargetPlatform.macOS);

      expect(usesDesktopUiPreview, isTrue);
    });
  });
}
