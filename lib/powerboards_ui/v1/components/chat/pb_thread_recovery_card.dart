import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../primitives/pb_svg_icon.dart';

bool powerboardsV1IsPoisonedAttachmentError(String message) {
  final normalized = message.toLowerCase();
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

class PbThreadPoisonedAttachmentRecoveryCard extends StatelessWidget {
  const PbThreadPoisonedAttachmentRecoveryCard({super.key, required this.onStartNewThread});

  final VoidCallback? onStartNewThread;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Container(
        key: const ValueKey('pb-thread-poisoned-attachment-recovery'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PbColors.customAlertSoft,
          border: Border.all(color: PbColors.borderSoft),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This thread can’t continue because an attachment format was rejected.',
              style: TextStyle(color: Color.lerp(PbColors.customAlert, PbColors.textBody, 0.18), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text('Start a new thread to keep chatting.', style: TextStyle(color: PbColors.textBody)),
            if (onStartNewThread != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('pb-thread-start-new-after-attachment-error'),
                onPressed: onStartNewThread,
                icon: const PbSvgIcon(assetName: 'plus', size: 16, color: PbColors.customBrandInk),
                label: const Text('Start new thread'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
