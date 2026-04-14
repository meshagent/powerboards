import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/ui/powerboards_adaptive_input.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  group('PowerboardsAdaptiveInput', () {
    testWidgets('does not install adaptive text-menu overrides on desktop platforms', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(
          ShadApp(
            home: Scaffold(body: PowerboardsAdaptiveInput(placeholder: const Text('Type here'))),
          ),
        );

        final input = tester.widget<PowerboardsAdaptiveInput>(find.byType(PowerboardsAdaptiveInput));
        expect(input.contextMenuBuilder, isNull);
        expect(input.onPressedOutside, isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('installs adaptive text-menu overrides on native mobile platforms', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          ShadApp(
            home: Scaffold(body: PowerboardsAdaptiveInput(placeholder: const Text('Type here'))),
          ),
        );

        final input = tester.widget<PowerboardsAdaptiveInput>(find.byType(PowerboardsAdaptiveInput));
        expect(input.contextMenuBuilder, isNotNull);
        expect(input.onPressedOutside, isNotNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
