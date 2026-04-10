import 'package:flutter/material.dart';

import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/theme/theme.dart';

const double powerboardsCompactDesktopDialogWidth = 360;
const BoxConstraints powerboardsCompactDesktopDialogConstraints = BoxConstraints(maxWidth: powerboardsCompactDesktopDialogWidth);
const double powerboardsMobileDialogEdgeInset = 16;
const double powerboardsDialogScrollViewportVerticalInset = 18;
const EdgeInsets powerboardsDialogScrollViewportPadding = EdgeInsets.symmetric(vertical: powerboardsDialogScrollViewportVerticalInset);
const EdgeInsets powerboardsDialogScrollableListPadding = powerboardsDialogScrollViewportPadding;

const double _desktopDialogCloseButtonSize = 32;
const double _desktopDialogCloseIconSize = 24;
const double _desktopDialogCloseButtonTop = 20;
const double _desktopDialogCloseButtonInset = 24;
const double _mobileFullScreenDialogTitleTopPadding = 40;
const double _mobileFullScreenDialogHorizontalPadding = 24;
const double _mobileFullScreenDialogBottomPadding = 48;
const double _mobileFullScreenDialogTitleRowHeight = 34;
const double _compactDesktopDialogWidthThreshold = 420;
const double _desktopDialogActionMinWidth = 152;
const double _desktopDialogActionMaxWidth = 220;

enum PowerboardsDialogMobilePresentation { inherit, inset, fullScreen }

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
    this.stackActionsOnMobile = false,
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
    this.stackActionsOnMobile = true,
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
    this.mobilePresentation = PowerboardsDialogMobilePresentation.inset,
    this.stackActionsOnMobile = true,
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
    this.stackActionsOnMobile = false,
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
    this.stackActionsOnMobile = true,
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
    this.mobilePresentation = PowerboardsDialogMobilePresentation.fullScreen,
    this.stackActionsOnMobile = true,
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
  final bool stackActionsOnMobile;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final screenSize = mediaQuery?.size ?? const Size(1024.0, 768.0);
    final isMobile = screenSize.width < 600;
    final usesMobileFullScreenPresentation = isMobile && mobilePresentation == PowerboardsDialogMobilePresentation.fullScreen;
    final mobileTopInset = usesMobileFullScreenPresentation
        ? (powerboardsMobileScreenTopInset + powerboardsMobileScreenBottomInset) * 2
        : (isMobile ? powerboardsMobileScreenTopInset : 0.0);
    final mobileBottomInset = usesMobileFullScreenPresentation ? 0.0 : (isMobile ? powerboardsMobileScreenBottomInset : 0.0);
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

    final effectiveCloseIcon = closeIcon ?? (isMobile ? null : _PowerboardsDialogCloseButton(iconData: closeIconData));
    final effectiveCloseIconPosition =
        closeIconPosition ??
        (isMobile ? null : const ShadPosition(top: _desktopDialogCloseButtonTop, right: _desktopDialogCloseButtonInset));
    final effectiveScrollable = _resolveDialogScrollable(scrollable, usesMobileFullScreenPresentation: usesMobileFullScreenPresentation);
    final effectiveUseSafeArea = _resolveDialogUseSafeArea(useSafeArea, usesMobileFullScreenPresentation: usesMobileFullScreenPresentation);
    final effectivePadding = _resolveDialogPadding(padding, usesMobileFullScreenPresentation: usesMobileFullScreenPresentation);
    final effectiveChild = usesMobileFullScreenPresentation
        ? _buildMobileFullScreenDialogContent(
            context,
            title: title,
            description: description,
            child: child,
            titleStyle: titleStyle,
            descriptionStyle: descriptionStyle,
            closeIconData: closeIconData,
            gap: gap ?? 8,
          )
        : child;
    final effectiveActions = _buildDialogActions(
      actions,
      isMobile: isMobile,
      isCompactDesktopDialog: isCompactDesktopDialog,
      expandDesktopActions: expandDesktopActions ?? false,
      effectiveDialogMaxWidth: effectiveDialogMaxWidth,
      actionsGap: actionsGap ?? 8,
      stackActionsOnMobile: stackActionsOnMobile,
    );
    final effectiveActionsAxis = actionsAxis ?? (isMobile && stackActionsOnMobile ? Axis.vertical : null);
    final effectiveActionsMainAxisSize =
        actionsMainAxisSize ??
        (isMobile && stackActionsOnMobile
            ? MainAxisSize.max
            : ((isCompactDesktopDialog || expandDesktopActions == true) ? MainAxisSize.max : MainAxisSize.min));
    final effectiveActionsMainAxisAlignment =
        actionsMainAxisAlignment ??
        (isMobile && stackActionsOnMobile
            ? MainAxisAlignment.start
            : ((isCompactDesktopDialog || expandDesktopActions == true) ? MainAxisAlignment.start : MainAxisAlignment.end));
    final effectiveTitleTextAlign = titleTextAlign ?? TextAlign.left;
    final effectiveDescriptionTextAlign = descriptionTextAlign ?? TextAlign.left;
    final effectiveAlignment = alignment ?? (usesMobileFullScreenPresentation ? Alignment.bottomCenter : null);

    return ShadDialog.raw(
      key: key,
      variant: variant,
      title: usesMobileFullScreenPresentation ? null : title,
      description: usesMobileFullScreenPresentation ? null : description,
      actions: effectiveActions,
      closeIcon: usesMobileFullScreenPresentation ? const SizedBox.shrink() : effectiveCloseIcon,
      closeIconData: usesMobileFullScreenPresentation ? null : (effectiveCloseIcon == null ? closeIconData : null),
      closeIconPosition: usesMobileFullScreenPresentation ? const ShadPosition(top: 0, right: 0) : effectiveCloseIconPosition,
      radius: radius,
      backgroundColor: backgroundColor,
      expandActionsWhenTiny: expandActionsWhenTiny,
      padding: effectivePadding,
      gap: gap,
      constraints: effectiveConstraints,
      border: border,
      shadows: shadows,
      removeBorderRadiusWhenTiny: removeBorderRadiusWhenTiny,
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
      actionsPinned: actionsPinned,
      child: effectiveChild,
    );
  }
}

Widget? _buildMobileFullScreenDialogContent(
  BuildContext context, {
  required Widget? title,
  required Widget? description,
  required Widget? child,
  required TextStyle? titleStyle,
  required TextStyle? descriptionStyle,
  required IconData? closeIconData,
  required double gap,
}) {
  if (title == null && description == null && child == null) {
    return null;
  }

  final theme = ShadTheme.of(context);
  final resolvedTitleStyle = (titleStyle ?? theme.textTheme.large).fallback(color: theme.colorScheme.foreground);
  final resolvedDescriptionStyle = (descriptionStyle ?? theme.textTheme.muted).fallback(color: theme.colorScheme.mutedForeground);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.max,
    children: [
      if (title != null)
        SizedBox(
          height: _mobileFullScreenDialogTitleRowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: DefaultTextStyle(style: resolvedTitleStyle, textAlign: TextAlign.left, child: title),
              ),
              const SizedBox(width: 12),
              SizedBox(width: 20, height: 20, child: _PowerboardsMobileDialogCloseButton(iconData: closeIconData)),
            ],
          ),
        )
      else
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(width: 20, height: 20, child: _PowerboardsMobileDialogCloseButton(iconData: closeIconData)),
        ),
      if (description != null) ...[
        SizedBox(height: gap),
        DefaultTextStyle(style: resolvedDescriptionStyle, textAlign: TextAlign.left, child: description),
      ],
      if (child != null) ...[
        SizedBox(height: gap),
        Expanded(
          child: Align(alignment: Alignment.topCenter, child: child),
        ),
      ],
    ],
  );
}

bool? _resolveDialogScrollable(bool? scrollable, {required bool usesMobileFullScreenPresentation}) {
  if (usesMobileFullScreenPresentation) {
    return false;
  }

  return scrollable;
}

bool? _resolveDialogUseSafeArea(bool? useSafeArea, {required bool usesMobileFullScreenPresentation}) {
  if (usesMobileFullScreenPresentation) {
    return false;
  }

  return useSafeArea;
}

EdgeInsetsGeometry? _resolveDialogPadding(EdgeInsetsGeometry? padding, {required bool usesMobileFullScreenPresentation}) {
  if (padding != null) {
    return padding;
  }

  if (!usesMobileFullScreenPresentation) {
    return null;
  }

  return const EdgeInsets.fromLTRB(
    _mobileFullScreenDialogHorizontalPadding,
    _mobileFullScreenDialogTitleTopPadding,
    _mobileFullScreenDialogHorizontalPadding,
    _mobileFullScreenDialogBottomPadding,
  );
}

List<Widget> _buildDialogActions(
  List<Widget> actions, {
  required bool isMobile,
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
    if (!stackActionsOnMobile) {
      return actions;
    }

    return actions.map((action) => SizedBox(width: double.infinity, child: action)).toList(growable: false);
  }

  if (isCompactDesktopDialog) {
    return actions.map((action) => Expanded(child: action)).toList(growable: false);
  }

  if (expandDesktopActions) {
    return actions.map((action) => Expanded(child: action)).toList(growable: false);
  }

  final usableWidth = effectiveDialogMaxWidth - 48 - (actionsGap * (actions.length - 1));
  final actionWidth = (usableWidth / actions.length).clamp(_desktopDialogActionMinWidth, _desktopDialogActionMaxWidth);

  return actions.map((action) => SizedBox(width: actionWidth, child: action)).toList(growable: false);
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

  if (isMobile && mobilePresentation == PowerboardsDialogMobilePresentation.fullScreen) {
    return BoxConstraints(
      minWidth: screenSize.width,
      maxWidth: screenSize.width,
      minHeight: availableMobileHeight,
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
      width: 20,
      height: 20,
      padding: EdgeInsets.zero,
      foregroundColor: theme.colorScheme.foreground.withValues(alpha: .5),
      hoverBackgroundColor: Colors.transparent,
      hoverForegroundColor: theme.colorScheme.foreground,
      pressedForegroundColor: theme.colorScheme.foreground,
      icon: Icon(iconData ?? LucideIcons.x, size: 16),
    );
  }
}
