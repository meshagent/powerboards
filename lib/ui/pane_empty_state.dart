import 'package:flutter/material.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';

class PaneEmptyState extends StatelessWidget {
  const PaneEmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.action,
    this.titleScaleOverride,
    this.verticalOffset = 0,
    this.iconGap = 16,
    this.actionGap = 24,
  });

  final String title;
  final String? description;
  final Widget? icon;
  final Widget? action;
  final double? titleScaleOverride;
  final double verticalOffset;
  final double iconGap;
  final double actionGap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: Offset(0, verticalOffset),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[icon!, SizedBox(height: iconGap)],
                ChatThreadEmptyStateContent(title: title, description: description, titleScaleOverride: titleScaleOverride),
                if (action != null) ...[SizedBox(height: actionGap), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
