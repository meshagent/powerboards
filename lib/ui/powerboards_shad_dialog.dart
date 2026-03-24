import 'package:flutter/material.dart';

import 'package:shadcn_ui/shadcn_ui.dart';

const double _desktopDialogCloseButtonSize = 32;
const double _desktopDialogCloseIconSize = 24;
const double _desktopDialogCloseButtonTop = 20;
const double _desktopDialogCloseButtonInset = 24;

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
  }) : variant = ShadDialogVariant.alert;

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 1024.0;
    final isMobile = screenWidth < 600;

    final effectiveCloseIcon = closeIcon ?? (isMobile ? null : _PowerboardsDialogCloseButton(iconData: closeIconData));
    final effectiveCloseIconPosition =
        closeIconPosition ??
        (isMobile ? null : const ShadPosition(top: _desktopDialogCloseButtonTop, right: _desktopDialogCloseButtonInset));

    return ShadDialog.raw(
      key: key,
      variant: variant,
      title: title,
      description: description,
      actions: actions,
      closeIcon: effectiveCloseIcon,
      closeIconData: effectiveCloseIcon == null ? closeIconData : null,
      closeIconPosition: effectiveCloseIconPosition,
      radius: radius,
      backgroundColor: backgroundColor,
      expandActionsWhenTiny: expandActionsWhenTiny,
      padding: padding,
      gap: gap,
      constraints: constraints,
      border: border,
      shadows: shadows,
      removeBorderRadiusWhenTiny: removeBorderRadiusWhenTiny,
      actionsAxis: actionsAxis,
      actionsMainAxisSize: actionsMainAxisSize,
      actionsMainAxisAlignment: actionsMainAxisAlignment,
      actionsVerticalDirection: actionsVerticalDirection,
      titleStyle: titleStyle,
      descriptionStyle: descriptionStyle,
      titleTextAlign: titleTextAlign,
      descriptionTextAlign: descriptionTextAlign,
      alignment: alignment,
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
