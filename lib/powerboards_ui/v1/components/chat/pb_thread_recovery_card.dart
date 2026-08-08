import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_tokens.dart';
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          key: const ValueKey('pb-thread-poisoned-attachment-recovery'),
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(color: PbColors.alertSoft, borderRadius: BorderRadius.circular(PbRadii.medium)),
          child: Text.rich(
            TextSpan(
              style: PowerboardsTypography.p.copyWith(color: PbColors.textBody),
              children: [
                const TextSpan(text: 'There was an error. To continue please '),
                TextSpan(
                  text: 'create a new thread',
                  style: PowerboardsTypography.p.copyWith(color: PbColors.alert, fontWeight: FontWeight.w600),
                  recognizer: widget.onStartNewThread == null ? null : _startNewThreadRecognizer,
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
