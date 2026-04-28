import 'package:flutter/material.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';

class PaneEmptyState extends StatelessWidget {
  const PaneEmptyState({
    super.key,
    required this.title,
    this.description,
    this.descriptionWidget,
    this.icon,
    this.action,
    this.titleScaleOverride,
    this.verticalOffset = 0,
    this.iconGap = 16,
    this.actionGap = 24,
    this.showActionOnMobile = false,
    this.pinActionToMobileFooterOnMobile = false,
  });

  final String title;
  final String? description;
  final Widget? descriptionWidget;
  final Widget? icon;
  final Widget? action;
  final double? titleScaleOverride;
  final double verticalOffset;
  final double iconGap;
  final double actionGap;
  final bool showActionOnMobile;
  final bool pinActionToMobileFooterOnMobile;

  static const double _mobileScreenWidthMax = 600;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < _mobileScreenWidthMax;
    final hideAction = isMobile && !showActionOnMobile;
    final shouldPinActionToFooter = isMobile && !hideAction && action != null && pinActionToMobileFooterOnMobile;
    final effectiveVerticalOffset = shouldPinActionToFooter ? 0.0 : verticalOffset;

    final content = Transform.translate(
      offset: Offset(0, effectiveVerticalOffset),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, SizedBox(height: iconGap)],
              if (descriptionWidget == null)
                ChatThreadEmptyStateContent(title: title, description: description, titleScaleOverride: titleScaleOverride)
              else ...[
                ChatThreadEmptyStateContent(title: title, titleScaleOverride: titleScaleOverride),
                const SizedBox(height: 8),
                descriptionWidget!,
              ],
              if (!shouldPinActionToFooter && !hideAction && action != null) ...[SizedBox(height: actionGap), action!],
            ],
          ),
        ),
      ),
    );

    if (shouldPinActionToFooter) {
      return SizedBox.expand(
        child: Column(
          children: [
            Expanded(child: Center(child: content)),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: SizedBox(width: double.infinity, child: action!),
            ),
          ],
        ),
      );
    }

    return Center(child: content);
  }
}
