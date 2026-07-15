import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../powerboards_ui/v1/components/primitives/pb_progress_bar.dart';
import '../powerboards_ui/v1/components/primitives/pb_svg_icon.dart';
import '../powerboards_ui/v1/theme/pb_colors.dart';
import '../powerboards_ui/v1/theme/pb_tokens.dart';
import '../powerboards_ui/v1/theme/pb_typography.dart';

const powerboardsToastDescriptionGap = 16.0;
const powerboardsToastPadding = EdgeInsetsDirectional.fromSTEB(28, 26, 64, 26);
const powerboardsToastCloseIconPosition = ShadPosition(top: 26, right: 28);
const powerboardsRootToastOffset = Offset(20, 20);
const powerboardsRootToastMaxWidth = 380.0;
const powerboardsRootToastShadows = [BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.14), blurRadius: 40, offset: Offset(0, 18))];

ShadToast powerboardsToast({required String title, String? description, bool destructive = false, Duration? duration, Widget? action}) {
  return powerboardsWidgetToast(
    title: Text(title),
    description: description == null ? null : Text(description),
    destructive: destructive,
    duration: duration,
    action: action,
  );
}

ShadToast powerboardsWidgetToast({
  required Widget title,
  Widget? description,
  bool destructive = false,
  Duration? duration,
  Widget? action,
}) {
  final spacedDescription = description == null
      ? null
      : Padding(
          padding: const EdgeInsets.only(top: powerboardsToastDescriptionGap),
          child: description,
        );

  if (destructive) {
    return ShadToast.destructive(
      title: title,
      description: spacedDescription,
      duration: duration,
      action: action,
      padding: powerboardsToastPadding,
      closeIcon: const PowerboardsToastCloseButton(),
      closeIconPosition: powerboardsToastCloseIconPosition,
      showCloseIconOnlyWhenHovered: false,
    );
  }

  return ShadToast(
    title: title,
    description: spacedDescription,
    duration: duration,
    action: action,
    padding: powerboardsToastPadding,
    closeIcon: const PowerboardsToastCloseButton(),
    closeIconPosition: powerboardsToastCloseIconPosition,
    showCloseIconOnlyWhenHovered: false,
  );
}

ShadToast powerboardsRoomLifecycleToast(
  BuildContext context, {
  required String title,
  String? description,
  bool destructive = false,
  Duration? duration,
  bool showProgress = false,
}) {
  final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? powerboardsRootToastMaxWidth;
  final toastWidth = math.min(powerboardsRootToastMaxWidth, math.max(0.0, screenWidth - (powerboardsRootToastOffset.dx * 2)));

  return ShadToast(
    title: Text(title),
    description: description == null && !showProgress
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: powerboardsToastDescriptionGap),
            child: _PowerboardsRoomLifecycleToastDescription(description: description, showProgress: showProgress),
          ),
    duration: duration,
    alignment: Alignment.bottomLeft,
    offset: powerboardsRootToastOffset,
    backgroundColor: PbColors.surfacePanel,
    border: ShadBorder.all(color: PbColors.menuCardBorder, width: 1),
    radius: BorderRadius.circular(PbRadii.large),
    shadows: powerboardsRootToastShadows,
    padding: powerboardsToastPadding,
    closeIcon: const PowerboardsToastCloseButton(),
    closeIconPosition: powerboardsToastCloseIconPosition,
    showCloseIconOnlyWhenHovered: false,
    constraints: BoxConstraints.tightFor(width: toastWidth),
    textDirection: TextDirection.ltr,
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.start,
    mainAxisSize: MainAxisSize.max,
    titleStyle: PowerboardsTypography.label.copyWith(
      color: destructive ? PbColors.alert : PbColors.textPrimary,
      backgroundColor: Colors.transparent,
    ),
    descriptionStyle: PowerboardsTypography.meta.copyWith(color: PbColors.textMuted, backgroundColor: Colors.transparent),
  );
}

class _PowerboardsRoomLifecycleToastDescription extends StatelessWidget {
  const _PowerboardsRoomLifecycleToastDescription({required this.showProgress, this.description});

  final bool showProgress;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final label = description?.trim() ?? '';
    if (!showProgress) {
      return Text(label);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (label.isNotEmpty) const SizedBox(height: 12),
        const PbProgressBar(value: null, color: PbColors.alert),
      ],
    );
  }
}

class PowerboardsToastCloseButton extends StatefulWidget {
  const PowerboardsToastCloseButton({super.key});

  @override
  State<PowerboardsToastCloseButton> createState() => _PowerboardsToastCloseButtonState();
}

class _PowerboardsToastCloseButtonState extends State<PowerboardsToastCloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final closeButton = Semantics(
      label: 'Close notification',
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ShadToaster.of(context).hide(),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: _hovered ? PbColors.borderFaint : Colors.transparent, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Opacity(
              opacity: _hovered ? 1 : 0.45,
              child: const PbSvgIcon(assetName: 'x', size: 18, color: PbColors.textMuted),
            ),
          ),
        ),
      ),
    );

    if (Overlay.maybeOf(context) == null) {
      return closeButton;
    }

    return Tooltip(message: 'Close', waitDuration: const Duration(milliseconds: 500), child: closeButton);
  }
}
