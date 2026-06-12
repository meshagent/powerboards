import 'package:flutter/material.dart';

import '../../theme/pb_typography.dart';
import '../files/pb_file_selection_checkbox.dart';
import '../primitives/pb_button.dart';
import '../primitives/pb_empty_state.dart';

class PbVoiceSessionEmptyState extends StatelessWidget {
  const PbVoiceSessionEmptyState({
    super.key,
    this.iconAssetName = 'audio-lines',
    this.title = 'Start an audio session',
    this.subtitle = 'Connect with this agent using your microphone.',
    this.primaryButtonLabel = 'Start session',
    this.transcribe = false,
    this.showStartSessionButton = true,
    this.showTranscribeToggle = true,
    this.onTranscribeChanged,
    this.onStartSessionPressed,
  });

  final String iconAssetName;
  final String title;
  final String subtitle;
  final String primaryButtonLabel;
  final bool transcribe;
  final bool showStartSessionButton;
  final bool showTranscribeToggle;
  final ValueChanged<bool>? onTranscribeChanged;
  final VoidCallback? onStartSessionPressed;

  @override
  Widget build(BuildContext context) {
    final actionChildren = <Widget>[
      if (showStartSessionButton)
        PbButton(label: primaryButtonLabel, variant: PbButtonVariant.primary, height: 42, onPressed: onStartSessionPressed),
      if (showTranscribeToggle) ...[
        if (showStartSessionButton) const SizedBox(height: 22),
        _PbVoiceSessionTranscribeToggle(checked: transcribe, onChanged: onTranscribeChanged),
      ],
    ];

    return PbEmptyState(
      iconAssetName: iconAssetName,
      title: title,
      subtitle: subtitle,
      topFactor: pbEmptyStateReferenceTopFactor,
      topOffset: pbEmptyStateReferenceTopOffset,
      actionTopGap: 30,
      action: actionChildren.isEmpty ? null : Column(mainAxisSize: MainAxisSize.min, children: actionChildren),
    );
  }
}

class _PbVoiceSessionTranscribeToggle extends StatelessWidget {
  const _PbVoiceSessionTranscribeToggle({required this.checked, this.onChanged});

  final bool checked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!checked),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PbFileSelectionCheckbox(
              checked: checked,
              compactHitArea: true,
              onPressed: onChanged == null ? () {} : () => onChanged!(!checked),
            ),
            const SizedBox(width: 14),
            Text('Transcribe', style: PowerboardsTypography.button),
          ],
        ),
      ),
    );
  }
}
