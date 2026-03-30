import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:powerboards/theme/theme.dart';

const double powerboardsMenuRowHeight = 80;
const double powerboardsMenuRowHorizontalPadding = 14;
const double powerboardsMenuRowLeadingSize = 32;
const double powerboardsMenuRowItemGap = 14;
const double powerboardsMenuRowTrailingGap = 12;

TextStyle powerboardsMenuRowTitleStyle() {
  return GoogleFonts.inter(fontSize: 16, height: 1.2, fontWeight: FontWeight.w600, color: shadForeground);
}

TextStyle powerboardsMenuRowDescriptionStyle() {
  return GoogleFonts.inter(fontSize: 14, height: 1.2, fontWeight: FontWeight.w500, color: shadSecondaryForeground);
}

class PowerboardsMenuRow extends StatelessWidget {
  const PowerboardsMenuRow({
    super.key,
    required this.title,
    this.description,
    this.leading,
    this.trailing,
    this.leadingSize = powerboardsMenuRowLeadingSize,
    this.horizontalPadding = powerboardsMenuRowHorizontalPadding,
    this.itemGap = powerboardsMenuRowItemGap,
    this.trailingGap = powerboardsMenuRowTrailingGap,
    this.height = powerboardsMenuRowHeight,
    this.descriptionMaxLines = 2,
    this.reserveLeadingSpace = true,
  });

  final String title;
  final String? description;
  final Widget? leading;
  final Widget? trailing;
  final double leadingSize;
  final double horizontalPadding;
  final double itemGap;
  final double trailingGap;
  final double height;
  final int descriptionMaxLines;
  final bool reserveLeadingSpace;

  @override
  Widget build(BuildContext context) {
    final titleStyle = powerboardsMenuRowTitleStyle();
    final descriptionStyle = powerboardsMenuRowDescriptionStyle();
    final resolvedDescription = description?.trim();
    final showDescription = resolvedDescription != null && resolvedDescription.isNotEmpty;

    Widget? leadingWidget = leading;
    if (leadingWidget != null || reserveLeadingSpace) {
      leadingWidget = SizedBox(
        width: leadingSize,
        height: leadingSize,
        child: leadingWidget == null ? null : Center(child: leadingWidget),
      );
    }

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leadingWidget != null) leadingWidget,
            if (leadingWidget != null) SizedBox(width: itemGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: titleStyle, overflow: TextOverflow.ellipsis),
                  if (showDescription) ...[
                    const SizedBox(height: 6),
                    Text(resolvedDescription, style: descriptionStyle, overflow: TextOverflow.ellipsis, maxLines: descriptionMaxLines),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[SizedBox(width: trailingGap), trailing!],
          ],
        ),
      ),
    );
  }
}
