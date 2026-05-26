import 'package:flutter/material.dart';
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
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      late bool usesDesktopUiPreview;
      powerboardsUiModeSignal.value = PowerboardsUiMode.v1;

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
    }

    testWidgets('stays off for narrow desktop/mobile-adaptive widths', (tester) async {
      final usesDesktopUiPreview = await pumpPreviewFlagProbe(tester, size: const Size(390, 844), platform: TargetPlatform.macOS);

      expect(usesDesktopUiPreview, isFalse);
    });

    testWidgets('turns on for desktop widths', (tester) async {
      final usesDesktopUiPreview = await pumpPreviewFlagProbe(tester, size: const Size(1440, 960), platform: TargetPlatform.macOS);

      expect(usesDesktopUiPreview, isTrue);
    });
  });
}
