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
    final mobileTopInset = isMobile ? powerboardsMobileScreenTopInset : 0.0;
    final mobileBottomInset = isMobile ? powerboardsMobileScreenBottomInset : 0.0;
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
    final effectiveAlignment =
        alignment ?? (isMobile && mobilePresentation == PowerboardsDialogMobilePresentation.fullScreen ? Alignment.topCenter : null);

    return ShadDialog.raw(
      key: key,
      variant: variant,
      title: title,
      description: description,
      actions: effectiveActions,
      closeIcon: effectiveCloseIcon,
      closeIconData: effectiveCloseIcon == null ? closeIconData : null,
      closeIconPosition: effectiveCloseIconPosition,
      radius: radius,
      backgroundColor: backgroundColor,
      expandActionsWhenTiny: expandActionsWhenTiny,
      padding: padding,
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
      scrollable: scrollable,
      scrollPadding: scrollPadding,
      actionsGap: actionsGap,
      useSafeArea: useSafeArea,
      titlePinned: titlePinned,
      descriptionPinned: descriptionPinned,
      actionsPinned: actionsPinned,
      child: child,
    );
  }
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
