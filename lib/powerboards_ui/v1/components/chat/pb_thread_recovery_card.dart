import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:meshagent_flutter_shadcn/thread_typography.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_typography.dart';

bool powerboardsV1IsPoisonedAttachmentError(String message) {
  final normalized = message.toLowerCase().replaceAll('’', "'");
  if (normalized.contains("this thread can't continue because an attachment format was rejected") ||
      normalized.contains('the image data you provided does not represent a valid image') ||
      normalized.contains('no tool output found for function call') ||
      (normalized.contains('unknown parameter') && RegExp(r'input\[\d+\]\.output').hasMatch(normalized))) {
    return true;
  }
  final rejectsInput =
      normalized.contains('unsupported') ||
      normalized.contains('not supported') ||
      normalized.contains('invalid') ||
      normalized.contains('must be one of') ||
      normalized.contains('only supports');
  if (!rejectsInput) {
    return false;
  }
  if (normalized.contains('svg')) {
    return true;
  }
  final describesImageInput =
      normalized.contains('image') && (normalized.contains('mime') || normalized.contains('format') || normalized.contains('input'));
  final namesRasterFormats = <String>['png', 'jpeg', 'jpg', 'webp', 'gif'].where(normalized.contains).length >= 2;
  return describesImageInput && namesRasterFormats;
}

class PbThreadPoisonedAttachmentRecoveryCard extends StatefulWidget {
  const PbThreadPoisonedAttachmentRecoveryCard({super.key, required this.onStartNewThread});

  final VoidCallback? onStartNewThread;

  @override
  State<PbThreadPoisonedAttachmentRecoveryCard> createState() => _PbThreadPoisonedAttachmentRecoveryCardState();
}

class _PbThreadPoisonedAttachmentRecoveryCardState extends State<PbThreadPoisonedAttachmentRecoveryCard> {
  late final TapGestureRecognizer _startNewThreadRecognizer;

  @override
  void initState() {
    super.initState();
    _startNewThreadRecognizer = TapGestureRecognizer()..onTap = widget.onStartNewThread;
  }

  @override
  void didUpdateWidget(covariant PbThreadPoisonedAttachmentRecoveryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startNewThreadRecognizer.onTap = widget.onStartNewThread;
  }

  @override
  void dispose() {
    _startNewThreadRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contentPadding =
        ThreadTypographyOverride.maybeAgentBubbleContentPaddingOf(context) ??
        ThreadTypographyOverride.maybeBubbleContentPaddingOf(context) ??
        const EdgeInsets.symmetric(horizontal: 18, vertical: 8);
    final textStyle = threadTypographyTextStyle(context, PowerboardsTypography.p).copyWith(
      color: PbColors.textBody,
      fontSize: ThreadTypographyOverride.maybeThreadParagraphBaseFontSizeOf(context) ?? PowerboardsTypography.p.fontSize,
      height: ThreadTypographyOverride.maybeThreadParagraphLineHeightOf(context) ?? PowerboardsTypography.p.height,
    );
    return SizedBox(
      width: double.infinity,
      child: Container(
        key: const ValueKey('pb-thread-poisoned-attachment-recovery'),
        padding: contentPadding,
        decoration: BoxDecoration(color: PbColors.alertSoft, borderRadius: BorderRadius.circular(16)),
        child: Text.rich(
          TextSpan(
            style: textStyle,
            children: [
              const TextSpan(text: 'There was an error. To continue please '),
              TextSpan(
                text: 'create a new thread',
                style: textStyle.copyWith(color: PbColors.alert, fontWeight: FontWeight.w600),
                recognizer: widget.onStartNewThread == null ? null : _startNewThreadRecognizer,
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
      ),
    );
  }
}
