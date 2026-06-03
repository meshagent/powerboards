import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../powerboards_ui/v1/components/primitives/pb_svg_icon.dart';
import '../powerboards_ui/v1/theme/pb_colors.dart';

const powerboardsToastDescriptionGap = 16.0;
const powerboardsToastPadding = EdgeInsetsDirectional.fromSTEB(28, 26, 64, 26);
const powerboardsToastCloseIconPosition = ShadPosition(top: 26, right: 28);

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

class PowerboardsToastCloseButton extends StatefulWidget {
  const PowerboardsToastCloseButton({super.key});

  @override
  State<PowerboardsToastCloseButton> createState() => _PowerboardsToastCloseButtonState();
}

class _PowerboardsToastCloseButtonState extends State<PowerboardsToastCloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Close',
      waitDuration: const Duration(milliseconds: 500),
      child: Semantics(
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
              decoration: BoxDecoration(
                color: _hovered ? PbColors.borderFaint : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Opacity(
                opacity: _hovered ? 1 : 0.45,
                child: const PbSvgIcon(assetName: 'x', size: 18, color: PbColors.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
