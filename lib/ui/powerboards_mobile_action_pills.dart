import 'package:flutter/material.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PowerboardsMobileActionPillItem {
  const PowerboardsMobileActionPillItem({required this.label, this.onPressed, this.selected = false, this.destructive = false});

  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final bool destructive;
}

class PowerboardsMobileActionPillStrip extends StatelessWidget {
  const PowerboardsMobileActionPillStrip({
    super.key,
    required this.items,
    this.viewportPadding = EdgeInsets.zero,
    this.itemGap = 10,
    this.pillPadding = const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
    this.textStyle,
    this.unselectedForegroundColor,
    this.unselectedBorderColor,
  });

  final List<PowerboardsMobileActionPillItem> items;
  final EdgeInsetsGeometry viewportPadding;
  final double itemGap;
  final EdgeInsetsGeometry pillPadding;
  final TextStyle? textStyle;
  final Color? unselectedForegroundColor;
  final Color? unselectedBorderColor;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: viewportPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) SizedBox(width: itemGap),
              _PowerboardsMobileActionPill(
                item: items[index],
                textStyle: textStyle,
                padding: pillPadding,
                unselectedForegroundColor: unselectedForegroundColor,
                unselectedBorderColor: unselectedBorderColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PowerboardsMobileActionPill extends StatelessWidget {
  const _PowerboardsMobileActionPill({
    required this.item,
    required this.padding,
    this.textStyle,
    this.unselectedForegroundColor,
    this.unselectedBorderColor,
  });

  final PowerboardsMobileActionPillItem item;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;
  final Color? unselectedForegroundColor;
  final Color? unselectedBorderColor;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final selectedBackgroundColor = item.destructive ? theme.colorScheme.destructive : theme.colorScheme.foreground;
    final selectedForegroundColor = item.destructive ? theme.colorScheme.destructiveForeground : theme.colorScheme.background;
    final unselectedDefaultForegroundColor = item.destructive
        ? theme.colorScheme.destructive
        : theme.colorScheme.mutedForeground.withValues(alpha: 0.92);
    final unselectedDefaultBorderColor = item.destructive
        ? theme.colorScheme.destructive.withValues(alpha: 0.9)
        : theme.colorScheme.border.withValues(alpha: 0.9);

    final backgroundColor = item.selected ? selectedBackgroundColor : Colors.transparent;
    final foregroundColor = item.selected ? selectedForegroundColor : (unselectedForegroundColor ?? unselectedDefaultForegroundColor);
    final borderColor = item.selected ? Colors.transparent : (unselectedBorderColor ?? unselectedDefaultBorderColor);
    final resolvedTextStyle =
        textStyle ?? powerboardsInterTextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: foregroundColor, height: 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onPressed,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Text(item.label, style: resolvedTextStyle.copyWith(color: foregroundColor)),
        ),
      ),
    );
  }
}
