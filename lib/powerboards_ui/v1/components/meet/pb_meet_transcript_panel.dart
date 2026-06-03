import 'package:flutter/material.dart';

import '../../models/pb_attachment_file_metadata.dart';
import '../../theme/pb_colors.dart';
import '../files/pb_sidepane_file_list.dart';
import '../layouts/pb_room_panel.dart';

const _recentTranscriptWindowDays = 7;
const _recentTranscriptFallbackLimit = 7;

class PbMeetTranscriptPanel extends StatefulWidget {
  const PbMeetTranscriptPanel({
    super.key,
    this.filePreviewResizing = false,
    this.borderOnTop = false,
    this.responsiveOverlay = false,
    this.responsiveOverlayMobile = false,
    this.openFilePreviewAsFullscreen = false,
    this.onResponsiveOverlayClose,
    this.transcripts = _meetTranscripts,
    this.emptyTranscripts = false,
    this.initialPreviewFile,
    this.initialFilePreviewOpen = false,
    this.filePreviewBuilder,
    this.filePreviewSourceBuilder,
    this.onAskFileAgent,
    this.onShareFile,
    this.onDownloadFile,
    this.onFilePreviewOpenChanged,
    this.onFilePreviewFullscreenChanged,
    this.onFilePreviewSelected,
  });

  final bool filePreviewResizing;
  final bool borderOnTop;
  final bool responsiveOverlay;
  final bool responsiveOverlayMobile;
  final bool openFilePreviewAsFullscreen;
  final VoidCallback? onResponsiveOverlayClose;
  final List<PbAttachmentListItemData> transcripts;
  final bool emptyTranscripts;
  final PbAttachmentListItemData? initialPreviewFile;
  final bool initialFilePreviewOpen;
  final Widget Function(PbAttachmentListItemData file)? filePreviewBuilder;
  final PbFilePreviewSource? Function(PbAttachmentListItemData file)? filePreviewSourceBuilder;
  final ValueChanged<PbAttachmentListItemData>? onAskFileAgent;
  final ValueChanged<PbAttachmentListItemData>? onShareFile;
  final ValueChanged<PbAttachmentListItemData>? onDownloadFile;
  final ValueChanged<bool>? onFilePreviewOpenChanged;
  final ValueChanged<bool>? onFilePreviewFullscreenChanged;
  final ValueChanged<PbAttachmentListItemData>? onFilePreviewSelected;

  @override
  State<PbMeetTranscriptPanel> createState() => _PbMeetTranscriptPanelState();
}

class _PbMeetTranscriptPanelState extends State<PbMeetTranscriptPanel> {
  late bool _filePreviewOpen = widget.initialFilePreviewOpen;
  late bool _filePreviewFullscreen = widget.initialFilePreviewOpen && widget.openFilePreviewAsFullscreen;
  late PbAttachmentListItemData _previewFile = widget.initialPreviewFile ?? _fallbackPreviewFile;

  List<PbAttachmentListItemData> get _effectiveTranscripts {
    return widget.emptyTranscripts ? const [] : _recentTranscripts(widget.transcripts);
  }

  PbAttachmentListItemData get _fallbackPreviewFile {
    if (widget.transcripts.isNotEmpty) {
      return widget.transcripts.first;
    }

    return _transcriptFile;
  }

  @override
  void didUpdateWidget(covariant PbMeetTranscriptPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialFilePreviewOpen != oldWidget.initialFilePreviewOpen) {
      _filePreviewOpen = widget.initialFilePreviewOpen;
      if (widget.initialFilePreviewOpen && widget.openFilePreviewAsFullscreen) {
        _filePreviewFullscreen = true;
      }
    }

    final nextPreviewFile = widget.initialPreviewFile;
    if (nextPreviewFile != null && nextPreviewFile != oldWidget.initialPreviewFile) {
      _previewFile = nextPreviewFile;
    }

    if (widget.openFilePreviewAsFullscreen && !oldWidget.openFilePreviewAsFullscreen && _filePreviewOpen) {
      _filePreviewFullscreen = true;
    }

    if (widget.emptyTranscripts && !oldWidget.emptyTranscripts) {
      _filePreviewOpen = false;
      _filePreviewFullscreen = false;
    }
  }

  void _openFilePreview(PbAttachmentListItemData file) {
    setState(() {
      _previewFile = file;
      _filePreviewOpen = true;
      _filePreviewFullscreen = widget.openFilePreviewAsFullscreen;
    });
    widget.onFilePreviewSelected?.call(file);
    widget.onFilePreviewOpenChanged?.call(true);
    widget.onFilePreviewFullscreenChanged?.call(widget.openFilePreviewAsFullscreen);
  }

  void _setFilePreviewFullscreen(bool fullscreen) {
    setState(() => _filePreviewFullscreen = fullscreen);
    widget.onFilePreviewFullscreenChanged?.call(fullscreen);
  }

  void _closeFilePreview() {
    setState(() {
      _filePreviewOpen = false;
      _filePreviewFullscreen = false;
    });
    widget.onFilePreviewOpenChanged?.call(false);
    widget.onFilePreviewFullscreenChanged?.call(false);
  }

  Widget _buildTranscriptContent({
    required bool showInlineBorder,
    required EdgeInsetsGeometry padding,
    Color backgroundColor = PbColors.surfacePanelWash,
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: !showInlineBorder
            ? null
            : widget.borderOnTop
            ? const Border(top: BorderSide(color: PbColors.borderSoft))
            : const Border(left: BorderSide(color: PbColors.borderSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PbStaticRoomTabs(label: 'Recent transcripts'),
          const SizedBox(height: 16),
          const PbRoomPanelDescription('Browse transcripts from recent meetings.'),
          const SizedBox(height: 20),
          PbMeetTranscriptList(
            transcripts: _effectiveTranscripts,
            onPreviewFile: _openFilePreview,
            onAskFileAgent: widget.onAskFileAgent,
            onShareFile: widget.onShareFile,
            onDownloadFile: widget.onDownloadFile,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPane({required bool showInlineBorder}) {
    final previewFullscreen = _filePreviewFullscreen || widget.openFilePreviewAsFullscreen;
    final previewSource = _previewFile.previewState == PbAttachmentPreviewState.none
        ? widget.filePreviewSourceBuilder?.call(_previewFile)
        : null;
    final previewContentChild = previewSource?.buildChild(previewFullscreen);

    return PbFilePreviewPane(
      file: _previewFile,
      fullscreen: previewFullscreen,
      resizing: widget.filePreviewResizing,
      borderOnTop: widget.borderOnTop,
      showInlineBorder: showInlineBorder,
      hideFullscreenToggle: widget.openFilePreviewAsFullscreen,
      onAskAgent: widget.onAskFileAgent == null ? null : () => widget.onAskFileAgent!(_previewFile),
      onShare: widget.onShareFile == null ? null : () => widget.onShareFile!(_previewFile),
      onDownload: widget.onDownloadFile == null ? null : () => widget.onDownloadFile!(_previewFile),
      onToggleFullscreen: () => _setFilePreviewFullscreen(!_filePreviewFullscreen),
      onClose: _closeFilePreview,
      previewContentChild: previewContentChild,
      loadText: previewSource?.loadText,
      onSaveTextRequested: previewSource?.saveText,
      child: previewSource == null && _previewFile.previewState == PbAttachmentPreviewState.none
          ? widget.filePreviewBuilder?.call(_previewFile)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.responsiveOverlay) {
      return PbResponsiveRoomPanelOverlayFrame(
        mobile: widget.responsiveOverlayMobile,
        onClose: widget.onResponsiveOverlayClose,
        preview: _filePreviewOpen ? _buildPreviewPane(showInlineBorder: false) : null,
        child: _buildTranscriptContent(
          showInlineBorder: false,
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: _filePreviewOpen ? 0 : 1,
          child: IgnorePointer(
            ignoring: _filePreviewOpen,
            child: _buildTranscriptContent(showInlineBorder: true, padding: const EdgeInsets.fromLTRB(22, 29, 22, 0)),
          ),
        ),
        if (_filePreviewOpen) Positioned.fill(child: _buildPreviewPane(showInlineBorder: true)),
      ],
    );
  }
}

class PbMeetTranscriptList extends StatelessWidget {
  const PbMeetTranscriptList({
    super.key,
    required this.transcripts,
    required this.onPreviewFile,
    this.onAskFileAgent,
    this.onShareFile,
    this.onDownloadFile,
  });

  static const _emptyTranscript = PbSidepaneFileEmptyStateData(
    title: 'No transcripts yet',
    subtitle: 'Transcripts will show up here.',
    fileType: PbAttachmentFileType.generic,
  );

  final List<PbAttachmentListItemData> transcripts;
  final ValueChanged<PbAttachmentListItemData> onPreviewFile;
  final ValueChanged<PbAttachmentListItemData>? onAskFileAgent;
  final ValueChanged<PbAttachmentListItemData>? onShareFile;
  final ValueChanged<PbAttachmentListItemData>? onDownloadFile;

  @override
  Widget build(BuildContext context) {
    return PbSidepaneFileList(
      files: [
        for (final transcript in transcripts)
          PbSidepaneFileListItem(
            data: transcript,
            onPressed: () => onPreviewFile(transcript),
            onAskAgent: onAskFileAgent == null ? null : () => onAskFileAgent!(transcript),
            onShare: onShareFile == null ? null : () => onShareFile!(transcript),
            onDownload: onDownloadFile == null ? null : () => onDownloadFile!(transcript),
          ),
      ],
      emptyState: _emptyTranscript,
    );
  }
}

const _transcriptFile = PbAttachmentListItemData(title: 'Transcript', subtitle: 'Transcript', fileType: PbAttachmentFileType.transcript);

const _launchPlanningTranscript = PbAttachmentListItemData(
  title: 'Launch planning',
  subtitle: 'Transcript',
  fileType: PbAttachmentFileType.transcript,
);

const _openQuestionsTranscript = PbAttachmentListItemData(
  title: 'Open questions',
  subtitle: 'Transcript',
  fileType: PbAttachmentFileType.transcript,
);

const _pilotLaunchBriefTranscript = PbAttachmentListItemData(
  title: 'Pilot launch brief',
  subtitle: 'Transcript',
  fileType: PbAttachmentFileType.transcript,
);

const _stakeholderRecapTranscript = PbAttachmentListItemData(
  title: 'Stakeholder recap',
  subtitle: 'Transcript',
  fileType: PbAttachmentFileType.transcript,
);

const _enablementChecklistTranscript = PbAttachmentListItemData(
  title: 'Enablement checklist',
  subtitle: 'Transcript',
  fileType: PbAttachmentFileType.transcript,
);

const _partnerOnboardingTranscript = PbAttachmentListItemData(
  title: 'Partner onboarding',
  subtitle: 'Transcript',
  fileType: PbAttachmentFileType.transcript,
);

const _meetTranscripts = [
  _transcriptFile,
  _launchPlanningTranscript,
  _openQuestionsTranscript,
  _pilotLaunchBriefTranscript,
  _stakeholderRecapTranscript,
  _enablementChecklistTranscript,
  _partnerOnboardingTranscript,
];

class _MeetTranscriptRecord {
  const _MeetTranscriptRecord({required this.data, required this.updatedSort});

  final PbAttachmentListItemData data;
  final int updatedSort;
}

List<PbAttachmentListItemData> _recentTranscripts(List<PbAttachmentListItemData> transcripts) {
  final records = [
    for (final transcript in transcripts) _meetTranscriptRecordFor(transcript) ?? _MeetTranscriptRecord(data: transcript, updatedSort: 0),
  ]..sort((left, right) => right.updatedSort.compareTo(left.updatedSort));

  final recentCutoff = _recentCutoffDate(_recentTranscriptWindowDays);
  final recent = records
      .where((record) => record.updatedSort > 0 && !_dateForSortValue(record.updatedSort).isBefore(recentCutoff))
      .toList();
  final selected = recent.isNotEmpty ? recent : records.take(_recentTranscriptFallbackLimit).toList();

  return [for (final record in selected) record.data];
}

_MeetTranscriptRecord? _meetTranscriptRecordFor(PbAttachmentListItemData transcript) {
  for (final record in _meetTranscriptRecords) {
    if (record.data.title == transcript.title) {
      return record;
    }
  }

  return null;
}

DateTime _recentCutoffDate(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
}

DateTime _dateForSortValue(int sortValue) {
  final value = sortValue.toString().padLeft(12, '0');
  return DateTime(
    int.parse(value.substring(0, 4)),
    int.parse(value.substring(4, 6)),
    int.parse(value.substring(6, 8)),
    value.length >= 10 ? int.parse(value.substring(8, 10)) : 0,
    value.length >= 12 ? int.parse(value.substring(10, 12)) : 0,
  );
}

const _meetTranscriptRecords = [
  _MeetTranscriptRecord(updatedSort: 202605291030, data: _transcriptFile),
  _MeetTranscriptRecord(updatedSort: 202605261430, data: _launchPlanningTranscript),
  _MeetTranscriptRecord(updatedSort: 202605251145, data: _openQuestionsTranscript),
  _MeetTranscriptRecord(updatedSort: 202605231600, data: _pilotLaunchBriefTranscript),
  _MeetTranscriptRecord(updatedSort: 202605211015, data: _stakeholderRecapTranscript),
  _MeetTranscriptRecord(updatedSort: 202605151300, data: _enablementChecklistTranscript),
  _MeetTranscriptRecord(updatedSort: 202605101130, data: _partnerOnboardingTranscript),
];
