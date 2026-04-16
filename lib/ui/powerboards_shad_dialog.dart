import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/theme/theme.dart';

const double powerboardsCompactDesktopDialogWidth = 360;
const BoxConstraints powerboardsCompactDesktopDialogConstraints = BoxConstraints(maxWidth: powerboardsCompactDesktopDialogWidth);
const double powerboardsMobileDialogEdgeInset = 16;
const double powerboardsDialogScrollViewportVerticalInset = 18;
const EdgeInsets powerboardsDialogScrollViewportPadding = EdgeInsets.symmetric(vertical: powerboardsDialogScrollViewportVerticalInset);
const EdgeInsets powerboardsDialogScrollableListPadding = EdgeInsets.only(bottom: powerboardsDialogScrollViewportVerticalInset);
const double powerboardsMobileFlowDialogContentSectionGap = 12;
const EdgeInsets powerboardsMobileFlowDialogCompactPadding = EdgeInsets.fromLTRB(24, 24, 24, 28);

const double _desktopDialogCloseButtonSize = 32;
const double _desktopDialogCloseIconSize = 24;
const double _desktopDialogCloseButtonTop = 20;
const double _desktopDialogCloseButtonInset = 24;
const double _mobileDialogCloseButtonSize = 40;
const double _mobileDialogCloseIconSize = 24;
const double _mobileDialogCloseButtonTop = 20;
const double _mobileDialogCloseButtonInset = 24;
const double _mobileFullScreenDialogHorizontalPadding = 24;
const double _compactDesktopDialogWidthThreshold = 420;
const double _desktopDialogActionMinWidth = 152;
const double _desktopDialogActionMaxWidth = 220;
const double _mobileFlowDialogTopGap = 20;
const double _mobileLandscapeFlowDialogTopGap = 8;
const double _mobileFlowDialogFloorHeightFactor = 0.34;
const double _mobileFormFlowDialogFloorHeightFactor = 0.22;
const double _mobileFlowDialogCornerRadius = 28;
const double _mobileFlowDialogTopPadding = 30;
const double _mobileLandscapeFlowDialogTopPadding = 24;
const double _mobileFlowDialogBottomPadding = 39;

enum PowerboardsDialogMobilePresentation { inherit, inset, flowSheet, fullScreen }

enum PowerboardsDialogMobileFlowBodyBehavior { inherit, scrollable, formScrollable, fill }

enum PowerboardsDialogMobileKeyboardBehavior { inherit, avoid, ignore }

typedef PowerboardsDialogChrome = ({String signature, List<Widget> actions, VoidCallback? onBack});

class _PowerboardsFlowDialogStepEntry {
  const _PowerboardsFlowDialogStepEntry({required this.builder, this.completer});

  final WidgetBuilder builder;
  final Completer<dynamic>? completer;
}

class _PowerboardsFlowDialogStepScope extends InheritedWidget {
  const _PowerboardsFlowDialogStepScope({required super.child, required this.state, required this.depth});

  final _PowerboardsFlowDialogStepHostState state;
  final int depth;

  static _PowerboardsFlowDialogStepScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_PowerboardsFlowDialogStepScope>();
  }

  Future<T?> pushStep<T>({required WidgetBuilder builder}) {
    return state.pushStep<T>(builder: builder);
  }

  VoidCallback? get defaultBackAction {
    if (depth <= 0) {
      return null;
    }

    return state.popCurrentStep;
  }

  @override
  bool updateShouldNotify(covariant _PowerboardsFlowDialogStepScope oldWidget) {
    return depth != oldWidget.depth || state != oldWidget.state;
  }
}

class _PowerboardsFlowDialogStepHost extends StatefulWidget {
  const _PowerboardsFlowDialogStepHost({required this.builder});

  final WidgetBuilder builder;

  @override
  State<_PowerboardsFlowDialogStepHost> createState() => _PowerboardsFlowDialogStepHostState();
}

class _PowerboardsFlowDialogStepHostState extends State<_PowerboardsFlowDialogStepHost> {
  late final List<_PowerboardsFlowDialogStepEntry> _steps = [_PowerboardsFlowDialogStepEntry(builder: widget.builder)];

  Future<T?> pushStep<T>({required WidgetBuilder builder}) {
    final completer = Completer<dynamic>();
    setState(() {
      _steps.add(_PowerboardsFlowDialogStepEntry(builder: builder, completer: completer));
    });
    return completer.future.then((value) => value as T?);
  }

  void popCurrentStep<T>([T? result]) {
    if (_steps.length <= 1) {
      Navigator.of(context).maybePop(result);
      return;
    }

    final removed = _steps.removeLast();
    if (removed.completer case final completer? when !completer.isCompleted) {
      completer.complete(result);
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final step in _steps.skip(1)) {
      if (step.completer case final completer? when !completer.isCompleted) {
        completer.complete(null);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _steps.last;
    return _PowerboardsFlowDialogStepScope(
      state: this,
      depth: _steps.length - 1,
      child: Builder(builder: currentStep.builder),
    );
  }
}

Future<T?> showPowerboardsFlowDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0xcc000000),
  String barrierLabel = '',
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) async {
  final mediaQuery = MediaQuery.maybeOf(context);
  final screenSize = mediaQuery?.size ?? const Size(1024.0, 768.0);
  final isMobile = _usesNativeMobileDialogLayout(screenSize);

  await dismissBackgroundKeyboardBeforeAdaptiveSurface(context);

  if (!context.mounted) {
    return null;
  }

  if (!isMobile) {
    return showShadDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      anchorPoint: anchorPoint,
    );
  }

  final stepScope = _PowerboardsFlowDialogStepScope.maybeOf(context);
  if (stepScope != null) {
    return stepScope.pushStep<T>(builder: builder);
  }

  return showModalBottomSheet<T>(
    context: context,
    builder: (_) => _PowerboardsFlowDialogStepHost(builder: builder),
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    isDismissible: barrierDismissible,
    enableDrag: true,
    isScrollControlled: true,
    useSafeArea: false,
    requestFocus: false,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
  );
}

Future<T?> showPowerboardsAlertDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0xcc000000),
  String barrierLabel = '',
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) async {
  await dismissBackgroundKeyboardBeforeAdaptiveSurface(context);

  if (!context.mounted) {
    return null;
  }

  return showShadDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
  );
}

Future<void> dismissBackgroundKeyboardBeforeAdaptiveSurface(BuildContext context) async {
  final mediaQuery = MediaQuery.maybeOf(context);
  final screenSize = mediaQuery?.size ?? const Size(1024.0, 768.0);
  final isMobile = _usesNativeMobileDialogLayout(screenSize);

  if (isMobile) {
    await _dismissBackgroundKeyboardBeforeFlowDialog(context);
  } else {
    FocusManager.instance.primaryFocus?.unfocus();
    await WidgetsBinding.instance.endOfFrame;
  }
}

Future<void> _dismissBackgroundKeyboardBeforeFlowDialog(BuildContext context) async {
  final initialBottomInset = MediaQuery.maybeOf(context)?.viewInsets.bottom ?? 0.0;
  if (initialBottomInset > 0.0) {
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  FocusManager.instance.primaryFocus?.unfocus();
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) {
    return;
  }

  for (var attempt = 0; attempt < 12; attempt++) {
    final bottomInset = MediaQuery.maybeOf(context)?.viewInsets.bottom ?? 0.0;
    if (bottomInset <= 0.0) {
      return;
    }

    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) {
      return;
    }
  }

  if (initialBottomInset > 0.0) {
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
  }
}

class PowerboardsShadDialog extends StatelessWidget {
  const PowerboardsShadDialog({
    super.key,
    this.title,
    this.description,
    this.child,
    this.actions = const [],
    this.closeIcon,
    this.closeIconData,
    this.closeIconPosition,
    this.radius,
    this.backgroundColor,
    this.expandActionsWhenTiny,
    this.padding,
    this.gap,
    this.constraints,
    this.border,
    this.shadows,
    this.removeBorderRadiusWhenTiny,
    this.actionsAxis,
    this.actionsMainAxisSize,
    this.actionsMainAxisAlignment,
    this.actionsVerticalDirection,
    this.titleStyle,
    this.descriptionStyle,
    this.titleTextAlign,
    this.descriptionTextAlign,
    this.alignment,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.scrollable,
    this.scrollPadding,
    this.actionsGap,
    this.useSafeArea,
    this.titlePinned,
    this.descriptionPinned,
    this.actionsPinned,
    this.expandDesktopActions,
    this.mobilePresentation = PowerboardsDialogMobilePresentation.inherit,
    this.mobileFlowBodyBehavior = PowerboardsDialogMobileFlowBodyBehavior.inherit,
    this.mobileKeyboardBehavior = PowerboardsDialogMobileKeyboardBehavior.inherit,
    this.stackActionsOnMobile = false,
    this.onBack,
  }) : variant = ShadDialogVariant.primary;

  const PowerboardsShadDialog.compact({
    super.key,
    this.title,
    this.description,
    this.child,
    this.actions = const [],
    this.closeIcon,
    this.closeIconData,
    this.closeIconPosition,
    this.radius,
    this.backgroundColor,
    this.expandActionsWhenTiny,
    this.padding,
    this.gap,
    this.constraints = powerboardsCompactDesktopDialogConstraints,
    this.border,
    this.shadows,
    this.removeBorderRadiusWhenTiny,
    this.actionsAxis,
    this.actionsMainAxisSize,
    this.actionsMainAxisAlignment,
    this.actionsVerticalDirection,
    this.titleStyle,
    this.descriptionStyle,
    this.titleTextAlign,
    this.descriptionTextAlign,
    this.alignment,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.scrollable,
    this.scrollPadding,
    this.actionsGap,
    this.useSafeArea = false,
    this.titlePinned,
    this.descriptionPinned,
    this.actionsPinned,
    this.expandDesktopActions,
    this.mobilePresentation = PowerboardsDialogMobilePresentation.inset,
    this.mobileFlowBodyBehavior = PowerboardsDialogMobileFlowBodyBehavior.inherit,
    this.mobileKeyboardBehavior = PowerboardsDialogMobileKeyboardBehavior.inherit,
    this.stackActionsOnMobile = true,
    this.onBack,
  }) : variant = ShadDialogVariant.primary;

  const PowerboardsShadDialog.listPicker({
    super.key,
    this.title,
    this.description,
    this.child,
    this.actions = const [],
    this.closeIcon,
    this.closeIconData,
    this.closeIconPosition,
    this.radius,
    this.backgroundColor,
    this.expandActionsWhenTiny,
    this.padding,
    this.gap,
    this.constraints = powerboardsCompactDesktopDialogConstraints,
    this.border,
    this.shadows,
    this.removeBorderRadiusWhenTiny,
    this.actionsAxis,
    this.actionsMainAxisSize,
    this.actionsMainAxisAlignment,
    this.actionsVerticalDirection,
    this.titleStyle,
    this.descriptionStyle,
    this.titleTextAlign,
    this.descriptionTextAlign,
    this.alignment,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.scrollable,
    this.scrollPadding,
    this.actionsGap,
    this.useSafeArea = false,
    this.titlePinned,
    this.descriptionPinned,
    this.actionsPinned,
    this.expandDesktopActions,
    this.mobilePresentation = PowerboardsDialogMobilePresentation.flowSheet,
    this.mobileFlowBodyBehavior = PowerboardsDialogMobileFlowBodyBehavior.scrollable,
    this.mobileKeyboardBehavior = PowerboardsDialogMobileKeyboardBehavior.ignore,
    this.stackActionsOnMobile = true,
    this.onBack,
  }) : variant = ShadDialogVariant.primary;

  const PowerboardsShadDialog.alert({
    super.key,
    this.title,
    this.description,
    this.child,
    this.actions = const [],
    this.closeIcon,
    this.closeIconData,
    this.closeIconPosition,
    this.radius,
    this.backgroundColor,
    this.expandActionsWhenTiny,
    this.padding,
    this.gap,
    this.constraints,
    this.border,
    this.shadows,
    this.removeBorderRadiusWhenTiny,
    this.actionsAxis,
    this.actionsMainAxisSize,
    this.actionsMainAxisAlignment,
    this.actionsVerticalDirection,
    this.titleStyle,
    this.descriptionStyle,
    this.titleTextAlign,
    this.descriptionTextAlign,
    this.alignment,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.scrollable,
    this.scrollPadding,
    this.actionsGap,
    this.useSafeArea,
    this.titlePinned,
    this.descriptionPinned,
    this.actionsPinned,
    this.expandDesktopActions,
    this.mobilePresentation = PowerboardsDialogMobilePresentation.inherit,
    this.mobileFlowBodyBehavior = PowerboardsDialogMobileFlowBodyBehavior.inherit,
    this.mobileKeyboardBehavior = PowerboardsDialogMobileKeyboardBehavior.inherit,
    this.stackActionsOnMobile = false,
    this.onBack,
  }) : variant = ShadDialogVariant.alert;

  const PowerboardsShadDialog.compactAlert({
    super.key,
    this.title,
    this.description,
    this.child,
    this.actions = const [],
    this.closeIcon,
    this.closeIconData,
    this.closeIconPosition,
    this.radius,
    this.backgroundColor,
    this.expandActionsWhenTiny,
    this.padding,
    this.gap,
    this.constraints = powerboardsCompactDesktopDialogConstraints,
    this.border,
    this.shadows,
    this.removeBorderRadiusWhenTiny,
    this.actionsAxis,
    this.actionsMainAxisSize,
    this.actionsMainAxisAlignment,
    this.actionsVerticalDirection,
    this.titleStyle,
    this.descriptionStyle,
    this.titleTextAlign,
    this.descriptionTextAlign,
    this.alignment,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.scrollable,
    this.scrollPadding,
    this.actionsGap,
    this.useSafeArea = false,
    this.titlePinned,
    this.descriptionPinned,
    this.actionsPinned,
    this.expandDesktopActions,
    this.mobilePresentation = PowerboardsDialogMobilePresentation.inset,
    this.mobileFlowBodyBehavior = PowerboardsDialogMobileFlowBodyBehavior.inherit,
    this.mobileKeyboardBehavior = PowerboardsDialogMobileKeyboardBehavior.inherit,
    this.stackActionsOnMobile = true,
    this.onBack,
  }) : variant = ShadDialogVariant.alert;

  const PowerboardsShadDialog.task({
    super.key,
    this.title,
    this.description,
    this.child,
    this.actions = const [],
    this.closeIcon,
    this.closeIconData,
    this.closeIconPosition,
    this.radius,
    this.backgroundColor,
    this.expandActionsWhenTiny,
    this.padding,
    this.gap,
    this.constraints,
    this.border,
    this.shadows,
    this.removeBorderRadiusWhenTiny,
    this.actionsAxis,
    this.actionsMainAxisSize,
    this.actionsMainAxisAlignment,
    this.actionsVerticalDirection,
    this.titleStyle,
    this.descriptionStyle,
    this.titleTextAlign,
    this.descriptionTextAlign,
    this.alignment,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.scrollable,
    this.scrollPadding,
    this.actionsGap,
    this.useSafeArea = false,
    this.titlePinned,
    this.descriptionPinned,
    this.actionsPinned,
    this.expandDesktopActions = true,
    this.mobilePresentation = PowerboardsDialogMobilePresentation.flowSheet,
    this.mobileFlowBodyBehavior = PowerboardsDialogMobileFlowBodyBehavior.scrollable,
    this.mobileKeyboardBehavior = PowerboardsDialogMobileKeyboardBehavior.avoid,
    this.stackActionsOnMobile = true,
    this.onBack,
  }) : variant = ShadDialogVariant.primary;

  const PowerboardsShadDialog.formTask({
    super.key,
    this.title,
    this.description,
    this.child,
    this.actions = const [],
    this.closeIcon,
    this.closeIconData,
    this.closeIconPosition,
    this.radius,
    this.backgroundColor,
    this.expandActionsWhenTiny,
    this.padding,
    this.gap,
    this.constraints,
    this.border,
    this.shadows,
    this.removeBorderRadiusWhenTiny,
    this.actionsAxis,
    this.actionsMainAxisSize,
    this.actionsMainAxisAlignment,
    this.actionsVerticalDirection,
    this.titleStyle,
    this.descriptionStyle,
    this.titleTextAlign,
    this.descriptionTextAlign,
    this.alignment,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.scrollable,
    this.scrollPadding,
    this.actionsGap,
    this.useSafeArea = false,
    this.titlePinned,
    this.descriptionPinned,
    this.actionsPinned,
    this.expandDesktopActions = true,
    this.mobilePresentation = PowerboardsDialogMobilePresentation.fullScreen,
    this.mobileFlowBodyBehavior = PowerboardsDialogMobileFlowBodyBehavior.formScrollable,
    this.mobileKeyboardBehavior = PowerboardsDialogMobileKeyboardBehavior.ignore,
    this.stackActionsOnMobile = true,
    this.onBack,
  }) : variant = ShadDialogVariant.primary;

  final Widget? title;
  final Widget? description;
  final Widget? child;
  final ShadDialogVariant variant;
  final List<Widget> actions;
  final Widget? closeIcon;
  final IconData? closeIconData;
  final ShadPosition? closeIconPosition;
  final BorderRadius? radius;
  final Color? backgroundColor;
  final bool? expandActionsWhenTiny;
  final EdgeInsetsGeometry? padding;
  final double? gap;
  final BoxConstraints? constraints;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;
  final bool? removeBorderRadiusWhenTiny;
  final Axis? actionsAxis;
  final MainAxisSize? actionsMainAxisSize;
  final MainAxisAlignment? actionsMainAxisAlignment;
  final VerticalDirection? actionsVerticalDirection;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;
  final TextAlign? titleTextAlign;
  final TextAlign? descriptionTextAlign;
  final Alignment? alignment;
  final MainAxisAlignment? mainAxisAlignment;
  final CrossAxisAlignment? crossAxisAlignment;
  final bool? scrollable;
  final EdgeInsetsGeometry? scrollPadding;
  final double? actionsGap;
  final bool? useSafeArea;
  final bool? titlePinned;
  final bool? descriptionPinned;
  final bool? actionsPinned;
  final bool? expandDesktopActions;
  final PowerboardsDialogMobilePresentation mobilePresentation;
  final PowerboardsDialogMobileFlowBodyBehavior mobileFlowBodyBehavior;
  final PowerboardsDialogMobileKeyboardBehavior mobileKeyboardBehavior;
  final bool stackActionsOnMobile;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final mediaQuery = MediaQuery.maybeOf(context);
    final screenSize = mediaQuery?.size ?? const Size(1024.0, 768.0);
    final isMobile = _usesNativeMobileDialogLayout(screenSize);
    final usesMobileFlowPresentation = isMobile && _usesMobileFlowPresentation(mobilePresentation);
    final usesLandscapeMobileFlowPresentation = usesMobileFlowPresentation && _usesLandscapeMobileDialogLayout(screenSize);
    final usesKeyboardAvoidance = _usesMobileFlowKeyboardAvoidance(
      mobileKeyboardBehavior: mobileKeyboardBehavior,
      bodyBehavior: mobileFlowBodyBehavior,
    );
    final rawMobileKeyboardInset = usesMobileFlowPresentation ? (mediaQuery?.viewInsets.bottom ?? 0.0) : 0.0;
    final pinsFooterDuringKeyboard =
        usesMobileFlowPresentation && mobileFlowBodyBehavior == PowerboardsDialogMobileFlowBodyBehavior.formScrollable;
    final mobileKeyboardInset = pinsFooterDuringKeyboard ? rawMobileKeyboardInset : (usesKeyboardAvoidance ? rawMobileKeyboardInset : 0.0);
    final mobileTopInset = usesMobileFlowPresentation
        ? (powerboardsMobileScreenTopInset +
              (usesLandscapeMobileFlowPresentation
                  ? _mobileLandscapeFlowDialogTopGap
                  : powerboardsMobileScreenBottomInset + _mobileFlowDialogTopGap))
        : (isMobile ? powerboardsMobileScreenTopInset : 0.0);
    final mobileBottomInset = usesMobileFlowPresentation
        ? (pinsFooterDuringKeyboard ? 0.0 : mobileKeyboardInset)
        : (isMobile ? powerboardsMobileScreenBottomInset : 0.0);
    final effectiveConstraints = _resolveDialogConstraints(
      constraints,
      screenSize: screenSize,
      isMobile: isMobile,
      mobilePresentation: mobilePresentation,
      bodyBehavior: mobileFlowBodyBehavior,
      mobileTopInset: mobileTopInset,
      mobileBottomInset: mobileBottomInset,
    );
    final effectiveDialogMaxWidth = _dialogMaxWidth(effectiveConstraints, screenSize: screenSize, isMobile: isMobile);
    final isCompactDesktopDialog = !isMobile && effectiveDialogMaxWidth <= _compactDesktopDialogWidthThreshold;

    final effectiveRadius = _resolveDialogRadius(radius, usesMobileFlowPresentation: usesMobileFlowPresentation);
    final effectiveBackgroundColor = _resolveDialogBackgroundColor(
      backgroundColor,
      theme: theme,
      usesMobileFlowPresentation: usesMobileFlowPresentation,
    );
    final effectiveCloseIcon =
        closeIcon ??
        (isMobile ? _PowerboardsMobileDialogCloseButton(iconData: closeIconData) : _PowerboardsDialogCloseButton(iconData: closeIconData));
    final effectiveCloseIconPosition =
        closeIconPosition ??
        (isMobile
            ? const ShadPosition(top: _mobileDialogCloseButtonTop, right: _mobileDialogCloseButtonInset)
            : const ShadPosition(top: _desktopDialogCloseButtonTop, right: _desktopDialogCloseButtonInset));
    final effectiveScrollable = _resolveDialogScrollable(scrollable, usesMobileFlowPresentation: usesMobileFlowPresentation);
    final effectiveUseSafeArea = _resolveDialogUseSafeArea(useSafeArea, usesMobileFlowPresentation: usesMobileFlowPresentation);
    final effectivePadding = _resolveDialogPaddingForSize(
      padding,
      usesMobileFlowPresentation: usesMobileFlowPresentation,
      screenSize: usesMobileFlowPresentation ? screenSize : null,
    );
    final useHorizontalMobileActionRow = _usesHorizontalMobileActionRow(isMobile: isMobile, actions: actions);
    final effectiveActions = _buildDialogActions(
      actions,
      isMobile: isMobile,
      usesHorizontalMobileActionRow: useHorizontalMobileActionRow,
      isCompactDesktopDialog: isCompactDesktopDialog,
      expandDesktopActions: expandDesktopActions ?? false,
      effectiveDialogMaxWidth: effectiveDialogMaxWidth,
      actionsGap: actionsGap ?? 8,
      stackActionsOnMobile: stackActionsOnMobile,
    );
    final effectiveActionsAxis =
        actionsAxis ?? (useHorizontalMobileActionRow ? Axis.horizontal : (isMobile && stackActionsOnMobile ? Axis.vertical : null));
    final effectiveActionsMainAxisSize =
        actionsMainAxisSize ??
        (useHorizontalMobileActionRow
            ? MainAxisSize.max
            : (isMobile && stackActionsOnMobile
                  ? MainAxisSize.max
                  : ((isCompactDesktopDialog || expandDesktopActions == true) ? MainAxisSize.max : MainAxisSize.min)));
    final effectiveActionsMainAxisAlignment =
        actionsMainAxisAlignment ??
        (useHorizontalMobileActionRow
            ? MainAxisAlignment.start
            : (isMobile && stackActionsOnMobile
                  ? MainAxisAlignment.start
                  : ((isCompactDesktopDialog || expandDesktopActions == true) ? MainAxisAlignment.start : MainAxisAlignment.end)));
    final effectiveTitleTextAlign = titleTextAlign ?? TextAlign.left;
    final effectiveDescriptionTextAlign = descriptionTextAlign ?? TextAlign.left;
    final effectiveGap = gap ?? theme.sheetTheme.gap ?? 16.0;
    final effectiveAlignment = alignment ?? (usesMobileFlowPresentation ? Alignment.bottomCenter : null);
    final effectiveActionsPinned = _resolveDialogActionsPinned(actionsPinned, usesMobileFlowPresentation: usesMobileFlowPresentation);
    final effectiveTitle = _resolveDialogTitle(
      context,
      title: title,
      titleStyle: titleStyle,
      closeIconData: closeIconData,
      onBack: onBack,
      usesMobileFlowPresentation: usesMobileFlowPresentation,
    );
    final effectiveFlowDescription = _resolveFlowDialogDescription(
      context,
      description: description,
      descriptionStyle: descriptionStyle,
      descriptionTextAlign: effectiveDescriptionTextAlign,
      usesMobileFlowPresentation: usesMobileFlowPresentation,
      usesLandscapeMobileFlowPresentation: usesLandscapeMobileFlowPresentation,
    );
    final effectiveRemoveBorderRadiusWhenTiny = _resolveRemoveBorderRadiusWhenTiny(
      removeBorderRadiusWhenTiny,
      usesMobileFlowPresentation: usesMobileFlowPresentation,
    );
    final dialog = usesMobileFlowPresentation
        ? _PowerboardsMobileFlowDialogSurface(
            key: key,
            constraints: effectiveConstraints,
            backgroundColor: effectiveBackgroundColor ?? theme.colorScheme.card,
            radius: effectiveRadius ?? const BorderRadius.vertical(top: Radius.circular(_mobileFlowDialogCornerRadius)),
            border: border ?? Border.all(color: theme.colorScheme.border),
            shadows: shadows,
            padding: effectivePadding ?? EdgeInsets.zero,
            title: effectiveTitle,
            description: effectiveFlowDescription,
            body: child,
            actions: effectiveActions,
            gap: effectiveGap,
            actionsGap: actionsGap ?? 8,
            bodyBehavior: mobileFlowBodyBehavior,
            usesHorizontalActionRow: useHorizontalMobileActionRow,
            keyboardInset: mobileKeyboardInset,
          )
        : ShadDialog.raw(
            key: key,
            variant: variant,
            title: effectiveTitle,
            description: description,
            actions: effectiveActions,
            closeIcon: effectiveCloseIcon,
            closeIconData: null,
            closeIconPosition: effectiveCloseIconPosition,
            radius: effectiveRadius,
            backgroundColor: effectiveBackgroundColor,
            expandActionsWhenTiny: expandActionsWhenTiny,
            padding: effectivePadding,
            gap: gap,
            constraints: effectiveConstraints,
            border: border,
            shadows: shadows,
            removeBorderRadiusWhenTiny: effectiveRemoveBorderRadiusWhenTiny,
            actionsAxis: effectiveActionsAxis,
            actionsMainAxisSize: effectiveActionsMainAxisSize,
            actionsMainAxisAlignment: effectiveActionsMainAxisAlignment,
            actionsVerticalDirection: actionsVerticalDirection,
            titleStyle: titleStyle,
            descriptionStyle: descriptionStyle,
            titleTextAlign: effectiveTitleTextAlign,
            descriptionTextAlign: effectiveDescriptionTextAlign,
            alignment: effectiveAlignment,
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            scrollable: effectiveScrollable,
            scrollPadding: scrollPadding,
            actionsGap: actionsGap,
            useSafeArea: effectiveUseSafeArea,
            titlePinned: titlePinned,
            descriptionPinned: descriptionPinned,
            actionsPinned: effectiveActionsPinned,
            child: child,
          );

    final wrappedDialog = usesMobileFlowPresentation && (pinsFooterDuringKeyboard || !usesKeyboardAvoidance)
        ? MediaQuery.removeViewInsets(context: context, removeBottom: true, child: dialog)
        : dialog;

    if (usesMobileFlowPresentation) {
      return wrappedDialog;
    }

    return GestureDetector(onTap: () => FocusManager.instance.primaryFocus?.unfocus(), child: wrappedDialog);
  }
}

bool powerboardsUsesNativeMobileDialogLayout(BuildContext context) {
  final screenSize = MediaQuery.maybeOf(context)?.size ?? const Size(1024.0, 768.0);
  return _usesNativeMobileDialogLayout(screenSize);
}

bool powerboardsUsesLandscapeMobileDialogLayout(BuildContext context) {
  final screenSize = MediaQuery.maybeOf(context)?.size ?? const Size(1024.0, 768.0);
  return _usesLandscapeMobileDialogLayout(screenSize);
}

bool _usesNativeMobileDialogLayout(Size screenSize) {
  if (kIsWeb) {
    return false;
  }

  final isMobilePlatform = switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => false,
  };

  return isMobilePlatform && screenSize.shortestSide < 600;
}

bool _usesLandscapeMobileDialogLayout(Size screenSize) {
  return _usesNativeMobileDialogLayout(screenSize) && screenSize.width > screenSize.height;
}

bool _usesMobileFlowPresentation(PowerboardsDialogMobilePresentation mobilePresentation) {
  return mobilePresentation == PowerboardsDialogMobilePresentation.flowSheet ||
      mobilePresentation == PowerboardsDialogMobilePresentation.fullScreen;
}

bool _usesMobileFlowKeyboardAvoidance({
  required PowerboardsDialogMobileKeyboardBehavior mobileKeyboardBehavior,
  required PowerboardsDialogMobileFlowBodyBehavior bodyBehavior,
}) {
  return switch (mobileKeyboardBehavior) {
    PowerboardsDialogMobileKeyboardBehavior.avoid => true,
    PowerboardsDialogMobileKeyboardBehavior.ignore => false,
    PowerboardsDialogMobileKeyboardBehavior.inherit => bodyBehavior != PowerboardsDialogMobileFlowBodyBehavior.formScrollable,
  };
}

bool? _resolveDialogScrollable(bool? scrollable, {required bool usesMobileFlowPresentation}) {
  if (usesMobileFlowPresentation) {
    return false;
  }

  return scrollable;
}

bool? _resolveDialogUseSafeArea(bool? useSafeArea, {required bool usesMobileFlowPresentation}) {
  if (usesMobileFlowPresentation) {
    return false;
  }

  return useSafeArea;
}

EdgeInsetsGeometry? _resolveDialogPaddingForSize(
  EdgeInsetsGeometry? padding, {
  required bool usesMobileFlowPresentation,
  required Size? screenSize,
}) {
  if (padding != null) {
    return padding;
  }

  if (!usesMobileFlowPresentation) {
    return null;
  }

  final usesLandscapeMobileFlowPresentation = screenSize != null && _usesLandscapeMobileDialogLayout(screenSize);

  return const EdgeInsets.fromLTRB(
    _mobileFullScreenDialogHorizontalPadding,
    0,
    _mobileFullScreenDialogHorizontalPadding,
    _mobileFlowDialogBottomPadding,
  ).copyWith(top: usesLandscapeMobileFlowPresentation ? _mobileLandscapeFlowDialogTopPadding : _mobileFlowDialogTopPadding);
}

BorderRadius? _resolveDialogRadius(BorderRadius? radius, {required bool usesMobileFlowPresentation}) {
  if (radius != null) {
    return radius;
  }

  if (!usesMobileFlowPresentation) {
    return null;
  }

  return const BorderRadius.vertical(top: Radius.circular(_mobileFlowDialogCornerRadius));
}

Color? _resolveDialogBackgroundColor(Color? backgroundColor, {required ShadThemeData theme, required bool usesMobileFlowPresentation}) {
  if (backgroundColor != null) {
    return backgroundColor;
  }

  if (usesMobileFlowPresentation) {
    return theme.colorScheme.card;
  }

  return null;
}

Widget? _resolveDialogTitle(
  BuildContext context, {
  required Widget? title,
  required TextStyle? titleStyle,
  required IconData? closeIconData,
  required VoidCallback? onBack,
  required bool usesMobileFlowPresentation,
}) {
  if (title == null) {
    return null;
  }

  final truncatedTitle = _PowerboardsMobileDialogTruncatedTitle(child: title);

  if (!usesMobileFlowPresentation) {
    return truncatedTitle;
  }

  final theme = ShadTheme.of(context);
  final resolvedTitleStyle = (titleStyle ?? theme.textTheme.large).fallback(color: theme.colorScheme.foreground);
  final stepScope = _PowerboardsFlowDialogStepScope.maybeOf(context);
  final resolvedOnBack = onBack ?? stepScope?.defaultBackAction;

  if (resolvedOnBack == null) {
    return PowerboardsMobileFlowDialogTitleBar(
      title: DefaultTextStyle(style: resolvedTitleStyle, textAlign: TextAlign.left, child: truncatedTitle),
      closeIconData: closeIconData,
    );
  }

  return _PowerboardsMobileFlowDialogHeader(
    title: DefaultTextStyle(style: resolvedTitleStyle, textAlign: TextAlign.center, child: truncatedTitle),
    onBack: resolvedOnBack,
    closeIconData: closeIconData,
  );
}

Widget? _resolveFlowDialogDescription(
  BuildContext context, {
  required Widget? description,
  required TextStyle? descriptionStyle,
  required TextAlign descriptionTextAlign,
  required bool usesMobileFlowPresentation,
  required bool usesLandscapeMobileFlowPresentation,
}) {
  if (!usesMobileFlowPresentation || description == null) {
    return description;
  }

  if (usesLandscapeMobileFlowPresentation) {
    return null;
  }

  final theme = ShadTheme.of(context);
  final resolvedDescriptionStyle = (descriptionStyle ?? theme.textTheme.muted).fallback(color: theme.colorScheme.mutedForeground);

  return DefaultTextStyle(style: resolvedDescriptionStyle, textAlign: descriptionTextAlign, child: description);
}

List<Widget> _buildDialogActions(
  List<Widget> actions, {
  required bool isMobile,
  required bool usesHorizontalMobileActionRow,
  required bool isCompactDesktopDialog,
  required bool expandDesktopActions,
  required double effectiveDialogMaxWidth,
  required double actionsGap,
  required bool stackActionsOnMobile,
}) {
  if (actions.isEmpty) {
    return actions;
  }

  if (isMobile) {
    if (usesHorizontalMobileActionRow) {
      return actions.map((action) => Expanded(child: _wrapDialogAction(action))).toList(growable: false);
    }

    if (!stackActionsOnMobile) {
      return actions.map(_wrapDialogAction).toList(growable: false);
    }

    return actions
        .map((action) => SizedBox(width: double.infinity, height: powerboardsFooterActionButtonHeight, child: action))
        .toList(growable: false);
  }

  if (isCompactDesktopDialog) {
    return actions.map((action) => Expanded(child: _wrapDialogAction(action))).toList(growable: false);
  }

  if (expandDesktopActions) {
    return actions.map((action) => Expanded(child: _wrapDialogAction(action))).toList(growable: false);
  }

  final usableWidth = effectiveDialogMaxWidth - 48 - (actionsGap * (actions.length - 1));
  final actionWidth = (usableWidth / actions.length).clamp(_desktopDialogActionMinWidth, _desktopDialogActionMaxWidth);

  return actions
      .map((action) => SizedBox(width: actionWidth, height: powerboardsFooterActionButtonHeight, child: action))
      .toList(growable: false);
}

Widget _wrapDialogAction(Widget action) {
  final resolvedAction = switch (action) {
    ShadButton button => _copyDialogActionButton(button),
    _ => action,
  };
  return SizedBox(height: powerboardsFooterActionButtonHeight, child: resolvedAction);
}

ShadButton _copyDialogActionButton(ShadButton button) {
  return ShadButton.raw(
    key: button.key,
    variant: button.variant,
    size: button.size,
    leading: button.leading,
    trailing: button.trailing,
    onPressed: button.onPressed,
    cursor: button.cursor,
    width: button.width,
    height: button.height,
    padding: button.padding,
    backgroundColor: button.backgroundColor,
    hoverBackgroundColor: button.hoverBackgroundColor,
    foregroundColor: button.foregroundColor,
    hoverForegroundColor: button.hoverForegroundColor,
    autofocus: button.autofocus,
    focusNode: button.focusNode,
    pressedBackgroundColor: button.pressedBackgroundColor,
    pressedForegroundColor: button.pressedForegroundColor,
    shadows: button.shadows,
    gradient: button.gradient,
    textDecoration: button.textDecoration,
    hoverTextDecoration: button.hoverTextDecoration,
    decoration: button.decoration,
    enabled: button.enabled,
    onLongPress: button.onLongPress,
    statesController: button.statesController,
    mainAxisAlignment: button.mainAxisAlignment,
    crossAxisAlignment: button.crossAxisAlignment,
    hoverStrategies: button.hoverStrategies,
    onHoverChange: button.onHoverChange,
    onTapDown: button.onTapDown,
    onTapUp: button.onTapUp,
    onTapCancel: button.onTapCancel,
    onSecondaryTapDown: button.onSecondaryTapDown,
    onSecondaryTapUp: button.onSecondaryTapUp,
    onSecondaryTapCancel: button.onSecondaryTapCancel,
    onLongPressStart: button.onLongPressStart,
    onLongPressCancel: button.onLongPressCancel,
    onLongPressUp: button.onLongPressUp,
    onLongPressDown: button.onLongPressDown,
    onLongPressEnd: button.onLongPressEnd,
    onDoubleTap: button.onDoubleTap,
    onDoubleTapDown: button.onDoubleTapDown,
    onDoubleTapCancel: button.onDoubleTapCancel,
    longPressDuration: button.longPressDuration,
    textDirection: button.textDirection,
    gap: button.gap,
    onFocusChange: button.onFocusChange,
    expands: button.child != null ? true : button.expands,
    textStyle: button.textStyle,
    canRequestFocus: button.canRequestFocus,
    child: _wrapDialogActionChild(button.child),
  );
}

Widget? _wrapDialogActionChild(Widget? child) {
  if (child == null) {
    return null;
  }

  if (child case final Text text) {
    return _PowerboardsDialogActionText(text: text);
  }

  return _PowerboardsDialogActionLabelDefaults(child: child);
}

class _PowerboardsDialogActionLabelDefaults extends StatelessWidget {
  const _PowerboardsDialogActionLabelDefaults({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, textAlign: TextAlign.center, child: child);
  }
}

class _PowerboardsDialogActionText extends StatelessWidget {
  const _PowerboardsDialogActionText({required this.text});

  final Text text;

  @override
  Widget build(BuildContext context) {
    final inlineSpan = text.textSpan ?? TextSpan(text: text.data);

    return Text.rich(
      inlineSpan,
      key: text.key,
      style: text.style,
      strutStyle: text.strutStyle,
      textAlign: text.textAlign ?? TextAlign.center,
      textDirection: text.textDirection,
      locale: text.locale,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textScaler: text.textScaler,
      maxLines: 1,
      semanticsLabel: text.semanticsLabel,
      textWidthBasis: text.textWidthBasis,
      textHeightBehavior: text.textHeightBehavior,
      selectionColor: text.selectionColor,
    );
  }
}

bool _usesHorizontalMobileActionRow({required bool isMobile, required List<Widget> actions}) {
  return isMobile && actions.isNotEmpty && actions.length <= 2;
}

BoxConstraints? _resolveDialogConstraints(
  BoxConstraints? constraints, {
  required Size screenSize,
  required bool isMobile,
  required PowerboardsDialogMobilePresentation mobilePresentation,
  required PowerboardsDialogMobileFlowBodyBehavior bodyBehavior,
  required double mobileTopInset,
  required double mobileBottomInset,
}) {
  final availableMobileHeight = (screenSize.height - mobileTopInset - mobileBottomInset).clamp(0.0, screenSize.height).toDouble();

  if (isMobile && _usesMobileFlowPresentation(mobilePresentation)) {
    final defaultMinHeight = _mobileFlowDefaultMinHeight(
      mobilePresentation,
      bodyBehavior: bodyBehavior,
      availableHeight: availableMobileHeight,
    );
    final resolvedMinHeight = constraints == null
        ? defaultMinHeight
        : constraints.minHeight.clamp(defaultMinHeight, availableMobileHeight).toDouble();

    return BoxConstraints(
      minWidth: screenSize.width,
      maxWidth: screenSize.width,
      minHeight: resolvedMinHeight,
      maxHeight: availableMobileHeight,
    );
  }

  if (!isMobile) {
    if (constraints == null) {
      return null;
    }

    return _clampToViewport(constraints, maxWidth: _dialogInsetExtent(screenSize.width), maxHeight: _dialogInsetExtent(screenSize.height));
  }

  return _clampToViewport(
    constraints,
    maxWidth: _dialogInsetExtent(screenSize.width),
    maxHeight: _dialogInsetExtent(availableMobileHeight),
  );
}

double _mobileFlowDefaultMinHeight(
  PowerboardsDialogMobilePresentation mobilePresentation, {
  required PowerboardsDialogMobileFlowBodyBehavior bodyBehavior,
  required double availableHeight,
}) {
  if (mobilePresentation == PowerboardsDialogMobilePresentation.fullScreen) {
    return availableHeight;
  }

  if (bodyBehavior == PowerboardsDialogMobileFlowBodyBehavior.formScrollable) {
    return (availableHeight * _mobileFormFlowDialogFloorHeightFactor).clamp(190.0, 280.0).toDouble();
  }

  return (availableHeight * _mobileFlowDialogFloorHeightFactor).clamp(300.0, 380.0).toDouble();
}

BoxConstraints _clampToViewport(BoxConstraints? constraints, {required double maxWidth, required double maxHeight}) {
  final resolvedMaxWidth = constraints == null
      ? maxWidth
      : (constraints.hasBoundedWidth ? constraints.maxWidth.clamp(0.0, maxWidth).toDouble() : maxWidth);
  final resolvedMaxHeight = constraints == null
      ? maxHeight
      : (constraints.hasBoundedHeight ? constraints.maxHeight.clamp(0.0, maxHeight).toDouble() : maxHeight);

  return BoxConstraints(
    minWidth: (constraints?.minWidth ?? 0.0).clamp(0.0, resolvedMaxWidth).toDouble(),
    maxWidth: resolvedMaxWidth,
    minHeight: (constraints?.minHeight ?? 0.0).clamp(0.0, resolvedMaxHeight).toDouble(),
    maxHeight: resolvedMaxHeight,
  );
}

double _dialogMaxWidth(BoxConstraints? constraints, {required Size screenSize, required bool isMobile}) {
  if (constraints != null && constraints.hasBoundedWidth) {
    return constraints.maxWidth;
  }

  return isMobile ? _dialogInsetExtent(screenSize.width) : 512.0;
}

double _dialogInsetExtent(double screenExtent) {
  final availableExtent = screenExtent - (powerboardsMobileDialogEdgeInset * 2);
  return availableExtent > 0 ? availableExtent : screenExtent;
}

bool? _resolveDialogActionsPinned(bool? actionsPinned, {required bool usesMobileFlowPresentation}) {
  if (usesMobileFlowPresentation) {
    return true;
  }

  return actionsPinned;
}

bool? _resolveRemoveBorderRadiusWhenTiny(bool? removeBorderRadiusWhenTiny, {required bool usesMobileFlowPresentation}) {
  if (usesMobileFlowPresentation) {
    return false;
  }

  return removeBorderRadiusWhenTiny;
}

class _PowerboardsDialogCloseButton extends StatelessWidget {
  const _PowerboardsDialogCloseButton({this.iconData});

  final IconData? iconData;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ShadIconButton.ghost(
      onPressed: () => Navigator.of(context).pop(),
      width: _desktopDialogCloseButtonSize,
      height: _desktopDialogCloseButtonSize,
      padding: EdgeInsets.zero,
      foregroundColor: theme.colorScheme.foreground.withValues(alpha: .58),
      hoverBackgroundColor: Colors.transparent,
      hoverForegroundColor: theme.colorScheme.foreground,
      pressedForegroundColor: theme.colorScheme.foreground,
      icon: Icon(iconData ?? LucideIcons.x, size: _desktopDialogCloseIconSize),
    );
  }
}

class _PowerboardsMobileDialogCloseButton extends StatelessWidget {
  const _PowerboardsMobileDialogCloseButton({this.iconData, this.onPressed});

  final IconData? iconData;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ShadIconButton.ghost(
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
      width: _mobileDialogCloseButtonSize,
      height: _mobileDialogCloseButtonSize,
      padding: EdgeInsets.zero,
      foregroundColor: theme.colorScheme.foreground.withValues(alpha: .5),
      hoverBackgroundColor: Colors.transparent,
      hoverForegroundColor: theme.colorScheme.foreground,
      pressedForegroundColor: theme.colorScheme.foreground,
      icon: Icon(iconData ?? LucideIcons.x, size: _mobileDialogCloseIconSize),
    );
  }
}

class _PowerboardsMobileDialogBackButton extends StatelessWidget {
  const _PowerboardsMobileDialogBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ShadIconButton.ghost(
      onPressed: onPressed,
      width: _mobileDialogCloseButtonSize,
      height: _mobileDialogCloseButtonSize,
      padding: EdgeInsets.zero,
      foregroundColor: theme.colorScheme.foreground.withValues(alpha: .72),
      hoverBackgroundColor: Colors.transparent,
      hoverForegroundColor: theme.colorScheme.foreground,
      pressedForegroundColor: theme.colorScheme.foreground,
      icon: const Icon(LucideIcons.chevronLeft, size: _mobileDialogCloseIconSize),
    );
  }
}

class _PowerboardsMobileDialogTruncatedTitle extends StatelessWidget {
  const _PowerboardsMobileDialogTruncatedTitle({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, child: child);
  }
}

class _PowerboardsMobileFlowDialogHeader extends StatelessWidget {
  const _PowerboardsMobileFlowDialogHeader({required this.title, required this.onBack, this.closeIconData});

  final Widget title;
  final VoidCallback onBack;
  final IconData? closeIconData;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _mobileDialogCloseButtonSize,
      child: Row(
        children: [
          _PowerboardsMobileDialogBackButton(onPressed: onBack),
          const SizedBox(width: 8),
          Expanded(child: Center(child: title)),
          const SizedBox(width: 8),
          _PowerboardsMobileDialogCloseButton(iconData: closeIconData),
        ],
      ),
    );
  }
}

class PowerboardsMobileFlowDialogCenteredTitleBar extends StatelessWidget {
  const PowerboardsMobileFlowDialogCenteredTitleBar({super.key, required this.title, this.closeIconData, this.onClose});

  final Widget title;
  final IconData? closeIconData;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _mobileDialogCloseButtonSize,
      child: Row(
        children: [
          const SizedBox(width: _mobileDialogCloseButtonSize),
          const SizedBox(width: 8),
          Expanded(child: Center(child: title)),
          const SizedBox(width: 8),
          _PowerboardsMobileDialogCloseButton(iconData: closeIconData, onPressed: onClose),
        ],
      ),
    );
  }
}

class PowerboardsMobileFlowDialogTitleBar extends StatelessWidget {
  const PowerboardsMobileFlowDialogTitleBar({super.key, required this.title, this.closeIconData, this.onClose});

  final Widget title;
  final IconData? closeIconData;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _mobileDialogCloseButtonSize,
      child: Row(
        children: [
          Expanded(child: title),
          const SizedBox(width: 12),
          _PowerboardsMobileDialogCloseButton(iconData: closeIconData, onPressed: onClose),
        ],
      ),
    );
  }
}

class _PowerboardsMobileFlowDialogFrame extends StatelessWidget {
  const _PowerboardsMobileFlowDialogFrame({
    required this.title,
    required this.description,
    required this.body,
    required this.actions,
    required this.gap,
    required this.actionsGap,
    required this.expandBody,
    required this.usesHorizontalActionRow,
  });

  final Widget? title;
  final Widget? description;
  final Widget? body;
  final List<Widget> actions;
  final double gap;
  final double actionsGap;
  final bool expandBody;
  final bool usesHorizontalActionRow;

  @override
  Widget build(BuildContext context) {
    final headerChildren = <Widget>[if (title != null) title!, if (description != null) description!];
    final headerSection = headerChildren.isEmpty
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _buildVerticalSection(headerChildren, spacing: gap),
          );

    final bodyContent = body ?? const SizedBox.shrink();
    final bodySection = expandBody ? Expanded(child: bodyContent) : bodyContent;
    final actionSection = actions.isEmpty
        ? null
        : usesHorizontalActionRow
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: _buildHorizontalSection(actions, spacing: actionsGap),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _buildVerticalSection(actions, spacing: actionsGap),
          );

    final contentSections = <Widget>[];
    if (headerSection != null) {
      contentSections.add(headerSection);
      contentSections.add(const SizedBox(height: powerboardsMobileFlowDialogContentSectionGap));
    }
    contentSections.add(bodySection);
    if (actionSection != null) {
      contentSections.add(SizedBox(height: gap * 2));
      contentSections.add(actionSection);
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: expandBody ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: contentSections,
      ),
    );
  }

  List<Widget> _buildVerticalSection(List<Widget> children, {required double spacing}) {
    final built = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        built.add(SizedBox(height: spacing));
      }
      built.add(children[i]);
    }
    return built;
  }

  List<Widget> _buildHorizontalSection(List<Widget> children, {required double spacing}) {
    final built = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        built.add(SizedBox(width: spacing));
      }
      built.add(children[i]);
    }
    return built;
  }
}

class _PowerboardsMobileFlowDialogSurface extends StatefulWidget {
  const _PowerboardsMobileFlowDialogSurface({
    super.key,
    required this.constraints,
    required this.backgroundColor,
    required this.radius,
    required this.border,
    required this.shadows,
    required this.padding,
    required this.title,
    required this.description,
    required this.body,
    required this.actions,
    required this.gap,
    required this.actionsGap,
    required this.bodyBehavior,
    required this.usesHorizontalActionRow,
    required this.keyboardInset,
  });

  final BoxConstraints? constraints;
  final Color backgroundColor;
  final BorderRadius radius;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry padding;
  final Widget? title;
  final Widget? description;
  final Widget? body;
  final List<Widget> actions;
  final double gap;
  final double actionsGap;
  final PowerboardsDialogMobileFlowBodyBehavior bodyBehavior;
  final bool usesHorizontalActionRow;
  final double keyboardInset;

  @override
  State<_PowerboardsMobileFlowDialogSurface> createState() => _PowerboardsMobileFlowDialogSurfaceState();
}

class _PowerboardsMobileFlowDialogSurfaceState extends State<_PowerboardsMobileFlowDialogSurface> {
  final _measureKey = GlobalKey();
  final _measureBodyKey = GlobalKey();
  double? _measuredContentHeight;
  double? _measuredBodyHeight;

  void _scheduleMeasurement() {
    if (widget.bodyBehavior == PowerboardsDialogMobileFlowBodyBehavior.fill) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMeasurement();
    });
  }

  void _updateMeasurement() {
    if (!mounted) {
      return;
    }

    final measureContext = _measureKey.currentContext;
    if (measureContext == null) {
      return;
    }

    final renderBox = measureContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }

    final nextContentHeight = renderBox.size.height;
    final nextBodyHeight = _naturalBodyHeightForBehavior();
    if ((_measuredContentHeight == nextContentHeight) && (_measuredBodyHeight == nextBodyHeight)) {
      return;
    }

    setState(() {
      _measuredContentHeight = nextContentHeight;
      _measuredBodyHeight = nextBodyHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    final routeBarrierDismissible = ModalRoute.of(context)?.barrierDismissible ?? true;
    final heightConstraints = widget.constraints ?? const BoxConstraints();
    final hasFixedHeight =
        heightConstraints.hasBoundedHeight && (heightConstraints.maxHeight - heightConstraints.minHeight).abs() < precisionErrorTolerance;
    final requiresMeasurement = widget.bodyBehavior != PowerboardsDialogMobileFlowBodyBehavior.fill && !hasFixedHeight;
    final pinsFooterDuringKeyboard = widget.bodyBehavior == PowerboardsDialogMobileFlowBodyBehavior.formScrollable;
    final surfaceKeyboardInset = pinsFooterDuringKeyboard ? 0.0 : widget.keyboardInset;
    final shouldRelaxClip = pinsFooterDuringKeyboard && widget.keyboardInset > 0;
    if (requiresMeasurement) {
      _scheduleMeasurement();
    }

    final resolvedPadding = widget.padding.resolve(Directionality.of(context));
    final minHeight = heightConstraints.hasBoundedHeight ? heightConstraints.minHeight : 0.0;
    final maxHeight = heightConstraints.hasBoundedHeight ? heightConstraints.maxHeight : double.infinity;
    final measuredHeight = requiresMeasurement
        ? ((_measuredContentHeight ?? (minHeight - resolvedPadding.vertical).clamp(0.0, minHeight).toDouble()) + resolvedPadding.vertical)
        : maxHeight;
    final targetHeight = measuredHeight.clamp(minHeight, maxHeight).toDouble();
    final hideActionsForKeyboard =
        widget.keyboardInset > 0 &&
        (widget.bodyBehavior == PowerboardsDialogMobileFlowBodyBehavior.scrollable ||
            widget.bodyBehavior == PowerboardsDialogMobileFlowBodyBehavior.formScrollable);
    final keyboardLiftOffset = pinsFooterDuringKeyboard && widget.keyboardInset > 0
        ? widget.keyboardInset.clamp(0.0, (maxHeight - targetHeight).clamp(0.0, widget.keyboardInset).toDouble()).toDouble()
        : 0.0;
    final bodyKeyboardInset = pinsFooterDuringKeyboard
        ? (widget.keyboardInset - keyboardLiftOffset).clamp(0.0, widget.keyboardInset).toDouble()
        : widget.keyboardInset;
    final visibleFrame = _PowerboardsMobileFlowDialogFrame(
      title: widget.title,
      description: widget.description,
      body: _buildVisibleBody(keyboardInset: bodyKeyboardInset),
      actions: hideActionsForKeyboard ? const <Widget>[] : widget.actions,
      gap: widget.gap,
      actionsGap: widget.actionsGap,
      expandBody: true,
      usesHorizontalActionRow: widget.usesHorizontalActionRow,
    );
    final provisionalFrame = requiresMeasurement
        ? _PowerboardsMobileFlowDialogFrame(
            title: widget.title,
            description: widget.description,
            body: _buildMeasuredBody(includeMeasureKey: false),
            actions: widget.actions,
            gap: widget.gap,
            actionsGap: widget.actionsGap,
            expandBody: false,
            usesHorizontalActionRow: widget.usesHorizontalActionRow,
          )
        : null;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: pinsFooterDuringKeyboard ? keyboardLiftOffset : surfaceKeyboardInset),
      child: SizedBox.expand(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: routeBarrierDismissible ? () => Navigator.of(context).maybePop() : null,
                child: const SizedBox.expand(),
              ),
            ),
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                if (requiresMeasurement)
                  Offstage(
                    child: IgnorePointer(
                      child: ExcludeFocus(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: widget.constraints?.minWidth ?? 0.0,
                            maxWidth: widget.constraints?.maxWidth ?? double.infinity,
                          ),
                          child: Padding(
                            padding: widget.padding,
                            child: NotificationListener<SizeChangedLayoutNotification>(
                              onNotification: (_) {
                                _scheduleMeasurement();
                                return false;
                              },
                              child: SizeChangedLayoutNotifier(
                                child: KeyedSubtree(
                                  key: _measureKey,
                                  child: _PowerboardsMobileFlowDialogFrame(
                                    title: widget.title,
                                    description: widget.description,
                                    body: _buildMeasuredBody(),
                                    actions: widget.actions,
                                    gap: widget.gap,
                                    actionsGap: widget.actionsGap,
                                    expandBody: false,
                                    usesHorizontalActionRow: widget.usesHorizontalActionRow,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: widget.constraints?.minWidth ?? 0.0,
                    maxWidth: widget.constraints?.maxWidth ?? double.infinity,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: widget.radius,
                      border: widget.border,
                      boxShadow: widget.shadows,
                    ),
                    child: ClipRRect(
                      borderRadius: widget.radius,
                      clipBehavior: shouldRelaxClip ? Clip.none : Clip.antiAlias,
                      child: SizedBox(
                        height: targetHeight,
                        child: Padding(
                          padding: widget.padding,
                          child: !requiresMeasurement || _measuredContentHeight != null
                              ? visibleFrame
                              : SingleChildScrollView(child: provisionalFrame!),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double? _naturalBodyHeightForBehavior() {
    if (widget.body == null) {
      return 0.0;
    }

    switch (widget.bodyBehavior) {
      case PowerboardsDialogMobileFlowBodyBehavior.fill:
        return null;
      case PowerboardsDialogMobileFlowBodyBehavior.inherit:
      case PowerboardsDialogMobileFlowBodyBehavior.scrollable:
      case PowerboardsDialogMobileFlowBodyBehavior.formScrollable:
        final bodyContext = _measureBodyKey.currentContext;
        final renderBox = bodyContext?.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) {
          return null;
        }
        return renderBox.size.height;
    }
  }

  Widget _buildMeasuredBody({bool includeMeasureKey = true}) {
    final body = widget.body;
    if (body == null) {
      return const SizedBox.shrink();
    }

    Widget content = includeMeasureKey ? KeyedSubtree(key: _measureBodyKey, child: body) : body;
    if (widget.bodyBehavior == PowerboardsDialogMobileFlowBodyBehavior.scrollable ||
        widget.bodyBehavior == PowerboardsDialogMobileFlowBodyBehavior.formScrollable) {
      content = Padding(padding: powerboardsDialogScrollableListPadding, child: content);
    }
    return content;
  }

  Widget _buildVisibleBody({required double keyboardInset}) {
    final body = widget.body;
    if (body == null) {
      return const SizedBox.shrink();
    }

    return switch (widget.bodyBehavior) {
      PowerboardsDialogMobileFlowBodyBehavior.inherit => Align(alignment: Alignment.topCenter, child: body),
      PowerboardsDialogMobileFlowBodyBehavior.scrollable => PowerboardsFlowDialogScrollableBody(
        contentHeight: _measuredBodyHeight,
        centerSparseContent: true,
        child: body,
      ),
      PowerboardsDialogMobileFlowBodyBehavior.formScrollable => PowerboardsFlowDialogScrollableBody(
        contentHeight: _measuredBodyHeight,
        centerSparseContent: false,
        keyboardInset: keyboardInset,
        child: body,
      ),
      PowerboardsDialogMobileFlowBodyBehavior.fill => PowerboardsFlowDialogFillBody(child: body),
    };
  }
}

class PowerboardsFlowDialogScrollableBody extends StatelessWidget {
  const PowerboardsFlowDialogScrollableBody({
    super.key,
    required this.child,
    this.padding = powerboardsDialogScrollableListPadding,
    this.maxWidth,
    this.contentHeight,
    this.centerSparseContent = false,
    this.keyboardInset = 0.0,
  });

  final Widget child;
  final EdgeInsets padding;
  final double? maxWidth;
  final double? contentHeight;
  final bool centerSparseContent;
  final double keyboardInset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectivePadding = padding.copyWith(bottom: padding.bottom + keyboardInset);
        final minContentHeight = (constraints.maxHeight - effectivePadding.vertical).clamp(0.0, constraints.maxHeight).toDouble();
        final canScroll = !centerSparseContent || contentHeight == null || contentHeight! > (minContentHeight + 1);
        final shouldCenter = centerSparseContent && contentHeight != null && contentHeight! <= (minContentHeight * 0.45);

        Widget content = child;

        if (maxWidth != null) {
          content = Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: content,
            ),
          );
        }

        return SingleChildScrollView(
          physics: canScroll ? null : const NeverScrollableScrollPhysics(),
          padding: effectivePadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minContentHeight),
            child: Align(alignment: shouldCenter ? Alignment.center : Alignment.topCenter, child: content),
          ),
        );
      },
    );
  }
}

class PowerboardsFlowDialogFillBody extends StatelessWidget {
  const PowerboardsFlowDialogFillBody({
    super.key,
    required this.child,
    this.padding = powerboardsDialogScrollableListPadding,
    this.maxWidth,
  });

  final Widget child;
  final EdgeInsets padding;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = (constraints.maxHeight - padding.vertical).clamp(0.0, constraints.maxHeight).toDouble();

        Widget content = SizedBox(width: double.infinity, height: availableHeight, child: child);

        if (maxWidth != null) {
          content = Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: content,
            ),
          );
        }

        return Padding(padding: padding, child: content);
      },
    );
  }
}
