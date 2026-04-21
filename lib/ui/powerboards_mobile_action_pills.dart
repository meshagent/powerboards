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
    this.pillPadding = const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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

class _PowerboardsMobileActionPill extends StatefulWidget {
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
  State<_PowerboardsMobileActionPill> createState() => _PowerboardsMobileActionPillState();
}

class _PowerboardsMobileActionPillState extends State<_PowerboardsMobileActionPill> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }

    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = ShadTheme.of(context);
    final selectedBackgroundColor = item.destructive
        ? theme.colorScheme.destructive.withValues(alpha: 0.96)
        : theme.colorScheme.foreground.withValues(alpha: 0.94);
    final selectedForegroundColor = item.destructive ? theme.colorScheme.destructiveForeground : theme.colorScheme.background;
    final unselectedDefaultForegroundColor = item.destructive
        ? theme.colorScheme.destructive
        : theme.colorScheme.foreground.withValues(alpha: 0.78);
    final unselectedDefaultBorderColor = item.destructive
        ? theme.colorScheme.destructive.withValues(alpha: 0.34)
        : theme.colorScheme.border;

    final backgroundColor = item.selected ? selectedBackgroundColor : null;
    final backgroundGradient = item.selected
        ? null
        : powerboardsMobileGlassGradient(theme.colorScheme.background, topTint: 0.92, bottomTint: 0.74, topAlpha: 0.96, bottomAlpha: 0.82);
    final foregroundColor = item.selected
        ? selectedForegroundColor
        : (widget.unselectedForegroundColor ?? unselectedDefaultForegroundColor);
    final borderColor = item.selected ? Colors.transparent : (widget.unselectedBorderColor ?? unselectedDefaultBorderColor);
    final resolvedTextStyle =
        widget.textStyle ??
        powerboardsInterTextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: foregroundColor, height: 1.0, letterSpacing: -0.1);

    return Material(
      color: Colors.transparent,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        opacity: _pressed ? powerboardsPressedOpacity : 1.0,
        child: InkWell(
          onTap: item.onPressed,
          borderRadius: BorderRadius.circular(999),
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: backgroundColor,
              gradient: backgroundGradient,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
            ),
            child: Text(item.label, style: resolvedTextStyle.copyWith(color: foregroundColor)),
          ),
        ),
      ),
    );
  }
}
