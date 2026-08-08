import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_tokens.dart';
import '../../theme/pb_typography.dart';
import '../primitives/pb_button.dart';
import '../primitives/pb_svg_icon.dart';

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

class PbThreadPoisonedAttachmentRecoveryCard extends StatelessWidget {
  const PbThreadPoisonedAttachmentRecoveryCard({super.key, required this.onStartNewThread});

  final VoidCallback? onStartNewThread;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          key: const ValueKey('pb-thread-poisoned-attachment-recovery'),
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            border: Border.all(color: PbColors.borderSoft),
            borderRadius: BorderRadius.circular(PbRadii.medium),
            gradient: const LinearGradient(
              colors: [PbColors.surfacePanel, PbColors.surfacePanelSoft],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: PbShadows.card,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: PbColors.alertSoft, borderRadius: BorderRadius.circular(PbRadii.small)),
                alignment: Alignment.center,
                child: const PbSvgIcon(assetName: 'triangle-alert', size: 21, color: PbColors.alert),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This thread can’t continue because an attachment format was rejected.',
                      style: PowerboardsTypography.smallStrong.copyWith(color: PbColors.textPrimary),
                    ),
                    const SizedBox(height: 7),
                    Text('Start a new thread to keep chatting.', style: PowerboardsTypography.p.copyWith(color: PbColors.textMuted)),
                    if (onStartNewThread != null) ...[
                      const SizedBox(height: 18),
                      KeyedSubtree(
                        key: const ValueKey('pb-thread-start-new-after-attachment-error'),
                        child: PbButton(
                          label: 'Start new thread',
                          iconAssetName: 'plus',
                          variant: PbButtonVariant.primary,
                          onPressed: onStartNewThread,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
