import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_progress_bar.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_tokens.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_typography.dart';
import 'package:powerboards/settings/ui_mode.dart';
import 'package:powerboards/ui/powerboards_breakpoints.dart';
import 'package:powerboards/ui/powerboards_toast_theme.dart';
import 'package:powerboards/ui/powerboards_toasts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  final originalMode = powerboardsUiModeSignal.value;

  tearDown(() {
    powerboardsUiModeSignal.value = originalMode;
  });

  Future<ShadToastTheme?> pumpToastThemeProbe(
    WidgetTester tester, {
    required PowerboardsUiMode mode,
    required Size size,
    required TargetPlatform platform,
    bool destructive = false,
  }) async {
    final previousPlatformOverride = debugDefaultTargetPlatformOverride;
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    debugDefaultTargetPlatformOverride = platform;
    powerboardsUiModeSignal.value = mode;

    late ShadToastTheme? toastTheme;

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: powerboardsResponsiveBreakpoints(
            child: Builder(
              builder: (context) {
                toastTheme = powerboardsToastThemeForContext(context, destructive: destructive);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      return toastTheme;
    } finally {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      debugDefaultTargetPlatformOverride = previousPlatformOverride;
    }
  }

  testWidgets('uses upload-aligned v1 toast styling on desktop preview widths', (tester) async {
    final toastTheme = await pumpToastThemeProbe(
      tester,
      mode: PowerboardsUiMode.v1,
      size: const Size(1440, 960),
      platform: TargetPlatform.macOS,
    );

    expect(toastTheme?.alignment, Alignment.bottomLeft);
    expect(toastTheme?.offset, const Offset(20, 20));
    expect(toastTheme?.backgroundColor, PbColors.surfacePanel);
    expect(toastTheme?.border?.toBorder().top.color, PbColors.menuCardBorder);
    expect(toastTheme?.radius, BorderRadius.circular(PbRadii.large));
    expect(toastTheme?.padding, powerboardsToastPadding);
    expect(toastTheme?.closeIcon, isA<PowerboardsToastCloseButton>());
    expect(toastTheme?.closeIconPosition, powerboardsToastCloseIconPosition);
    expect(toastTheme?.constraints?.minWidth, 380);
    expect(toastTheme?.constraints?.maxWidth, 380);
    expect(toastTheme?.showCloseIconOnlyWhenHovered, isFalse);
    expect(toastTheme?.textDirection, TextDirection.ltr);
    expect(toastTheme?.titleStyle?.fontSize, PowerboardsTypography.label.fontSize);
    expect(toastTheme?.descriptionStyle?.fontSize, PowerboardsTypography.meta.fontSize);
    expect(toastTheme?.titleStyle?.backgroundColor, Colors.transparent);
    expect(toastTheme?.descriptionStyle?.backgroundColor, Colors.transparent);
  });

  testWidgets('shrinks v1 toast width for responsive web preview widths', (tester) async {
    final toastTheme = await pumpToastThemeProbe(
      tester,
      mode: PowerboardsUiMode.v1,
      size: const Size(390, 844),
      platform: TargetPlatform.macOS,
    );

    expect(toastTheme?.alignment, Alignment.bottomLeft);
    expect(toastTheme?.constraints?.minWidth, 350);
    expect(toastTheme?.constraints?.maxWidth, 350);
  });

  testWidgets('uses destructive v1 toast colors for destructive toasts', (tester) async {
    final toastTheme = await pumpToastThemeProbe(
      tester,
      mode: PowerboardsUiMode.v1,
      size: const Size(1440, 960),
      platform: TargetPlatform.macOS,
      destructive: true,
    );

    expect(toastTheme?.backgroundColor, PbColors.surfacePanel);
    expect(toastTheme?.titleStyle?.color, PbColors.alert);
    expect(toastTheme?.descriptionStyle?.color, PbColors.textMuted);
    expect(toastTheme?.titleStyle?.backgroundColor, Colors.transparent);
    expect(toastTheme?.descriptionStyle?.backgroundColor, Colors.transparent);
  });

  test('powerboardsToast separates title and body text', () {
    final toast = powerboardsToast(title: 'Deleted', description: '1 item');
    final title = toast.title as Text;
    final description = toast.description as Padding;
    final descriptionText = description.child as Text;

    expect(title.data, 'Deleted');
    expect(description.padding, const EdgeInsets.only(top: powerboardsToastDescriptionGap));
    expect(descriptionText.data, '1 item');
    expect(toast.padding, powerboardsToastPadding);
    expect(toast.closeIcon, isA<PowerboardsToastCloseButton>());
    expect(toast.closeIconPosition, powerboardsToastCloseIconPosition);
    expect(toast.showCloseIconOnlyWhenHovered, isFalse);
    expect(toast.variant, ShadToastVariant.primary);
  });

  test('powerboardsToast keeps destructive styling on the title variant', () {
    final toast = powerboardsToast(title: 'Device settings', description: 'Microphone access was blocked.', destructive: true);

    expect(toast.variant, ShadToastVariant.destructive);
  });

  testWidgets('toast close button renders without an overlay-backed tooltip context', (tester) async {
    late BuildContext toastContext;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return ShadTheme(
            data: ShadThemeData(),
            child: ShadToaster(
              child: Builder(
                builder: (context) {
                  toastContext = context;
                  return child!;
                },
              ),
            ),
          );
        },
        home: const SizedBox.shrink(),
      ),
    );

    ShadToaster.of(toastContext).show(powerboardsToast(title: 'Website removed', description: 'The website files were kept.'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Website removed'), findsOneWidget);
    expect(find.byTooltip('Close'), findsNothing);
    expect(find.byType(PowerboardsToastCloseButton), findsOneWidget);
  });

  testWidgets('keeps legacy desktop toast theme unchanged', (tester) async {
    final toastTheme = await pumpToastThemeProbe(
      tester,
      mode: PowerboardsUiMode.legacy,
      size: const Size(1440, 960),
      platform: TargetPlatform.macOS,
    );

    expect(toastTheme, isNull);
  });

  testWidgets('room lifecycle toast uses shared v1 progress bar for active deletes', (tester) async {
    late ShadToast toast;

    await tester.pumpWidget(
      MaterialApp(
        home: ShadTheme(
          data: ShadThemeData(),
          child: Builder(
            builder: (context) {
              toast = powerboardsRoomLifecycleToast(context, title: 'Deleting room', description: 'test room', showProgress: true);
              return toast;
            },
          ),
        ),
      ),
    );

    expect(toast.variant, ShadToastVariant.primary);
    expect(find.text('Deleting room'), findsOneWidget);
    expect(find.text('test room'), findsOneWidget);
    expect(find.byType(PbProgressBar), findsOneWidget);
  });

  testWidgets('keeps native mobile adaptive toast styling out of the v1 theme', (tester) async {
    final toastTheme = await pumpToastThemeProbe(
      tester,
      mode: PowerboardsUiMode.v1,
      size: const Size(390, 844),
      platform: TargetPlatform.iOS,
    );

    expect(toastTheme?.alignment, Alignment.topCenter);
    expect(toastTheme?.backgroundColor, isNull);
    expect(toastTheme?.showCloseIconOnlyWhenHovered, isNull);
  });
}
