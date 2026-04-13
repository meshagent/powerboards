import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/theme/theme.dart';

const double powerboardsCompactDesktopDialogWidth = 360;
const BoxConstraints powerboardsCompactDesktopDialogConstraints = BoxConstraints(maxWidth: powerboardsCompactDesktopDialogWidth);
const double powerboardsMobileDialogEdgeInset = 16;
const double powerboardsDialogScrollViewportVerticalInset = 18;
const EdgeInsets powerboardsDialogScrollViewportPadding = EdgeInsets.symmetric(vertical: powerboardsDialogScrollViewportVerticalInset);
const EdgeInsets powerboardsDialogScrollableListPadding = EdgeInsets.only(bottom: powerboardsDialogScrollViewportVerticalInset);

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
const double _mobileFlowDialogFloorHeightFactor = 0.34;
const double _mobileFlowDialogCornerRadius = 28;
const double _mobileFlowDialogTopPadding = 30;
const double _mobileFlowDialogBottomPadding = 39;

enum PowerboardsDialogMobilePresentation { inherit, inset, flowSheet, fullScreen }

enum PowerboardsDialogMobileFlowBodyBehavior { inherit, scrollable, formScrollable, fill }

Future<T?> showPowerboardsFlowDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0xcc000000),
  String barrierLabel = '',
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) {
  final mediaQuery = MediaQuery.maybeOf(context);
  final screenWidth = mediaQuery?.size.width ?? 1024.0;
  final isMobile = _usesNativeMobileDialogLayout(screenWidth);

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

  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    isDismissible: barrierDismissible,
    enableDrag: true,
    isScrollControlled: true,
    useSafeArea: false,
    requestFocus: true,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
  );
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
  final bool stackActionsOnMobile;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final mediaQuery = MediaQuery.maybeOf(context);
    final screenSize = mediaQuery?.size ?? const Size(1024.0, 768.0);
    final isMobile = _usesNativeMobileDialogLayout(screenSize.width);
    final usesMobileFlowPresentation = isMobile && _usesMobileFlowPresentation(mobilePresentation);
    final usesKeyboardAvoidance = _usesMobileFlowKeyboardAvoidance(mobileFlowBodyBehavior);
    final mobileKeyboardInset = usesMobileFlowPresentation && usesKeyboardAvoidance ? (mediaQuery?.viewInsets.bottom ?? 0.0) : 0.0;
    final mobileTopInset = usesMobileFlowPresentation
        ? (powerboardsMobileScreenTopInset + powerboardsMobileScreenBottomInset + _mobileFlowDialogTopGap)
        : (isMobile ? powerboardsMobileScreenTopInset : 0.0);
    final mobileBottomInset = usesMobileFlowPresentation ? mobileKeyboardInset : (isMobile ? powerboardsMobileScreenBottomInset : 0.0);
    final effectiveConstraints = _resolveDialogConstraints(
      constraints,
      screenSize: screenSize,
      isMobile: isMobile,
      mobilePresentation: mobilePresentation,
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
    final effectivePadding = _resolveDialogPadding(padding, usesMobileFlowPresentation: usesMobileFlowPresentation);
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

    final wrappedDialog = usesMobileFlowPresentation && !usesKeyboardAvoidance
        ? MediaQuery.removeViewInsets(context: context, removeBottom: true, child: dialog)
        : dialog;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: wrappedDialog,
    );
  }
}

bool powerboardsUsesNativeMobileDialogLayout(BuildContext context) {
  final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 1024.0;
  return _usesNativeMobileDialogLayout(screenWidth);
}

bool _usesNativeMobileDialogLayout(double screenWidth) {
  if (kIsWeb) {
    return false;
  }

  final isMobilePlatform = switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => false,
  };

  return isMobilePlatform && screenWidth < 600;
}

bool _usesMobileFlowPresentation(PowerboardsDialogMobilePresentation mobilePresentation) {
  return mobilePresentation == PowerboardsDialogMobilePresentation.flowSheet ||
      mobilePresentation == PowerboardsDialogMobilePresentation.fullScreen;
}

bool _usesMobileFlowKeyboardAvoidance(PowerboardsDialogMobileFlowBodyBehavior bodyBehavior) {
  return bodyBehavior != PowerboardsDialogMobileFlowBodyBehavior.formScrollable;
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

EdgeInsetsGeometry? _resolveDialogPadding(EdgeInsetsGeometry? padding, {required bool usesMobileFlowPresentation}) {
  if (padding != null) {
    return padding;
  }

  if (!usesMobileFlowPresentation) {
    return null;
  }

  return const EdgeInsets.fromLTRB(
    _mobileFullScreenDialogHorizontalPadding,
    _mobileFlowDialogTopPadding,
    _mobileFullScreenDialogHorizontalPadding,
    _mobileFlowDialogBottomPadding,
  );
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

  if (onBack == null) {
    return _PowerboardsMobileFlowDialogTitleBar(
      title: DefaultTextStyle(style: resolvedTitleStyle, textAlign: TextAlign.left, child: truncatedTitle),
      closeIconData: closeIconData,
    );
  }

  return _PowerboardsMobileFlowDialogHeader(
    title: DefaultTextStyle(style: resolvedTitleStyle, textAlign: TextAlign.center, child: truncatedTitle),
    onBack: onBack,
    closeIconData: closeIconData,
  );
}

Widget? _resolveFlowDialogDescription(
  BuildContext context, {
  required Widget? description,
  required TextStyle? descriptionStyle,
  required TextAlign descriptionTextAlign,
  required bool usesMobileFlowPresentation,
}) {
  if (!usesMobileFlowPresentation || description == null) {
    return description;
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
  return SizedBox(height: powerboardsFooterActionButtonHeight, child: action);
}

bool _usesHorizontalMobileActionRow({required bool isMobile, required List<Widget> actions}) {
  return isMobile && actions.isNotEmpty && actions.length <= 2;
}

BoxConstraints? _resolveDialogConstraints(
  BoxConstraints? constraints, {
  required Size screenSize,
  required bool isMobile,
  required PowerboardsDialogMobilePresentation mobilePresentation,
  required double mobileTopInset,
  required double mobileBottomInset,
}) {
  final availableMobileHeight = (screenSize.height - mobileTopInset - mobileBottomInset).clamp(0.0, screenSize.height).toDouble();

  if (isMobile && _usesMobileFlowPresentation(mobilePresentation)) {
    final defaultMinHeight = _mobileFlowDefaultMinHeight(mobilePresentation, availableHeight: availableMobileHeight);
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

double _mobileFlowDefaultMinHeight(PowerboardsDialogMobilePresentation mobilePresentation, {required double availableHeight}) {
  if (mobilePresentation == PowerboardsDialogMobilePresentation.fullScreen) {
    return availableHeight;
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
  const _PowerboardsMobileDialogCloseButton({this.iconData});

  final IconData? iconData;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ShadIconButton.ghost(
      onPressed: () => Navigator.of(context).pop(),
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

class _PowerboardsMobileFlowDialogTitleBar extends StatelessWidget {
  const _PowerboardsMobileFlowDialogTitleBar({required this.title, this.closeIconData});

  final Widget title;
  final IconData? closeIconData;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _mobileDialogCloseButtonSize,
      child: Row(
        children: [
          Expanded(child: title),
          const SizedBox(width: 12),
          _PowerboardsMobileDialogCloseButton(iconData: closeIconData),
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

    final contentSections = <Widget>[
      if (headerSection != null) headerSection,
      bodySection,
      if (actions.isNotEmpty)
        usesHorizontalActionRow
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: _buildHorizontalSection(actions, spacing: actionsGap),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildVerticalSection(actions, spacing: actionsGap),
              ),
    ];

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: expandBody ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _buildVerticalSection(contentSections, spacing: gap * 2),
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final heightConstraints = widget.constraints ?? const BoxConstraints();
    final hasFixedHeight =
        heightConstraints.hasBoundedHeight && (heightConstraints.maxHeight - heightConstraints.minHeight).abs() < precisionErrorTolerance;
    final requiresMeasurement = widget.bodyBehavior != PowerboardsDialogMobileFlowBodyBehavior.fill && !hasFixedHeight;
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
    final visibleFrame = _PowerboardsMobileFlowDialogFrame(
      title: widget.title,
      description: widget.description,
      body: _buildVisibleBody(),
      actions: widget.actions,
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
      padding: EdgeInsets.only(bottom: widget.keyboardInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Stack(
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

  Widget _buildVisibleBody() {
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
  });

  final Widget child;
  final EdgeInsets padding;
  final double? maxWidth;
  final double? contentHeight;
  final bool centerSparseContent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minContentHeight = (constraints.maxHeight - padding.vertical).clamp(0.0, constraints.maxHeight).toDouble();
        final canScroll = contentHeight == null || contentHeight! > (minContentHeight + 1);
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
          padding: padding,
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
