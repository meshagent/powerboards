import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:meshagent/meshagent.dart' as meshagent_api;
import 'package:path/path.dart' as p;
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:powerboards/ui/powerboards_toasts.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'package:meshagent/document.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_flutter/document_connection_scope.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/chat/conversation_descriptor.dart' as ma;
import 'package:meshagent_flutter_shadcn/chat/file_prompt_actions.dart';
import 'package:meshagent_flutter_shadcn/file_preview/code.dart';
import 'package:meshagent_flutter_shadcn/file_preview/file_preview.dart';
import 'package:meshagent_flutter_shadcn/file_preview/video.dart';
import 'package:meshagent_flutter_shadcn/storage/file_browser.dart';
import 'package:meshagent_flutter_shadcn/storage/pending_storage_deletes.dart';
import 'package:meshagent_flutter_shadcn/storage/transcript_file_name.dart';
import 'package:meshagent_flutter_shadcn/ui/ui.dart';
import 'package:meshagent_flutter_shadcn/viewers/builder.dart';
import 'package:meshagent_flutter_shadcn/viewers/file.dart';

import 'package:powerboards/meshagent/archive_extract.dart';
import 'package:powerboards/meshagent/archive_extract_toast.dart';
import 'package:powerboards/meshagent/agent_config.dart';
import 'package:powerboards/meshagent/agent_containers.dart';
import 'package:powerboards/meshagent/file_breadcrumb_layout.dart';
import 'package:powerboards/meshagent/file_attachment_index.dart';
import 'package:powerboards/meshagent/agent_option.dart';
import 'package:powerboards/meshagent/document_pane.dart';
import 'package:powerboards/meshagent/file_list_primitives.dart';
import 'package:powerboards/meshagent/file_move_copy.dart';
import 'package:powerboards/meshagent/file_reference_registry.dart';
import 'package:powerboards/meshagent/file_preview_origin.dart';
import 'package:powerboards/meshagent/file_preview_state.dart';
import 'package:powerboards/meshagent/install_agent.dart';
import 'package:powerboards/meshagent/lapce_code_preview_editor.dart';
import 'package:powerboards/meshagent/meshagent.dart' as powerboards_meshagent;
import 'package:powerboards/meshagent/path.dart';
import 'package:powerboards/meshagent/route_service_match.dart';
import 'package:powerboards/meshagent/thread_display_name.dart';
import 'package:powerboards/meshagent/share_remote_file.dart';
import 'package:powerboards/meshagent/v1_file_preview_source.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_file_preview_state_card.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_archive_extract.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_dialog_file_list.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_file_select_dialog.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_data.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_drop_target.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_layout_values.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_side_pane.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_upload_progress_popover.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_website_preview_document.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_website_preview_pane.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_files_page.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_room_panel.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_room_panel_mount.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';
import 'package:powerboards/powerboards_ui/v1/preview/preview_room_rail_menu.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_typography.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/settings/format_date.dart';
import 'package:powerboards/settings/ui_mode.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:powerboards/ui/app_context_menu.dart';
import 'package:powerboards/ui/desktop_sidetray_toggle.dart';
import 'package:powerboards/ui/pane_empty_state.dart';
import 'package:powerboards/ui/pane_header_action_scope.dart';
import 'package:powerboards/ui/powerboards_adaptive_input.dart';
import 'package:powerboards/ui/powerboards_breakpoints.dart';
import 'package:powerboards/ui/powerboards_mobile_action_pills.dart';
import 'package:powerboards/ui/powerboards_mobile_overlay_header.dart';
import 'package:powerboards/ui/text_validators.dart';

import 'file_upload.dart';

const Set<String> editExtensions = {"md"};
const Set<String> _v1EditableTextExtensions = {'txt', 'text', 'md', 'markdown', 'mdown', 'mkdn', 'rst', 'log', 'csv', 'tsv'};
const String placeholderFileName = ".placeholder";
const double filePaneTableHeaderHeight = 48;

bool _usesAdaptiveMobileLayout(BuildContext context) {
  if (powerboardsUsesDesktopUiPreview(context)) {
    return false;
  }

  return ResponsiveBreakpoints.of(context).isMobile || powerboardsIsLandscapePhoneViewport(context);
}

String _displayFileName(String fileName) {
  return formatTranscriptFileNameForDisplay(fileName);
}

const List<String> _fileSizeUnits = <String>['B', 'KB', 'MB', 'GB', 'TB'];
const int _v1RecentlyOpenedFilesLimit = 7;
const Duration _v1DeleteProcessingStep = Duration(milliseconds: 650);
const Duration _v1SaveProcessingStep = Duration(milliseconds: 850);
const Duration _v1LongActionToastDelay = Duration(milliseconds: 700);
const Duration _downloadArchiveCleanupDelay = Duration(seconds: 30);
const Offset _uploadProgressPopoverOffset = Offset(20, -20);
const String _webServerFolderName = powerboardsWebServerFolderName;
const String _webServerServiceId = powerboardsWebServerServiceId;
const String _webServerFolderIconAssetName = 'folder-code';
const String _webServerUrlVariableName = 'url';
const String _webServerPreviewQueryParameter = 'webserver_preview';
const bool _v1AttachmentsFilesShowWebsiteInstallAction = false;
const String _v1DownloadArchiveStagingFolder = '.powerboards-downloads';
const Set<String> _websitePreviewIgnoredDirectoryNames = <String>{'.cache', '.git', '.npm', '.pnpm-store', 'node_modules'};
const Set<String> _websitePreviewAppProjectFileNames = <String>{
  'angular.json',
  'astro.config.js',
  'astro.config.mjs',
  'next.config.js',
  'next.config.mjs',
  'package.json',
  'remotion.config.js',
  'remotion.config.mjs',
  'vite.config.js',
  'vite.config.mjs',
};
const Set<String> _websitePreviewAppProjectFolderNames = <String>{'node_modules', 'src'};

class _V1MoveDestinationSelection {
  const _V1MoveDestinationSelection({required this.roomName, required this.path, required this.copyFilesInstead});

  final String roomName;
  final String path;
  final bool copyFilesInstead;
}

typedef PowerboardsV1FilePromptRequested =
    FutureOr<void> Function(
      ChatFilePromptAction action,
      String filePath, {
      required bool isFolder,
      required bool responsiveHandoff,
      String? fileDisplayName,
    });

@visibleForTesting
bool powerboardsV1FilePromptShouldCleanupSurfaces({required bool isFolder, required bool responsiveHandoff}) {
  return !isFolder && responsiveHandoff;
}

@visibleForTesting
bool powerboardsV1IsCanonicalWebServerFolder({required bool usesDesktopV1FilesBrowser, required String fullPath, required bool isFolder}) {
  return usesDesktopV1FilesBrowser && isFolder && PendingStorageDeletes.normalizePath(fullPath) == powerboardsWebServerFolderName;
}

@visibleForTesting
Future<bool> powerboardsV1DeleteFolderIfPresent({required Future<bool> Function() exists, required Future<void> Function() delete}) async {
  if (!await exists()) {
    return false;
  }

  try {
    await delete();
    return true;
  } catch (_) {
    if (!await exists()) {
      return false;
    }
    rethrow;
  }
}

class _V1WebsitePreviewState {
  const _V1WebsitePreviewState({required this.entryPath, this.previewHtml, this.previewUrl, required this.title})
    : assert(previewHtml != null || previewUrl != null);

  final String entryPath;
  final String? previewHtml;
  final Uri? previewUrl;
  final String title;
}

@visibleForTesting
bool powerboardsWebsitePreviewShouldUseRoute(Iterable<StorageEntry> entries) {
  var appFileSignals = 0;
  var hasAppFolderSignal = false;
  for (final entry in entries) {
    final normalizedName = entry.name.trim().toLowerCase();
    if (normalizedName.isEmpty) {
      continue;
    }
    if (entry.isFolder) {
      hasAppFolderSignal = hasAppFolderSignal || _websitePreviewAppProjectFolderNames.contains(normalizedName);
      continue;
    }
    if (_websitePreviewAppProjectFileNames.contains(normalizedName)) {
      appFileSignals += 1;
    }
  }
  return appFileSignals > 0 && hasAppFolderSignal;
}

@visibleForTesting
Future<void> powerboardsRefreshFilesWebServerState({
  Resource<List<ServiceSpec>>? services,
  required Resource<List<meshagent_api.Route>> roomRoutes,
}) async {
  await Future.wait<void>([if (services != null) services.refresh(), roomRoutes.refresh()]);
}

const Map<String, String> _powerboardsV1FileTypeKeysByExtension = {
  'thread': 'thread',
  'transcript': 'transcript',
  'widget': 'widget',
  'document': 'document',
  'presentation': 'presentation',
  'gallery': 'image',
  'form': 'document',
};

@visibleForTesting
String? powerboardsV1FileTypeKeyForPath(String path) {
  final extension = p.extension(path).replaceFirst('.', '').toLowerCase();
  if (extension.isEmpty) {
    return null;
  }

  return _powerboardsV1FileTypeKeysByExtension[extension];
}

class _V1TranscriptDocumentPreview extends StatelessWidget {
  const _V1TranscriptDocumentPreview({required this.room, required this.path, required this.file, required this.fullscreen});

  final RoomClient room;
  final String path;
  final PbAttachmentListItemData file;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    return DocumentConnectionScope(
      room: room,
      path: path,
      builder: (context, document, error) {
        if (document == null) {
          if (error != null) {
            return _v1PreviewStatus(file, 'No preview available');
          }

          return _v1PreviewStatus(file, null);
        }

        return ChangeNotifierBuilder(
          source: document,
          builder: (context) {
            final segments = document.root.getElementsByTagName('segment');
            return PbTranscriptPreviewContent(
              data: _v1TranscriptDataFromSegments(context, segments),
              fullscreen: fullscreen,
              emptyStateFile: file,
            );
          },
        );
      },
    );
  }
}

class _V1TextTranscriptPreview extends StatefulWidget {
  const _V1TextTranscriptPreview({
    required this.room,
    required this.path,
    required this.file,
    required this.title,
    required this.fullscreen,
  });

  final RoomClient room;
  final String path;
  final PbAttachmentListItemData file;
  final String title;
  final bool fullscreen;

  @override
  State<_V1TextTranscriptPreview> createState() => _V1TextTranscriptPreviewState();
}

class _V1TextTranscriptPreviewState extends State<_V1TextTranscriptPreview> {
  late Future<String> _textFuture = _loadText();

  @override
  void didUpdateWidget(covariant _V1TextTranscriptPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.room != widget.room || oldWidget.path != widget.path) {
      _textFuture = _loadText();
    }
  }

  Future<String> _loadText() async {
    final content = await widget.room.storage.download(widget.path);
    return utf8.decode(content.data, allowMalformed: true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _textFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _v1PreviewStatus(widget.file, 'No preview available');
        }

        final text = snapshot.data;
        if (text == null) {
          return _v1PreviewStatus(widget.file, null);
        }

        return PbTranscriptPreviewContent(
          data: _v1TranscriptDataFromText(context, text, title: widget.title),
          fullscreen: widget.fullscreen,
          emptyStateFile: widget.file,
        );
      },
    );
  }
}

Widget _v1PreviewStatus(PbAttachmentListItemData file, String? message) {
  if (message == null) {
    return const ColoredBox(
      color: PbColors.surfacePanel,
      child: Center(child: CircularProgressIndicator(color: PbColors.textSubtle)),
    );
  }

  return ColoredBox(
    color: PbColors.surfacePanel,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PbFilePreviewStateCard(file: file, state: PbAttachmentPreviewState.unavailable, label: message),
      ),
    ),
  );
}

class _V1TranscriptMeta {
  const _V1TranscriptMeta({required this.startTime, required this.endTime, required this.participants});

  final DateTime? startTime;
  final DateTime? endTime;
  final List<PbTranscriptPreviewParticipant> participants;

  Duration? get duration {
    final start = startTime;
    final end = endTime;
    if (start == null || end == null) {
      return null;
    }

    return end.difference(start);
  }
}

PbTranscriptPreviewData _v1TranscriptDataFromSegments(BuildContext context, List<MeshElement> segments) {
  final meta = _v1TranscriptMetaFromSegments(segments);
  final turns = <PbTranscriptPreviewTurn>[];

  for (final segment in segments) {
    final text = _v1AttributeString(segment, 'text')?.trim();
    if (text == null || text.isEmpty) {
      continue;
    }

    final participant = _v1TranscriptParticipantForSegment(segment);
    final segmentTime = _v1TryParseSegmentTime(segment);
    final elapsed = segmentTime != null && meta.startTime != null ? segmentTime.difference(meta.startTime!) : Duration.zero;

    turns.add(
      PbTranscriptPreviewTurn(timestamp: _v1FormatTranscriptTimecode(elapsed), speaker: participant?.label ?? 'Speaker', text: text),
    );
  }

  return PbTranscriptPreviewData(
    dateLabel: _v1FormatTranscriptHeaderDate(context, meta.startTime) ?? 'Transcript',
    detailLabel: _v1FormatTranscriptDetail(context, meta),
    participants: meta.participants,
    turns: turns,
  );
}

_V1TranscriptMeta _v1TranscriptMetaFromSegments(List<MeshElement> segments) {
  DateTime? first;
  DateTime? last;
  final participantsByLabel = <String, PbTranscriptPreviewParticipant>{};

  for (final segment in segments) {
    final parsed = _v1TryParseSegmentTime(segment);
    if (parsed != null) {
      first ??= parsed;
      last = parsed;
    }

    final participant = _v1TranscriptParticipantForSegment(segment);
    if (participant != null) {
      participantsByLabel.putIfAbsent(participant.label, () => participant);
    }
  }

  return _V1TranscriptMeta(startTime: first, endTime: last, participants: participantsByLabel.values.toList(growable: false));
}

DateTime? _v1TryParseSegmentTime(MeshElement segment) {
  final value = _v1AttributeString(segment, 'time');
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}

PbTranscriptPreviewParticipant? _v1TranscriptParticipantForSegment(MeshElement segment) {
  final label = _v1AttributeString(segment, 'participant_name')?.trim();
  if (label == null || label.isEmpty) {
    return null;
  }

  final role = _v1AttributeString(segment, 'participant_role')?.trim().toLowerCase();
  return _v1TranscriptParticipant(label: label, role: role);
}

String? _v1AttributeString(MeshElement element, String name) {
  final value = element.getAttribute(name);
  return value is String ? value : null;
}

PbTranscriptPreviewData _v1TranscriptDataFromText(BuildContext context, String text, {required String title}) {
  final cues = _v1ParseCaptionCues(text);
  final participantsByLabel = <String, PbTranscriptPreviewParticipant>{};
  final turns = <PbTranscriptPreviewTurn>[];

  Duration? lastCueStart;
  for (final cue in cues) {
    final speaker = cue.speaker ?? 'Transcript';
    participantsByLabel.putIfAbsent(speaker, () => _v1TranscriptParticipant(label: speaker));
    lastCueStart = cue.start ?? lastCueStart;
    turns.add(
      PbTranscriptPreviewTurn(timestamp: _v1FormatTranscriptTimecode(cue.start ?? Duration.zero), speaker: speaker, text: cue.text),
    );
  }

  final duration = lastCueStart == null ? null : lastCueStart + const Duration(seconds: 1);
  final detailParts = <String>['Transcript'];
  final durationLabel = _v1FormatTranscriptDuration(duration);
  if (durationLabel != null) {
    detailParts.add(durationLabel);
  }

  return PbTranscriptPreviewData(
    dateLabel: title.trim().isEmpty ? 'Transcript' : title.trim(),
    detailLabel: detailParts.join('   '),
    participants: participantsByLabel.values.toList(growable: false),
    turns: turns,
  );
}

class _V1CaptionCue {
  const _V1CaptionCue({required this.start, required this.speaker, required this.text});

  final Duration? start;
  final String? speaker;
  final String text;
}

List<_V1CaptionCue> _v1ParseCaptionCues(String text) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final blocks = normalized.split(RegExp(r'\n\s*\n'));
  final cues = <_V1CaptionCue>[];

  for (final block in blocks) {
    final lines = block
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty && line.trim() != 'WEBVTT')
        .toList(growable: false);
    final timeLineIndex = lines.indexWhere((line) => line.contains('-->'));
    if (timeLineIndex < 0 || timeLineIndex == lines.length - 1) {
      continue;
    }

    final start = _v1ParseCueTimestamp(lines[timeLineIndex].split('-->').first.trim());
    final rawCueText = lines.skip(timeLineIndex + 1).join('\n').trim();
    final cueText = rawCueText.replaceAll(RegExp(r'<[^>]+>'), '').trim();
    if (cueText.isEmpty) {
      continue;
    }

    final parsed = _v1ExtractCaptionSpeaker(cueText);
    cues.add(_V1CaptionCue(start: start, speaker: parsed.$1, text: parsed.$2));
  }

  if (cues.isNotEmpty) {
    return cues;
  }

  final fallbackText = normalized.trim();
  return fallbackText.isEmpty
      ? const <_V1CaptionCue>[]
      : <_V1CaptionCue>[_V1CaptionCue(start: Duration.zero, speaker: null, text: fallbackText)];
}

Duration? _v1ParseCueTimestamp(String value) {
  final timestamp = value.split(RegExp(r'\s+')).first.replaceAll(',', '.');
  final parts = timestamp.split(':');
  if (parts.length < 2 || parts.length > 3) {
    return null;
  }

  final hours = parts.length == 3 ? int.tryParse(parts[0]) : 0;
  final minutes = int.tryParse(parts[parts.length - 2]);
  final seconds = double.tryParse(parts.last);
  if (hours == null || minutes == null || seconds == null) {
    return null;
  }

  return Duration(hours: hours, minutes: minutes, milliseconds: (seconds * 1000).round());
}

(String?, String) _v1ExtractCaptionSpeaker(String cueText) {
  final lines = cueText.split('\n');
  if (lines.isEmpty) {
    return (null, cueText);
  }

  final match = RegExp(r'^([^:\n]{1,80}):\s*(.*)$').firstMatch(lines.first.trim());
  if (match == null) {
    return (null, cueText);
  }

  final speaker = match.group(1)?.trim();
  final firstText = match.group(2)?.trim();
  final remainingLines = <String>[if (firstText != null && firstText.isNotEmpty) firstText, ...lines.skip(1)];
  final text = remainingLines.join('\n').trim();
  return (speaker == null || speaker.isEmpty ? null : speaker, text.isEmpty ? cueText : text);
}

PbTranscriptPreviewParticipant _v1TranscriptParticipant({required String label, String? role}) {
  final normalizedRole = role?.trim().toLowerCase();
  final normalizedLabel = label.trim().toLowerCase();
  final isAgentLike =
      normalizedRole == 'agent' ||
      normalizedRole == 'assistant' ||
      normalizedLabel.contains('assistant') ||
      normalizedLabel.contains('agent');

  return PbTranscriptPreviewParticipant(label: label, initials: _v1TranscriptInitials(label), isAgentLike: isAgentLike);
}

String _v1TranscriptInitials(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return 'U';
  }

  final base = normalized.contains('@') ? normalized.split('@').first : normalized;
  final parts = base.split(RegExp(r'[-._ ]+')).where((part) => part.isNotEmpty).toList(growable: false);
  if (parts.length >= 2) {
    return '${_v1SingleInitial(parts[0])}${_v1SingleInitial(parts[1])}';
  }
  if (parts.length == 1) {
    return _v1SingleInitial(parts.first);
  }

  return 'U';
}

String _v1SingleInitial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'U';
  }

  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

String _v1FormatTranscriptTimecode(Duration elapsed) {
  final totalSeconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  String twoDigits(int value) => value.toString().padLeft(2, '0');

  return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
}

String? _v1FormatTranscriptHeaderDate(BuildContext context, DateTime? startTime) {
  if (startTime == null) {
    return null;
  }

  final local = startTime.toLocal();
  final month = MaterialLocalizations.of(context).formatMonthYear(local).split(' ').first;
  return '$month ${local.day}, ${local.year}';
}

String _v1FormatTranscriptDetail(BuildContext context, _V1TranscriptMeta meta) {
  final detailParts = <String>['Transcript'];
  final time = _v1FormatTranscriptHeaderTime(context, meta.startTime);
  final duration = _v1FormatTranscriptDuration(meta.duration);

  if (time != null && duration != null) {
    detailParts.add('$time - $duration');
  } else if (time != null) {
    detailParts.add(time);
  } else if (duration != null) {
    detailParts.add(duration);
  }

  return detailParts.join('   ');
}

String? _v1FormatTranscriptHeaderTime(BuildContext context, DateTime? startTime) {
  if (startTime == null) {
    return null;
  }

  final local = startTime.toLocal();
  final formatted = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: false);
  return formatted.replaceAll(' AM', 'a').replaceAll(' PM', 'p');
}

String? _v1FormatTranscriptDuration(Duration? duration) {
  if (duration == null) {
    return null;
  }

  final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  if (totalSeconds < 60) {
    return totalSeconds == 1 ? '1 sec' : '$totalSeconds secs';
  }

  final totalMinutes = duration.inMinutes;
  if (totalMinutes < 60) {
    return totalMinutes == 1 ? '1 min' : '$totalMinutes mins';
  }

  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) {
    return hours == 1 ? '1 hr' : '$hours hrs';
  }

  final hoursLabel = hours == 1 ? '1 hr' : '$hours hrs';
  final minutesLabel = minutes == 1 ? '1 min' : '$minutes mins';
  return '$hoursLabel $minutesLabel';
}

String _formatFileSizeBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }

  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < _fileSizeUnits.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  final decimals = value >= 10 || value == value.roundToDouble() ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${_fileSizeUnits[unitIndex]}';
}

String _shellQuote(String value) {
  if (value.isEmpty) {
    return "''";
  }

  return "'${value.replaceAll("'", r"'\''")}'";
}

@visibleForTesting
String powerboardsDownloadArchiveCommand({required String archiveFileName, required Iterable<String> itemNames}) {
  final items = itemNames.toList(growable: false);
  assert(items.isNotEmpty, 'Archive downloads need at least one item.');
  final quotedItems = items.map(_shellQuote).join(' ');
  return "/usr/bin/zip -r ${_shellQuote(archiveFileName)} $quotedItems "
      "-x ${_shellQuote('*/$placeholderFileName')} ${_shellQuote(placeholderFileName)}";
}

String _archiveTimestamp(DateTime createdAt) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');

  return '${createdAt.year}'
      '${twoDigits(createdAt.month)}'
      '${twoDigits(createdAt.day)}-'
      '${twoDigits(createdAt.hour)}'
      '${twoDigits(createdAt.minute)}'
      '${twoDigits(createdAt.second)}';
}

String _archiveSafeStem(String value) {
  final withoutReserved = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
  final normalizedWhitespace = withoutReserved.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalizedWhitespace.isEmpty ? 'download' : normalizedWhitespace;
}

@visibleForTesting
bool powerboardsV1IsDownloadArchiveStagingPath(String path) {
  final normalized = PendingStorageDeletes.normalizePath(path);
  return normalized == _v1DownloadArchiveStagingFolder || normalized.startsWith('$_v1DownloadArchiveStagingFolder/');
}

String _v1DownloadArchiveStagingPath(String archiveFileName) {
  return joinPaths(_v1DownloadArchiveStagingFolder, archiveFileName);
}

@visibleForTesting
String powerboardsDownloadArchiveFileName({required String baseName, required int itemCount, required DateTime createdAt}) {
  final stem = _archiveSafeStem(baseName);
  final countSuffix = itemCount > 1 ? '-$itemCount-items' : '';
  return '$stem$countSuffix-${_archiveTimestamp(createdAt)}.zip';
}

enum FileSortField { name, modified }

enum _FileAction { open, download, share, upload, compressFolder, rename, delete }

@visibleForTesting
List<PbFilesItemData> powerboardsV1RecordRecentlyOpenedFile(
  List<PbFilesItemData> current,
  PbFilesItemData item, {
  int limit = _v1RecentlyOpenedFilesLimit,
}) {
  final next = <PbFilesItemData>[];
  if (item.canPreview) {
    next.add(item);
  }

  for (final opened in current) {
    if (!opened.canPreview || opened.id == item.id) {
      continue;
    }
    next.add(opened);
  }

  return next.take(limit).toList(growable: false);
}

final Map<String, List<PbFilesItemData>> _v1RecentlyOpenedFilesBySession = <String, List<PbFilesItemData>>{};
final Map<String, List<StorageEntry>> _v1FolderEntriesBySession = <String, List<StorageEntry>>{};

String _v1RecentlyOpenedFilesSessionKey({required String? projectId, required String? roomName}) {
  return '${projectId?.trim() ?? ''}\u{1f}${roomName?.trim() ?? ''}';
}

String _v1FolderEntriesSessionKey({required String? projectId, required String? roomName, required String folderPath}) {
  final normalizedFolderPath = folderPath.trim().replaceAll(RegExp(r'/+$'), '');
  return '${_v1RecentlyOpenedFilesSessionKey(projectId: projectId, roomName: roomName)}\u{1f}$normalizedFolderPath';
}

List<PbFilesItemData> _sanitizeV1RecentlyOpenedFiles(List<PbFilesItemData> files) {
  final seen = <String>{};
  return [
    for (final file in files)
      if (file.canPreview && seen.add(file.id)) file,
  ].take(_v1RecentlyOpenedFilesLimit).toList(growable: false);
}

@visibleForTesting
List<PbFilesItemData> powerboardsV1RecentlyOpenedFilesForSession({required String? projectId, required String? roomName}) {
  final key = _v1RecentlyOpenedFilesSessionKey(projectId: projectId, roomName: roomName);
  return List<PbFilesItemData>.of(_v1RecentlyOpenedFilesBySession[key] ?? const <PbFilesItemData>[]);
}

@visibleForTesting
void powerboardsV1SaveRecentlyOpenedFilesForSession({
  required String? projectId,
  required String? roomName,
  required List<PbFilesItemData> files,
}) {
  final key = _v1RecentlyOpenedFilesSessionKey(projectId: projectId, roomName: roomName);
  final sanitized = _sanitizeV1RecentlyOpenedFiles(files);
  if (sanitized.isEmpty) {
    _v1RecentlyOpenedFilesBySession.remove(key);
    return;
  }
  _v1RecentlyOpenedFilesBySession[key] = List<PbFilesItemData>.unmodifiable(sanitized);
}

@visibleForTesting
void powerboardsV1ClearRecentlyOpenedFileSessionCache() {
  _v1RecentlyOpenedFilesBySession.clear();
}

@visibleForTesting
List<StorageEntry>? powerboardsV1FolderEntriesForSession({
  required String? projectId,
  required String? roomName,
  required String folderPath,
}) {
  final key = _v1FolderEntriesSessionKey(projectId: projectId, roomName: roomName, folderPath: folderPath);
  final entries = _v1FolderEntriesBySession[key];
  return entries == null ? null : List<StorageEntry>.of(entries);
}

void _saveV1FolderEntriesForSession({
  required String? projectId,
  required String? roomName,
  required String folderPath,
  required List<StorageEntry> entries,
}) {
  final key = _v1FolderEntriesSessionKey(projectId: projectId, roomName: roomName, folderPath: folderPath);
  _v1FolderEntriesBySession[key] = List<StorageEntry>.unmodifiable(entries);
}

@visibleForTesting
void powerboardsV1SaveFolderEntriesForTesting({
  required String? projectId,
  required String? roomName,
  required String folderPath,
  required List<StorageEntry> entries,
}) {
  _saveV1FolderEntriesForSession(projectId: projectId, roomName: roomName, folderPath: folderPath, entries: entries);
}

@visibleForTesting
void powerboardsV1ClearFolderEntriesSessionCache() {
  _v1FolderEntriesBySession.clear();
}

@visibleForTesting
bool powerboardsV1LiveFolderEntriesMatchRoute({
  required String routeFolder,
  required String activeFolder,
  required String? loadedFolderPath,
}) {
  final normalizedRouteFolder = PendingStorageDeletes.normalizePath(routeFolder);
  final normalizedActiveFolder = PendingStorageDeletes.normalizePath(activeFolder);
  final normalizedLoadedFolder = loadedFolderPath == null ? null : PendingStorageDeletes.normalizePath(loadedFolderPath);
  return normalizedRouteFolder == normalizedActiveFolder && normalizedLoadedFolder == normalizedActiveFolder;
}

@visibleForTesting
bool powerboardsV1FileItemIsSelectable(PbFilesItemData item) {
  return item.kind == PbFilesItemKind.file || item.kind == PbFilesItemKind.folder;
}

@visibleForTesting
Set<String> powerboardsV1SelectedVisibleItemIds(Set<String> selectedIds, Iterable<PbFilesItemData> visibleItems) {
  final visibleIds = {for (final item in visibleItems) item.id};
  return selectedIds.where(visibleIds.contains).toSet();
}

@visibleForTesting
List<PbFilesItemData> powerboardsV1ItemsExcludingReplacementRows(Iterable<PbFilesItemData> items, Set<String> replacementRowIds) {
  return [
    for (final item in items)
      if (!replacementRowIds.contains(item.id)) item,
  ];
}

String _relocatePathForMove(String currentPath, String sourcePath, String destinationPath) {
  if (currentPath == sourcePath) {
    return destinationPath;
  }

  final sourcePrefix = '$sourcePath/';
  if (!currentPath.startsWith(sourcePrefix)) {
    return currentPath;
  }

  final suffix = currentPath.substring(sourcePrefix.length);
  return destinationPath.isEmpty ? suffix : '$destinationPath/$suffix';
}

class _FileLocation {
  final String folder;
  final String? openedFile;

  const _FileLocation({required this.folder, required this.openedFile});

  @override
  bool operator ==(Object other) => other is _FileLocation && other.folder == folder && other.openedFile == openedFile;

  @override
  int get hashCode => Object.hash(folder, openedFile);

  factory _FileLocation.fromUri(Uri uri) {
    final raw = uri.queryParameters['p'] ?? '';

    if (raw.isEmpty) {
      return const _FileLocation(folder: "", openedFile: null);
    }

    final isFolder = raw.endsWith('/');
    final normalizedPath = joinPaths(raw, '');

    if (isFolder) {
      return _FileLocation(folder: normalizedPath, openedFile: null);
    }

    return _FileLocation(folder: parentPath(normalizedPath), openedFile: normalizedPath);
  }
}

class FileSort {
  final FileSortField field;
  final bool ascending;
  const FileSort(this.field, this.ascending);

  int compare(StorageEntry a, StorageEntry b) {
    // folders before files
    if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;

    int cmp;
    switch (field) {
      case FileSortField.name:
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        break;
      case FileSortField.modified:
        final aDate = a.updatedAt;
        final bDate = b.updatedAt;

        if (aDate == null && bDate == null) {
          cmp = 0;
        } else if (aDate == null) {
          cmp = -1;
        } else if (bDate == null) {
          cmp = 1;
        } else {
          cmp = aDate.compareTo(bDate);
        }
        break;
    }

    return ascending ? cmp : -cmp;
  }
}

class _FilePathKey {
  const _FilePathKey._();

  static String pathForEntry(String currentPath, StorageEntry entry) {
    return joinPaths(currentPath, entry.name);
  }

  static String keyForPath(String path, bool isFolder) {
    return isFolder ? '$path/' : path;
  }

  static String keyForEntry(String currentPath, StorageEntry entry) {
    final path = pathForEntry(currentPath, entry);
    return keyForPath(path, entry.isFolder);
  }

  static String pathFromKey(String key) {
    return key.endsWith('/') ? key.substring(0, key.length - 1) : key;
  }

  static bool isFolderKey(String key) => key.endsWith('/');
}

class _PendingDeleteOperation {
  const _PendingDeleteOperation({required this.handle, required this.displayUntil});

  final PendingStorageDeleteHandle handle;
  final DateTime displayUntil;
}

class _DownloadArchiveItem {
  const _DownloadArchiveItem({required this.path, required this.isFolder});

  final String path;
  final bool isFolder;
}

class _PendingArchiveExtractRequest {
  const _PendingArchiveExtractRequest({required this.archivePath, required this.inspection});

  final String archivePath;
  final PbArchiveInspectionResult inspection;
}

class _PendingExtractedArchiveOpenRequest {
  const _PendingExtractedArchiveOpenRequest({required this.target});

  final PowerboardsArchiveExtractionOpenTarget target;
}

class FileManagerViewController {
  Future<void> Function()? _createFolderInCurrentLocation;
  void Function()? _createTextFileInCurrentLocation;
  Future<void> Function()? _addFilesInCurrentLocation;
  Future<void> Function()? _shareOpenedFileInCurrentLocation;
  Future<void> Function(String archivePath, PbArchiveInspectionResult inspection)? _extractArchiveForPreview;
  void Function(PowerboardsArchiveExtractionOpenTarget target)? _openExtractedArchiveForPreview;
  _PendingArchiveExtractRequest? _pendingArchiveExtractRequest;
  _PendingExtractedArchiveOpenRequest? _pendingExtractedArchiveOpenRequest;

  Future<void> createFolderInCurrentLocation() async {
    final action = _createFolderInCurrentLocation;
    if (action == null) {
      return;
    }
    await action();
  }

  void createTextFileInCurrentLocation() {
    _createTextFileInCurrentLocation?.call();
  }

  Future<void> addFilesInCurrentLocation() async {
    final action = _addFilesInCurrentLocation;
    if (action == null) {
      return;
    }
    await action();
  }

  Future<void> shareOpenedFileInCurrentLocation() async {
    final action = _shareOpenedFileInCurrentLocation;
    if (action == null) {
      return;
    }
    await action();
  }

  Future<void> extractArchiveForPreview({required String archivePath, required PbArchiveInspectionResult inspection}) async {
    final action = _extractArchiveForPreview;
    if (action == null) {
      _pendingArchiveExtractRequest = _PendingArchiveExtractRequest(archivePath: archivePath, inspection: inspection);
      return;
    }

    await action(archivePath, inspection);
  }

  void openExtractedArchiveForPreview(PowerboardsArchiveExtractionOpenTarget target) {
    final action = _openExtractedArchiveForPreview;
    if (action == null) {
      _pendingExtractedArchiveOpenRequest = _PendingExtractedArchiveOpenRequest(target: target);
      return;
    }

    action(target);
  }

  void _flushPendingArchiveExtractRequest() {
    final request = _pendingArchiveExtractRequest;
    final action = _extractArchiveForPreview;
    if (request == null || action == null) {
      return;
    }

    _pendingArchiveExtractRequest = null;
    unawaited(action(request.archivePath, request.inspection));
  }

  void _flushPendingExtractedArchiveOpenRequest() {
    final request = _pendingExtractedArchiveOpenRequest;
    final action = _openExtractedArchiveForPreview;
    if (request == null || action == null) {
      return;
    }

    _pendingExtractedArchiveOpenRequest = null;
    action(request.target);
  }
}

class FileManagerView extends StatefulWidget {
  final RoomClient client;
  final String? projectId;
  final Resource<List<ServiceSpec>>? services;
  final bool hideSystem;
  final bool mobileShellOwnsHeader;
  final FileManagerViewController? controller;
  final List<Widget> desktopHeaderLeadingActions;
  final List<Widget> desktopHeaderActions;
  final double desktopHeaderActionLeadingWidthFloor;
  final double desktopHeaderActionMinimumLeadingWidth;
  final double desktopHeaderActionReserve;
  final bool showDesktopSidetrayToggle;
  final bool canInstallServices;
  final bool? v1RoomPanelCollapsed;
  final ValueChanged<bool>? onV1RoomPanelCollapsedChanged;
  final double? v1RoomPanelWidth;
  final ValueChanged<double>? onV1RoomPanelWidthChanged;
  final PowerboardsV1FilePromptRequested? onV1FilePromptRequested;
  final VoidCallback? onServiceChanged;

  const FileManagerView({
    super.key,
    required this.client,
    this.projectId,
    this.services,
    this.hideSystem = false,
    this.mobileShellOwnsHeader = false,
    this.controller,
    this.desktopHeaderLeadingActions = const [],
    this.desktopHeaderActions = const [],
    this.desktopHeaderActionLeadingWidthFloor = 0,
    this.desktopHeaderActionMinimumLeadingWidth = 0,
    this.desktopHeaderActionReserve = desktopPaneHeaderActionReserve,
    this.showDesktopSidetrayToggle = true,
    this.canInstallServices = false,
    this.v1RoomPanelCollapsed,
    this.onV1RoomPanelCollapsedChanged,
    this.v1RoomPanelWidth,
    this.onV1RoomPanelWidthChanged,
    this.onV1FilePromptRequested,
    this.onServiceChanged,
  });

  @override
  State<FileManagerView> createState() => _FileManagerViewState();
}

class _FileManagerViewState extends State<FileManagerView> {
  static TextStyle breadcrumbLinkStyle = powerboardsSectionTitleStyle();
  static const String _threadIndexFileName = 'index.threadl';

  _FileLocation _location = const _FileLocation(folder: "", openedFile: null);
  String? get _openedFile => _location.openedFile;
  bool _isDisposing = false;
  bool get _canUpdateUi => mounted && !_isDisposing;

  bool _forceShowSelect = false;
  String _tab = 'preview';
  final popoverController = ShadPopoverController();
  final ShadContextMenuController _collapsedBreadcrumbMenuController = ShadContextMenuController();
  final CodePreviewController _codePreviewController = CodePreviewController();
  late final uploadNotifications = UploadProgressNotifications(popoverController: popoverController);
  final Set<String> _optimisticEmptyTextFiles = <String>{};
  final Set<String> _threadTitleResolutionsInFlight = <String>{};
  MeshDocument? _threadIndexDocument;
  String? _threadIndexPath;
  Map<String, String> _threadDisplayNamesByPath = const <String, String>{};
  bool _installingWebServer = false;

  late StreamSubscription<RoomEvent> roomSub;

  late final _folderSig = Signal<String>(_location.folder);
  final _sortSig = Signal<FileSort>(const FileSort(FileSortField.name, true));
  final _selectedSig = Signal<Set<String>>(<String>{});
  final TextEditingController _v1FilterController = TextEditingController();
  final OverlayPortalController _v1FilesRoomPanelOverlayController = OverlayPortalController();
  final FocusNode _v1FilesKeyboardFocusNode = FocusNode(debugLabel: 'Files keyboard navigation');
  PbFilesSortKey _v1SortKey = PbFilesSortKey.updated;
  bool _v1SortDirectionDescending = true;
  bool _v1FilesRoomPanelCollapsed = false;
  bool _v1FilesRoomPanelOverlayOpen = false;
  bool _v1FilePreviewFullscreen = false;
  bool _v1RestoreRoomPanelOverlayOnPreviewClose = false;
  String? _v1KeyboardPreviewFileId;
  int _v1KeyboardPreviewDirection = 0;
  bool _v1FilesKeyboardBrowseArmed = false;
  final ValueNotifier<bool> _v1FilesDropTargetActive = ValueNotifier(false);
  PbFilesItemData? _v1PreviewFile;
  _V1WebsitePreviewState? _v1WebsitePreview;
  String? _v1PreviewDraftPath;
  String? _v1PreviewDraftText;
  List<PbFilesItemData> _v1RecentlyOpenedFiles = const <PbFilesItemData>[];
  final Set<String> _v1SavingFileIds = <String>{};
  final Set<String> _v1ExtractingArchivePaths = <String>{};
  final Map<String, PbFilesItemData> _v1FileStateRowsById = <String, PbFilesItemData>{};
  final Map<String, Future<String>> _v1DownloadUrlFuturesByPath = <String, Future<String>>{};
  String? _v1LoadedFolderPath;
  List<PowerboardsFileAttachmentLink> _fileAttachmentLinks = const <PowerboardsFileAttachmentLink>[];
  final Map<String, String> _fileCreatorNamesByPath = <String, String>{};
  final Map<String, DateTime> _v1DownloadUrlExpiresAtByPath = <String, DateTime>{};

  PendingStorageDeleteScope get _deleteScope => PendingStorageDeleteScope(projectId: widget.projectId, roomName: widget.client.roomName);
  bool get _effectiveV1FilesRoomPanelCollapsed => widget.v1RoomPanelCollapsed ?? _v1FilesRoomPanelCollapsed;

  void _setV1FilesRoomPanelCollapsed(bool collapsed) {
    if (widget.v1RoomPanelCollapsed != null) {
      if (widget.v1RoomPanelCollapsed != collapsed) {
        widget.onV1RoomPanelCollapsedChanged?.call(collapsed);
      }
      return;
    }

    if (_v1FilesRoomPanelCollapsed == collapsed) {
      return;
    }

    setState(() => _v1FilesRoomPanelCollapsed = collapsed);
  }

  void _setV1FilesDropTargetActive(bool active) {
    if (_isDisposing || _v1FilesDropTargetActive.value == active) {
      return;
    }

    _v1FilesDropTargetActive.value = active;
  }

  bool _isDeletePending(String path, bool isFolder) {
    return PendingStorageDeletes.contains(scope: _deleteScope, path: path, isFolder: isFolder);
  }

  bool _usesDesktopV1FilesBrowser() {
    return mounted && !_usesAdaptiveMobileLayout(context) && powerboardsUsesDesktopUiPreview(context);
  }

  bool _usesResponsiveV1FilePromptHandoff() {
    return _usesDesktopV1FilesBrowser() && MediaQuery.sizeOf(context).width <= pbRoomPanelStackBreakpoint;
  }

  bool _v1DeleteCoversPath({required String deletePath, required bool isFolder, required String candidatePath}) {
    final normalizedDeletePath = PendingStorageDeletes.normalizePath(deletePath);
    final normalizedCandidatePath = PendingStorageDeletes.normalizePath(candidatePath);
    if (normalizedDeletePath == normalizedCandidatePath) {
      return true;
    }

    return isFolder && normalizedDeletePath.isNotEmpty && normalizedCandidatePath.startsWith('$normalizedDeletePath/');
  }

  bool _v1StateRowMatchesPath(PbFilesItemData item, String path, {required bool isFolder}) {
    final normalizedPath = PendingStorageDeletes.normalizePath(path);
    return item.id == _FilePathKey.keyForPath(path, isFolder) || item.id.startsWith('upload-error:$normalizedPath:');
  }

  void _prepareV1PendingDeleteFeedback(Iterable<String> keys) {
    if (!_usesDesktopV1FilesBrowser()) {
      return;
    }

    final targets = [for (final key in keys) (path: _FilePathKey.pathFromKey(key), isFolder: _FilePathKey.isFolderKey(key))];
    if (targets.isEmpty) {
      return;
    }

    final closesPreviewFile =
        _v1PreviewFile != null &&
        targets.any(
          (target) =>
              _v1DeleteCoversPath(deletePath: target.path, isFolder: target.isFolder, candidatePath: _v1PathForItem(_v1PreviewFile!)),
        );
    final closesWebsitePreview =
        _v1WebsitePreview != null &&
        targets.any(
          (target) => _v1DeleteCoversPath(deletePath: target.path, isFolder: target.isFolder, candidatePath: _v1WebsitePreview!.entryPath),
        );
    final closesOpenedFile =
        _openedFile != null &&
        targets.any((target) => _v1DeleteCoversPath(deletePath: target.path, isFolder: target.isFolder, candidatePath: _openedFile!));
    final nextRecentlyOpenedFiles = [
      for (final item in _v1RecentlyOpenedFiles)
        if (!targets.any(
          (target) => _v1DeleteCoversPath(deletePath: target.path, isFolder: target.isFolder, candidatePath: _v1PathForItem(item)),
        ))
          item,
    ];
    final recentFilesChanged = nextRecentlyOpenedFiles.length != _v1RecentlyOpenedFiles.length;
    final stateRowKeys = keys.toSet();
    final stateRowsChanged = stateRowKeys.any(_v1FileStateRowsById.containsKey);

    if (closesPreviewFile || closesWebsitePreview || closesOpenedFile || recentFilesChanged || stateRowsChanged) {
      setState(() {
        if (stateRowsChanged) {
          _v1FileStateRowsById.removeWhere((key, _) => stateRowKeys.contains(key));
        }

        if (recentFilesChanged) {
          _replaceV1RecentlyOpenedFiles(nextRecentlyOpenedFiles);
        }

        if (closesPreviewFile || closesWebsitePreview || closesOpenedFile) {
          if (_v1PreviewDraftPath != null &&
              targets.any(
                (target) => _v1DeleteCoversPath(deletePath: target.path, isFolder: target.isFolder, candidatePath: _v1PreviewDraftPath!),
              )) {
            _clearV1PreviewDraft();
          }
          _v1PreviewFile = null;
          _v1WebsitePreview = null;
          _v1FilePreviewFullscreen = false;
          _v1FilesRoomPanelOverlayOpen = false;
          _v1RestoreRoomPanelOverlayOnPreviewClose = false;
          setPreviewFilePreviewFullscreen(false);
        }
      });
    }

    if (closesOpenedFile) {
      _closeFile();
    }
  }

  Future<void> _waitForV1PendingDeleteDisplay(DateTime displayUntil) async {
    final shouldHoldForFeedback = _usesDesktopV1FilesBrowser();
    if (!shouldHoldForFeedback) {
      return;
    }

    await WidgetsBinding.instance.endOfFrame;
    final remaining = displayUntil.difference(DateTime.now());
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  late final storageEntries = Resource<List<StorageEntry>>(() => _getChildren(_folderSig.value), source: _folderSig);
  late final roomRoutes = Resource<List<meshagent_api.Route>>(() async {
    final projectId = widget.projectId;
    final roomName = widget.client.roomName?.trim();
    if (projectId == null || roomName == null || roomName.isEmpty) {
      return const <meshagent_api.Route>[];
    }

    return await powerboards_meshagent.getMeshagentClient().listRoomRoutes(projectId: projectId, roomName: roomName);
  });

  List<StorageEntry> _storageEntriesSnapshot() {
    return storageEntries.state.when(
      loading: () => _v1CachedFolderEntries(_folderSig.value) ?? const <StorageEntry>[],
      error: (_, _) => _v1CachedFolderEntries(_folderSig.value) ?? const <StorageEntry>[],
      ready: (entries) => entries,
    );
  }

  List<StorageEntry>? _currentFolderEntriesForMutation() {
    return storageEntries.state.asReady?.value ?? _v1CachedFolderEntries(_folderSig.value);
  }

  late final _visibleSortedEntries = Computed<List<StorageEntry>>(() {
    final entries = _storageEntriesSnapshot();
    final sort = _sortSig.value;

    var visible = entries;
    if (widget.hideSystem) {
      visible = visible.where((e) => !e.name.startsWith('.')).toList();
    }

    final sorted = List<StorageEntry>.from(visible)..sort(sort.compare);
    return sorted;
  });

  late final _visibleKeys = Computed<Set<String>>(() {
    final folder = _folderSig.value;
    final entries = _visibleSortedEntries.value;

    return entries.map((e) => _FilePathKey.keyForEntry(folder, e)).toSet();
  });

  late final _visibleSelected = Computed<Set<String>>(() {
    final raw = _selectedSig.value;
    final visible = _visibleKeys.value;
    // intersection
    return raw.where(visible.contains).toSet();
  });

  late final _visibleSortedFiles = Computed<List<String>>(() {
    final sorted = _visibleSortedEntries.value;
    final folder = _folderSig.value;
    return sorted.where((e) => !e.isFolder).map((e) => joinPaths(folder, e.name)).toList(growable: false);
  });

  @override
  void initState() {
    super.initState();
    _restoreV1RecentlyOpenedFilesFromSession();
    roomSub = widget.client.listen(_onRoomEvent);
    _bindController(widget.controller);
    unawaited(_rebindThreadIndexDocument());
    unawaited(_refreshFileAttachmentLinks());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setLocation();
  }

  @override
  void didUpdateWidget(covariant FileManagerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _unbindController(oldWidget.controller);
      _bindController(widget.controller);
    }
    if (oldWidget.projectId != widget.projectId || oldWidget.client.roomName != widget.client.roomName) {
      _restoreV1RecentlyOpenedFilesFromSession();
    }
  }

  @override
  void dispose() {
    _unbindController(widget.controller);
    _isDisposing = true;
    if (previewFilePreviewFullscreenListenable.value) {
      setPreviewFilePreviewFullscreen(false);
    }
    roomSub.cancel();

    uploadNotifications.dispose();
    _v1FilterController.dispose();
    _v1FilesKeyboardFocusNode.dispose();
    _v1FilesDropTargetActive.dispose();
    _collapsedBreadcrumbMenuController.dispose();
    popoverController.dispose();
    _codePreviewController.dispose();

    _visibleSortedFiles.dispose();
    _visibleSelected.dispose();
    _visibleKeys.dispose();
    _visibleSortedEntries.dispose();

    storageEntries.dispose();
    roomRoutes.dispose();
    _sortSig.dispose();
    _selectedSig.dispose();
    _folderSig.dispose();
    unawaited(_closeThreadIndexDocument(refreshUi: false));

    widget.client.localParticipant?.setAttribute("current_file", null);
    super.dispose();
  }

  void _restoreV1RecentlyOpenedFilesFromSession() {
    _v1RecentlyOpenedFiles = powerboardsV1RecentlyOpenedFilesForSession(projectId: widget.projectId, roomName: widget.client.roomName);
  }

  void _replaceV1RecentlyOpenedFiles(List<PbFilesItemData> files) {
    final sanitized = _sanitizeV1RecentlyOpenedFiles(files);
    _v1RecentlyOpenedFiles = sanitized;
    powerboardsV1SaveRecentlyOpenedFilesForSession(projectId: widget.projectId, roomName: widget.client.roomName, files: sanitized);
  }

  List<StorageEntry>? _v1CachedFolderEntries(String folderPath) {
    return powerboardsV1FolderEntriesForSession(projectId: widget.projectId, roomName: widget.client.roomName, folderPath: folderPath);
  }

  void _saveV1FolderEntries(String folderPath, List<StorageEntry> entries) {
    _saveV1FolderEntriesForSession(projectId: widget.projectId, roomName: widget.client.roomName, folderPath: folderPath, entries: entries);
  }

  String _v1DownloadUrlCacheKey(String path) {
    return path.split('/').where((segment) => segment.isNotEmpty).join('/');
  }

  bool _v1DownloadUrlCacheKeyMatchesPath(String key, String path) {
    final normalizedPath = _v1DownloadUrlCacheKey(path);
    if (normalizedPath.isEmpty) {
      return true;
    }

    return key == normalizedPath || key.startsWith('$normalizedPath/');
  }

  void _clearV1DownloadUrlCacheForPath(String path) {
    final normalizedPath = _v1DownloadUrlCacheKey(path);
    if (normalizedPath.isEmpty) {
      _v1DownloadUrlFuturesByPath.clear();
      _v1DownloadUrlExpiresAtByPath.clear();
      return;
    }

    _v1DownloadUrlFuturesByPath.removeWhere((key, _) => _v1DownloadUrlCacheKeyMatchesPath(key, normalizedPath));
    _v1DownloadUrlExpiresAtByPath.removeWhere((key, _) => _v1DownloadUrlCacheKeyMatchesPath(key, normalizedPath));
  }

  void _moveV1DownloadUrlCache(String sourcePath, String destinationPath) {
    final sourceKey = _v1DownloadUrlCacheKey(sourcePath);
    final destinationKey = _v1DownloadUrlCacheKey(destinationPath);
    if (sourceKey.isEmpty || destinationKey.isEmpty) {
      _clearV1DownloadUrlCacheForPath(sourcePath);
      _clearV1DownloadUrlCacheForPath(destinationPath);
      return;
    }

    _v1DownloadUrlFuturesByPath.removeWhere((key, _) {
      return _v1DownloadUrlCacheKeyMatchesPath(key, sourceKey) || _v1DownloadUrlCacheKeyMatchesPath(key, destinationKey);
    });
    _v1DownloadUrlExpiresAtByPath.removeWhere((key, _) {
      return _v1DownloadUrlCacheKeyMatchesPath(key, sourceKey) || _v1DownloadUrlCacheKeyMatchesPath(key, destinationKey);
    });
  }

  void _bindController(FileManagerViewController? controller) {
    if (controller == null) {
      return;
    }

    controller._createFolderInCurrentLocation = () => _addFolder(_folderSig.value);
    controller._createTextFileInCurrentLocation = _showNewTextFileDialog;
    controller._addFilesInCurrentLocation = () => _addFiles(_folderSig.value);
    controller._extractArchiveForPreview = _extractV1ArchiveForPreviewPath;
    controller._openExtractedArchiveForPreview = _openV1ExtractedArchiveForPreview;
    controller._shareOpenedFileInCurrentLocation = () async {
      final openedFile = _openedFile;
      if (openedFile == null || !supportsNativeFileShare) {
        return;
      }
      await _shareFile(openedFile);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.controller != controller) {
        return;
      }

      controller._flushPendingArchiveExtractRequest();
      controller._flushPendingExtractedArchiveOpenRequest();
    });
  }

  void _unbindController(FileManagerViewController? controller) {
    if (controller == null) {
      return;
    }

    controller._createFolderInCurrentLocation = null;
    controller._createTextFileInCurrentLocation = null;
    controller._addFilesInCurrentLocation = null;
    controller._extractArchiveForPreview = null;
    controller._openExtractedArchiveForPreview = null;
    controller._shareOpenedFileInCurrentLocation = null;
  }

  void _setLocation() {
    final uri = PathRouteMatch.of(context).uri;
    final next = _FileLocation.fromUri(uri);
    if (_location == next) return;

    final folderChanged = _location.folder != next.folder;
    final openedFileChanged = _location.openedFile != next.openedFile;
    final closesPreviewForFolder = next.openedFile == null && (folderChanged || openedFileChanged);

    if (folderChanged) {
      _folderSig.value = next.folder;
      _v1LoadedFolderPath = null;
      _v1WebsitePreview = null;
      _selectedSig.value = <String>{};
      _forceShowSelect = false;
      unawaited(_rebindThreadIndexDocument());
    }

    if (openedFileChanged) {
      _forceShowSelect = false;
      widget.client.localParticipant?.setAttribute("current_file", next.openedFile);
      if (next.openedFile != null) {
        unawaited(_refreshCurrentFolder());
      }
    }

    setState(() {
      if (closesPreviewForFolder) {
        if (_v1PreviewFile != null) {
          _clearV1PreviewDraftForItem(_v1PreviewFile);
        }
        _v1PreviewFile = null;
        _v1FilePreviewFullscreen = false;
        _v1FilesRoomPanelOverlayOpen = false;
        _v1RestoreRoomPanelOverlayOnPreviewClose = false;
      }
      if (openedFileChanged) {
        _tab = 'preview';
      }
      if (folderChanged || openedFileChanged) {
        _clearV1KeyboardPreviewNavigationState();
      }
      _location = next;
    });
    if (closesPreviewForFolder) {
      setPreviewFilePreviewFullscreen(false);
    }
  }

  void _onRoomEvent(RoomEvent event) {
    if (event is FileUpdatedEvent) {
      _rememberFileCreator(event.path, event.participantId);
      if (normalizePowerboardsAttachmentPath(event.path) == powerboardsFileAttachmentIndexPath) {
        unawaited(_refreshFileAttachmentLinks());
      }
      _onFileUpdated(event.path);
      return;
    }

    if (event is FileDeletedEvent) {
      if (normalizePowerboardsAttachmentPath(event.path) == powerboardsFileAttachmentIndexPath) {
        unawaited(_refreshFileAttachmentLinks());
      }
      _onFileDeleted(event.path);
      return;
    }

    if (event is FileMovedEvent) {
      _moveFileCreatorState(event.sourcePath, event.destinationPath);
      _onFileMoved(event.sourcePath, event.destinationPath);
    }
  }

  void _moveFileCreatorState(String sourcePath, String destinationPath) {
    final creator = _fileCreatorNamesByPath.remove(normalizePowerboardsAttachmentPath(sourcePath));
    if (creator == null) {
      return;
    }
    _fileCreatorNamesByPath[normalizePowerboardsAttachmentPath(destinationPath)] = creator;
  }

  void _removeV1RecentlyOpenedPath(String path) {
    final key = _FilePathKey.keyForPath(path, false);
    if (!_v1RecentlyOpenedFiles.any((item) => item.id == key)) {
      return;
    }

    setState(() {
      _replaceV1RecentlyOpenedFiles([
        for (final item in _v1RecentlyOpenedFiles)
          if (item.id != key) item,
      ]);
    });
  }

  void _onFileUpdated(String path) {
    _clearV1DownloadUrlCacheForPath(path);
    final ready = storageEntries.state.asReady;
    if (ready == null) return; // ignore if loading/error

    final name = path.split('/').where((s) => s.isNotEmpty).last;
    final next = List<StorageEntry>.of(ready.value);
    final now = DateTime.now();
    final fileParent = parentPath(path);

    if (fileParent != _folderSig.value) {
      if (parentPath(fileParent) == _folderSig.value) {
        final parentName = fileParent.split('/').where((s) => s.isNotEmpty).last;
        final idx = next.indexWhere((e) => e.name == parentName);
        if (idx == -1) {
          next.add(StorageEntry(name: parentName, isFolder: true, size: null, createdAt: now, updatedAt: null));
          _setEntries(next);
        }
      }
      return;
    }

    final idx = next.indexWhere((e) => e.name == name);
    _v1FileStateRowsById.removeWhere((_, item) => _v1StateRowMatchesPath(item, path, isFolder: false));
    if (idx == -1) {
      next.add(StorageEntry(name: name, isFolder: false, size: null, createdAt: now, updatedAt: now));
      unawaited(_refreshCurrentFolder());
    } else {
      final old = next[idx];
      next[idx] = StorageEntry(name: name, isFolder: false, size: old.size, createdAt: old.createdAt, updatedAt: now);
      if (old.size == null || old.size == 0) {
        unawaited(_refreshCurrentFolder());
      }
    }

    _setEntries(next);
  }

  void _onFileDeleted(String path) {
    _clearV1DownloadUrlCacheForPath(path);
    if (parentPath(path) != _folderSig.value) {
      return;
    }

    final entries = _currentFolderEntriesForMutation();
    if (entries == null) return; // ignore if loading/error without cache

    final name = path.split('/').where((s) => s.isNotEmpty).last;
    final next = List<StorageEntry>.of(entries);
    next.removeWhere((e) => e.name == name);
    _v1FileStateRowsById.removeWhere((_, item) => _v1StateRowMatchesPath(item, path, isFolder: false));
    final previewFile = _v1PreviewFile;
    final closesWebsitePreview = _v1WebsitePreview?.entryPath == path;
    if ((previewFile != null && _v1PathForItem(previewFile) == path) || closesWebsitePreview) {
      _v1PreviewFile = null;
      _v1WebsitePreview = null;
      _v1FilePreviewFullscreen = false;
      _v1FilesRoomPanelOverlayOpen = false;
      _v1RestoreRoomPanelOverlayOnPreviewClose = false;
      setPreviewFilePreviewFullscreen(false);
    }
    _toggleSelected(_FilePathKey.keyForPath(path, false), false);
    _optimisticEmptyTextFiles.remove(path);
    _removeV1RecentlyOpenedPath(path);

    _setEntries(next);
  }

  bool _replaceLocationForMove(String sourcePath, String destinationPath) {
    final nextFolder = _relocatePathForMove(_location.folder, sourcePath, destinationPath);
    final openedFile = _location.openedFile;
    final nextOpenedFile = openedFile == null ? null : _relocatePathForMove(openedFile, sourcePath, destinationPath);

    if (nextFolder == _location.folder && nextOpenedFile == _location.openedFile) {
      return false;
    }

    _openEntry(nextOpenedFile ?? nextFolder, nextOpenedFile == null);
    return true;
  }

  void _moveSelectedPaths(String sourcePath, String destinationPath) {
    _mutateSelected((selected) {
      return selected.map((key) {
        final isFolder = _FilePathKey.isFolderKey(key);
        final movedPath = _relocatePathForMove(_FilePathKey.pathFromKey(key), sourcePath, destinationPath);
        return _FilePathKey.keyForPath(movedPath, isFolder);
      }).toSet();
    });
  }

  void _moveOptimisticPaths(String sourcePath, String destinationPath) {
    if (_optimisticEmptyTextFiles.isEmpty) {
      return;
    }

    final movedPaths = _optimisticEmptyTextFiles.map((path) => _relocatePathForMove(path, sourcePath, destinationPath)).toSet();
    _optimisticEmptyTextFiles
      ..clear()
      ..addAll(movedPaths);
  }

  void _moveThreadDisplayNameState(String sourcePath, String destinationPath) {
    if (_threadDisplayNamesByPath.isEmpty && _threadTitleResolutionsInFlight.isEmpty) {
      return;
    }

    String relocate(String path) => _relocatePathForMove(path, sourcePath, destinationPath);

    final nextDisplayNames = <String, String>{for (final entry in _threadDisplayNamesByPath.entries) relocate(entry.key): entry.value};
    final nextInFlight = _threadTitleResolutionsInFlight.map(relocate).toSet();

    if (!_canUpdateUi) {
      _threadDisplayNamesByPath = nextDisplayNames;
      _threadTitleResolutionsInFlight
        ..clear()
        ..addAll(nextInFlight);
      return;
    }

    final displayNamesChanged = !mapEquals(_threadDisplayNamesByPath, nextDisplayNames);
    final inFlightChanged =
        _threadTitleResolutionsInFlight.length != nextInFlight.length || !_threadTitleResolutionsInFlight.containsAll(nextInFlight);

    if (!displayNamesChanged && !inFlightChanged) {
      return;
    }

    setState(() {
      _threadDisplayNamesByPath = nextDisplayNames;
    });
    _threadTitleResolutionsInFlight
      ..clear()
      ..addAll(nextInFlight);
  }

  void _onFileMoved(String sourcePath, String destinationPath) {
    _moveV1DownloadUrlCache(sourcePath, destinationPath);
    _removeV1RecentlyOpenedPath(sourcePath);
    _moveSelectedPaths(sourcePath, destinationPath);
    _moveOptimisticPaths(sourcePath, destinationPath);
    _moveThreadDisplayNameState(sourcePath, destinationPath);

    if (_replaceLocationForMove(sourcePath, destinationPath)) {
      return;
    }

    final currentFolder = _folderSig.value;
    if (parentPath(sourcePath) == currentFolder || parentPath(destinationPath) == currentFolder) {
      unawaited(_refreshCurrentFolder());
    }
  }

  String? _threadIndexPathForFolder(String folder) {
    final trimmed = folder.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return joinPaths(trimmed, _threadIndexFileName);
  }

  String _displayNameForPath(String path) {
    final fileName = path.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? path;
    if (isThreadPath(path)) {
      final normalizedPath = normalizeThreadStoragePath(path);
      return threadFileDisplayNameFromPath(path, threadDisplayName: _threadDisplayNamesByPath[normalizedPath]);
    }
    return _displayFileName(fileName);
  }

  String _displayNameForEntry(StorageEntry entry) {
    final path = joinPaths(_folderSig.value, entry.name);
    return entry.isFolder ? entry.name : _displayNameForPath(path);
  }

  Future<void> _refreshFileAttachmentLinks() async {
    final links = await loadPowerboardsFileAttachmentLinks(widget.client);
    if (!_canUpdateUi) {
      return;
    }

    setState(() {
      _fileAttachmentLinks = links;
    });
  }

  String? _participantDisplayNameForId(String participantId) {
    final localParticipant = widget.client.localParticipant;
    if (localParticipant != null && localParticipant.id == participantId) {
      final name = localParticipant.getAttribute("name");
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
    }

    for (final participant in widget.client.messaging.remoteParticipants) {
      if (participant.id != participantId) {
        continue;
      }

      final name = participant.getAttribute("name");
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
    }

    return null;
  }

  void _rememberFileCreator(String path, String participantId) {
    final name = _participantDisplayNameForId(participantId);
    if (name == null) {
      return;
    }

    _fileCreatorNamesByPath[normalizePowerboardsAttachmentPath(path)] = name;
  }

  String _fallbackCreatorName() {
    final name = widget.client.localParticipant?.getAttribute("name");
    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }
    return 'Unknown';
  }

  List<PowerboardsFileAttachmentLink> _fileAttachmentLinksForPath(String path) {
    final normalizedPath = normalizePowerboardsAttachmentPath(path);
    final links = _fileAttachmentLinks.where((link) => link.filePath == normalizedPath).toList()
      ..sort((left, right) {
        final rightCreatedAt = right.createdAt?.millisecondsSinceEpoch ?? 0;
        final leftCreatedAt = left.createdAt?.millisecondsSinceEpoch ?? 0;
        return rightCreatedAt.compareTo(leftCreatedAt);
      });
    return links;
  }

  List<String> _linkedThreadNamesForPath(String path) {
    final seen = <String>{};
    final names = <String>[];
    for (final link in _fileAttachmentLinksForPath(path)) {
      final name = link.threadDisplayName.trim();
      final key = name.toLowerCase();
      if (name.isEmpty || seen.contains(key)) {
        continue;
      }

      seen.add(key);
      names.add(name);
    }
    return names;
  }

  String _creatorNameForPath(String path) {
    final normalizedPath = normalizePowerboardsAttachmentPath(path);
    final creator = _fileCreatorNamesByPath[normalizedPath];
    if (creator != null && creator.trim().isNotEmpty) {
      return creator.trim();
    }

    for (final link in _fileAttachmentLinksForPath(path)) {
      final attachedBy = link.createdBy.trim();
      if (attachedBy.isNotEmpty) {
        return attachedBy;
      }
    }

    return _fallbackCreatorName();
  }

  String _creatorInitialsForName(String creator) {
    final parts = creator.trim().split(RegExp(r'[\s@._-]+')).where((part) => part.trim().isNotEmpty).toList(growable: false);
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    final compact = creator.trim().replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (compact.isEmpty) {
      return '?';
    }
    return compact.substring(0, math.min(2, compact.length)).toUpperCase();
  }

  void _openV1LinkedThread(PbFilesItemData item, String threadName) {
    final target = _fileAttachmentLinksForPath(
      _v1PathForItem(item),
    ).firstWhereOrNull((link) => link.threadDisplayName.toLowerCase() == threadName.toLowerCase());
    if (target == null) {
      return;
    }

    _openEntry(target.threadPath, false);
  }

  String _v1UpdatedLabel(StorageEntry entry) {
    return entry.updatedAt?.modified() ?? entry.createdAt?.modified() ?? '';
  }

  int _v1UpdatedSort(StorageEntry entry) {
    return (entry.updatedAt ?? entry.createdAt)?.millisecondsSinceEpoch ?? 0;
  }

  String _v1SizeLabel(StorageEntry entry) {
    if (entry.isFolder) {
      return '-';
    }

    final size = entry.size;
    if (size == null) {
      return '-';
    }

    return _formatFileSizeBytes(size);
  }

  int _v1SizeSort(StorageEntry entry) {
    if (entry.isFolder) {
      return -1;
    }

    return entry.size ?? 0;
  }

  PbFilesItemData _v1ItemForEntry(StorageEntry entry) {
    final folder = _folderSig.value;
    final fullPath = _FilePathKey.pathForEntry(folder, entry);
    final key = _FilePathKey.keyForEntry(folder, entry);
    final updatedLabel = _v1UpdatedLabel(entry);
    final updatedSort = _v1UpdatedSort(entry);
    final sizeLabel = _v1SizeLabel(entry);
    final sizeSort = _v1SizeSort(entry);
    final creator = _creatorNameForPath(fullPath);
    final creatorInitials = _creatorInitialsForName(creator);

    if (entry.isFolder) {
      final isWebsiteFolder = folder.isEmpty && entry.name == _webServerFolderName;
      final presentAsWebServer = isWebsiteFolder && _hasInstalledWebServer;
      return PbFilesItemData(
        id: key,
        title: presentAsWebServer ? _webServerDisplayLabel() : entry.name,
        type: PbAttachmentFileType.folder.defaultDisplayLabel,
        sizeLabel: sizeLabel,
        sizeSort: sizeSort,
        thread: '',
        creator: creator,
        creatorInitials: creatorInitials,
        updatedLabel: updatedLabel,
        updatedSort: updatedSort,
        parentPath: folder,
        folderPath: fullPath,
        fileType: PbAttachmentFileType.folder,
        kind: PbFilesItemKind.folder,
        iconAssetNameOverride: presentAsWebServer ? _webServerFolderIconAssetName : null,
        renameActionLabelOverride: presentAsWebServer ? 'Rename' : null,
      );
    }

    final linkedThreads = _linkedThreadNamesForPath(fullPath);
    return PbFilesItemData.fromFileName(
      id: key,
      title: _displayNameForEntry(entry),
      thread: linkedThreads.firstOrNull ?? '',
      linkedThreads: linkedThreads,
      sizeLabel: sizeLabel,
      sizeSort: sizeSort,
      creator: creator,
      creatorInitials: creatorInitials,
      updatedLabel: updatedLabel,
      updatedSort: updatedSort,
      parentPath: folder,
      path: fullPath,
      fileTypeKey: powerboardsV1FileTypeKeyForPath(fullPath),
      previewState: powerboardsV1PreviewStateForPath(fullPath),
    );
  }

  PbFilesItemData _v1ItemForPath(String fullPath) {
    final linkedThreads = _linkedThreadNamesForPath(fullPath);
    final creator = _creatorNameForPath(fullPath);

    return PbFilesItemData.fromFileName(
      id: _FilePathKey.keyForPath(fullPath, false),
      title: _displayNameForPath(fullPath),
      thread: linkedThreads.firstOrNull ?? '',
      linkedThreads: linkedThreads,
      sizeLabel: '-',
      sizeSort: 0,
      creator: creator,
      creatorInitials: _creatorInitialsForName(creator),
      updatedLabel: '',
      updatedSort: 0,
      parentPath: parentPath(fullPath),
      path: fullPath,
      fileTypeKey: powerboardsV1FileTypeKeyForPath(fullPath),
      previewState: powerboardsV1PreviewStateForPath(fullPath),
    );
  }

  PbFilesItemData _v1ProcessingDeleteItem(PendingStorageDeleteEntry pendingDelete) {
    final path = pendingDelete.path;
    final fallbackName = path.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? path;
    final displayName = pendingDelete.isFolder ? fallbackName : _displayNameForPath(path);
    final title = displayName.isEmpty ? 'Deleting item' : 'Deleting $displayName';

    return _v1StateRow(
      id: _FilePathKey.keyForPath(path, pendingDelete.isFolder),
      title: title,
      path: path,
      isFolder: pendingDelete.isFolder,
      updatedLabel: 'Deleting',
      updatedSort: pendingDelete.startedAt.millisecondsSinceEpoch + pendingDelete.sequence,
      kind: PbFilesItemKind.processing,
    );
  }

  PbFilesItemData _v1StateRow({
    required String id,
    required String title,
    required String path,
    required bool isFolder,
    required String updatedLabel,
    required int updatedSort,
    required PbFilesItemKind kind,
  }) {
    return PbFilesItemData.fromFileName(
      id: id,
      title: title,
      type: '',
      thread: '',
      creator: '',
      creatorInitials: '',
      updatedLabel: updatedLabel,
      updatedSort: updatedSort,
      parentPath: parentPath(path),
      folderPath: isFolder ? path : '',
      fileType: isFolder ? PbAttachmentFileType.folder : PbAttachmentFileType.generic,
      kind: kind,
    );
  }

  PbFilesItemData _v1DeleteErrorRow({required String path, required bool isFolder}) {
    final fallbackName = path.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? path;
    final displayName = isFolder ? fallbackName : _displayNameForPath(path);
    final title = displayName.isEmpty ? 'Delete failed' : 'Failed to delete $displayName';

    return _v1StateRow(
      id: _FilePathKey.keyForPath(path, isFolder),
      title: title,
      path: path,
      isFolder: isFolder,
      updatedLabel: 'Failed',
      updatedSort: DateTime.now().millisecondsSinceEpoch,
      kind: PbFilesItemKind.processingError,
    );
  }

  PbFilesItemData _v1UploadErrorRow(String path) {
    final displayName = _displayNameForPath(path);
    final title = displayName.isEmpty ? 'Upload failed' : 'Failed upload $displayName';

    return _v1StateRow(
      id: 'upload-error:${PendingStorageDeletes.normalizePath(path)}:${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      path: path,
      isFolder: false,
      updatedLabel: 'Failed',
      updatedSort: DateTime.now().millisecondsSinceEpoch,
      kind: PbFilesItemKind.processingError,
    );
  }

  bool _v1EntryCanEnableFilter(StorageEntry entry, {String? folderPath}) {
    final currentFolder = folderPath ?? _folderSig.value;
    final path = _FilePathKey.pathForEntry(currentFolder, entry);
    if (widget.hideSystem && entry.name.startsWith('.')) {
      return false;
    }

    if (_isDeletePending(path, entry.isFolder)) {
      return false;
    }

    final key = _FilePathKey.keyForEntry(currentFolder, entry);
    return !_v1FileStateRowsById.containsKey(key);
  }

  bool _v1FilterEnabled(List<StorageEntry> entries, {String? folderPath}) {
    return entries.any((entry) => _v1EntryCanEnableFilter(entry, folderPath: folderPath));
  }

  void _clearV1FilterIfUnavailable(bool filterEnabled, {String? folderPath}) {
    if (filterEnabled || _v1FilterController.text.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _v1FilterEnabled(_storageEntriesSnapshot(), folderPath: folderPath) || _v1FilterController.text.isEmpty) {
        return;
      }

      _v1FilterController.clear();
      setState(() {});
    });
  }

  List<PbFilesItemData> _v1VisibleItems(List<StorageEntry> entries, {String? folderPath}) {
    final currentFolder = folderPath ?? _folderSig.value;
    final query = _v1FilterController.text.trim().toLowerCase();
    final pendingDeleteItemsForFolder = PendingStorageDeletes.entriesFor(
      _deleteScope,
    ).where((pendingDelete) => parentPath(pendingDelete.path) == currentFolder).map(_v1ProcessingDeleteItem).toList();
    final pendingDeleteItems = pendingDeleteItemsForFolder.where((item) => query.isEmpty || item.filterText.contains(query)).toList();
    final stateRowsForFolder = _v1FileStateRowsById.values.where((item) => item.parentPath == currentFolder).toList();
    final stateRows = stateRowsForFolder.where((item) => query.isEmpty || item.filterText.contains(query)).toList();
    final replacementRowIds = {for (final item in pendingDeleteItemsForFolder) item.id, for (final item in stateRowsForFolder) item.id};
    final items = entries
        .where((entry) => !widget.hideSystem || !entry.name.startsWith('.'))
        .where((entry) => !powerboardsV1IsDownloadArchiveStagingPath(_FilePathKey.pathForEntry(currentFolder, entry)))
        .where((entry) => !_isDeletePending(_FilePathKey.pathForEntry(currentFolder, entry), entry.isFolder))
        .where((entry) => !replacementRowIds.contains(_FilePathKey.keyForEntry(currentFolder, entry)))
        .map(_v1ItemForEntry)
        .where((item) => query.isEmpty || item.filterText.contains(query))
        .toList();
    items.addAll(pendingDeleteItems);
    items.addAll(stateRows);
    items.sort(_compareV1Files);
    return items;
  }

  void _setV1FileStateRow(PbFilesItemData item) {
    setState(() => _v1FileStateRowsById[item.id] = item);
  }

  void _removeV1FileStateRow(PbFilesItemData item) {
    if (!_v1FileStateRowsById.containsKey(item.id)) {
      return;
    }

    setState(() => _v1FileStateRowsById.remove(item.id));
  }

  bool _v1ItemIsSelectable(PbFilesItemData item) {
    return powerboardsV1FileItemIsSelectable(item);
  }

  Set<String> _v1SelectedItemIdsForAction(List<PbFilesItemData> items) {
    final rawSelected = _selectedSig.value;
    final visibleSelected = powerboardsV1SelectedVisibleItemIds(rawSelected, items);
    if (visibleSelected.isNotEmpty || items.isNotEmpty || storageEntries.state.asReady != null) {
      return visibleSelected;
    }

    return rawSelected;
  }

  Iterable<PbFilesItemData> _v1SelectableItems(Iterable<PbFilesItemData> items) {
    return items.where(_v1ItemIsSelectable);
  }

  List<PbFilesItemData> get _v1RecentlyOpenedFilesForSidePane {
    return [
      for (final item in _v1RecentlyOpenedFiles)
        if (item.canPreview && !_isDeletePending(_v1PathForItem(item), false)) item,
    ].take(_v1RecentlyOpenedFilesLimit).toList(growable: false);
  }

  void _recordV1RecentlyOpenedFile(PbFilesItemData item) {
    _replaceV1RecentlyOpenedFiles(powerboardsV1RecordRecentlyOpenedFile(_v1RecentlyOpenedFiles, item));
  }

  int _compareV1Files(PbFilesItemData left, PbFilesItemData right) {
    if (left.kind == PbFilesItemKind.folder && right.kind != PbFilesItemKind.folder) {
      return -1;
    }
    if (left.kind != PbFilesItemKind.folder && right.kind == PbFilesItemKind.folder) {
      return 1;
    }

    final result = switch (_v1SortKey) {
      PbFilesSortKey.updated => left.updatedSort.compareTo(right.updatedSort),
      PbFilesSortKey.name => left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      PbFilesSortKey.type => left.type.toLowerCase().compareTo(right.type.toLowerCase()),
      PbFilesSortKey.size => left.sizeSort.compareTo(right.sizeSort),
      PbFilesSortKey.thread => left.threadLabel.toLowerCase().compareTo(right.threadLabel.toLowerCase()),
      PbFilesSortKey.creator => left.creator.toLowerCase().compareTo(right.creator.toLowerCase()),
    };

    return _v1SortDirectionDescending ? -result : result;
  }

  void _setV1Sort(PbFilesSortKey key) {
    setState(() {
      if (_v1SortKey == key) {
        _v1SortDirectionDescending = !_v1SortDirectionDescending;
      } else {
        _v1SortKey = key;
        _v1SortDirectionDescending = key == PbFilesSortKey.updated || key == PbFilesSortKey.size;
      }
    });
  }

  String _v1PathForItem(PbFilesItemData item) {
    return _FilePathKey.pathFromKey(item.id);
  }

  Set<String> get _v1ExtractingArchiveIds {
    return {for (final path in _v1ExtractingArchivePaths) _FilePathKey.keyForPath(path, false)};
  }

  bool _v1ArchiveExtractionInProgress(String archivePath) {
    return _v1ExtractingArchivePaths.contains(PendingStorageDeletes.normalizePath(archivePath));
  }

  void _setV1ArchiveExtractionInProgress(String archivePath, bool extracting) {
    final normalizedPath = PendingStorageDeletes.normalizePath(archivePath);
    if (normalizedPath.isEmpty || _v1ExtractingArchivePaths.contains(normalizedPath) == extracting) {
      return;
    }

    void update() {
      if (extracting) {
        _v1ExtractingArchivePaths.add(normalizedPath);
      } else {
        _v1ExtractingArchivePaths.remove(normalizedPath);
      }
    }

    if (!mounted) {
      update();
      return;
    }

    setState(update);
  }

  String? _v1PreviewDraftTextForItem(PbFilesItemData? item) {
    return item != null && _v1PreviewDraftPath == _v1PathForItem(item) ? _v1PreviewDraftText : null;
  }

  bool _v1PreviewDraftDirtyForItem(PbFilesItemData? item) {
    return item != null && _v1PreviewDraftPath == _v1PathForItem(item) && _v1PreviewDraftText != null;
  }

  void _setV1PreviewDraftText(PbFilesItemData item, String text) {
    final path = _v1PathForItem(item);
    if (_v1PreviewDraftPath == path && _v1PreviewDraftText == text) {
      return;
    }

    setState(() {
      _v1PreviewDraftPath = path;
      _v1PreviewDraftText = text;
    });
  }

  void _clearV1PreviewDraftForItem(PbFilesItemData? item) {
    if (item == null) {
      return;
    }

    final path = _v1PathForItem(item);
    if (_v1PreviewDraftPath != path) {
      return;
    }

    _clearV1PreviewDraft();
  }

  void _discardV1PreviewDraftIfDifferent(PbFilesItemData item) {
    final path = _v1PathForItem(item);
    if (_v1PreviewDraftPath == null || _v1PreviewDraftPath == path) {
      return;
    }

    _clearV1PreviewDraft();
  }

  void _clearV1PreviewDraft() {
    _v1PreviewDraftPath = null;
    _v1PreviewDraftText = null;
  }

  bool _v1IsFolder(PbFilesItemData item) {
    return item.kind == PbFilesItemKind.folder;
  }

  bool get _v1KeyboardPreviewNavigationActive =>
      _v1FilesKeyboardBrowseArmed || _v1KeyboardPreviewFileId != null || _v1KeyboardPreviewDirection != 0;

  void _clearV1KeyboardPreviewNavigationState() {
    _v1KeyboardPreviewFileId = null;
    _v1KeyboardPreviewDirection = 0;
    _v1FilesKeyboardBrowseArmed = false;
  }

  void _clearV1KeyboardPreviewNavigation() {
    if (!_v1KeyboardPreviewNavigationActive) {
      return;
    }

    setState(_clearV1KeyboardPreviewNavigationState);
  }

  bool _isV1FilesKeyboardNavigationBlocked() {
    return FocusManager.instance.primaryFocus?.context?.widget is EditableText;
  }

  void _openV1Preview(
    PbFilesItemData item, {
    bool openOverlay = false,
    bool openFullscreen = false,
    bool restoreOverlayOnClose = false,
    bool armKeyboardBrowse = true,
    int keyboardDirection = 0,
  }) {
    if (!item.canPreview) {
      return;
    }

    if (armKeyboardBrowse) {
      _v1FilesKeyboardFocusNode.requestFocus();
    }

    setState(() {
      _discardV1PreviewDraftIfDifferent(item);
      _v1WebsitePreview = null;
      _v1PreviewFile = item;
      _v1FilePreviewFullscreen = openFullscreen;
      _v1RestoreRoomPanelOverlayOnPreviewClose = restoreOverlayOnClose && (openOverlay || openFullscreen);
      _v1FilesRoomPanelCollapsed = false;
      _v1FilesRoomPanelOverlayOpen = openFullscreen ? false : openOverlay;
      if (armKeyboardBrowse) {
        _v1KeyboardPreviewFileId = keyboardDirection == 0 ? null : item.id;
        _v1KeyboardPreviewDirection = keyboardDirection;
        _v1FilesKeyboardBrowseArmed = true;
      } else {
        _clearV1KeyboardPreviewNavigationState();
      }
      _recordV1RecentlyOpenedFile(item);
      _clearSelected();
    });
    _setV1FilesRoomPanelCollapsed(false);
    setPreviewFilePreviewFullscreen(openFullscreen);
  }

  void _closeV1Preview() {
    final clearOpenedFileRoute = _openedFile != null && !_usesAdaptiveMobileLayout(context) && powerboardsUsesDesktopUiPreview(context);
    final restoreRoomPanelOverlay = _v1RestoreRoomPanelOverlayOnPreviewClose && !clearOpenedFileRoute;

    setState(() {
      if (_v1PreviewFile != null) {
        _clearV1PreviewDraftForItem(_v1PreviewFile);
      } else if (_openedFile != null && _v1PreviewDraftPath == _openedFile) {
        _clearV1PreviewDraft();
      }
      _v1PreviewFile = null;
      _v1WebsitePreview = null;
      _v1FilePreviewFullscreen = false;
      _v1FilesRoomPanelOverlayOpen = restoreRoomPanelOverlay;
      _v1RestoreRoomPanelOverlayOnPreviewClose = false;
      _clearV1KeyboardPreviewNavigationState();
    });
    setPreviewFilePreviewFullscreen(false);

    if (clearOpenedFileRoute) {
      _closeFile();
    }
  }

  void _closeV1PreviewForSelection() {
    final openedFile = _openedFile;
    final clearOpenedFileRoute = openedFile != null && !_usesAdaptiveMobileLayout(context) && powerboardsUsesDesktopUiPreview(context);
    final previewFile = _v1PreviewFile;

    if (previewFile == null && _v1WebsitePreview == null && !clearOpenedFileRoute) {
      _clearV1KeyboardPreviewNavigation();
      return;
    }

    setState(() {
      _clearV1PreviewDraftForItem(previewFile);
      if (openedFile != null && _v1PreviewDraftPath == openedFile) {
        _clearV1PreviewDraft();
      }
      _v1PreviewFile = null;
      _v1WebsitePreview = null;
      _v1FilePreviewFullscreen = false;
      _v1FilesRoomPanelOverlayOpen = false;
      _v1RestoreRoomPanelOverlayOnPreviewClose = false;
      _clearV1KeyboardPreviewNavigationState();
    });
    setPreviewFilePreviewFullscreen(false);

    if (clearOpenedFileRoute) {
      _openEntry(_folderSig.value, true);
    }
  }

  void _toggleV1ItemSelection(String id, bool selected) {
    if (selected) {
      _closeV1PreviewForSelection();
    } else {
      _clearV1KeyboardPreviewNavigation();
    }

    _toggleSelected(id, selected);
  }

  void _finishV1FilePromptHandoff({PbFilesItemData? recentlyOpenedItem, required bool cleanupSurfaces}) {
    final recentlyOpened = recentlyOpenedItem;

    if (!cleanupSurfaces) {
      if (recentlyOpened != null && recentlyOpened.canPreview) {
        setState(() {
          _recordV1RecentlyOpenedFile(recentlyOpened);
        });
      }
      return;
    }

    _v1FilesRoomPanelOverlayController.hide();
    _clearSelected();
    final openedFile = _openedFile;
    if (openedFile != null) {
      widget.client.localParticipant?.setAttribute("current_file", null);
    }
    setState(() {
      if (recentlyOpened != null && recentlyOpened.canPreview) {
        _recordV1RecentlyOpenedFile(recentlyOpened);
      }
      if (_v1PreviewFile != null) {
        _clearV1PreviewDraftForItem(_v1PreviewFile);
      }
      if (openedFile != null && _v1PreviewDraftPath == openedFile) {
        _clearV1PreviewDraft();
      }
      if (openedFile != null) {
        _location = _FileLocation(folder: _location.folder, openedFile: null);
        _tab = 'preview';
      }
      _v1PreviewFile = null;
      _v1WebsitePreview = null;
      _v1FilePreviewFullscreen = false;
      _v1FilesRoomPanelCollapsed = true;
      _v1FilesRoomPanelOverlayOpen = false;
      _v1RestoreRoomPanelOverlayOnPreviewClose = false;
      _clearV1KeyboardPreviewNavigationState();
    });
    setPreviewFilePreviewFullscreen(false);
  }

  void _revealV1PreviewPanelForKeyboard({required bool openOverlay}) {
    if (openOverlay) {
      if (!_v1FilesRoomPanelOverlayOpen) {
        setState(() => _v1FilesRoomPanelOverlayOpen = true);
      }
      return;
    }

    _setV1FilesRoomPanelCollapsed(false);
  }

  void _openV1PreviewFromKeyboard(PbFilesItemData item, {required bool openOverlay, required bool openFullscreen, required int direction}) {
    _openV1Preview(item, openOverlay: openOverlay, openFullscreen: openFullscreen, keyboardDirection: direction);
  }

  KeyEventResult _handleV1FilesKeyEvent(
    KeyEvent event, {
    required List<PbFilesItemData> items,
    required PbFilesItemData? previewFile,
    required bool responsivePanel,
    required bool openFullscreen,
  }) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (!_v1KeyboardPreviewNavigationActive) {
        return KeyEventResult.ignored;
      }

      _clearV1KeyboardPreviewNavigation();
      return KeyEventResult.handled;
    }

    if (key != LogicalKeyboardKey.arrowDown && key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }

    if (_selectedSig.value.isNotEmpty || previewFile == null || !_v1FilesKeyboardBrowseArmed || _isV1FilesKeyboardNavigationBlocked()) {
      return KeyEventResult.ignored;
    }

    final previewableItems = items.where((item) => item.canPreview).toList(growable: false);
    final currentIndex = previewableItems.indexWhere((item) => item.id == previewFile.id);
    if (currentIndex < 0) {
      return KeyEventResult.ignored;
    }

    final direction = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
    final nextIndex = math.max(0, math.min(previewableItems.length - 1, currentIndex + direction));
    if (nextIndex == currentIndex) {
      _revealV1PreviewPanelForKeyboard(openOverlay: responsivePanel);
      return KeyEventResult.handled;
    }

    _openV1PreviewFromKeyboard(
      previewableItems[nextIndex],
      openOverlay: responsivePanel,
      openFullscreen: openFullscreen,
      direction: direction,
    );
    return KeyEventResult.handled;
  }

  void _setV1PreviewFullscreen(bool fullscreen) {
    setState(() {
      _v1FilePreviewFullscreen = fullscreen;
      if (fullscreen) {
        _v1RestoreRoomPanelOverlayOnPreviewClose = _v1RestoreRoomPanelOverlayOnPreviewClose || _v1FilesRoomPanelOverlayOpen;
        _v1FilesRoomPanelOverlayOpen = false;
      } else if (_v1PreviewFile != null || _openedFile != null) {
        _v1FilesRoomPanelOverlayOpen = true;
      }
    });
    setPreviewFilePreviewFullscreen(fullscreen);
  }

  void _closeV1FilesRoomPanelOverlay() {
    _v1FilesRoomPanelOverlayController.hide();
    setState(() {
      _v1FilesRoomPanelOverlayOpen = false;
      if (_v1PreviewFile == null && _openedFile == null) {
        _v1RestoreRoomPanelOverlayOnPreviewClose = false;
      }
    });
  }

  String _v1ExtensionForPath(String path) {
    return p.extension(path).replaceFirst('.', '').toLowerCase();
  }

  bool _v1IsEditableTextPreview(PbFilesItemData item, String path, {String? classificationPath}) {
    if (path.startsWith('dataset://')) {
      return false;
    }

    final previewPath = classificationPath ?? path;
    final extension = _v1ExtensionForPath(previewPath);
    if (_v1EditableTextExtensions.contains(extension)) {
      return true;
    }

    final kind = classifyFile(previewPath);
    if (kind == FileKind.markdown || kind == FileKind.code || kind == FileKind.tsv) {
      return true;
    }

    return switch (item.fileType) {
      PbAttachmentFileType.codeGeneric ||
      PbAttachmentFileType.script ||
      PbAttachmentFileType.code ||
      PbAttachmentFileType.key ||
      PbAttachmentFileType.settings => true,
      _ => false,
    };
  }

  bool _v1IsNativeDocumentPath(String path) {
    return const {'thread', 'widget', 'document', 'gallery', 'presentation', 'form'}.contains(_v1ExtensionForPath(path));
  }

  Future<String> _loadV1PreviewText(String path) async {
    final content = await widget.client.storage.download(path);
    return utf8.decode(content.data, allowMalformed: true);
  }

  Future<void> _saveV1PreviewText(PbFilesItemData item, String path, String text) async {
    if (!item.canPreview) {
      await Future<void>.delayed(_v1SaveProcessingStep);
      return;
    }

    setState(() => _v1SavingFileIds.add(item.id));

    try {
      final bytes = Uint8List.fromList(utf8.encode(text));
      await widget.client.storage.uploadStream(path, Stream<Uint8List>.value(bytes), overwrite: true, size: bytes.length);

      if (!mounted) {
        return;
      }

      _finishV1PreviewSave(item);
    } catch (_) {
      if (mounted) {
        setState(() => _v1SavingFileIds.remove(item.id));
      }
      rethrow;
    }
  }

  Future<String> _v1DownloadUrlForPath(String path) {
    final key = _v1DownloadUrlCacheKey(path);
    final cached = _v1DownloadUrlFuturesByPath[key];
    final expiresAt = _v1DownloadUrlExpiresAtByPath[key];
    if (cached != null && expiresAt != null && expiresAt.isAfter(DateTime.now())) {
      return cached;
    }

    _v1DownloadUrlFuturesByPath.remove(key);
    _v1DownloadUrlExpiresAtByPath.remove(key);

    late final Future<String> future;
    future = widget.client.storage.downloadUrl(path).catchError((Object error, StackTrace stackTrace) {
      if (identical(_v1DownloadUrlFuturesByPath[key], future)) {
        _v1DownloadUrlFuturesByPath.remove(key);
        _v1DownloadUrlExpiresAtByPath.remove(key);
      }
      return Future<String>.error(error, stackTrace);
    });
    _v1DownloadUrlFuturesByPath[key] = future;
    _v1DownloadUrlExpiresAtByPath[key] = DateTime.now().add(powerboardsV1DownloadUrlCacheDuration);
    return future;
  }

  Widget _v1StorageUrlPreview(PbFilesItemData item, String path, Widget Function(Uri url) builder) {
    return FutureBuilder<String>(
      future: _v1DownloadUrlForPath(path),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ColoredBox(
            color: PbColors.surfacePanel,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: PbFilePreviewStateCard(file: item.toAttachmentData(), state: PbAttachmentPreviewState.unavailable),
              ),
            ),
          );
        }

        final url = snapshot.data;
        if (url == null) {
          return const Center(child: CircularProgressIndicator(color: PbColors.textSubtle));
        }

        return builder(Uri.parse(url));
      },
    );
  }

  Widget _v1DocumentPaneContent(PbFilesItemData item, String path) {
    return DocumentPane(
      path: path,
      room: widget.client,
      noPreviewBuilder: (context, _) => Center(
        child: PbFilePreviewStateCard(file: item.toAttachmentData(), state: PbAttachmentPreviewState.unavailable),
      ),
    );
  }

  Widget? _buildV1PreviewContentChild(PbFilesItemData item, String path) {
    final file = item.toAttachmentData();
    final classificationPath = powerboardsV1PreviewClassificationPath(file: file, path: path);
    final extension = _v1ExtensionForPath(classificationPath);
    final kind = classifyFile(classificationPath);

    if (item.fileType == PbAttachmentFileType.thread || extension == 'thread' || kind == FileKind.thread) {
      return null;
    }

    if (_v1IsNativeDocumentPath(classificationPath)) {
      return _v1DocumentPaneContent(item, path);
    }

    switch (item.fileType) {
      case PbAttachmentFileType.image:
        return PowerboardsV1StorageImagePreview(key: ValueKey('v1-image-preview:$path'), room: widget.client, path: path, file: file);
      case PbAttachmentFileType.video:
      case PbAttachmentFileType.mediaGeneric:
        return _v1StorageUrlPreview(item, path, powerboardsV1VideoPreview);
      case PbAttachmentFileType.sound:
      case PbAttachmentFileType.music:
        return _v1StorageUrlPreview(item, path, (url) => AudioPreview(url: url));
      case PbAttachmentFileType.pdf:
        return PowerboardsV1PdfPreview(key: ValueKey('v1-pdf-preview:$path'), room: widget.client, path: path, file: file);
      case PbAttachmentFileType.transcript:
      case PbAttachmentFileType.thread:
      case PbAttachmentFileType.presentation:
        return null;
      case PbAttachmentFileType.generic:
      case PbAttachmentFileType.folder:
      case PbAttachmentFileType.archive:
      case PbAttachmentFileType.type:
      case PbAttachmentFileType.widget:
      case PbAttachmentFileType.businessGeneric:
      case PbAttachmentFileType.spreadsheet:
      case PbAttachmentFileType.document:
      case PbAttachmentFileType.codeGeneric:
      case PbAttachmentFileType.script:
      case PbAttachmentFileType.code:
      case PbAttachmentFileType.key:
      case PbAttachmentFileType.settings:
        break;
    }

    switch (kind) {
      case FileKind.image:
        return PowerboardsV1StorageImagePreview(key: ValueKey('v1-image-preview:$path'), room: widget.client, path: path, file: file);
      case FileKind.video:
        return _v1StorageUrlPreview(item, path, powerboardsV1VideoPreview);
      case FileKind.audio:
        return _v1StorageUrlPreview(item, path, (url) => AudioPreview(url: url));
      case FileKind.pdf:
        return PowerboardsV1PdfPreview(key: ValueKey('v1-pdf-preview:$path'), room: widget.client, path: path, file: file);
      case FileKind.thread:
      case FileKind.markdown:
      case FileKind.code:
      case FileKind.tsv:
        return null;
      case FileKind.custom:
      case FileKind.parquet:
      case FileKind.office:
      case FileKind.lance:
      case FileKind.unknown:
        break;
    }

    return null;
  }

  PbFilePreviewSource _buildV1PreviewSource(PbFilesItemData item) {
    final path = _v1PathForItem(item);
    final file = item.toAttachmentData();
    final classificationPath = powerboardsV1PreviewClassificationPath(file: file, path: path);
    final extension = _v1ExtensionForPath(classificationPath);
    final kind = classifyFile(classificationPath);
    if (item.fileType == PbAttachmentFileType.thread || extension == 'thread' || kind == FileKind.thread) {
      return powerboardsV1PreviewSourceForAttachment(
        room: widget.client,
        file: file,
        path: path,
        loadText: (_) => _loadV1PreviewText(path),
        saveText: (_, text) => _saveV1PreviewText(item, path, text),
        downloadUrl: (_) => _v1DownloadUrlForPath(path),
      );
    }

    if (item.fileType == PbAttachmentFileType.transcript || extension == 'transcript' || extension == 'srt' || extension == 'vtt') {
      return PbFilePreviewSource(
        sourceKey: path,
        childBuilder: (fullscreen) => extension == 'transcript'
            ? _V1TranscriptDocumentPreview(room: widget.client, path: path, file: file, fullscreen: fullscreen)
            : _V1TextTranscriptPreview(room: widget.client, path: path, file: file, title: item.title, fullscreen: fullscreen),
      );
    }

    if (_v1IsEditableTextPreview(item, path, classificationPath: classificationPath)) {
      return PbFilePreviewSource(
        sourceKey: path,
        loadText: () => _loadV1PreviewText(path),
        saveText: (text) => _saveV1PreviewText(item, path, text),
      );
    }

    return PbFilePreviewSource(sourceKey: path, child: _buildV1PreviewContentChild(item, path));
  }

  void _finishV1PreviewSave(PbFilesItemData item) {
    setState(() {
      _v1SavingFileIds.remove(item.id);

      final updatedItem = item.copyWith(updatedLabel: 'Now', updatedSort: DateTime.now().millisecondsSinceEpoch);
      if (_v1PreviewFile?.id == item.id) {
        _v1PreviewFile = updatedItem;
      }
      _replaceV1RecentlyOpenedFiles([
        updatedItem,
        for (final recent in _v1RecentlyOpenedFiles)
          if (recent.id != item.id) recent,
      ]);
    });
  }

  Future<void> _saveV1PreviewFile(PbFilesItemData item) async {
    if (!item.canPreview) {
      await Future<void>.delayed(_v1SaveProcessingStep);
      return;
    }

    setState(() => _v1SavingFileIds.add(item.id));
    await Future<void>.delayed(_v1SaveProcessingStep);

    if (!mounted) {
      return;
    }

    _finishV1PreviewSave(item);
  }

  PbFilesItemData? _v1PreviewFileFromRoute(List<PbFilesItemData> items) {
    final openedFile = _openedFile;
    if (openedFile == null) {
      return null;
    }

    final key = _FilePathKey.keyForPath(openedFile, false);
    final item = items.firstWhereOrNull((item) => item.id == key);
    if (item != null) {
      return item.canPreview ? item : null;
    }

    return _v1ItemForPath(openedFile);
  }

  void _toggleV1VisibleSelection(List<PbFilesItemData> items) {
    final visibleIds = _v1SelectableItems(items).map((item) => item.id).toSet();
    final selected = powerboardsV1SelectedVisibleItemIds(_selectedSig.value, items);
    final allSelected = visibleIds.isNotEmpty && visibleIds.every(selected.contains);

    if (allSelected) {
      _clearV1KeyboardPreviewNavigation();
    } else {
      _closeV1PreviewForSelection();
    }

    _mutateSelected((next) {
      if (allSelected) {
        next.removeAll(visibleIds);
      } else {
        next.addAll(visibleIds);
      }
      return next;
    });
  }

  List<ChatFilePromptAction> _filePromptActionsForPath(String fullPath, {required bool isFolder, bool allowFolder = false}) {
    if (isFolder && !allowFolder || widget.services?.state.isReady != true) {
      return const <ChatFilePromptAction>[];
    }

    final actions = resolveChatFilePromptActions(services: widget.services!.state.value!, filePath: fullPath);
    if (actions.isNotEmpty) {
      return actions;
    }

    final fallback = _fallbackFilePromptAction(isFolder: isFolder);
    return fallback == null ? const <ChatFilePromptAction>[] : [fallback];
  }

  ChatFilePromptAction? _fallbackFilePromptAction({required bool isFolder}) {
    if (widget.services?.state.isReady != true) {
      return null;
    }

    for (final service in widget.services!.state.value!) {
      final descriptor = ma.serviceConversationDescriptor(service, remoteParticipants: widget.client.messaging.remoteParticipants);
      if (descriptor?.isChat != true) {
        continue;
      }

      final rawAgentName = service.agents.firstOrNull?.name;
      if (rawAgentName == null) {
        continue;
      }

      final agentName = rawAgentName.trim();
      if (agentName.isNotEmpty) {
        return isFolder ? defaultChatFolderPromptAction(agentName: agentName) : defaultChatFilePromptAction(agentName: agentName);
      }
    }

    for (final participant in widget.client.messaging.remoteParticipants) {
      final descriptor = ma.participantConversationDescriptor(participant);
      if (descriptor?.isChat != true) {
        continue;
      }

      final agentName = ma.participantDisplayName(participant);
      if (agentName != null) {
        return isFolder ? defaultChatFolderPromptAction(agentName: agentName) : defaultChatFilePromptAction(agentName: agentName);
      }
    }

    return null;
  }

  Future<void> _openManageAgentsForFilePrompt({required bool isFolder}) async {
    final projectId = widget.projectId?.trim();
    if (projectId == null || projectId.isEmpty) {
      if (mounted) {
        ShadToaster.of(context).show(
          powerboardsToast(
            title: "No chat agent available",
            description: "Install a chat agent before asking about this ${isFolder ? 'folder' : 'file'}.",
            destructive: true,
          ),
        );
      }
      return;
    }

    await showManageAgentsSurface(
      context: context,
      projectId: projectId,
      room: widget.client,
      onServiceChanged: () {
        widget.services?.refresh();
      },
    );
    if (!mounted) {
      return;
    }
    widget.services?.refresh();
  }

  Future<void> _startDefaultFilePrompt(
    String fullPath, {
    required bool isFolder,
    PbFilesItemData? recentlyOpenedItem,
    required bool cleanupSurfacesAfterHandoff,
    String? fileDisplayName,
  }) async {
    final action = _filePromptActionsForPath(fullPath, isFolder: isFolder, allowFolder: true).firstOrNull;
    if (action == null) {
      await _openManageAgentsForFilePrompt(isFolder: isFolder);
      return;
    }

    final callback = widget.onV1FilePromptRequested;
    if (callback != null) {
      await callback(
        action,
        fullPath,
        isFolder: isFolder,
        responsiveHandoff: cleanupSurfacesAfterHandoff,
        fileDisplayName: fileDisplayName,
      );
      if (!mounted) {
        return;
      }
      _finishV1FilePromptHandoff(
        recentlyOpenedItem: isFolder ? null : recentlyOpenedItem,
        cleanupSurfaces: powerboardsV1FilePromptShouldCleanupSurfaces(isFolder: isFolder, responsiveHandoff: cleanupSurfacesAfterHandoff),
      );
      return;
    }

    try {
      final threadPath = await startChatFilePromptThread(room: widget.client, action: action, filePath: fullPath);
      if (!mounted) {
        return;
      }

      _openEntry(threadPath, false);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ShadToaster.of(context).show(powerboardsToast(title: "Unable to start chat", description: "$error", destructive: true));
    }
  }

  Future<void> _closeThreadIndexDocument({bool refreshUi = true}) async {
    final document = _threadIndexDocument;
    final threadIndexPath = _threadIndexPath;
    if (document != null) {
      document.removeListener(_onThreadIndexChanged);
    }
    _threadIndexDocument = null;
    _threadIndexPath = null;
    _threadDisplayNamesByPath = const <String, String>{};
    _threadTitleResolutionsInFlight.clear();

    if (threadIndexPath != null) {
      try {
        await widget.client.sync.close(threadIndexPath);
      } catch (_) {}
    }

    if (refreshUi && _canUpdateUi) {
      setState(() {});
    }
  }

  void _onThreadIndexChanged() {
    if (!_canUpdateUi) {
      return;
    }
    _refreshThreadDisplayNames();
  }

  Future<void> _rebindThreadIndexDocument() async {
    final nextThreadIndexPath = _threadIndexPathForFolder(_folderSig.value);
    if (_threadIndexPath == nextThreadIndexPath && _threadIndexDocument != null) {
      _refreshThreadDisplayNames();
      return;
    }

    await _closeThreadIndexDocument();
    if (!_canUpdateUi) {
      return;
    }
    if (nextThreadIndexPath == null) {
      return;
    }

    try {
      final exists = await widget.client.storage.exists(nextThreadIndexPath);
      if (!_canUpdateUi || !exists) {
        return;
      }

      final document = await widget.client.sync.open(nextThreadIndexPath);
      if (!_canUpdateUi || _threadIndexPathForFolder(_folderSig.value) != nextThreadIndexPath) {
        try {
          await widget.client.sync.close(nextThreadIndexPath);
        } catch (_) {}
        return;
      }

      document.addListener(_onThreadIndexChanged);
      _threadIndexDocument = document;
      _threadIndexPath = nextThreadIndexPath;
      _refreshThreadDisplayNames();
    } catch (_) {
      if (!_canUpdateUi) {
        return;
      }
      setState(() {
        _threadDisplayNamesByPath = const <String, String>{};
      });
    }
  }

  void _refreshThreadDisplayNames() {
    final document = _threadIndexDocument;
    final next = <String, String>{};
    if (document != null) {
      for (final node in document.root.getChildren().whereType<MeshElement>()) {
        if (node.tagName != 'thread') {
          continue;
        }

        final rawPath = node.getAttribute('path');
        if (rawPath is! String) {
          continue;
        }
        final path = normalizeThreadStoragePath(rawPath);
        if (path.isEmpty) {
          continue;
        }

        final rawName = node.getAttribute('name');
        if (rawName is! String) {
          continue;
        }
        final displayName = rawName.trim();
        if (displayName.isEmpty) {
          continue;
        }

        next[path] = displayName;
      }
    }

    if (!mapEquals(_threadDisplayNamesByPath, next)) {
      if (!_canUpdateUi) {
        _threadDisplayNamesByPath = next;
        return;
      }
      setState(() {
        _threadDisplayNamesByPath = next;
      });
    }
  }

  MeshElement? _threadNodeForPath(String path) {
    final document = _threadIndexDocument;
    if (document == null) {
      return null;
    }

    final normalizedPath = normalizeThreadStoragePath(path);

    return document.root.getChildren().whereType<MeshElement>().firstWhereOrNull((node) {
      final nodePath = node.getAttribute('path');
      return node.tagName == 'thread' && nodePath is String && normalizeThreadStoragePath(nodePath) == normalizedPath;
    });
  }

  void _removePath(String path, {isFolder = false}) {
    _clearV1DownloadUrlCacheForPath(path);
    if (parentPath(path) != _folderSig.value) return;

    final entries = _currentFolderEntriesForMutation();
    if (entries == null) return; // ignore if loading/error without cache

    final name = path.split('/').where((s) => s.isNotEmpty).last;
    final next = List<StorageEntry>.of(entries);
    next.removeWhere((e) => e.name == name && e.isFolder == isFolder);
    _v1FileStateRowsById.removeWhere((_, item) => _v1StateRowMatchesPath(item, path, isFolder: isFolder));
    _toggleSelected(_FilePathKey.keyForPath(path, isFolder), false);

    _setEntries(next);
  }

  void _setEntries(List<StorageEntry> entries) {
    storageEntries.state = ResourceState.ready(entries);
    _saveV1FolderEntries(_folderSig.value, entries);
    final hasThreadIndex = entries.any((entry) => !entry.isFolder && entry.name == _threadIndexFileName);
    final expectedThreadIndexPath = _threadIndexPathForFolder(_folderSig.value);
    if (hasThreadIndex && _threadIndexDocument == null && expectedThreadIndexPath != null) {
      unawaited(_rebindThreadIndexDocument());
    } else if (!hasThreadIndex && _threadIndexPath == expectedThreadIndexPath && _threadIndexDocument != null) {
      unawaited(_closeThreadIndexDocument());
    }
  }

  bool _isTransientStorageDeleteError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('503')) {
      return true;
    }

    if (!message.contains('gcs') && !message.contains('websocket') && !message.contains('connection closed')) {
      return false;
    }

    return message.contains('unavailable') ||
        message.contains('timeout') ||
        message.contains('timed out') ||
        message.contains('connection closed') ||
        message.contains('websocket');
  }

  Future<void> _deleteStoragePath(String path, {bool recursive = false}) async {
    const retryDelays = [Duration(milliseconds: 250), Duration(milliseconds: 650)];

    for (var attempt = 0; ; attempt++) {
      try {
        await widget.client.storage.delete(path, recursive: recursive ? true : null);
        return;
      } catch (error) {
        if (attempt >= retryDelays.length || !_isTransientStorageDeleteError(error)) {
          rethrow;
        }

        await Future<void>.delayed(retryDelays[attempt]);
      }
    }
  }

  void _setSort(FileSort sort) {
    _sortSig.value = sort;
  }

  void _setSelected(Set<String> next) {
    _selectedSig.value = Set<String>.of(next);
  }

  void _mutateSelected(Set<String> Function(Set<String>) fn) {
    final next = fn(Set<String>.of(_selectedSig.value));
    _selectedSig.value = next;
  }

  void _toggleSelected(String key, bool selected) {
    _mutateSelected((s) {
      if (selected) {
        s.add(key);
      } else {
        s.remove(key);
      }
      return s;
    });
  }

  void _toggleAllSelected(bool selected) {
    if (selected) {
      _selectAllVisible();
    } else {
      _clearSelected();
    }
  }

  void _selectAllVisible() {
    final folder = _folderSig.value;
    final keys = _visibleSortedEntries.value
        .where((entry) => !_isDeletePending(joinPaths(folder, entry.name), entry.isFolder))
        .map((entry) => _FilePathKey.keyForEntry(folder, entry))
        .toSet();
    _setSelected(keys);
  }

  void _clearSelected() => _setSelected(<String>{});

  void _activateMobileSelectionMode() {
    _selectAllVisible();
    setState(() {
      _forceShowSelect = true;
    });
  }

  void _clearMobileSelectionMode() {
    _clearSelected();
    setState(() {
      _forceShowSelect = false;
    });
  }

  void _toggleForceShowSelect() {
    setState(() {
      _forceShowSelect = !_forceShowSelect;
    });
  }

  void _openEntry(String path, bool isFolder) {
    _clearV1KeyboardPreviewNavigation();

    if (isFolder && (_v1PreviewFile != null || _v1FilePreviewFullscreen || _v1FilesRoomPanelOverlayOpen)) {
      setState(() {
        if (_v1PreviewFile != null) {
          _clearV1PreviewDraftForItem(_v1PreviewFile);
        }
        _v1PreviewFile = null;
        _v1FilePreviewFullscreen = false;
        _v1FilesRoomPanelOverlayOpen = false;
        _v1RestoreRoomPanelOverlayOnPreviewClose = false;
      });
      setPreviewFilePreviewFullscreen(false);
    }

    final state = PathRouteMatch.of(context);
    final currentUri = state.uri;

    final updatedQueryParameters = Map<String, String>.from(currentUri.queryParameters);
    updatedQueryParameters['pane'] = 'files';
    updatedQueryParameters['p'] = path.isEmpty ? '' : (isFolder ? '$path/' : path);
    updatedQueryParameters.remove(filePreviewOriginQueryParameter);

    final newUri = currentUri.replace(queryParameters: updatedQueryParameters);
    context.go(newUri.toString());
  }

  Future<void> _cycleFile(int offset) async {
    await storageEntries.untilReady();

    final files = _visibleSortedFiles.value;
    if (files.length < 2 || _openedFile == null) return;

    final currentIndex = files.indexOf(_openedFile!);
    if (currentIndex < 0) return;

    final nextIndex = (currentIndex + offset + files.length) % files.length;
    _openEntry(files[nextIndex], false);
  }

  void _closeFile() {
    final currentUri = PathRouteMatch.of(context).uri;
    final previewOrigin = currentUri.queryParameters[filePreviewOriginQueryParameter];
    if (previewOrigin != null && previewOrigin.isNotEmpty && previewOrigin != currentUri.toString()) {
      context.go(previewOrigin);
      return;
    }

    _openEntry(_folderSig.value, true);
  }

  void _previousFile() => _cycleFile(-1);
  void _nextFile() => _cycleFile(1);

  Future<List<StorageEntry>> _getChildren(String folderPath) async {
    final entries = await widget.client.storage.list(folderPath);
    _saveV1FolderEntries(folderPath, entries);
    if (_folderSig.value == folderPath) {
      _v1LoadedFolderPath = folderPath;
    }
    return entries;
  }

  Future<void> _uploadFile(Stream<Uint8List> stream, String path, int totalBytes) async {
    if (totalBytes == 0 && _isEditableTextFile(path)) {
      _optimisticEmptyTextFiles.add(path);
    }

    final upload = MeshagentFileUpload(room: widget.client, path: path, dataStream: stream, size: totalBytes);
    uploadNotifications.addUpload(upload, totalBytes);

    unawaited(
      upload.done
          .then((_) async {
            if (!mounted) {
              return;
            }

            if (parentPath(path) == _folderSig.value) {
              await _refreshCurrentFolder();
            }
          })
          .catchError((Object error) {
            if (!mounted || !_usesDesktopV1FilesBrowser()) {
              return;
            }

            _setV1FileStateRow(_v1UploadErrorRow(path));
          }),
    );
  }

  Future<void> _downloadFile(String path, {bool throwOnLaunchFailure = false}) async {
    final url = await widget.client.storage.downloadUrl(path, download: true);
    final launched = await launchUrl(Uri.parse(url));
    if (!launched && throwOnLaunchFailure) {
      throw StateError('Unable to open download URL.');
    }
  }

  void _showDownloadFailure(Object error) {
    if (!mounted) {
      return;
    }

    ShadToaster.of(
      context,
    ).show(powerboardsToast(title: 'Download failed', description: '$error', destructive: true, duration: const Duration(seconds: 6)));
  }

  Future<void> _downloadV1FileWithToast(String path) async {
    final toaster = ShadToaster.of(context);
    toaster.show(powerboardsToast(title: 'Downloading', description: _displayNameForPath(path), duration: const Duration(seconds: 4)));

    try {
      await _downloadFile(path, throwOnLaunchFailure: true);
    } catch (error) {
      _showDownloadFailure(error);
    }
  }

  Future<void> _downloadV1FilesWithToast(List<String> paths) async {
    if (paths.isEmpty) {
      return;
    }

    final toaster = ShadToaster.of(context);
    toaster.show(
      powerboardsToast(
        title: 'Downloading',
        description: paths.length == 1 ? _displayNameForPath(paths.single) : '${paths.length} files',
        duration: const Duration(seconds: 4),
      ),
    );

    try {
      for (final path in paths) {
        await _downloadFile(path, throwOnLaunchFailure: true);
      }
    } catch (error) {
      _showDownloadFailure(error);
    }
  }

  Future<void> _downloadV1Item(PbFilesItemData item) async {
    final path = _v1PathForItem(item);
    if (_v1IsFolder(item)) {
      await _downloadV1Archive([_DownloadArchiveItem(path: path, isFolder: true)]);
      return;
    }

    await _downloadV1FileWithToast(path);
  }

  void _openV1ExtractedArchiveForPreview(PowerboardsArchiveExtractionOpenTarget target) {
    _openEntry(target.folderPath, true);
  }

  Future<void> _extractV1ArchiveForPreviewPath(String archivePath, PbArchiveInspectionResult inspection) async {
    if (!_usesDesktopV1FilesBrowser()) {
      return;
    }

    final normalizedArchivePath = PendingStorageDeletes.normalizePath(archivePath);
    if (normalizedArchivePath.isEmpty) {
      return;
    }

    final item = _v1ItemForPath(normalizedArchivePath);
    if (!pbCanExtractArchive(item.toAttachmentData())) {
      return;
    }

    await _extractV1ArchiveForPreview(item, inspection);
  }

  Future<void> _showV1ArchiveExtractDialog(PbFilesItemData item) async {
    final archivePath = _v1PathForItem(item);
    final file = item.toAttachmentData();
    if (!pbCanExtractArchive(file) || _v1ArchiveExtractionInProgress(archivePath)) {
      return;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        void closeDialog() {
          Navigator.of(dialogContext).pop();
        }

        return Stack(
          children: [
            PbArchiveExtractPreviewDialog(
              file: file,
              onClose: closeDialog,
              onInspect: (_) => inspectPowerboardsArchive(
                room: widget.client,
                archivePath: archivePath,
                targetFolderName: pbArchiveExtractFolderName(file.title),
              ),
              onConfirm: (inspection) {
                closeDialog();
                unawaited(_extractV1ArchiveForPreview(item, inspection));
              },
              onDownload: () {
                closeDialog();
                unawaited(_downloadV1Item(item));
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _extractV1ArchiveForPreview(PbFilesItemData item, PbArchiveInspectionResult inspection) async {
    final archivePath = _v1PathForItem(item);
    if (_v1ArchiveExtractionInProgress(archivePath)) {
      return;
    }

    _setV1ArchiveExtractionInProgress(archivePath, true);
    try {
      final target = await startPowerboardsArchiveExtractionWithToast(
        context: context,
        room: widget.client,
        archivePath: archivePath,
        inspection: inspection,
        onOpenResult: (target) {
          if (!mounted) {
            return;
          }

          _openV1ExtractedArchiveForPreview(target);
        },
      );

      if (mounted && target != null && parentPath(target.targetFolderPath) == _folderSig.value) {
        await _refreshCurrentFolder();
      }
    } finally {
      _setV1ArchiveExtractionInProgress(archivePath, false);
    }
  }

  Future<void> _downloadV1Archive(List<_DownloadArchiveItem> items) async {
    if (items.isEmpty) {
      return;
    }

    final currentFolder = _folderSig.value;
    final itemNames = [for (final item in items) p.basename(item.path)];
    final archiveBaseName = items.length == 1 && items.single.isFolder
        ? p.basename(items.single.path)
        : _v1FolderLabelForPath(currentFolder);
    final archiveFileName = powerboardsDownloadArchiveFileName(
      baseName: archiveBaseName,
      itemCount: items.length,
      createdAt: DateTime.now(),
    );
    final archivePath = _v1DownloadArchiveStagingPath(archiveFileName);
    final archiveContainerPath = p.posix.join('/data', archivePath);
    final toaster = ShadToaster.of(context);

    toaster.show(
      powerboardsToast(
        title: 'Preparing download',
        description: '${items.length} item${items.length == 1 ? '' : 's'} as zip',
        duration: const Duration(seconds: 5),
      ),
    );

    String? containerId;
    try {
      await _ensureV1DownloadArchiveStagingFolder();
      containerId = await widget.client.containers.run(
        image: "docker.io/joshkeegan/zip:latest",
        command: powerboardsDownloadArchiveCommand(archiveFileName: archiveContainerPath, itemNames: itemNames),
        mountPath: "/data",
        workingDir: "/data/$currentFolder",
        private: true,
      );

      final returnCode = await widget.client.containers.waitForExit(containerId: containerId);
      if (!mounted) {
        return;
      }

      if (returnCode != 0) {
        toaster.show(
          powerboardsToast(
            title: 'Download failed',
            description: 'Couldn’t prepare the zip archive. (Error code: $returnCode)',
            destructive: true,
            duration: const Duration(seconds: 8),
          ),
        );
        return;
      }

      await _downloadFile(archivePath, throwOnLaunchFailure: true);
      if (!mounted) {
        return;
      }

      toaster.show(powerboardsToast(title: 'Downloading', description: archiveFileName, duration: const Duration(seconds: 4)));
      _scheduleDownloadArchiveCleanup(archivePath);
    } catch (error) {
      _showDownloadFailure(error);
    } finally {
      try {
        if (containerId != null) {
          await widget.client.containers.deleteContainer(containerId: containerId);
        }
      } catch (error) {
        debugPrint("Failed to clean up download archive container: $error");
      }
    }
  }

  Future<void> _downloadV1WebsiteArchive() async {
    final archiveBaseName = _webServerDisplayLabel();
    final archiveFileName = powerboardsDownloadArchiveFileName(baseName: archiveBaseName, itemCount: 1, createdAt: DateTime.now());
    final archivePath = _v1DownloadArchiveStagingPath(archiveFileName);
    final archiveContainerPath = p.posix.join('/data', archivePath);
    final toaster = ShadToaster.of(context);

    toaster.show(powerboardsToast(title: 'Preparing download', description: 'Website as zip', duration: const Duration(seconds: 5)));

    String? containerId;
    try {
      await _ensureV1DownloadArchiveStagingFolder();
      containerId = await widget.client.containers.run(
        image: "docker.io/joshkeegan/zip:latest",
        command: powerboardsDownloadArchiveCommand(archiveFileName: archiveContainerPath, itemNames: const [_webServerFolderName]),
        mountPath: "/data",
        workingDir: "/data",
        private: true,
      );

      final returnCode = await widget.client.containers.waitForExit(containerId: containerId);
      if (!mounted) {
        return;
      }

      if (returnCode != 0) {
        toaster.show(
          powerboardsToast(
            title: 'Download failed',
            description: 'Couldn’t prepare the zip archive. (Error code: $returnCode)',
            destructive: true,
            duration: const Duration(seconds: 8),
          ),
        );
        return;
      }

      await _downloadFile(archivePath, throwOnLaunchFailure: true);
      if (!mounted) {
        return;
      }

      toaster.show(powerboardsToast(title: 'Downloading', description: archiveFileName, duration: const Duration(seconds: 4)));
      _scheduleDownloadArchiveCleanup(archivePath);
    } catch (error) {
      _showDownloadFailure(error);
    } finally {
      try {
        if (containerId != null) {
          await widget.client.containers.deleteContainer(containerId: containerId);
        }
      } catch (error) {
        debugPrint("Failed to clean up download archive container: $error");
      }
    }
  }

  void _scheduleDownloadArchiveCleanup(String archivePath) {
    final client = widget.client;
    unawaited(
      Future<void>.delayed(_downloadArchiveCleanupDelay, () async {
        try {
          await client.storage.delete(archivePath);
          if (!mounted) {
            return;
          }

          _removePath(archivePath, isFolder: false);
        } catch (error) {
          debugPrint("Failed to clean up download archive: $error");
        }
      }),
    );
  }

  Future<void> _ensureV1DownloadArchiveStagingFolder() async {
    if (await widget.client.storage.exists(_v1DownloadArchiveStagingFolder)) {
      return;
    }

    await widget.client.storage.uploadStream(
      joinPaths(_v1DownloadArchiveStagingFolder, placeholderFileName),
      Stream<Uint8List>.value(Uint8List(0)),
      overwrite: true,
      size: 0,
    );
  }

  Future<void> _shareFile(String path) async {
    final toaster = ShadToaster.of(context);
    Timer? progressTimer;
    if (_usesDesktopV1FilesBrowser()) {
      progressTimer = Timer(_v1LongActionToastDelay, () {
        if (!mounted || !_usesDesktopV1FilesBrowser()) {
          return;
        }

        toaster.show(
          powerboardsToast(title: 'Preparing share', description: _displayNameForPath(path), duration: const Duration(seconds: 4)),
        );
      });
    }

    try {
      await shareRemoteStorageFile(context: context, client: widget.client, path: path);
    } catch (error) {
      if (!mounted) {
        return;
      }

      toaster.show(powerboardsToast(title: 'Unable to share file', description: '$error', destructive: true));
    } finally {
      progressTimer?.cancel();
    }
  }

  Future<void> _deleteFile(
    String path, {
    PendingStorageDeleteHandle? pendingDelete,
    DateTime? pendingDeleteDisplayUntil,
    bool prepareV1Feedback = true,
  }) async {
    _toggleSelected(_FilePathKey.keyForPath(path, false), false);
    final displayUntil = pendingDeleteDisplayUntil ?? DateTime.now().add(_v1DeleteProcessingStep);
    final deleteHandle = pendingDelete ?? PendingStorageDeletes.begin(scope: _deleteScope, path: path, isFolder: false);
    if (prepareV1Feedback) {
      _prepareV1PendingDeleteFeedback([_FilePathKey.keyForPath(path, false)]);
    }

    try {
      await Future.wait<void>([_deleteStoragePath(path).then((_) => _onFileDeleted(path)), _waitForV1PendingDeleteDisplay(displayUntil)]);
    } catch (_) {
      deleteHandle.complete();
      if (mounted && _usesDesktopV1FilesBrowser()) {
        _setV1FileStateRow(_v1DeleteErrorRow(path: path, isFolder: false));
      }
      rethrow;
    } finally {
      deleteHandle.complete();
    }
  }

  Future<void> _deleteFolder(
    String folderPath, {
    PendingStorageDeleteHandle? pendingDelete,
    DateTime? pendingDeleteDisplayUntil,
    bool prepareV1Feedback = true,
  }) async {
    _toggleSelected(_FilePathKey.keyForPath(folderPath, true), false);
    final displayUntil = pendingDeleteDisplayUntil ?? DateTime.now().add(_v1DeleteProcessingStep);
    final deleteHandle = pendingDelete ?? PendingStorageDeletes.begin(scope: _deleteScope, path: folderPath, isFolder: true);
    if (prepareV1Feedback) {
      _prepareV1PendingDeleteFeedback([_FilePathKey.keyForPath(folderPath, true)]);
    }

    try {
      await Future.wait<void>([
        _deleteStoragePath(folderPath, recursive: true).then((_) => _removePath(folderPath, isFolder: true)),
        _waitForV1PendingDeleteDisplay(displayUntil),
      ]);
    } catch (_) {
      deleteHandle.complete();
      if (mounted && _usesDesktopV1FilesBrowser()) {
        _setV1FileStateRow(_v1DeleteErrorRow(path: folderPath, isFolder: true));
      }
      rethrow;
    } finally {
      deleteHandle.complete();
    }
  }

  String? _validateRenameInput(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Name cannot be empty';
    }
    if (trimmed.contains('/') || trimmed.contains('\\')) {
      return 'Enter a name, not a path';
    }
    if (trimmed == '.' || trimmed == '..') {
      return 'Enter a valid name';
    }
    return null;
  }

  String? _webServerDomainSuffix() {
    final currentValue = _webServerRouteDomain() ?? _webServerUrlValue();
    if (currentValue == null || currentValue.isEmpty) {
      final configuredDomains = powerboards_meshagent.MeshagentConfig.current?.domains ?? const <String>[];
      return configuredDomains.firstWhereOrNull((domain) => domain.trim().isNotEmpty)?.trim();
    }

    return powerboardsWebServerDomainSuffix(currentValue, configuredDomains: powerboards_meshagent.MeshagentConfig.current?.domains);
  }

  String _webServerEditableSlug() {
    final currentValue = _webServerRouteDomain() ?? _webServerUrlValue();
    if (currentValue == null || currentValue.isEmpty) {
      return _webServerFolderName;
    }

    return powerboardsWebServerSlugFromValue(currentValue, configuredDomains: powerboards_meshagent.MeshagentConfig.current?.domains);
  }

  String? _validateWebServerSlugInput(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Name cannot be empty';
    }
    if (trimmed.contains('/') || trimmed.contains('\\')) {
      return 'Enter a name, not a path';
    }
    if (trimmed.contains('.')) {
      return 'Enter only the name before the domain';
    }
    final normalized = trimmed.toLowerCase();
    if (!RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(normalized)) {
      return 'Use lowercase letters, numbers, or hyphens';
    }
    return null;
  }

  bool _usesThreadDisplayNameRename(String fullPath, {required bool isFolder}) {
    return !isFolder && isThreadPath(fullPath);
  }

  String _renameFieldInitialValue(String fullPath, {required bool isFolder}) {
    if (_usesThreadDisplayNameRename(fullPath, isFolder: isFolder)) {
      final normalizedPath = normalizeThreadStoragePath(fullPath);
      return threadFileDisplayNameFromPath(fullPath, threadDisplayName: _threadDisplayNamesByPath[normalizedPath]);
    }

    return p.basename(fullPath);
  }

  String _renameConflictDisplayName(String nextName, {required bool isFolder}) {
    if (!isFolder && isThreadFileName(nextName)) {
      return threadFileDisplayNameFromPath(nextName);
    }

    return nextName;
  }

  Future<String?> _promptRenamePath(String fullPath, {required bool isFolder}) async {
    final initialValue = _renameFieldInitialValue(fullPath, isFolder: isFolder);
    final usesThreadDisplayNameRename = _usesThreadDisplayNameRename(fullPath, isFolder: isFolder);

    return await showPowerboardsAlertDialog<String>(
      context: context,
      builder: (context) {
        return ControlledForm(
          builder: (context, controller, formKey) {
            void submit() {
              if (!formKey.currentState!.saveAndValidate()) {
                return;
              }

              final formData = formKey.currentState!.value;
              final name = (formData["name"] as String? ?? "").trim();
              Navigator.of(context).pop(name);
            }

            return PowerboardsShadDialog.compact(
              crossAxisAlignment: CrossAxisAlignment.start,
              title: Text(isFolder ? "Rename folder" : (usesThreadDisplayNameRename ? "Rename thread" : "Rename file")),
              actions: [
                ShadButton.outline(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                ShadButton(onPressed: submit, child: const Text("Rename")),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    PowerboardsAdaptiveInputFormField(
                      id: "name",
                      initialValue: initialValue,
                      validator: _validateRenameInput,
                      label: const Text("Name"),
                      autofocus: true,
                      onSubmitted: (_) => submit(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _renamePath(String fullPath, {required bool isFolder}) async {
    if (_isWebServerFolderPath(fullPath, isFolder: isFolder)) {
      await _openWebServerUrlDialog();
      return;
    }

    final usesThreadDisplayNameRename = _usesThreadDisplayNameRename(fullPath, isFolder: isFolder);
    final currentName = p.basename(fullPath);
    final nextName = await _promptRenamePath(fullPath, isFolder: isFolder);
    if (!mounted) {
      return;
    }
    if (nextName == null) {
      return;
    }

    if (usesThreadDisplayNameRename) {
      final currentDisplayName = _renameFieldInitialValue(fullPath, isFolder: isFolder);
      if (nextName == currentDisplayName) {
        return;
      }

      final threadNode = _threadNodeForPath(fullPath);
      if (threadNode != null) {
        threadNode.setAttribute('name', nextName);
        final normalizedPath = normalizeThreadStoragePath(fullPath);
        setState(() {
          _threadDisplayNamesByPath = <String, String>{..._threadDisplayNamesByPath, normalizedPath: nextName};
        });
        return;
      }
    }

    final resolvedNextName = usesThreadDisplayNameRename ? threadFileNameFromDisplayName(nextName) : nextName;
    if (resolvedNextName == currentName) {
      return;
    }

    final destinationPath = joinPaths(parentPath(fullPath), resolvedNextName);
    final toaster = ShadToaster.of(context);
    final showV1Progress = _usesDesktopV1FilesBrowser();
    var progressShown = false;
    Timer? progressTimer;

    try {
      if (showV1Progress) {
        progressTimer = Timer(_v1LongActionToastDelay, () {
          if (!mounted || !_usesDesktopV1FilesBrowser()) {
            return;
          }

          progressShown = true;
          toaster.show(
            powerboardsToast(
              title: isFolder ? 'Renaming folder' : 'Renaming file',
              description: _displayNameForPath(fullPath),
              duration: const Duration(seconds: 4),
            ),
          );
        });
      }

      if (await widget.client.storage.exists(destinationPath)) {
        if (!mounted) {
          return;
        }

        toaster.show(
          powerboardsToast(
            title: "Rename failed",
            description:
                "${isFolder ? 'Folder' : 'File'} `${_renameConflictDisplayName(resolvedNextName, isFolder: isFolder)}` already exists in this location.",
            destructive: true,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      await widget.client.storage.move(fullPath, destinationPath);
      if (mounted) {
        _onFileMoved(fullPath, destinationPath);
      }
      if (showV1Progress) {
        await _registerV1TransferredPath(
          sourcePath: fullPath,
          destinationPath: destinationPath,
          destinationClient: widget.client,
          destinationRoomName: widget.client.roomName?.trim() ?? '',
          folder: isFolder,
          move: true,
        );
      }
      if (!mounted) {
        return;
      }
      if (progressShown) {
        toaster.show(
          powerboardsToast(
            title: 'Renamed',
            description: _renameConflictDisplayName(resolvedNextName, isFolder: isFolder),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      toaster.show(
        powerboardsToast(title: "Rename failed", description: "$error", destructive: true, duration: const Duration(seconds: 6)),
      );
    } finally {
      progressTimer?.cancel();
    }
  }

  Future<void> _refreshCurrentFolder() async {
    final entries = await _getChildren(_folderSig.value);
    if (!mounted) {
      return;
    }

    for (final entry in entries) {
      if (entry.isFolder || entry.size == null || entry.size == 0) {
        continue;
      }
      _optimisticEmptyTextFiles.remove(joinPaths(_folderSig.value, entry.name));
    }

    _setEntries(entries);
  }

  bool _v1ItemCanMove(PbFilesItemData item) {
    return _v1ItemIsSelectable(item);
  }

  Future<RoomClient> _connectV1MoveRoom(String roomName) async {
    final projectId = widget.projectId;
    if (projectId == null) {
      throw StateError('The project context is not available.');
    }

    final connection = await powerboards_meshagent.getMeshagentClient().connectRoom(projectId: projectId, roomName: roomName);
    final roomClient = RoomClient(
      protocolFactory: meshagent_api.WebSocketClientProtocol.createFactory(url: connection.roomUrl, token: connection.jwt),
    );
    try {
      await roomClient.start();
      await roomClient.ready;
      return roomClient;
    } catch (_) {
      roomClient.dispose();
      rethrow;
    }
  }

  Future<List<String>> _v1MoveRoomOptions(String currentRoomName) async {
    final projectId = widget.projectId;
    if (projectId == null) {
      return [currentRoomName];
    }

    try {
      final rooms = await powerboards_meshagent.listMeshagentRooms(projectId);
      return {currentRoomName, ...rooms.map((room) => room.name).where((name) => name.trim().isNotEmpty)}.toList()
        ..sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
    } catch (_) {
      return [currentRoomName];
    }
  }

  Widget _buildV1MoveDestinationList(BuildContext context, List<FileBrowserRowViewModel> rows, {required Set<String> sourceItemPaths}) {
    final rowsById = {for (final row in rows) row.fullPath: row};
    return PbDialogFileList(
      items: [
        for (final row in rows)
          PbDialogFileListItemData(
            id: row.fullPath,
            title: row.displayName,
            iconAssetName: PbResolvedAttachmentMetadata.resolve(
              title: row.entry.name,
              explicitFileType: row.entry.isFolder ? PbAttachmentFileType.folder : null,
            ).iconAssetName,
            iconColor: row.entry.isFolder
                ? PbColors.surfaceRailActive
                : PbResolvedAttachmentMetadata.resolve(title: row.entry.name).iconColor,
            enabled: row.canActivate && !sourceItemPaths.contains(powerboardsNormalizeStoragePath(row.fullPath)),
            selectionEnabled: false,
            visuallyDisabled: sourceItemPaths.contains(powerboardsNormalizeStoragePath(row.fullPath)),
          ),
      ],
      showCheckboxes: false,
      framed: false,
      rowMargin: const EdgeInsets.symmetric(horizontal: 30, vertical: 1),
      rowPadding: const EdgeInsets.all(11),
      listPadding: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.none,
      onItemPressed: (item) => rowsById[item.id]?.onPressed(),
    );
  }

  Widget _buildV1MoveDestinationBrowser({
    required RoomClient room,
    required String roomName,
    required String initialPath,
    required Set<String> sourceItemPaths,
    required ValueChanged<String> onPathChanged,
  }) {
    return FileBrowser(
      key: ValueKey('v1-move-browser:$roomName:${identityHashCode(room)}'),
      room: room,
      initialPath: initialPath,
      selectionMode: FileBrowserSelectionMode.folders,
      showFilesWhenSelectingFolders: true,
      onPathChanged: onPathChanged,
      headerBuilder: (context, model) =>
          PbFileSelectBreadcrumb(currentPath: model.path, onRootPressed: model.onRootPressed, onSegmentPressed: model.onSegmentPressed),
      listBuilder: (context, rows) => _buildV1MoveDestinationList(context, rows, sourceItemPaths: sourceItemPaths),
      emptyBuilder: (context) => const PbFileSelectStatus.empty(message: 'Nothing here yet'),
      loadingBuilder: (context) => const PbFileSelectStatus(message: 'Loading files...', loading: true),
      errorBuilder: (context, error) => const PbFileSelectStatus(message: 'Unable to load files'),
    );
  }

  Future<void> _showV1MoveDestinationDialog(List<PbFilesItemData> items, {required String initialPath}) async {
    if (items.isEmpty) {
      return;
    }
    if (items.any((item) => !_v1ItemCanMove(item))) {
      ShadToaster.of(context).show(
        powerboardsToast(
          title: 'Unable to move selection',
          description: 'One or more selected items cannot be moved.',
          destructive: true,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    final sourceRoomName = widget.client.roomName?.trim() ?? '';
    if (sourceRoomName.isEmpty) {
      return;
    }

    final roomOptionsFuture = _v1MoveRoomOptions(sourceRoomName);

    var roomOptions = <String>[sourceRoomName];
    var roomOptionsLoadStarted = false;
    var selectedRoomName = sourceRoomName;
    var selectedRoomClient = widget.client;
    var destinationPath = powerboardsNormalizeStoragePath(initialPath);
    var resolvingRoom = false;
    var roomResolveError = false;
    var connectionGeneration = 0;
    var dialogFinished = false;
    final remoteClients = <RoomClient>{};
    final sourceItemPaths = items.map(_v1PathForItem).map(powerboardsNormalizeStoragePath).toSet();
    final sourceFolderPaths = items.where(_v1IsFolder).map(_v1PathForItem).toList(growable: false);
    final selectionContainsLinkedAttachments = _v1SelectionContainsLinkedAttachments(items);

    try {
      final selection = await showDialog<_V1MoveDestinationSelection>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        useSafeArea: false,
        builder: (dialogContext) => Stack(
          children: [
            StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                if (!roomOptionsLoadStarted) {
                  roomOptionsLoadStarted = true;
                  unawaited(
                    roomOptionsFuture.then((options) {
                      if (dialogFinished || !dialogContext.mounted) {
                        return;
                      }
                      setDialogState(() => roomOptions = options);
                    }),
                  );
                }
                final canConfirm =
                    !resolvingRoom &&
                    !roomResolveError &&
                    powerboardsV1CanUseMoveDestination(
                      sourceRoom: sourceRoomName,
                      destinationRoom: selectedRoomName,
                      initialPath: initialPath,
                      destinationPath: destinationPath,
                      sourceFolderPaths: sourceFolderPaths,
                    );
                final browser = resolvingRoom
                    ? const PbFileSelectStatus(message: 'Connecting to room...', loading: true)
                    : roomResolveError
                    ? const PbFileSelectStatus(message: 'Room failed to connect')
                    : _buildV1MoveDestinationBrowser(
                        room: selectedRoomClient,
                        roomName: selectedRoomName,
                        initialPath: selectedRoomName == sourceRoomName ? initialPath : '',
                        sourceItemPaths: selectedRoomName == sourceRoomName ? sourceItemPaths : const <String>{},
                        onPathChanged: (path) {
                          final normalizedPath = powerboardsNormalizeStoragePath(path);
                          if (!dialogContext.mounted || normalizedPath == destinationPath) {
                            return;
                          }
                          setDialogState(() => destinationPath = normalizedPath);
                        },
                      );

                return PbFilesMoveDestinationDialog(
                  rooms: roomOptions,
                  selectedRoom: selectedRoomName,
                  fileBrowser: browser,
                  itemCount: items.length,
                  canConfirm: canConfirm,
                  onClose: () => Navigator.of(dialogContext).pop(),
                  onConfirm: (copyFilesInstead) {
                    Future<void> confirmSelection() async {
                      var resolvedCopyFilesInstead = copyFilesInstead;
                      if (powerboardsV1ShouldConfirmCrossRoomLinkedMove(
                        sourceRoom: sourceRoomName,
                        destinationRoom: selectedRoomName,
                        copyFilesInstead: copyFilesInstead,
                        containsLinkedAttachments: selectionContainsLinkedAttachments,
                      )) {
                        final confirmed = await showPowerboardsAlertDialog<bool>(
                          context: dialogContext,
                          builder: (confirmationContext) => PowerboardsShadDialog.compactAlert(
                            title: const Text('Copy linked files instead?'),
                            description: const Text(
                              'Moving these files to another room would disconnect them from existing thread attachments. Continue to copy them instead, or cancel to keep choosing a destination.',
                            ),
                            actions: [
                              ShadButton.outline(
                                onPressed: () => Navigator.of(confirmationContext).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ShadButton(onPressed: () => Navigator.of(confirmationContext).pop(true), child: const Text('Continue')),
                            ],
                          ),
                        );
                        if (confirmed != true || !dialogContext.mounted) {
                          return;
                        }
                        resolvedCopyFilesInstead = true;
                      }

                      if (!dialogContext.mounted) {
                        return;
                      }
                      Navigator.of(dialogContext).pop(
                        _V1MoveDestinationSelection(
                          roomName: selectedRoomName,
                          path: destinationPath,
                          copyFilesInstead: resolvedCopyFilesInstead,
                        ),
                      );
                    }

                    unawaited(confirmSelection());
                  },
                  onRoomSelected: (roomName) async {
                    if (roomName == selectedRoomName || resolvingRoom) {
                      return;
                    }

                    final generation = ++connectionGeneration;
                    setDialogState(() {
                      resolvingRoom = true;
                      roomResolveError = false;
                    });

                    RoomClient? nextRoomClient;
                    try {
                      nextRoomClient = roomName == sourceRoomName ? widget.client : await _connectV1MoveRoom(roomName);
                      if (!identical(nextRoomClient, widget.client)) {
                        remoteClients.add(nextRoomClient);
                      }
                    } catch (_) {}

                    if (dialogFinished || !dialogContext.mounted || generation != connectionGeneration) {
                      if (nextRoomClient != null && !identical(nextRoomClient, widget.client)) {
                        nextRoomClient.dispose();
                        remoteClients.remove(nextRoomClient);
                      }
                      return;
                    }

                    if (nextRoomClient == null) {
                      setDialogState(() {
                        resolvingRoom = false;
                        roomResolveError = true;
                      });
                      return;
                    }

                    setDialogState(() {
                      selectedRoomName = roomName;
                      selectedRoomClient = nextRoomClient!;
                      destinationPath = roomName == sourceRoomName ? powerboardsNormalizeStoragePath(initialPath) : '';
                      resolvingRoom = false;
                    });
                  },
                );
              },
            ),
          ],
        ),
      );

      if (selection == null || !mounted) {
        return;
      }

      await _transferV1Items(
        items,
        destinationRoomName: selection.roomName,
        destinationPath: selection.path,
        destinationClient: selectedRoomClient,
        move: !selection.copyFilesInstead,
      );
    } finally {
      dialogFinished = true;
      for (final remoteClient in remoteClients) {
        remoteClient.dispose();
      }
    }
  }

  Future<void> _transferV1Items(
    List<PbFilesItemData> items, {
    required String destinationRoomName,
    required String destinationPath,
    required RoomClient destinationClient,
    required bool move,
  }) async {
    final toaster = ShadToaster.of(context);
    final verb = move ? 'move' : 'copy';
    final presentParticiple = move ? 'Moving' : 'Copying';
    final progressTimer = Timer(_v1LongActionToastDelay, () {
      if (!mounted) {
        return;
      }
      toaster.show(
        powerboardsToast(
          title: '$presentParticiple ${items.length == 1 ? 'item' : 'items'}',
          description: destinationRoomName,
          duration: const Duration(seconds: 4),
        ),
      );
    });

    var succeeded = 0;
    var registrationFailures = 0;
    Object? firstError;
    try {
      for (final item in items) {
        final sourcePath = _v1PathForItem(item);
        final folder = _v1IsFolder(item);
        try {
          final resolvedDestinationPath = await powerboardsTransferStoragePath(
            sourceStorage: widget.client.storage,
            destinationStorage: destinationClient.storage,
            sourcePath: sourcePath,
            destinationFolder: destinationPath,
            folder: folder,
            move: move,
          );
          succeeded += 1;
          if (move && identical(widget.client, destinationClient)) {
            _onFileMoved(sourcePath, resolvedDestinationPath);
          } else if (move) {
            _removePath(sourcePath, isFolder: folder);
          }
          final registered = await _registerV1TransferredPath(
            sourcePath: sourcePath,
            destinationPath: resolvedDestinationPath,
            destinationClient: destinationClient,
            destinationRoomName: destinationRoomName,
            folder: folder,
            move: move,
          );
          if (!registered) {
            registrationFailures += 1;
          }
        } catch (error) {
          firstError ??= error;
        }
      }
    } finally {
      progressTimer.cancel();
    }

    if (!mounted) {
      return;
    }

    if (succeeded > 0) {
      _clearSelected();
      await Future.wait([_refreshCurrentFolder(), _refreshFileAttachmentLinks()]);
      if (!mounted) {
        return;
      }
    }

    if (succeeded == items.length) {
      toaster.show(
        powerboardsToast(
          title: move ? 'Files moved' : 'Files copied',
          description: registrationFailures == 0
              ? '${items.length} ${items.length == 1 ? 'item' : 'items'} ${move ? 'moved' : 'copied'} successfully.'
              : '${items.length} ${items.length == 1 ? 'item was' : 'items were'} ${move ? 'moved' : 'copied'}, but some thread references could not be updated.',
          destructive: registrationFailures > 0,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    toaster.show(
      powerboardsToast(
        title: succeeded == 0 ? 'Unable to $verb files' : 'Some files could not be ${move ? 'moved' : 'copied'}',
        description: succeeded == 0 ? '$firstError' : '$succeeded of ${items.length} completed. $firstError',
        destructive: true,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  bool _v1SelectionContainsLinkedAttachments(Iterable<PbFilesItemData> items) {
    for (final item in items) {
      final sourcePath = powerboardsNormalizeStoragePath(_v1PathForItem(item));
      final folder = _v1IsFolder(item);
      if (_fileAttachmentLinks.any((link) => link.filePath == sourcePath || (folder && link.filePath.startsWith('$sourcePath/')))) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _registerV1TransferredPath({
    required String sourcePath,
    required String destinationPath,
    required RoomClient destinationClient,
    required String destinationRoomName,
    required bool folder,
    required bool move,
  }) async {
    final sourceRoomName = widget.client.roomName?.trim() ?? '';
    if (sourceRoomName.isEmpty || destinationRoomName.trim().isEmpty) {
      return false;
    }

    try {
      await registerPowerboardsFileTransfer(
        sourceRoom: widget.client,
        destinationRoom: destinationClient,
        sourceRoomName: sourceRoomName,
        destinationRoomName: destinationRoomName,
        sourcePath: sourcePath,
        destinationPath: destinationPath,
        folder: folder,
        move: move,
      );
      return true;
    } catch (error) {
      debugPrint('Failed to register ${move ? 'move' : 'copy'} reference for $sourcePath: $error');
      return false;
    }
  }

  Future<void> _compressFolder(String folderPath) async {
    final toaster = ShadToaster.of(context);
    final folderName = p.basename(folderPath);
    final parentFolder = parentPath(folderPath);

    final zipFileName = "$folderName.zip";

    toaster.show(powerboardsToast(title: "Compressing folder", description: "Creating $zipFileName", duration: const Duration(seconds: 5)));

    String? containerId;

    try {
      containerId = await widget.client.containers.run(
        image: "docker.io/joshkeegan/zip:latest",
        command: "/usr/bin/zip -r ${_shellQuote(zipFileName)} ${_shellQuote(folderName)}",
        mountPath: "/data",
        workingDir: "/data/$parentFolder",
        private: true,
      );

      final returnCode = await widget.client.containers.waitForExit(containerId: containerId);

      if (!mounted) {
        return;
      }

      if (returnCode == 0) {
        toaster.show(
          powerboardsToast(title: "Compression complete", description: "Created $zipFileName", duration: const Duration(seconds: 5)),
        );
        _refreshCurrentFolder();
      } else {
        toaster.show(
          powerboardsToast(
            title: "Compression failed",
            description: "Ups something went wrong while compressing the folder. Please try again. (Error code: $returnCode)",
            destructive: true,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      try {
        if (containerId != null) {
          await widget.client.containers.deleteContainer(containerId: containerId);
        }
      } catch (e) {
        debugPrint("Failed to clean up compression container: $e");
      }
    }
  }

  Future<void> _onFileDrop(String name, Stream<Uint8List> stream, int? fileSize) async {
    final fileName = joinPaths(_folderSig.value, name);
    await _uploadFile(stream, fileName, fileSize ?? 0);
  }

  Future<void> _addPhotos(String path) async {
    await FileUploadHelper.pickAndUploadPhotos(path: path, onUpload: _uploadFile);
  }

  Future<void> _addFiles(String path) async {
    await FileUploadHelper.pickAndUploadFiles(path: path, onUpload: _uploadFile);
  }

  Future<void> _addFolder(String path) async {
    final result = await showPowerboardsAlertDialog<String>(
      context: context,
      builder: (context) {
        return ControlledForm(
          builder: (context, controller, formKey) {
            void submit() {
              if (!formKey.currentState!.saveAndValidate()) {
                return;
              }

              final formData = formKey.currentState!.value;
              final name = formData["name"] ?? "";

              Navigator.of(context).pop(name);
            }

            return PowerboardsShadDialog.compact(
              crossAxisAlignment: CrossAxisAlignment.start,
              title: Text("New folder"),
              actions: [
                ShadButton.outline(
                  onPressed: () {
                    Navigator.of(context).pop(null);
                  },
                  child: const Text('Cancel'),
                ),

                ShadButton(onPressed: submit, child: const Text("OK")),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    PowerboardsAdaptiveInputFormField(
                      initialValue: "",
                      validator: TextValidators.folder,
                      id: "name",
                      label: Text("Name"),
                      autofocus: true,
                      onSubmitted: (_) => submit(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result == null) {
      return;
    }

    final fileName = joinPaths(path, "$result/$placeholderFileName");
    await _uploadFile(Stream.empty(), fileName, 0);
  }

  Future<void> _createOrOpenWebServerFolder() async {
    final placeholderPath = joinPaths(_webServerFolderName, placeholderFileName);
    await _uploadFile(Stream.empty(), placeholderPath, 0);
    if (!mounted) {
      return;
    }

    _openEntry(_webServerFolderName, true);
  }

  bool get _canInstallWebServerFromFiles {
    final roomName = widget.client.roomName?.trim();
    return widget.canInstallServices && widget.projectId != null && roomName != null && roomName.isNotEmpty;
  }

  ServiceSpec? _currentWebServerService() {
    if (widget.services?.state.isReady != true) {
      return null;
    }

    final services = widget.services?.state.value;
    if (services == null) {
      return null;
    }

    return services.firstWhereOrNull((service) => service.metadata.annotations['meshagent.service.id'] == _webServerServiceId);
  }

  Map<String, String> _webServerTemplateValues(ServiceSpec service) {
    final raw = service.metadata.annotations['meshagent.service.template.values'];
    if (raw == null || raw.trim().isEmpty) {
      return const <String, String>{};
    }

    try {
      return (jsonDecode(raw) as Map).map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''));
    } catch (_) {
      return const <String, String>{};
    }
  }

  String? _webServerUrlValue() {
    final service = _currentWebServerService();
    if (service == null) {
      return null;
    }

    final values = _webServerTemplateValues(service);
    final url = values[_webServerUrlVariableName]?.trim();
    if (url == null || url.isEmpty) {
      return null;
    }

    return url;
  }

  String? _webServerRouteDomain() {
    final service = _currentWebServerService();
    final routes = roomRoutes.state.asReady?.value;
    if (service == null || routes == null || routes.isEmpty) {
      return null;
    }

    final matchedRoutes = routesForService(routes: routes, service: service);
    final preferredDomain = _webServerUrlValue();
    final matchingPreferredRoute = preferredDomain == null
        ? null
        : matchedRoutes.firstWhereOrNull((route) => route.domain.trim() == _webServerLabelFromUrlValue(preferredDomain));
    final domain = (matchingPreferredRoute ?? matchedRoutes.firstOrNull)?.domain.trim();
    if (domain == null || domain.isEmpty) {
      return null;
    }

    return domain;
  }

  String _webServerLabelFromUrlValue(String url) {
    return powerboardsWebServerDisplayHost(url, fallback: _webServerFolderName);
  }

  String _webServerDisplayLabel() {
    final routeDomain = _webServerRouteDomain();
    if (routeDomain != null && routeDomain.isNotEmpty) {
      return routeDomain;
    }

    final url = _webServerUrlValue();
    if (url == null || url.isEmpty) {
      return _webServerFolderName;
    }

    return _webServerLabelFromUrlValue(url);
  }

  Uri? _webServerSiteUri() {
    final routeDomain = _webServerRouteDomain();
    if (routeDomain == null || routeDomain.isEmpty) {
      return null;
    }

    final normalized = routeDomain.trim();
    return Uri.tryParse(normalized.contains('://') ? normalized : 'https://$normalized');
  }

  bool _isWebServerFolderRoot(String path) {
    return PendingStorageDeletes.normalizePath(path) == _webServerFolderName;
  }

  bool _isWebServerPreviewHtmlEntry(StorageEntry entry) {
    if (entry.isFolder) {
      return false;
    }

    final normalized = entry.name.trim().toLowerCase();
    return normalized.endsWith('.html') || normalized.endsWith('.htm');
  }

  String? _webServerPreviewEntryPathFromEntries(Iterable<StorageEntry> entries) {
    final htmlEntries = entries.where(_isWebServerPreviewHtmlEntry).toList(growable: false);
    if (htmlEntries.isEmpty) {
      return null;
    }

    final preferred = htmlEntries.firstWhereOrNull((entry) => entry.name.trim().toLowerCase() == 'index.html');
    final entry = preferred ?? htmlEntries.sortedBy((entry) => entry.name.toLowerCase()).first;
    return joinPaths(_webServerFolderName, entry.name);
  }

  Future<List<String>> _listWebsitePreviewFilePaths(String folderPath) async {
    final entries = await widget.client.storage.list(folderPath);
    final paths = <String>[];
    for (final entry in entries) {
      final entryPath = joinPaths(folderPath, entry.name);
      if (entry.isFolder) {
        if (_websitePreviewIgnoredDirectoryNames.contains(entry.name.trim().toLowerCase())) {
          continue;
        }
        paths.addAll(await _listWebsitePreviewFilePaths(entryPath));
        continue;
      }

      paths.add(entryPath);
    }
    return paths;
  }

  Future<String> _buildWebsitePreviewHtml({required String entryPath}) async {
    final websiteRootPath = p.posix.split(entryPath).first;
    final filePaths = await _listWebsitePreviewFilePaths(websiteRootPath);
    final urlEntries = await Future.wait(filePaths.map((path) async => MapEntry(path, await widget.client.storage.downloadUrl(path))));
    final textPaths = filePaths.where((path) {
      final extension = p.extension(path).toLowerCase();
      return extension == '.html' || extension == '.htm' || extension == '.css';
    });
    final textEntries = await Future.wait(
      textPaths.map((path) async {
        final file = await widget.client.storage.download(path);
        return MapEntry(path, utf8.decode(file.data));
      }),
    );
    final textContentByPath = Map<String, String>.fromEntries(textEntries);
    final entryHtml = textContentByPath[entryPath];
    if (entryHtml == null) {
      throw StateError('Unable to load website preview entry: $entryPath');
    }

    return buildPbWebsitePreviewHtml(
      entryPath: entryPath,
      html: entryHtml,
      textContentByPath: textContentByPath,
      urlByPath: Map<String, String>.fromEntries(urlEntries),
    );
  }

  Future<void> _openV1WebsitePreview({required Iterable<StorageEntry> entries}) async {
    final previewPath = _webServerPreviewEntryPathFromEntries(entries);
    if (previewPath == null) {
      if (mounted) {
        ShadToaster.of(context).show(
          powerboardsToast(
            title: 'Website preview unavailable',
            description: 'Add an HTML file such as `index.html` to preview this website.',
            destructive: true,
          ),
        );
      }
      return;
    }

    try {
      final routePreviewUri = _webServerSiteUri();
      final useRoutePreview = routePreviewUri != null && powerboardsWebsitePreviewShouldUseRoute(entries);
      final previewHtml = useRoutePreview ? null : await _buildWebsitePreviewHtml(entryPath: previewPath);
      if (!mounted) {
        return;
      }

      setState(() {
        if (_v1PreviewFile != null) {
          _clearV1PreviewDraftForItem(_v1PreviewFile);
        }
        _v1PreviewFile = null;
        _v1WebsitePreview = _V1WebsitePreviewState(
          entryPath: previewPath,
          previewHtml: previewHtml,
          previewUrl: useRoutePreview ? routePreviewUri : null,
          title: _webServerDisplayLabel(),
        );
        _v1FilePreviewFullscreen = true;
        _v1FilesRoomPanelCollapsed = false;
        _v1FilesRoomPanelOverlayOpen = false;
        _v1RestoreRoomPanelOverlayOnPreviewClose = false;
        _clearV1KeyboardPreviewNavigationState();
        _clearSelected();
      });
      setPreviewFilePreviewFullscreen(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ShadToaster.of(context).show(
        powerboardsToast(
          title: 'Website preview unavailable',
          description: '$error',
          destructive: true,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _openRouteRequestedWebServerPreviewIfNeeded({required Iterable<StorageEntry> entries}) {
    final uri = PathRouteMatch.of(context).uri;
    if (uri.queryParameters[_webServerPreviewQueryParameter] != '1') {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final currentUri = PathRouteMatch.of(context).uri;
      if (currentUri.queryParameters[_webServerPreviewQueryParameter] != '1') {
        return;
      }
      final updatedQueryParameters = Map<String, String>.from(currentUri.queryParameters)..remove(_webServerPreviewQueryParameter);
      context.go(currentUri.replace(queryParameters: updatedQueryParameters).toString());
      if (_webServerPreviewEntryPathFromEntries(entries) == null) {
        return;
      }
      unawaited(_openV1WebsitePreview(entries: entries));
    });
  }

  void _closeV1WebsitePreview() {
    if (_v1WebsitePreview == null) {
      return;
    }

    setState(() {
      _v1WebsitePreview = null;
      _v1FilePreviewFullscreen = false;
    });
    setPreviewFilePreviewFullscreen(false);
  }

  Future<void> _openV1WebsiteSite() async {
    final siteUri = _webServerSiteUri();
    if (siteUri == null) {
      return;
    }

    final launched = await launchUrl(siteUri, webOnlyWindowName: '_blank');
    if (launched || !mounted) {
      return;
    }

    ShadToaster.of(context).show(
      powerboardsToast(
        title: 'Unable to open website',
        description: 'The published website could not be opened in a new tab.',
        destructive: true,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  bool get _hasInstalledWebServer => _currentWebServerService() != null;

  bool _isWebServerFolderPath(String fullPath, {required bool isFolder}) {
    return powerboardsV1IsCanonicalWebServerFolder(
      usesDesktopV1FilesBrowser: _usesDesktopV1FilesBrowser(),
      fullPath: fullPath,
      isFolder: isFolder,
    );
  }

  bool _isWebServerInstalled() {
    return _hasInstalledWebServer;
  }

  Future<ServiceDirectoryEntry?> _loadWebServerTemplate() async {
    final serverUrl = powerboards_meshagent.MeshagentConfig.current?.serverUrl;
    if (serverUrl == null) {
      throw StateError("MeshagentConfig.current.serverUrl is not set");
    }

    final response = await http.get(serverUrl.resolve("/directory"));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("Failed to load service directory: ${response.statusCode}");
    }

    final directory = await ServiceDirectoryPage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    return directory.templates.firstWhereOrNull(
      (entry) => entry.parsed.metadata.annotations["meshagent.service.id"] == _webServerServiceId,
    );
  }

  Future<void> _refreshWebServerState() async {
    final services = widget.services;
    await powerboardsRefreshFilesWebServerState(services: services, roomRoutes: roomRoutes);
    widget.onServiceChanged?.call();
    if (mounted) {
      setState(() {});
    }
  }

  Future<String?> _promptRenameWebServerUrl() async {
    final initialValue = _webServerEditableSlug();
    final suffix = _webServerDomainSuffix();

    return await showPowerboardsAlertDialog<String>(
      context: context,
      builder: (context) {
        final theme = ShadTheme.of(context);
        return ControlledForm(
          builder: (context, controller, formKey) {
            void submit() {
              if (!formKey.currentState!.saveAndValidate()) {
                return;
              }

              final formData = formKey.currentState!.value;
              final name = (formData["name"] as String? ?? "").trim().toLowerCase();
              Navigator.of(context).pop(name);
            }

            return PowerboardsShadDialog.compact(
              crossAxisAlignment: CrossAxisAlignment.start,
              title: const Text('Rename website URL'),
              actions: [
                ShadButton.outline(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                ShadButton(onPressed: submit, child: const Text('Rename')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    PowerboardsAdaptiveInputFormField(
                      id: "name",
                      initialValue: initialValue,
                      validator: _validateWebServerSlugInput,
                      label: const Text("Name"),
                      autofocus: true,
                      trailing: suffix == null || suffix.isEmpty
                          ? null
                          : Container(
                              color: theme.colorScheme.muted,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Text('.$suffix', style: theme.textTheme.small.copyWith(color: theme.colorScheme.mutedForeground)),
                            ),
                      onSubmitted: (_) => submit(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _webServerDomainForSlug(String slug) {
    final currentValue = _webServerRouteDomain() ?? _webServerUrlValue();
    return powerboardsWebServerDomainFromSlug(
      slug,
      currentValue: currentValue,
      configuredDomains: powerboards_meshagent.MeshagentConfig.current?.domains,
    );
  }

  Future<void> _renameWebServerUrl(String nextSlug) async {
    final projectId = widget.projectId;
    final roomName = widget.client.roomName?.trim();
    final service = _currentWebServerService();
    if (projectId == null || roomName == null || roomName.isEmpty || service?.id == null) {
      return;
    }

    final toaster = ShadToaster.of(context);

    try {
      final prefilled = _webServerTemplateValues(service!);
      final nextDomain = _webServerDomainForSlug(nextSlug);
      final currentDomain = _webServerRouteDomain() ?? _webServerUrlValue();
      if (currentDomain != null && _webServerLabelFromUrlValue(currentDomain) == _webServerLabelFromUrlValue(nextDomain)) {
        return;
      }

      final existingTemplate = service.metadata.annotations['meshagent.service.template.yaml'];
      String? template = existingTemplate;
      ServiceTemplateSpec? manifest;

      if (template != null && template.trim().isNotEmpty) {
        manifest = await powerboards_meshagent.getMeshagentClient().renderTemplate(template: template, values: prefilled);
      } else {
        final directoryTemplate = await _loadWebServerTemplate();
        template = directoryTemplate?.template;
        manifest = directoryTemplate?.parsed;
      }

      if (!mounted || template == null || template.trim().isEmpty) {
        return;
      }

      final nextValues = <String, String>{...prefilled, _webServerUrlVariableName: nextDomain};
      final renderedTemplate =
          manifest ?? await powerboards_meshagent.getMeshagentClient().renderTemplate(template: template, values: nextValues);
      final inputVariables = renderedTemplate.variables ?? const <ServiceTemplateVariable>[];
      final routeRequests = <({String domain, String port})>[];
      for (final variable in inputVariables) {
        if (variable.type != 'route') {
          continue;
        }

        final domain = (nextValues[variable.name] ?? '').trim();
        if (domain.isEmpty) {
          continue;
        }

        final port = variable.annotations?['meshagent.route.port']?.trim();
        if (port == null || port.isEmpty) {
          throw RoomServerException('meshagent.route.port is missing for ${variable.name}');
        }
        routeRequests.add((domain: domain, port: port));
      }

      final client = powerboards_meshagent.getMeshagentClient();
      final existingServiceRoutes = routesForService(
        routes: await client.listRoomRoutes(projectId: projectId, roomName: roomName),
        service: service,
      );
      final requestedRouteDomains = {for (final route in routeRequests) route.domain};

      if (routeRequests.isNotEmpty) {
        final room = await client.getRoom(projectId: projectId, name: roomName);
        for (final route in routeRequests) {
          try {
            final existing = await client.getRoute(projectId: projectId, domain: route.domain);
            if (existing.roomName != room.name) {
              throw RoomServerException('Domain ${route.domain} has already been assigned to another room');
            }
            await client.updateRoute(
              projectId: projectId,
              domain: route.domain,
              roomName: room.name,
              port: route.port,
              annotations: {'meshagent.service.id': _webServerServiceId},
            );
          } on meshagent_api.NotFoundException {
            await client.createRoute(
              projectId: projectId,
              domain: route.domain,
              roomName: room.name,
              port: route.port,
              annotations: {'meshagent.service.id': _webServerServiceId},
            );
          }
        }
      }

      await client.updateRoomServiceFromTemplate(
        projectId: projectId,
        serviceId: service.id!,
        template: template,
        values: nextValues,
        roomName: roomName,
      );

      for (final route in existingServiceRoutes) {
        if (requestedRouteDomains.contains(route.domain)) {
          continue;
        }
        await client.deleteRoute(projectId: projectId, domain: route.domain);
      }

      await _refreshWebServerState();
    } catch (error) {
      if (mounted) {
        toaster.show(powerboardsToast(title: 'Unable to change website URL', description: '$error', destructive: true));
      }
    }
  }

  Future<void> _openWebServerUrlDialog() async {
    final nextSlug = await _promptRenameWebServerUrl();
    if (!mounted || nextSlug == null) {
      return;
    }

    if (nextSlug == _webServerEditableSlug()) {
      return;
    }

    await _renameWebServerUrl(nextSlug);
  }

  Future<void> _openWebServerInstallDialog() async {
    if (!_canInstallWebServerFromFiles || _installingWebServer) {
      return;
    }

    final projectId = widget.projectId!;
    final roomName = widget.client.roomName!.trim();
    final toaster = ShadToaster.of(context);
    setState(() => _installingWebServer = true);
    try {
      final template = await _loadWebServerTemplate();
      if (!mounted) {
        return;
      }

      if (template == null) {
        toaster.show(
          powerboardsToast(
            title: "Web server unavailable",
            description: 'The Web server service template is not available right now.',
            destructive: true,
          ),
        );
        return;
      }

      final installed = await showPowerboardsFlowDialog<bool>(
        context: context,
        builder: (_) => InstallServiceDialog(
          template: template.template,
          projectId: projectId,
          roomName: roomName,
          onInstalled: (dialogContext, _, _, _) {
            Navigator.of(dialogContext).pop(true);
          },
        ),
      );

      if (!mounted || installed != true) {
        return;
      }

      await _refreshWebServerState();

      await _createOrOpenWebServerFolder();
      if (!mounted) {
        return;
      }

      toaster.show(powerboardsToast(title: "Web server installed", description: 'The "website" folder is ready for files.'));
    } catch (_) {
      if (mounted) {
        toaster.show(
          powerboardsToast(
            title: "Unable to install Web server",
            description: 'Try again from Files or from Agents & Services.',
            destructive: true,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _installingWebServer = false);
      }
    }
  }

  Future<void> _deleteActiveWebServerFolder(String folderPath) async {
    final projectId = widget.projectId;
    final roomName = widget.client.roomName?.trim();
    if (projectId == null || roomName == null || roomName.isEmpty) {
      throw StateError('Web server room context is not available.');
    }

    final client = powerboards_meshagent.getMeshagentClient();
    await powerboardsUninstallV1WebServerResources(client: client, projectId: projectId, roomName: roomName);

    try {
      final deleted = await powerboardsV1DeleteFolderIfPresent(
        exists: () => widget.client.storage.exists(folderPath),
        delete: () => _deleteFolder(folderPath),
      );
      if (!deleted) {
        _removePath(folderPath, isFolder: true);
      }
    } catch (error) {
      await _refreshWebServerState();
      throw StateError('The website service was removed, but the website folder could not be deleted: $error');
    }

    await _refreshWebServerState();
  }

  Future<bool> _confirmAndDeleteWebServerFolder(String folderPath) async {
    final confirmDelete = await showPowerboardsAlertDialog<bool>(
      context: context,
      builder: (context) => PowerboardsShadDialog.compactAlert(
        title: const Text('Delete website'),
        description: const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('This will uninstall the website service and permanently delete the website folder and all its contents.'),
        ),
        actions: [
          ShadButton.outline(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
          ShadButton.destructive(child: const Text('Delete'), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );

    if (confirmDelete != true) {
      return false;
    }

    try {
      await _deleteActiveWebServerFolder(folderPath);
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      ShadToaster.of(context).show(
        powerboardsToast(title: 'Unable to delete website', description: '$error', destructive: true, duration: const Duration(seconds: 6)),
      );
      return false;
    }
  }

  Future<bool> _confirmAndDelete(String fullPath, bool isFolder) async {
    if (_isWebServerFolderPath(fullPath, isFolder: isFolder)) {
      return _confirmAndDeleteWebServerFolder(fullPath);
    }

    final name = fullPath.split('/').where((s) => s.isNotEmpty).last;
    final displayName = isFolder ? name : _displayNameForPath(fullPath);
    final bool? confirmDelete = await showPowerboardsAlertDialog<bool>(
      context: context,
      builder: (context) => PowerboardsShadDialog.compactAlert(
        title: const Text("Confirm Delete"),
        description: Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text("Are you sure you want to delete ${isFolder ? 'folder $displayName and all its contents' : displayName}?"),
        ),
        actions: [
          ShadButton.outline(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
          ShadButton.destructive(child: const Text('Delete'), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        if (isFolder) {
          await _deleteFolder(fullPath);
        } else {
          await _deleteFile(fullPath);
        }
      } catch (error) {
        if (!mounted) {
          return false;
        }

        ShadToaster.of(context).show(
          powerboardsToast(
            title: "Unable to delete ${isFolder ? 'folder' : 'file'}",
            description: "$error",
            destructive: true,
            duration: const Duration(seconds: 6),
          ),
        );
        return false;
      }
      return true;
    }

    return false;
  }

  Future<void> _confirmAndDeleteSelected() async {
    final useDesktopV1FilesBrowser = _usesDesktopV1FilesBrowser();
    final v1Items = useDesktopV1FilesBrowser ? _v1VisibleItems(_storageEntriesSnapshot()) : const <PbFilesItemData>[];
    final selected = useDesktopV1FilesBrowser ? _v1SelectedItemIdsForAction(v1Items) : _visibleSelected.value;
    if (selected.isEmpty) return;

    final toaster = ShadToaster.of(context);
    final isMobile = _usesAdaptiveMobileLayout(context);
    final count = selected.length;
    final names = selected.take(6).map((key) {
      final path = _FilePathKey.pathFromKey(key);
      if (_FilePathKey.isFolderKey(key)) {
        final folderName = path.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? path;
        return '$folderName/';
      }
      return _displayNameForPath(path);
    }).toList();

    final confirmDelete = await showPowerboardsAlertDialog<bool>(
      context: context,
      builder: (context) => PowerboardsShadDialog.compactAlert(
        title: const Text("Confirm Delete"),
        description: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Delete $count item${count == 1 ? '' : 's'}?"),
              const SizedBox(height: 8),
              for (final n in names) Text("• $n"),
              if (count > names.length) Text("• …and ${count - names.length} more"),
            ],
          ),
        ),
        actions: [
          ShadButton.outline(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
          ShadButton.destructive(child: const Text('Delete'), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );

    if (confirmDelete != true) return;

    int success = 0;
    final failures = <String>[];
    final v1ItemsById = useDesktopV1FilesBrowser ? {for (final item in v1Items) item.id: item} : const <String, PbFilesItemData>{};
    final toDelete = useDesktopV1FilesBrowser
        ? [
            for (final key in selected)
              if (v1ItemsById[key] == null || _v1ItemIsSelectable(v1ItemsById[key]!)) key,
          ]
        : selected.toList();
    final webServerSelections = [
      for (final key in toDelete)
        if (_isWebServerFolderPath(_FilePathKey.pathFromKey(key), isFolder: _FilePathKey.isFolderKey(key))) key,
    ];
    if (webServerSelections.isNotEmpty) {
      if (toDelete.length == 1) {
        await _confirmAndDelete(_FilePathKey.pathFromKey(webServerSelections.first), true);
        return;
      }

      toaster.show(
        powerboardsToast(
          title: 'Remove website separately',
          description: 'Remove the website on its own before using batch delete.',
          destructive: true,
        ),
      );
      return;
    }

    final pendingDeletes = <String, _PendingDeleteOperation>{};
    final batchStartedAt = DateTime.now();

    for (final key in toDelete) {
      final isFolder = _FilePathKey.isFolderKey(key);
      final path = _FilePathKey.pathFromKey(key);
      if (_isDeletePending(path, isFolder)) {
        continue;
      }

      pendingDeletes[key] = _PendingDeleteOperation(
        handle: PendingStorageDeletes.begin(scope: _deleteScope, path: path, isFolder: isFolder),
        displayUntil: batchStartedAt.add(Duration(milliseconds: _v1DeleteProcessingStep.inMilliseconds * (pendingDeletes.length + 1))),
      );
    }

    _prepareV1PendingDeleteFeedback(pendingDeletes.keys);

    if (isMobile) {
      _clearMobileSelectionMode();
    } else {
      _clearSelected();
    }

    for (final key in toDelete) {
      final pendingDeleteOperation = pendingDeletes[key];
      if (pendingDeleteOperation == null) {
        continue;
      }

      final isFolder = _FilePathKey.isFolderKey(key);
      final path = _FilePathKey.pathFromKey(key);

      try {
        if (isFolder) {
          await _deleteFolder(
            path,
            pendingDelete: pendingDeleteOperation.handle,
            pendingDeleteDisplayUntil: pendingDeleteOperation.displayUntil,
            prepareV1Feedback: false,
          );
        } else {
          await _deleteFile(
            path,
            pendingDelete: pendingDeleteOperation.handle,
            pendingDeleteDisplayUntil: pendingDeleteOperation.displayUntil,
            prepareV1Feedback: false,
          );
        }
        success++;
      } catch (e) {
        failures.add(path);
      }
    }

    if (failures.isEmpty) {
      toaster.show(
        powerboardsToast(title: "Deleted", description: "$success item${success == 1 ? '' : 's'}", duration: const Duration(seconds: 4)),
      );
    } else {
      toaster.show(
        powerboardsToast(
          title: "Delete failed",
          description: "Deleted $success item${success == 1 ? '' : 's'}. Failed ${failures.length} item${failures.length == 1 ? '' : 's'}.",
          destructive: true,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _downloadSelected() async {
    final useDesktopV1FilesBrowser = _usesDesktopV1FilesBrowser();
    final selected = useDesktopV1FilesBrowser
        ? powerboardsV1SelectedVisibleItemIds(_selectedSig.value, _v1VisibleItems(_storageEntriesSnapshot()))
        : _visibleSelected.value;
    if (selected.isEmpty) return;

    if (useDesktopV1FilesBrowser) {
      final items = [
        for (final key in selected) _DownloadArchiveItem(path: _FilePathKey.pathFromKey(key), isFolder: _FilePathKey.isFolderKey(key)),
      ];

      if (items.any((item) => item.isFolder)) {
        await _downloadV1Archive(items);
        return;
      }

      await _downloadV1FilesWithToast([for (final item in items) item.path]);
      return;
    }

    final toaster = ShadToaster.of(context);
    var downloaded = 0;
    var skippedFolders = 0;

    for (final key in selected) {
      if (_FilePathKey.isFolderKey(key)) {
        skippedFolders++;
        continue;
      }

      await _downloadFile(_FilePathKey.pathFromKey(key));
      downloaded++;
    }

    if (!mounted) {
      return;
    }

    if (downloaded > 0 && skippedFolders == 0) {
      toaster.show(
        powerboardsToast(
          title: "Downloading",
          description: "$downloaded file${downloaded == 1 ? '' : 's'}",
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (downloaded > 0) {
      toaster.show(
        powerboardsToast(
          title: "Downloading",
          description:
              "Downloading $downloaded file${downloaded == 1 ? '' : 's'}. Skipped $skippedFolders folder${skippedFolders == 1 ? '' : 's'}.",
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    toaster.show(
      powerboardsToast(
        title: "Download unavailable",
        description: "Folders can’t be downloaded from multi-select yet.",
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showNewTextFileDialog() {
    showPowerboardsAlertDialog<String>(
      context: context,
      builder: (context) {
        return ControlledForm(
          builder: (context, controller, formKey) {
            Future<void> submit(_) async {
              if (!formKey.currentState!.saveAndValidate()) {
                return;
              }

              final formData = formKey.currentState!.value;
              final String name = formData["name"] ?? "";
              final String trimmedName = name.trim();
              String? resolvedName = trimmedName;

              if (!trimmedName.contains('.')) {
                resolvedName = await showPowerboardsAlertDialog<String>(
                  context: context,
                  builder: (context) {
                    return PowerboardsShadDialog.compact(
                      title: const Text("Add .txt extension?"),
                      description: Text("`$trimmedName` has no extension."),
                      actions: [
                        ShadButton.outline(onPressed: () => Navigator.of(context).pop(trimmedName), child: const Text("No extension")),
                        ShadButton(onPressed: () => Navigator.of(context).pop("$trimmedName.txt"), child: const Text("Add .txt")),
                      ],
                    );
                  },
                );
              }

              if (resolvedName == null) {
                return;
              }

              if (!context.mounted) {
                return;
              }

              Navigator.of(context).pop(resolvedName);
            }

            return PowerboardsShadDialog.compact(
              crossAxisAlignment: CrossAxisAlignment.start,
              title: Text("New Text File"),
              actions: [
                ShadButton.outline(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                ShadButton(onPressed: () => submit(null), child: const Text("OK")),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    PowerboardsAdaptiveInputFormField(
                      id: "name",
                      initialValue: "",
                      validator: (value) => value.trim().isEmpty ? "File name cannot be empty" : null,
                      label: Text("Name"),
                      autofocus: true,
                      onSubmitted: submit,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((fileName) {
      if (fileName != null) {
        final path = joinPaths(_folderSig.value, fileName);
        _uploadFile(Stream.value(Uint8List(0)), path, 0);
      }
    });
  }

  String _uploadTitle(List<UploadProgressItem> uploads, bool isCompleted) {
    if (uploads.isEmpty) {
      return "";
    }

    final isFolder = uploads.length == 1 && uploads.first.upload.filename == placeholderFileName;
    final failed = uploads.where((item) => item.failed).length;
    final completed = uploads.where((item) => item.completed).length;
    if (isFolder) {
      if (failed > 0) {
        return "Folder failed";
      }

      return isCompleted ? "Folder created" : "Creating folder";
    }

    final count = uploads.length;
    if (isCompleted && failed > 0) {
      if (completed == 0) {
        return "Upload failed";
      }

      return "Uploaded $completed, $failed failed";
    }

    final verb = isCompleted ? "Uploaded" : "Uploading";
    return "$verb $count file${count > 1 ? 's' : ''}";
  }

  String _uploadDisplayName(UploadProgressItem item) {
    final upload = item.upload;
    return upload.filename == placeholderFileName ? parentPath(upload.path) : upload.path.split('/').last;
  }

  Widget _v1UploadProgressPopover(BuildContext context) {
    return PbUploadProgressPopover(
      uploadsListenable: uploadNotifications.uploadsVN,
      isCompletedListenable: uploadNotifications.isCompletedVN,
      onClose: uploadNotifications.hide,
      titleBuilder: _uploadTitle,
      nameBuilder: _uploadDisplayName,
    );
  }

  Widget _popover(BuildContext context) {
    final theme = ShadTheme.of(context);
    final tt = theme.textTheme;

    return ValueListenableBuilder<List<UploadProgressItem>>(
      valueListenable: uploadNotifications.uploadsVN,
      builder: (context, uploads, _) {
        if (uploads.isEmpty) {
          return SizedBox.shrink();
        }

        return ValueListenableBuilder<bool>(
          valueListenable: uploadNotifications.isCompletedVN,
          builder: (context, isCompleted, _) {
            return SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                spacing: 12,
                children: [
                  Padding(
                    padding: const .only(top: 20, left: 16, right: 16, bottom: 12),
                    child: Text(_uploadTitle(uploads, isCompleted), style: tt.small.copyWith(fontWeight: .w700)),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: .min,
                          crossAxisAlignment: .start,
                          spacing: 12,
                          children: uploads.map((item) {
                            final upload = item.upload;
                            final totalBytes = item.totalBytes;

                            return AnimatedBuilder(
                              animation: upload,
                              builder: (context, _) {
                                final double percent = totalBytes > 0 ? (upload.bytesUploaded / totalBytes).clamp(0.0, 1.0) : 1.0;
                                final name = upload.filename == placeholderFileName ? parentPath(upload.path) : upload.path.split('/').last;

                                return Padding(
                                  padding: const .only(bottom: 8),
                                  child: Column(
                                    crossAxisAlignment: .start,
                                    children: [
                                      Text(name, style: TextStyle(fontSize: 12)),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: percent,
                                        backgroundColor: PbColors.borderFaint,
                                        color: PbColors.statusOnline,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const .only(top: 0, left: 16, right: 16, bottom: 20),
                    child: Row(
                      mainAxisAlignment: .end,
                      children: [ShadButton.outline(onPressed: uploadNotifications.hide, child: const Text("Close"))],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDesktopV1FilesBrowser(BuildContext context, {required List<StorageEntry> entries, String? folderPath}) {
    final currentFolder = folderPath ?? _folderSig.value;
    final items = _v1VisibleItems(entries, folderPath: currentFolder);
    final selected = powerboardsV1SelectedVisibleItemIds(_selectedSig.value, items);
    final routePreviewFile = _v1PreviewFileFromRoute(items);
    final activePreviewFile = _v1PreviewFile ?? routePreviewFile;
    final previewFile = selected.isEmpty ? activePreviewFile : null;
    final recentlyOpenedFiles = _v1RecentlyOpenedFilesForSidePane;
    final filterEnabled = _v1FilterEnabled(entries, folderPath: currentFolder);
    final extractingArchiveIds = _v1ExtractingArchiveIds;
    _clearV1FilterIfUnavailable(filterEnabled, folderPath: currentFolder);

    return IconTheme(
      data: IconThemeData(color: ShadTheme.of(context).colorScheme.primary),
      child: ShadPopover(
        controller: popoverController,
        padding: EdgeInsets.zero,
        decoration: ShadDecoration.none,
        shadows: const [],
        anchor: ShadAnchor(
          childAlignment: Alignment.bottomLeft,
          overlayAlignment: Alignment.bottomLeft,
          offset: _uploadProgressPopoverOffset,
        ),
        popover: _v1UploadProgressPopover,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final usesStackedRoomPanel = constraints.maxWidth <= pbRoomPanelStackBreakpoint;
            final usesShellMobileLayout = constraints.maxWidth <= pbShellMobileBreakpoint;
            final websitePreview = _v1WebsitePreview;
            final filePreviewFullscreen =
                websitePreview != null || _v1FilePreviewFullscreen || (usesShellMobileLayout && previewFile != null);
            final responsivePanel = usesStackedRoomPanel && !filePreviewFullscreen;
            final responsiveMode = usesShellMobileLayout
                ? PbFilesResponsiveMode.mobile
                : responsivePanel
                ? PbFilesResponsiveMode.overlay
                : PbFilesResponsiveMode.docked;
            final showWebServerPreview = _isWebServerFolderRoot(currentFolder);
            final webServerPreviewEntryPath = showWebServerPreview ? _webServerPreviewEntryPathFromEntries(entries) : null;
            final webServerPreviewReady = webServerPreviewEntryPath != null;
            if (showWebServerPreview) {
              _openRouteRequestedWebServerPreviewIfNeeded(entries: entries);
            }
            if (websitePreview != null) {
              return PbWebsitePreviewPane(
                title: websitePreview.title,
                previewHtml: websitePreview.previewHtml,
                previewUrl: websitePreview.previewUrl,
                onOpenSite: _webServerSiteUri() == null ? null : () => unawaited(_openV1WebsiteSite()),
                onDownloadZip: () => unawaited(_downloadV1WebsiteArchive()),
                onClose: _closeV1WebsitePreview,
              );
            }
            final roomHasInstalledAgent = widget.services?.state.isReady == true && widget.services!.state.value!.isNotEmpty;
            final sidePaneAvailable =
                previewFile != null ||
                recentlyOpenedFiles.isNotEmpty ||
                items.isNotEmpty ||
                currentFolder.isNotEmpty ||
                roomHasInstalledAgent;
            final roomPanelCollapsed = !sidePaneAvailable || (routePreviewFile == null && _effectiveV1FilesRoomPanelCollapsed);
            final roomPanelExpanded = responsivePanel ? false : !roomPanelCollapsed;
            final dropTargetPadding = responsiveMode == PbFilesResponsiveMode.docked
                ? const PbFilesPanelPadding(left: 30, right: 28)
                : const PbFilesPanelPadding(left: 20, right: 20);
            final dropTargetTop = responsiveMode == PbFilesResponsiveMode.mobile ? 202.0 : 142.0;
            if (filePreviewFullscreen && !_v1FilePreviewFullscreen) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final previewStillAvailable = _v1PreviewFile != null || routePreviewFile != null;
                if (!mounted || !previewStillAvailable || _v1FilePreviewFullscreen) {
                  return;
                }

                setState(() {
                  _v1FilePreviewFullscreen = true;
                  _v1RestoreRoomPanelOverlayOnPreviewClose = _v1RestoreRoomPanelOverlayOnPreviewClose || _v1FilesRoomPanelOverlayOpen;
                  _v1FilesRoomPanelOverlayOpen = false;
                });
                setPreviewFilePreviewFullscreen(true);
              });
            }
            final mainPanel = Stack(
              children: [
                PbFilesMainPanel(
                  currentPath: currentFolder,
                  folderLabelForPath: _v1FolderLabelForPath,
                  items: items,
                  selectedIds: selected,
                  sortKey: _v1SortKey,
                  sortDirectionDescending: _v1SortDirectionDescending,
                  filterController: _v1FilterController,
                  filterEnabled: filterEnabled,
                  hasActiveFilter: _v1FilterController.text.trim().isNotEmpty,
                  roomPanelExpanded: roomPanelExpanded,
                  responsiveMode: responsiveMode,
                  showRoomPanelControls: sidePaneAvailable,
                  previewFileId: previewFile?.id,
                  keyboardPreviewFileId: _v1KeyboardPreviewFileId,
                  keyboardPreviewDirection: _v1KeyboardPreviewDirection,
                  savingIds: _v1SavingFileIds,
                  extractingArchiveIds: extractingArchiveIds,
                  enableDropTarget: false,
                  onBreadcrumbPressed: (path) => _openEntry(path, true),
                  onSortChanged: _setV1Sort,
                  onFilterChanged: (_) => setState(() {}),
                  onToggleSelection: (id) {
                    final item = items.firstWhereOrNull((item) => item.id == id);
                    if (item == null || !_v1ItemIsSelectable(item)) {
                      return;
                    }

                    _toggleV1ItemSelection(id, !selected.contains(id));
                  },
                  onToggleVisibleSelection: () => _toggleV1VisibleSelection(items),
                  onClearSelection: () {
                    _clearV1KeyboardPreviewNavigation();
                    _clearSelected();
                  },
                  onMoveSelection: () {
                    final selectedItems = items
                        .where((item) => selected.contains(item.id) && _v1ItemIsSelectable(item))
                        .toList(growable: false);
                    unawaited(_showV1MoveDestinationDialog(selectedItems, initialPath: currentFolder));
                  },
                  onDeleteSelection: _confirmAndDeleteSelected,
                  onDownloadSelection: _downloadSelected,
                  onCreateFolder: () => unawaited(_addFolder(currentFolder)),
                  onInstallWebServer:
                      _v1AttachmentsFilesShowWebsiteInstallAction &&
                          currentFolder.isEmpty &&
                          _canInstallWebServerFromFiles &&
                          !_isWebServerInstalled()
                      ? () => unawaited(_openWebServerInstallDialog())
                      : null,
                  onCreateTextFile: _showNewTextFileDialog,
                  onUpload: () => unawaited(_addFiles(currentFolder)),
                  onAskCurrentFolder: () =>
                      unawaited(_startDefaultFilePrompt(currentFolder, isFolder: true, cleanupSurfacesAfterHandoff: usesStackedRoomPanel)),
                  showWebServerPreview: showWebServerPreview,
                  webServerPreviewActive: webServerPreviewReady,
                  onPreviewWebServer: webServerPreviewReady ? () => unawaited(_openV1WebsitePreview(entries: entries)) : null,
                  onFilesDropped: (_) {},
                  onOpenRecentFiles: () {
                    if (!sidePaneAvailable) {
                      return;
                    }

                    if (responsivePanel) {
                      setState(() => _v1FilesRoomPanelOverlayOpen = true);
                      return;
                    }

                    _setV1FilesRoomPanelCollapsed(false);
                  },
                  onRoomPanelToggle: () {
                    if (!sidePaneAvailable) {
                      return;
                    }

                    if (responsivePanel) {
                      setState(() => _v1FilesRoomPanelOverlayOpen = true);
                      return;
                    }

                    _setV1FilesRoomPanelCollapsed(!roomPanelCollapsed);
                  },
                  onItemPressed: (item) {
                    if (selected.isNotEmpty && _v1ItemIsSelectable(item)) {
                      _toggleV1ItemSelection(item.id, !selected.contains(item.id));
                      return;
                    }

                    if (_v1IsFolder(item)) {
                      _openEntry(_v1PathForItem(item), true);
                      return;
                    }
                    _openV1Preview(item, openOverlay: responsivePanel, openFullscreen: usesShellMobileLayout);
                  },
                  onBrowseFolder: (item) => _openEntry(item.folderPath, true),
                  onRemoveProcessingRow: _removeV1FileStateRow,
                  onLinkedThreadPressed: _openV1LinkedThread,
                  onAskAgent: (item) => unawaited(
                    _startDefaultFilePrompt(
                      _v1PathForItem(item),
                      isFolder: _v1IsFolder(item),
                      recentlyOpenedItem: item,
                      cleanupSurfacesAfterHandoff: usesStackedRoomPanel,
                      fileDisplayName: item.title,
                    ),
                  ),
                  onExtract: (item) => unawaited(_showV1ArchiveExtractDialog(item)),
                  onDownload: (item) => unawaited(_downloadV1Item(item)),
                  onMoveTo: (item) => unawaited(_showV1MoveDestinationDialog([item], initialPath: item.parentPath)),
                  onRename: (item) => unawaited(_renamePath(_v1PathForItem(item), isFolder: _v1IsFolder(item))),
                  onDelete: (item) => unawaited(_confirmAndDelete(_v1PathForItem(item), _v1IsFolder(item))),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _v1FilesDropTargetActive,
                  builder: (context, active, child) => Positioned.fill(
                    child: PbFilesDropTargetOverlayLayer(active: active, top: dropTargetTop, padding: dropTargetPadding),
                  ),
                ),
              ],
            );
            final keyboardPanel = Focus(
              focusNode: _v1FilesKeyboardFocusNode,
              autofocus: true,
              onKeyEvent: (node, event) => _handleV1FilesKeyEvent(
                event,
                items: items,
                previewFile: previewFile,
                responsivePanel: responsivePanel,
                openFullscreen: usesShellMobileLayout || filePreviewFullscreen,
              ),
              child: Listener(onPointerDown: (_) => _clearV1KeyboardPreviewNavigation(), child: mainPanel),
            );

            PbFilesSidePane sidePaneBuilder(BuildContext context, bool resizing) {
              final previewDraftFile = previewFile;
              return PbFilesSidePane(
                files: recentlyOpenedFiles,
                previewFile: previewFile,
                extractingArchiveIds: extractingArchiveIds,
                fullscreen: filePreviewFullscreen,
                resizing: resizing,
                borderOnTop: responsivePanel,
                responsiveOverlay: responsivePanel,
                responsiveOverlayMobile: usesShellMobileLayout,
                onPreviewFile: (item) => _openV1Preview(
                  item,
                  openOverlay: responsivePanel,
                  openFullscreen: usesShellMobileLayout,
                  restoreOverlayOnClose: responsivePanel,
                  armKeyboardBrowse: false,
                ),
                previewSourceBuilder: _buildV1PreviewSource,
                onAskAgent: (item) => unawaited(
                  _startDefaultFilePrompt(
                    _v1PathForItem(item),
                    isFolder: false,
                    recentlyOpenedItem: item,
                    cleanupSurfacesAfterHandoff: usesStackedRoomPanel,
                    fileDisplayName: item.title,
                  ),
                ),
                onExtractArchive: (item) => unawaited(_showV1ArchiveExtractDialog(item)),
                onDownload: (item) => unawaited(_downloadV1FileWithToast(_v1PathForItem(item))),
                onSaveRequested: _saveV1PreviewFile,
                previewDraftText: _v1PreviewDraftTextForItem(previewDraftFile),
                previewDraftDirty: _v1PreviewDraftDirtyForItem(previewDraftFile),
                onPreviewDraftChanged: previewDraftFile == null ? null : (text) => _setV1PreviewDraftText(previewDraftFile, text),
                onPreviewDraftSaved: previewDraftFile == null ? null : () => setState(() => _clearV1PreviewDraftForItem(previewDraftFile)),
                onToggleFullscreen: () => _setV1PreviewFullscreen(!_v1FilePreviewFullscreen),
                onClosePreview: _closeV1Preview,
              );
            }

            if (responsivePanel) {
              if (!sidePaneAvailable && _v1FilesRoomPanelOverlayOpen) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _closeV1FilesRoomPanelOverlay();
                  }
                });
              } else if (_v1FilesRoomPanelOverlayOpen) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _v1FilesRoomPanelOverlayController.show();
                  }
                });
              }

              return OverlayPortal(
                controller: _v1FilesRoomPanelOverlayController,
                overlayChildBuilder: (context) => Positioned.fill(
                  child: sidePaneAvailable
                      ? sidePaneBuilder(
                          context,
                          false,
                        ).asOverlayFrame(mobile: usesShellMobileLayout, onClose: _closeV1FilesRoomPanelOverlay)
                      : const SizedBox.shrink(),
                ),
                child: ColoredBox(color: PbColors.surfacePanelWash, child: keyboardPanel),
              );
            }

            if (_v1FilesRoomPanelOverlayOpen || !sidePaneAvailable && _v1FilesRoomPanelOverlayController.isShowing) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  if (_v1FilesRoomPanelOverlayController.isShowing) {
                    _v1FilesRoomPanelOverlayController.hide();
                  }
                  setState(() => _v1FilesRoomPanelOverlayOpen = false);
                }
              });
            }

            return ColoredBox(
              color: PbColors.surfacePanelWash,
              child: PbRoomPanelMount(
                activeTab: PbRoomPanelTab.files,
                filePreviewOpen: previewFile != null,
                filePreviewFullscreen: filePreviewFullscreen,
                roomPanelCollapsed: roomPanelCollapsed,
                panelWidth: widget.v1RoomPanelWidth,
                onPanelWidthChanged: widget.onV1RoomPanelWidthChanged,
                threadPanel: keyboardPanel,
                roomPanelBuilder: sidePaneBuilder,
              ),
            );
          },
        ),
      ),
    );
  }

  String _v1FolderLabelForPath(String path) {
    if (path.isEmpty) {
      return 'Files';
    }

    if (_hasInstalledWebServer && PendingStorageDeletes.normalizePath(path) == _webServerFolderName) {
      return _webServerDisplayLabel();
    }

    return path.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? path;
  }

  Widget _buildActionsMenu(BuildContext? boundaryContext, String fullPath, bool isFolder, bool showTrigger) {
    final isAdaptiveMobile = _usesAdaptiveMobileLayout(context);

    Future<void> onAction(_FileAction action) async {
      switch (action) {
        case _FileAction.open:
          _openEntry(fullPath, isFolder);
          break;
        case _FileAction.delete:
          await _confirmAndDelete(fullPath, isFolder);
          break;
        case _FileAction.upload:
          await _addFiles(fullPath);
          break;
        case _FileAction.compressFolder:
          await _compressFolder(fullPath);
          break;
        case _FileAction.rename:
          await _renamePath(fullPath, isFolder: isFolder);
          break;
        case _FileAction.download:
          if (_usesDesktopV1FilesBrowser()) {
            await _downloadV1FileWithToast(fullPath);
          } else {
            await _downloadFile(fullPath);
          }
          break;
        case _FileAction.share:
          await _shareFile(fullPath);
          break;
      }
    }

    Future<void> onStartFilePrompt(ChatFilePromptAction action) async {
      final callback = widget.onV1FilePromptRequested;
      if (callback != null) {
        final responsiveHandoff = _usesResponsiveV1FilePromptHandoff();
        await callback(
          action,
          fullPath,
          isFolder: isFolder,
          responsiveHandoff: responsiveHandoff,
          fileDisplayName: isFolder ? _v1FolderLabelForPath(fullPath) : _displayFileName(p.basename(fullPath)),
        );
        if (!mounted) {
          return;
        }
        _finishV1FilePromptHandoff(cleanupSurfaces: responsiveHandoff);
        return;
      }

      try {
        final threadPath = await startChatFilePromptThread(room: widget.client, action: action, filePath: fullPath);
        if (!mounted) {
          return;
        }

        _openEntry(threadPath, false);
      } catch (error) {
        if (!mounted) {
          return;
        }

        ShadToaster.of(context).show(powerboardsToast(title: "Unable to start chat", description: "$error", destructive: true));
      }
    }

    List<ChatFilePromptAction> filePromptActions() {
      return _filePromptActionsForPath(fullPath, isFolder: isFolder);
    }

    List<Widget> items() {
      final promptActions = filePromptActions();
      return [
        if (!isFolder)
          ShadContextMenuItem(
            height: 40.0,
            leading: const Icon(LucideIcons.externalLink, size: 16),
            onPressed: () => onAction(_FileAction.open),
            child: const Text('Open'),
          ),
        if (!isFolder && !isAdaptiveMobile)
          ShadContextMenuItem(
            height: 40.0,
            leading: const Icon(LucideIcons.download, size: 16),
            onPressed: () => onAction(_FileAction.download),
            child: const Text('Download'),
          ),
        if (!isFolder && supportsNativeFileShare)
          ShadContextMenuItem(
            height: 40.0,
            leading: const Icon(LucideIcons.share, size: 16),
            onPressed: () => onAction(_FileAction.share),
            child: const Text('Share'),
          ),
        if (isFolder)
          ShadContextMenuItem(
            height: 40.0,
            leading: const Icon(LucideIcons.folderOpen, size: 16),
            onPressed: () => onAction(_FileAction.open),
            child: const Text('Open folder'),
          ),
        if (isFolder)
          ShadContextMenuItem(
            height: 40.0,
            leading: const Icon(LucideIcons.upload, size: 16),
            onPressed: () => onAction(_FileAction.upload),
            child: const Text('Upload here'),
          ),
        if (isFolder)
          ShadContextMenuItem(
            height: 40.0,
            leading: const Icon(LucideIcons.archive, size: 16),
            onPressed: () => onAction(_FileAction.compressFolder),
            child: const Text('Compress folder'),
          ),
        ShadContextMenuItem(
          height: 40.0,
          leading: const Icon(LucideIcons.pencil, size: 16),
          onPressed: () => onAction(_FileAction.rename),
          child: const Text('Rename'),
        ),
        ShadContextMenuItem(
          height: 40.0,
          leading: const Icon(LucideIcons.trash, size: 16),
          onPressed: () => onAction(_FileAction.delete),
          child: const Text('Delete'),
        ),
        if (promptActions.isNotEmpty) const Divider(height: 1),
        for (final action in promptActions)
          ShadContextMenuItem(
            height: 40.0,
            leading: const Icon(LucideIcons.messageSquarePlus, size: 16),
            onPressed: () => onStartFilePrompt(action),
            child: Text(action.menuLabel),
          ),
      ];
    }

    final menuItems = items();
    return _FileActionsMenuButton(
      key: ValueKey(_FilePathKey.keyForPath(fullPath, isFolder)),
      boundaryContext: boundaryContext,
      items: menuItems,
      estimatedMenuWidth: 200,
      estimatedMenuHeight: menuItems.fold<double>(8.0, (height, item) {
        return height + (item is Divider ? 17.0 : 40.0);
      }),
      onOpen: widget.services == null ? null : () => widget.services!.refresh(),
      showTrigger: showTrigger,
    );
  }

  Widget _buildToolbar(Set<String> selected) {
    final isMobile = _usesAdaptiveMobileLayout(context);
    if (!isMobile) {
      return _buildDesktopToolbar(selected);
    }

    if (widget.mobileShellOwnsHeader) {
      if (_openedFile != null) {
        return _buildAdaptiveMobileOpenedFileToolbar();
      }
      return const SizedBox.shrink();
    }

    return _buildMobileToolbar(selected);
  }

  Widget _buildAdaptiveMobileScrollAwareSecondaryRow(Widget child) {
    if (!(widget.mobileShellOwnsHeader && _usesAdaptiveMobileLayout(context))) {
      return child;
    }

    final overlayHeaderScope = PowerboardsMobileOverlayHeaderScope.maybeOf(context);
    final collapseProgress = overlayHeaderScope?.collapseProgress ?? 0;
    final hideForScroll = collapseProgress > 0.1;

    return AnimatedSwitcher(
      duration: powerboardsMobileOverlayHeaderTransitionDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        return ClipRect(
          child: FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, alignment: AlignmentDirectional.topStart, child: child),
          ),
        );
      },
      child: hideForScroll
          ? const SizedBox.shrink(key: ValueKey('files-mobile-secondary-row-hidden'))
          : KeyedSubtree(key: const ValueKey('files-mobile-secondary-row-visible'), child: child),
    );
  }

  Widget _buildDesktopToolbar(Set<String> selected) {
    final desktopActions = widget.desktopHeaderActions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: headerHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final leadingWidth = math.max(
                _estimateDesktopHeaderLeadingWidth(context, constraints.maxWidth),
                widget.desktopHeaderActionLeadingWidthFloor,
              );
              final localActionState = resolvePaneHeaderActionState(
                constraints,
                leadingWidth: leadingWidth,
                minimumLeadingWidth: math.max(_minimumDesktopHeaderLeadingWidth(), widget.desktopHeaderActionMinimumLeadingWidth),
                reserve: widget.desktopHeaderActionReserve,
                actions: desktopActions,
              );
              final actionState = localActionState;
              final visibleDesktopActions = visiblePaneHeaderActions(desktopActions, overflowCollapsed: actionState.overflowCollapsed);

              return Center(
                child: SizedBox(
                  height: desktopPaneHeaderContentHeight,
                  child: Row(
                    crossAxisAlignment: .center,
                    spacing: desktopPaneHeaderButtonGap,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ClipRect(child: _buildDesktopHeaderLeading()),
                        ),
                      ),
                      if (visibleDesktopActions.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: CompactHeaderActions(
                            state: actionState,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: desktopPaneHeaderButtonGap,
                              children: visibleDesktopActions,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _buildDesktopContextToolbar(selected),
      ],
    );
  }

  Widget _buildDesktopHeaderLeadingRow({required List<Widget> trailing}) {
    final sidetrayScope = DesktopSidetrayToggleScope.maybeOf(context);
    final sidetrayOpenButton = widget.showDesktopSidetrayToggle && sidetrayScope?.enabled == true && sidetrayScope?.collapsed == true
        ? DesktopSidetrayToggleButton(collapsed: true, onPressed: sidetrayScope!.onExpand)
        : null;
    final leadingActions = widget.desktopHeaderLeadingActions;
    return Row(
      spacing: desktopPaneHeaderButtonGap,
      children: [
        ?sidetrayOpenButton,
        if (leadingActions.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, spacing: desktopPaneHeaderButtonGap, children: leadingActions),
        ...trailing,
      ],
    );
  }

  Widget _buildDesktopHeaderLeading() {
    final sidetrayScope = DesktopSidetrayToggleScope.maybeOf(context);
    final showsSidetrayOpenButton = widget.showDesktopSidetrayToggle && sidetrayScope?.enabled == true && sidetrayScope?.collapsed == true;
    if (_openedFile == null) {
      if (widget.desktopHeaderLeadingActions.isEmpty && !showsSidetrayOpenButton) {
        return _buildBreadcrumb();
      }

      return _buildDesktopHeaderLeadingRow(
        trailing: [
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: _buildBreadcrumb()),
          ),
        ],
      );
    }

    final fileName = _displayNameForPath(_openedFile!);

    return _buildDesktopHeaderLeadingRow(
      trailing: [
        ..._buildFileCloseAction(),
        Expanded(
          child: Text(fileName, style: breadcrumbLinkStyle, maxLines: 1, overflow: .ellipsis),
        ),
      ],
    );
  }

  double _minimumDesktopHeaderLeadingWidth() {
    if (_openedFile != null) {
      return 124.0;
    }

    return 136.0;
  }

  Widget _buildDesktopContextToolbar(Set<String> selected) {
    final showSelectionActions = selected.isNotEmpty && _openedFile == null;

    if (showSelectionActions) {
      return _buildSelection(selected);
    }

    if (_openedFile != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final compactToolbar = constraints.maxWidth < 540;
          final gap = compactToolbar ? 6.0 : desktopPaneHeaderButtonGap;
          final children = <Widget>[
            ..._buildFileCycleActions(),
            if (_openedFileSupportsEditTabs) _buildOpenFileTabs(),
            if (_openedFileSupportsExternalSave) _buildExternalSaveButton(compact: compactToolbar),
            ..._buildRouteActions(),
          ];

          return _buildDesktopContextToolbarRow(children: children, gap: gap);
        },
      );
    }

    return _buildDesktopContextToolbarRow(children: _buildRouteActions());
  }

  Widget _buildDesktopContextToolbarRow({required List<Widget> children, double gap = desktopPaneHeaderButtonGap}) {
    return SizedBox(
      height: desktopPaneSecondaryControlHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, spacing: gap, children: children),
      ),
    );
  }

  bool get _openedFileSupportsEditTabs {
    final openedFile = _openedFile;
    if (openedFile == null) {
      return false;
    }

    return _isEditableTextFile(openedFile);
  }

  bool get _openedFileSupportsExternalSave {
    final openedFile = _openedFile;
    if (openedFile == null) {
      return false;
    }

    return _isEditableTextFile(openedFile);
  }

  bool _isEditableTextFile(String path) {
    return switch (classifyFile(path)) {
      FileKind.code || FileKind.markdown => true,
      _ => false,
    };
  }

  Widget _buildOpenFileTabs() {
    final theme = ShadTheme.of(context);
    final borderColor = theme.colorScheme.foreground.withValues(alpha: 0.16);
    final radius = theme.radius;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        border: Border.all(color: borderColor),
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOpenFileToggleButton(
            value: 'preview',
            tooltip: 'Preview',
            icon: LucideIcons.eye,
            borderRadius: BorderRadius.only(topLeft: radius.topLeft, bottomLeft: radius.bottomLeft),
          ),
          Container(width: 1, height: double.infinity, color: borderColor),
          _buildOpenFileToggleButton(
            value: 'edit',
            tooltip: 'Edit',
            icon: LucideIcons.pencil,
            borderRadius: BorderRadius.only(topRight: radius.topRight, bottomRight: radius.bottomRight),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenFileToggleButton({
    required String value,
    required String tooltip,
    required IconData icon,
    required BorderRadius borderRadius,
  }) {
    final selected = _tab == value;
    final theme = ShadTheme.of(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? theme.colorScheme.foreground : Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () => setState(() => _tab = value),
          child: SizedBox(
            width: 48,
            height: 38,
            child: Icon(icon, size: 18, color: selected ? theme.colorScheme.background : theme.colorScheme.foreground),
          ),
        ),
      ),
    );
  }

  Widget _buildExternalSaveButton({required bool compact}) {
    return AnimatedBuilder(
      animation: _codePreviewController,
      builder: (context, _) {
        final saving = _codePreviewController.saving;
        final needsSaveAttention = _codePreviewController.dirty || saving;

        return (needsSaveAttention ? ShadButton.destructive : ShadButton.outline)(
          enabled: _codePreviewController.canSave,
          onPressed: () async {
            await _codePreviewController.save();
          },
          leading: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator()) : const Icon(LucideIcons.save),
          child: compact ? null : const Text("Save"),
        );
      },
    );
  }

  Future<void> _saveAdaptiveMobileEdits() async {
    await _codePreviewController.save();

    if (!mounted) {
      return;
    }

    if (_codePreviewController.dirty || _codePreviewController.saving || _codePreviewController.saveError != null) {
      return;
    }

    await _refreshCurrentFolder();

    if (!mounted) {
      return;
    }

    setState(() {
      _tab = 'preview';
    });
  }

  PowerboardsMobileActionPillItem _buildAdaptiveMobileOpenedFilePrimaryPillItem() {
    if (!_openedFileSupportsEditTabs) {
      return const PowerboardsMobileActionPillItem(label: "Preview", selected: true);
    }

    if (_tab != 'edit') {
      return PowerboardsMobileActionPillItem(label: "Edit this file", onPressed: () => setState(() => _tab = 'edit'));
    }

    return PowerboardsMobileActionPillItem(label: "Save your edits", selected: true, onPressed: _saveAdaptiveMobileEdits);
  }

  Widget _buildAdaptiveMobileOpenedFileToolbar() {
    final theme = ShadTheme.of(context);
    final pillTextStyle = powerboardsInterTextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.0);
    final primaryPill = _buildAdaptiveMobileOpenedFilePrimaryPillItem();
    final deletePill = PowerboardsMobileActionPillItem(
      label: "Delete",
      selected: true,
      destructive: true,
      onPressed: _openedFile == null || _isDeletePending(_openedFile!, false)
          ? null
          : () async {
              final openedFile = _openedFile;
              if (openedFile == null) {
                return;
              }

              final confirmDelete = await _confirmAndDelete(openedFile, false);
              if (confirmDelete == true) {
                _openEntry(_folderSig.value, true);
              }
            },
    );

    return Padding(
      padding: const EdgeInsets.only(top: powerboardsMobileOverlaySecondaryRowLift),
      child: SizedBox(
        height: powerboardsMobileSecondaryRowHeight,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: powerboardsMobileShellHorizontalInset),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PowerboardsMobileActionPillStrip(
                      items: [primaryPill, deletePill],
                      textStyle: pillTextStyle,
                      unselectedForegroundColor: theme.colorScheme.foreground,
                      itemGap: 10,
                      pillPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileToolbar(Set<String> selected) {
    final showSelectionActions = selected.isNotEmpty && _openedFile == null;
    final showRouteActions = !showSelectionActions;
    final leading = showSelectionActions ? _buildSelection(selected) : _buildBreadcrumb();
    final selectToggle = Tooltip(
      message: "Select items",
      child: (_forceShowSelect ? ShadIconButton.new : ShadIconButton.outline)(
        icon: const Icon(LucideIcons.squareCheckBig),
        decoration: powerboardsAdaptiveIconButtonDecoration(context),
        onPressed: _toggleForceShowSelect,
      ),
    );

    if (widget.mobileShellOwnsHeader && !showSelectionActions) {
      final actionWidgets = <Widget>[if (showRouteActions) ..._buildRouteActions(), if (_openedFile == null) selectToggle];

      if (actionWidgets.isEmpty) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: EdgeInsets.only(bottom: _openedFile == null ? 8 : 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, spacing: 6, children: actionWidgets),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, _openedFile == null ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 6,
        children: [
          if (_openedFile != null) ..._buildFileCloseAction(),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: leading),
          ),
          if (showRouteActions) ..._buildRouteActions(),
          selectToggle,
        ],
      ),
    );
  }

  List<Widget> _buildFileCloseAction() {
    return [
      Tooltip(
        message: "Close file",
        child: ShadIconButton.ghost(
          icon: const Icon(LucideIcons.x),
          decoration: powerboardsAdaptiveIconButtonDecoration(context),
          onPressed: _closeFile,
        ),
      ),
    ];
  }

  List<Widget> _buildFileCycleActions() {
    final canCycleFiles = _visibleSortedFiles.value.length > 1;

    return [
      if (canCycleFiles)
        Tooltip(
          message: "Previous file",
          child: ShadIconButton.outline(
            icon: const Icon(LucideIcons.chevronLeft),
            decoration: powerboardsAdaptiveIconButtonDecoration(context),
            onPressed: _previousFile,
          ),
        ),
      if (canCycleFiles)
        Tooltip(
          message: "Next file",
          child: ShadIconButton.outline(
            icon: const Icon(LucideIcons.chevronRight),
            decoration: powerboardsAdaptiveIconButtonDecoration(context),
            onPressed: _nextFile,
          ),
        ),
    ];
  }

  List<Widget> _buildRouteActions() {
    if (_openedFile != null) {
      final isMobile = _usesAdaptiveMobileLayout(context);
      final showLegacyMobileEditActions = isMobile && !widget.mobileShellOwnsHeader;

      return [
        if (showLegacyMobileEditActions && _openedFileSupportsEditTabs) _buildOpenFileTabs(),
        if (showLegacyMobileEditActions && _openedFileSupportsExternalSave) _buildExternalSaveButton(compact: true),
        if (supportsNativeFileShare && !widget.mobileShellOwnsHeader)
          Tooltip(
            message: "Share",
            child: ShadIconButton.outline(
              icon: const Icon(LucideIcons.share),
              decoration: powerboardsAdaptiveIconButtonDecoration(context),
              onPressed: () {
                _shareFile(_openedFile!);
              },
            ),
          ),
        if (!isMobile)
          Tooltip(
            message: "Download",
            child: ShadIconButton.outline(
              icon: const Icon(LucideIcons.download),
              decoration: powerboardsAdaptiveIconButtonDecoration(context),
              onPressed: () {
                if (_usesDesktopV1FilesBrowser()) {
                  unawaited(_downloadV1FileWithToast(_openedFile!));
                } else {
                  _downloadFile(_openedFile!);
                }
              },
            ),
          ),
        Tooltip(
          message: "Delete file",
          child: ShadIconButton.outline(
            icon: const Icon(LucideIcons.trash),
            decoration: powerboardsAdaptiveIconButtonDecoration(context),
            onPressed: _isDeletePending(_openedFile!, false)
                ? null
                : () async {
                    final confirmDelete = await _confirmAndDelete(_openedFile!, false);
                    if (confirmDelete == true) {
                      _openEntry(_folderSig.value, true);
                    }
                  },
          ),
        ),
      ];
    } else {
      return [
        Tooltip(
          message: "New folder",
          child: ShadIconButton.outline(
            icon: const Icon(LucideIcons.folderPlus),
            decoration: powerboardsAdaptiveIconButtonDecoration(context),
            onPressed: () {
              _addFolder(_folderSig.value);
            },
          ),
        ),
        _buildUploadMenu(),
        if (FileUploadHelper.supportsPhotoUploadPicker)
          Tooltip(
            message: "Upload photo",
            child: ShadIconButton.outline(
              icon: const Icon(LucideIcons.imagePlus),
              decoration: powerboardsAdaptiveIconButtonDecoration(context),
              onPressed: () {
                _addPhotos(_folderSig.value);
              },
            ),
          ),
      ];
    }
  }

  Widget _buildUploadMenu() {
    return AppContextMenuButton(
      compact: true,
      boundaryContext: context,
      entries: [
        AppMenuEntry(
          title: "Upload files",
          description: "Upload files to this folder",
          icon: LucideIcons.upload,
          onPressed: () {
            _addFiles(_folderSig.value);
          },
        ),
        AppMenuEntry(
          title: "New Text File",
          description: "Create a new text file in this folder",
          icon: LucideIcons.fileText,
          onPressed: _showNewTextFileDialog,
        ),
      ],
      constraints: const BoxConstraints(minWidth: 200),
      childBuilder: (context, controller) {
        return Tooltip(
          message: "Upload file",
          child: ShadIconButton.outline(
            icon: const Icon(LucideIcons.upload),
            decoration: powerboardsAdaptiveIconButtonDecoration(context),
            onPressed: controller.toggle,
          ),
        );
      },
    );
  }

  Widget _buildSelection(Set<String> selected) {
    final isMobile = _usesAdaptiveMobileLayout(context);
    final countPadding = isMobile ? 4.0 : 6.0;
    final children = <Widget>[
      ShadButton.outline(onPressed: _clearSelected, child: Text(isMobile ? "Clear" : "Clear selection")),
      ShadButton.destructive(onPressed: () => _confirmAndDeleteSelected(), child: const Text("Delete")),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: countPadding),
        child: Text('${selected.length} selected', style: breadcrumbLinkStyle),
      ),
    ];

    if (!isMobile) {
      return _buildDesktopContextToolbarRow(children: children, gap: 8);
    }

    return Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: children);
  }

  double _measureBreadcrumbLabelWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: breadcrumbLinkStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();

    return painter.width;
  }

  double _estimateDesktopHeaderLeadingWidth(BuildContext context, double maxWidth) {
    final sidetrayScope = DesktopSidetrayToggleScope.maybeOf(context);
    final sidetrayLeadingWidth = widget.showDesktopSidetrayToggle && sidetrayScope?.enabled == true && sidetrayScope?.collapsed == true
        ? desktopPaneHeaderCompactButtonWidth + desktopPaneHeaderButtonGap
        : 0.0;
    final openedFile = _openedFile;
    if (openedFile != null) {
      final fileName = _displayNameForPath(openedFile);
      final closeActionWidth = 40.0 + desktopPaneHeaderButtonGap;
      final fileNameWidth = _measureBreadcrumbLabelWidth(context, fileName) + 24.0;
      return math.min(sidetrayLeadingWidth + closeActionWidth + fileNameWidth, math.min(240.0, maxWidth * 0.3));
    }

    final segments = _folderBreadcrumbSegments();
    var width = 0.0;
    for (var i = 0; i < segments.length; i++) {
      width += _measureBreadcrumbLabelWidth(context, segments[i].label) + 40.0;
      if (i > 0) {
        width += 20.0;
      }
    }

    return math.min(sidetrayLeadingWidth + width, math.min(240.0, maxWidth * 0.3));
  }

  List<FileBreadcrumbSegment> _folderBreadcrumbSegments() {
    final segments = <FileBreadcrumbSegment>[const FileBreadcrumbSegment(label: "Files", path: "")];
    final folderSegments = _folderSig.value.split('/').where((s) => s.isNotEmpty).toList();

    var accumulated = "";
    for (final segment in folderSegments) {
      accumulated = accumulated.isEmpty ? segment : "$accumulated/$segment";
      segments.add(FileBreadcrumbSegment(label: segment, path: accumulated));
    }

    return segments;
  }

  Widget _breadcrumbSeparator() {
    return const SizedBox(
      width: 20,
      child: Center(child: Icon(LucideIcons.chevronRight, size: 16, color: Color(0xffa5a5a5))),
    );
  }

  Widget _buildBreadcrumbCrumb(FileBreadcrumbSegment segment) {
    return ShadButton.ghost(
      onPressed: () => _openEntry(segment.path, true),
      child: Text(segment.label, style: breadcrumbLinkStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildCollapsedBreadcrumbCurrent(FileBreadcrumbSegment segment) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openEntry(segment.path, true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(segment.label, style: breadcrumbLinkStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Widget _buildCollapsedBreadcrumbMenu(List<FileBreadcrumbSegment> hiddenSegments) {
    return AdaptiveShadContextMenu(
      controller: _collapsedBreadcrumbMenuController,
      boundaryContext: context,
      constraints: const BoxConstraints(minWidth: 200),
      estimatedMenuWidth: 200,
      estimatedMenuHeight: hiddenSegments.length * 40.0 + 8.0,
      items: hiddenSegments.reversed
          .map(
            (segment) => ShadContextMenuItem(
              height: 40.0,
              leading: const Icon(LucideIcons.folder, size: 16),
              onPressed: () => _openEntry(segment.path, true),
              child: Text(segment.label),
            ),
          )
          .toList(growable: false),
      child: Tooltip(
        message: "Browse collapsed path",
        child: ShadIconButton.outline(
          icon: const Icon(LucideIcons.folderTree),
          decoration: powerboardsAdaptiveIconButtonDecoration(context),
          onPressed: _collapsedBreadcrumbMenuController.toggle,
        ),
      ),
    );
  }

  Widget _buildBreadcrumbTrail(List<FileBreadcrumbSegment> segments) {
    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        children.add(_breadcrumbSeparator());
      }
      children.add(_buildBreadcrumbCrumb(segments[i]));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildCollapsedBreadcrumbTrail(List<FileBreadcrumbSegment> segments) {
    if (segments.length == 1) {
      return Row(children: [Expanded(child: _buildCollapsedBreadcrumbCurrent(segments.first))]);
    }

    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        children.add(_breadcrumbSeparator());
      }

      if (i == segments.length - 1) {
        children.add(Expanded(child: _buildCollapsedBreadcrumbCurrent(segments[i])));
        continue;
      }

      children.add(_buildBreadcrumbCrumb(segments[i]));
    }
    return Row(children: children);
  }

  Widget _buildFileNameOnly() {
    final fileName = _displayNameForPath(_openedFile!);

    return Text(fileName, style: breadcrumbLinkStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Widget _buildBreadcrumb() {
    if (_openedFile != null) {
      return _buildFileNameOnly();
    }

    final segments = _folderBreadcrumbSegments();
    if (segments.length <= 1) {
      return _buildBreadcrumbCrumb(segments.first);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const separatorWidth = 20.0;
        // Keep a little safety margin so ghost-button chrome collapses
        // before the row reaches a visible overflow.
        const crumbChromeWidth = 52.0;
        const collapseButtonWidth = 48.0;

        final segmentWidths = segments
            .map((segment) => _measureBreadcrumbLabelWidth(context, segment.label) + crumbChromeWidth)
            .toList(growable: false);

        final layout = computeFileBreadcrumbLayout(
          segments: segments,
          segmentWidths: segmentWidths,
          maxWidth: constraints.maxWidth,
          separatorWidth: separatorWidth,
          collapseButtonWidth: collapseButtonWidth,
        );

        if (layout.isCollapsed) {
          return Row(
            children: [
              _buildCollapsedBreadcrumbMenu(layout.hiddenSegments),
              _breadcrumbSeparator(),
              Expanded(child: _buildCollapsedBreadcrumbTrail(layout.visibleSegments)),
            ],
          );
        }

        return _buildBreadcrumbTrail(layout.visibleSegments);
      },
    );
  }

  Widget _buildOpenedFile(BuildContext context) {
    if (_openedFile == null) return const SizedBox.shrink();

    final path = _openedFile!;
    final fileKind = classifyFile(path);
    final showEditTabs = _isEditableTextFile(path);
    final showExternalSave = _isEditableTextFile(path);
    final openedFileEntry = storageEntries.state.asReady?.value.firstWhereOrNull(
      (entry) => !entry.isFolder && joinPaths(_folderSig.value, entry.name) == path,
    );
    final isKnownEmptyTextFile = showExternalSave && ((openedFileEntry?.size == 0) || _optimisticEmptyTextFiles.contains(path));

    Widget buildTextDocument({required bool readOnly, required bool showToolbar, CodePreviewController? controller}) {
      if (isKnownEmptyTextFile) {
        return CodePreview(
          filename: path,
          room: widget.client,
          text: "",
          readOnly: readOnly,
          controller: controller,
          showToolbar: showToolbar,
          editorBuilder: buildPowerboardsLapceCodePreviewEditor,
        );
      }

      return DocumentPane(
        path: path,
        room: widget.client,
        forceTextViewer: true,
        readOnlyTextViewer: readOnly,
        codePreviewController: controller,
        showCodeToolbar: showToolbar,
      );
    }

    if (!showExternalSave) {
      return _buildOpenedFileSurface(
        fileViewer(widget.client, path, codeEditorBuilder: buildPowerboardsLapceCodePreviewEditor) ??
            DocumentPane(path: path, room: widget.client),
        insetContent: _shouldInsetOpenedFileSurface(fileKind: fileKind, editing: false),
      );
    }

    final edit = _buildOpenedFileSurface(
      buildTextDocument(readOnly: false, controller: _codePreviewController, showToolbar: false),
      insetContent: _shouldInsetOpenedFileSurface(fileKind: fileKind, editing: true),
    );

    final readOnlyTextPreview = _buildOpenedFileSurface(
      buildTextDocument(readOnly: true, showToolbar: false),
      insetContent: _shouldInsetOpenedFileSurface(fileKind: fileKind, editing: false),
    );

    if (!showEditTabs) {
      return edit;
    }

    final view = fileKind == FileKind.code
        ? readOnlyTextPreview
        : _buildOpenedFileSurface(
            fileViewer(widget.client, path, codeEditorBuilder: buildPowerboardsLapceCodePreviewEditor) ??
                DocumentPane(path: path, room: widget.client),
            insetContent: _shouldInsetOpenedFileSurface(fileKind: fileKind, editing: false),
          );

    return Column(
      key: ValueKey(_openedFile),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: IndexedStack(
            index: _tab == 'preview' ? 0 : 1,
            children: [
              Container(key: ValueKey("preview$_tab"), child: view),
              edit,
            ],
          ),
        ),
      ],
    );
  }

  bool _shouldInsetOpenedFileSurface({required FileKind fileKind, required bool editing}) {
    if (editing) {
      return false;
    }

    return switch (fileKind) {
      FileKind.pdf || FileKind.office || FileKind.code || FileKind.tsv => false,
      _ => true,
    };
  }

  Widget _buildOpenedFileSurface(Widget child, {required bool insetContent}) {
    final isAdaptiveMobile = _usesAdaptiveMobileLayout(context) && widget.mobileShellOwnsHeader;
    if (isAdaptiveMobile) {
      return SizedBox.expand(
        child: ClipRect(
          child: ColoredBox(color: shadCard, child: child),
        ),
      );
    }

    final radius = ShadTheme.of(context).radius.resolve(Directionality.of(context));
    const borderWidth = 1.0;
    const previewPadding = 16.0;
    final innerRadius = BorderRadius.only(
      topLeft: Radius.circular(math.max(0, radius.topLeft.x - borderWidth)),
      topRight: Radius.circular(math.max(0, radius.topRight.x - borderWidth)),
      bottomLeft: Radius.circular(math.max(0, radius.bottomLeft.x - borderWidth)),
      bottomRight: Radius.circular(math.max(0, radius.bottomRight.x - borderWidth)),
    );

    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: shadCard,
          border: Border.all(color: shadBorder, width: borderWidth),
          borderRadius: radius,
        ),
        child: Padding(
          padding: EdgeInsets.all(borderWidth + (insetContent ? previewPadding : 0)),
          child: ClipRRect(
            borderRadius: innerRadius,
            child: ColoredBox(color: shadCard, child: child),
          ),
        ),
      ),
    );
  }

  void _retryLoadCurrentFolder() {
    unawaited(
      _refreshCurrentFolder().catchError((Object error) {
        if (!mounted) {
          return;
        }

        ShadToaster.of(context).show(
          powerboardsToast(
            title: 'Folder still unavailable',
            description: '$error',
            destructive: true,
            duration: const Duration(seconds: 6),
          ),
        );
      }),
    );
  }

  Widget _buildDesktopV1FilesLoadError(BuildContext context, Object error) {
    final cachedEntries = _v1CachedFolderEntries(_folderSig.value);
    if (cachedEntries != null) {
      return _buildDesktopV1FilesBrowser(context, entries: cachedEntries);
    }

    return _buildFilesLoadError(context, error);
  }

  Widget _buildDesktopV1FilesLoading() {
    return ColoredBox(
      color: PbColors.surfacePanel,
      child: Center(
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: PbColors.textSubtle)),
      ),
    );
  }

  Widget _buildFilesLoadError(BuildContext context, Object error) {
    final currentFolder = _folderSig.value;
    final canGoToParent = currentFolder.trim().isNotEmpty;
    final parentFolder = parentPath(currentFolder);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Couldn’t load this folder',
                textAlign: TextAlign.center,
                style: PowerboardsTypography.h4.copyWith(color: PbColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: PowerboardsTypography.p.copyWith(color: PbColors.textMuted),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (canGoToParent)
                    ShadButton.outline(onPressed: () => _openEntry(parentFolder, true), child: const Text('Back to parent')),
                  ShadButton(onPressed: _retryLoadCurrentFolder, child: const Text('Retry')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isAdaptiveMobile = widget.mobileShellOwnsHeader && _usesAdaptiveMobileLayout(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _openedFile == null
            ? (_forceShowSelect ? _clearMobileSelectionMode : _clearSelected)
            : _closeFile,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _previousFile,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _nextFile,
      },
      child: Focus(
        autofocus: true,
        child: FileDropArea(
          onFileDrop: _onFileDrop,
          onDraggingChanged: _setV1FilesDropTargetActive,
          overlayBuilder: !isAdaptiveMobile && powerboardsUsesDesktopUiPreview(context) ? (_, _) => const SizedBox.shrink() : null,
          child: SignalBuilder(
            builder: (context, _) {
              final selected = _visibleSelected.value;
              final hasOpenedFile = _openedFile != null;
              final useDesktopV1FilesBrowser = !isAdaptiveMobile && powerboardsUsesDesktopUiPreview(context);
              widget.services?.state.isReady;
              roomRoutes.state.isReady;
              if (useDesktopV1FilesBrowser) {
                return SizedBox.expand(
                  child: ValueListenableBuilder<int>(
                    valueListenable: PendingStorageDeletes.listenableFor(_deleteScope),
                    builder: (context, _, _) {
                      final routeFolder = _FileLocation.fromUri(PathRouteMatch.of(context).uri).folder;
                      final cachedEntries = _v1CachedFolderEntries(routeFolder);
                      final liveEntriesMatchRoute = powerboardsV1LiveFolderEntriesMatchRoute(
                        routeFolder: routeFolder,
                        activeFolder: _folderSig.value,
                        loadedFolderPath: _v1LoadedFolderPath,
                      );

                      return storageEntries.state.when(
                        loading: () {
                          if (cachedEntries != null) {
                            return _buildDesktopV1FilesBrowser(context, entries: cachedEntries, folderPath: routeFolder);
                          }
                          return _buildDesktopV1FilesLoading();
                        },
                        error: (e, st) => _buildDesktopV1FilesLoadError(context, e),
                        ready: (entries) {
                          if (liveEntriesMatchRoute) {
                            return _buildDesktopV1FilesBrowser(context, entries: entries, folderPath: routeFolder);
                          }
                          if (cachedEntries != null) {
                            return _buildDesktopV1FilesBrowser(context, entries: cachedEntries, folderPath: routeFolder);
                          }
                          return _buildDesktopV1FilesLoading();
                        },
                      );
                    },
                  ),
                );
              }

              final hideEmbeddedMobileToolbar = isAdaptiveMobile && !hasOpenedFile;
              final showAdaptiveOpenedFileDivider = isAdaptiveMobile && hasOpenedFile;
              final adaptiveSecondaryRow = showAdaptiveOpenedFileDivider
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToolbar(selected),
                        const SizedBox(height: desktopPaneSecondaryRowContentGap),
                      ],
                    )
                  : hideEmbeddedMobileToolbar
                  ? const SizedBox.shrink()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToolbar(selected),
                        const SizedBox(height: desktopPaneSecondaryRowContentGap),
                      ],
                    );
              return Column(
                crossAxisAlignment: .start,
                children: [
                  _buildAdaptiveMobileScrollAwareSecondaryRow(adaptiveSecondaryRow),
                  Expanded(
                    child: IndexedStack(
                      index: _openedFile == null ? 0 : 1,
                      children: [
                        IconTheme(
                          data: IconThemeData(color: theme.colorScheme.primary),
                          child: ShadPopover(
                            controller: popoverController,
                            padding: .zero,
                            anchor: ShadAnchor(
                              childAlignment: .bottomRight,
                              overlayAlignment: .bottomRight,
                              offset: const Offset(-20.0, -20.0),
                            ),
                            popover: _popover,
                            child: SignalBuilder(
                              builder: (context, _) {
                                return storageEntries.state.when(
                                  loading: () => const Center(child: CircularProgressIndicator()),
                                  error: (e, st) => _buildFilesLoadError(context, e),
                                  ready: (_) {
                                    final entries = _visibleSortedEntries.value;
                                    final sort = _sortSig.value;
                                    final folder = _folderSig.value;
                                    return FileTableView(
                                      currentPath: folder,
                                      entries: entries,
                                      selected: selected,
                                      sort: sort,
                                      forceShowSelect: _forceShowSelect,
                                      displayNameBuilder: _displayNameForEntry,
                                      deleteRevision: PendingStorageDeletes.listenableFor(_deleteScope),
                                      isDeletePending: _isDeletePending,
                                      onOpen: _openEntry,
                                      onToggleSelected: _toggleSelected,
                                      onToggleAllSelected: _toggleAllSelected,
                                      onSortChanged: _setSort,
                                      onActivateSelectionMode: _activateMobileSelectionMode,
                                      onClearSelectionMode: _clearMobileSelectionMode,
                                      onDownloadSelected: _downloadSelected,
                                      onDeleteSelected: _confirmAndDeleteSelected,
                                      onUploadFiles: () => _addFiles(folder),
                                      onCreateFolder: () => _addFolder(folder),
                                      onCreateTextFile: _showNewTextFileDialog,
                                      buildActionsMenu: _buildActionsMenu,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                        _buildOpenedFile(context),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class FileTableView extends StatefulWidget {
  final String currentPath;
  final List<StorageEntry> entries;
  final Set<String> selected;
  final FileSort sort;
  final bool forceShowSelect;
  final String Function(StorageEntry entry)? displayNameBuilder;
  final ValueListenable<int> deleteRevision;
  final bool Function(String fullPath, bool isFolder) isDeletePending;
  final void Function(String fullPath, bool isFolder) onOpen;
  final void Function(String key, bool selected) onToggleSelected;
  final void Function(bool selected) onToggleAllSelected;
  final void Function(FileSort) onSortChanged;
  final VoidCallback onActivateSelectionMode;
  final VoidCallback onClearSelectionMode;
  final VoidCallback onDownloadSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onUploadFiles;
  final VoidCallback onCreateFolder;
  final VoidCallback onCreateTextFile;
  final Widget Function(BuildContext? boundaryContext, String fullPath, bool isFolder, bool showTrigger) buildActionsMenu;

  const FileTableView({
    super.key,
    required this.currentPath,
    required this.entries,
    required this.selected,
    required this.sort,
    required this.forceShowSelect,
    this.displayNameBuilder,
    required this.deleteRevision,
    required this.isDeletePending,
    required this.onOpen,
    required this.onToggleSelected,
    required this.onToggleAllSelected,
    required this.onSortChanged,
    required this.onActivateSelectionMode,
    required this.onClearSelectionMode,
    required this.onDownloadSelected,
    required this.onDeleteSelected,
    required this.onUploadFiles,
    required this.onCreateFolder,
    required this.onCreateTextFile,
    required this.buildActionsMenu,
  });

  @override
  State createState() => _FileTableViewState();
}

class _FileTableViewState extends State<FileTableView> {
  static TextStyle get dataStyle => powerboardsFileListTitleStyle();
  static TextStyle get headerStyle => powerboardsFileListMetadataStyle();
  static const BorderRadius _fileCheckboxRadius = BorderRadius.all(Radius.circular(6));

  final ValueNotifier<String?> _hoveredRowKey = ValueNotifier<String?>(null);
  final GlobalKey _tableCardKey = GlobalKey();

  String _displayNameForEntry(StorageEntry entry) {
    return widget.displayNameBuilder?.call(entry) ?? entry.name;
  }

  @override
  void initState() {
    super.initState();
    dataTableShowLogs = false;
  }

  @override
  void dispose() {
    _hoveredRowKey.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FileTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      _hoveredRowKey.value = null;
    }
  }

  void _setHovered(String key) {
    if (_hoveredRowKey.value != key) _hoveredRowKey.value = key;
  }

  void _clearHoveredIf(String key) {
    if (_hoveredRowKey.value == key) _hoveredRowKey.value = null;
  }

  Widget _buildTableCard(Widget child) {
    if (_usesAdaptiveMobileLayout(context)) {
      return ColoredBox(key: _tableCardKey, color: shadCard, child: child);
    }

    final radius = ShadTheme.of(context).radius.resolve(Directionality.of(context));
    const borderWidth = 1.0;
    final innerRadius = BorderRadius.only(
      topLeft: Radius.circular(math.max(0, radius.topLeft.x - borderWidth)),
      topRight: Radius.circular(math.max(0, radius.topRight.x - borderWidth)),
      bottomLeft: Radius.circular(math.max(0, radius.bottomLeft.x - borderWidth)),
      bottomRight: Radius.circular(math.max(0, radius.bottomRight.x - borderWidth)),
    );

    return DecoratedBox(
      key: _tableCardKey,
      decoration: BoxDecoration(
        color: shadCard,
        border: Border.all(color: shadBorder, width: borderWidth),
        borderRadius: radius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(borderWidth),
        child: ClipRRect(borderRadius: innerRadius, child: child),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    Widget createMenuButton() {
      return AppContextMenuButton(
        boundaryContext: context,
        entries: [
          AppMenuEntry(
            title: "New folder",
            description: "Create a folder in this location",
            icon: LucideIcons.folderPlus,
            onPressed: widget.onCreateFolder,
          ),
          AppMenuEntry(
            title: "New Text File",
            description: "Create a new text file in this folder",
            icon: LucideIcons.fileText,
            onPressed: widget.onCreateTextFile,
          ),
        ],
        constraints: const BoxConstraints(minWidth: 220),
        childBuilder: (context, controller) {
          return ShadButton.outline(
            leading: const Icon(LucideIcons.plus),
            trailing: const Icon(LucideIcons.chevronDown),
            onPressed: controller.toggle,
            child: const Text("Create..."),
          );
        },
      );
    }

    return _buildTableCard(
      PaneEmptyState(
        title: "This folder is empty",
        titleScaleOverride: 0.72,
        verticalOffset: -28,
        action: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShadButton.outline(leading: const Icon(LucideIcons.upload), onPressed: widget.onUploadFiles, child: const Text("Upload files")),
            const SizedBox(width: 8),
            createMenuButton(),
          ],
        ),
      ),
    );
  }

  Widget _getIcon(StorageEntry entry) {
    return buildPowerboardsFileListIcon(context, entry);
  }

  Widget _getLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 5),
      child: Text(text, style: headerStyle),
    );
  }

  String? _formatEntrySize(StorageEntry entry) {
    if (entry.isFolder) {
      return null;
    }

    final size = entry.size;
    if (size == null) {
      return null;
    }

    return _formatFileSizeBytes(size);
  }

  Widget _hoverRegion(String rowKey, Widget child) {
    return MouseRegion(opaque: true, onEnter: (_) => _setHovered(rowKey), onExit: (_) => _clearHoveredIf(rowKey), child: child);
  }

  Widget _fileSelectionCheckbox({required bool value, required ShadDecoration decoration, ValueChanged<bool?>? onChanged}) {
    final checkboxForeground = ShadTheme.of(context).colorScheme.primaryForeground;

    return ShadCheckbox(
      decoration: decoration,
      value: value,
      icon: value ? Icon(LucideIcons.check, size: 14, weight: 3, color: checkboxForeground) : null,
      onChanged: onChanged,
    );
  }

  PowerboardsMobileActionPillItem _buildMobileSelectionHeaderPillItem() {
    final selectionActive = widget.forceShowSelect;
    return PowerboardsMobileActionPillItem(
      label: selectionActive ? 'Exit' : 'Select',
      selected: selectionActive,
      onPressed: selectionActive ? widget.onClearSelectionMode : widget.onActivateSelectionMode,
    );
  }

  PowerboardsMobileActionPillItem _buildMobileSortHeaderPillItem({String label = 'Sort by name'}) {
    final isNameSort = widget.sort.field == FileSortField.name;
    final descending = isNameSort && !widget.sort.ascending;
    return PowerboardsMobileActionPillItem(
      label: label,
      selected: descending,
      onPressed: () => widget.onSortChanged(FileSort(FileSortField.name, isNameSort ? !widget.sort.ascending : true)),
    );
  }

  PowerboardsMobileActionPillItem _buildMobileDeleteHeaderPillItem() {
    return PowerboardsMobileActionPillItem(label: "Delete", selected: true, destructive: true, onPressed: widget.onDeleteSelected);
  }

  Widget _buildMobileHeader(bool showSelectColumn, bool? selectAllValue) {
    final theme = ShadTheme.of(context);
    final showSelectionModeActions = widget.forceShowSelect;
    final compactToolbarWidth = MediaQuery.sizeOf(context).width < 390;
    final sortLabel = showSelectionModeActions && compactToolbarWidth ? 'Sort by…' : 'Sort by name';
    final pills = <PowerboardsMobileActionPillItem>[
      _buildMobileSelectionHeaderPillItem(),
      _buildMobileSortHeaderPillItem(label: sortLabel),
      if (showSelectionModeActions) _buildMobileDeleteHeaderPillItem(),
    ];
    final pillTextStyle = powerboardsInterTextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.0);
    final pillGap = showSelectionModeActions && compactToolbarWidth ? 8.0 : 10.0;
    final pillPadding = showSelectionModeActions && compactToolbarWidth
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 11)
        : const EdgeInsets.symmetric(horizontal: 17, vertical: 11);

    return Padding(
      padding: const EdgeInsets.only(top: powerboardsMobileOverlaySecondaryRowLift),
      child: SizedBox(
        height: powerboardsMobileSecondaryRowHeight,
        child: Center(
          child: Padding(
            padding: powerboardsMobileSecondaryRowPadding,
            child: Row(
              children: [
                if (showSelectColumn) ...[
                  SizedBox(
                    width: 36,
                    child: Center(
                      child: ShadTriCheckbox(value: selectAllValue, onChanged: (v) => widget.onToggleAllSelected(v == true)),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PowerboardsMobileActionPillStrip(
                      items: pills,
                      textStyle: pillTextStyle,
                      unselectedForegroundColor: theme.colorScheme.foreground,
                      itemGap: pillGap,
                      pillPadding: pillPadding,
                    ),
                  ),
                ),
                const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollAwareMobileHeader(Widget child) {
    final overlayHeaderScope = PowerboardsMobileOverlayHeaderScope.maybeOf(context);
    final collapseProgress = overlayHeaderScope?.collapseProgress ?? 0;
    final hideForScroll = collapseProgress > 0.1;

    return AnimatedSwitcher(
      duration: powerboardsMobileOverlayHeaderTransitionDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        return ClipRect(
          child: FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, alignment: AlignmentDirectional.topStart, child: child),
          ),
        );
      },
      child: hideForScroll
          ? const SizedBox.shrink(key: ValueKey('file-browser-mobile-header-hidden'))
          : KeyedSubtree(key: const ValueKey('file-browser-mobile-header-visible'), child: child),
    );
  }

  Widget _buildMobileList(BuildContext context, bool showSelectColumn, bool alwaysShowMenu, bool? selectAllValue, bool showSize) {
    final colorScheme = ShadTheme.of(context).colorScheme;

    return _buildTableCard(
      Column(
        children: [
          _buildScrollAwareMobileHeader(_buildMobileHeader(showSelectColumn, selectAllValue)),
          Expanded(
            child: ListView.separated(
              itemCount: widget.entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: shadBorder),
              itemBuilder: (context, index) {
                final entry = widget.entries[index];
                final fullPath = _FilePathKey.pathForEntry(widget.currentPath, entry);
                final key = _FilePathKey.keyForEntry(widget.currentPath, entry);
                final isSelected = widget.selected.contains(key);
                final checkboxDecoration = ShadDecoration(
                  border: ShadBorder.all(color: colorScheme.border, radius: _fileCheckboxRadius),
                );
                final showRowMenu = !widget.forceShowSelect;
                final sizeLabel = showSize ? _formatEntrySize(entry) : null;
                final modifiedLabel = entry.updatedAt?.modified() ?? '';
                final metadataLabel = <String>[?sizeLabel, if (modifiedLabel.isNotEmpty) modifiedLabel].join(' • ');
                final showMetadataLabel = metadataLabel.isNotEmpty;
                final displayName = _displayNameForEntry(entry);
                final deletePending = widget.isDeletePending(fullPath, entry.isFolder);

                return Opacity(
                  opacity: deletePending ? 0.45 : 1,
                  child: Material(
                    color: isSelected ? const Color(0xFFF2F1FF) : shadCard,
                    child: InkWell(
                      onTap: deletePending ? null : () => widget.onOpen(fullPath, entry.isFolder),
                      child: Padding(
                        padding: powerboardsFileListRowPadding,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (showSelectColumn) ...[
                              SizedBox(
                                width: 36,
                                child: Center(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: deletePending ? null : () => widget.onToggleSelected(key, !isSelected),
                                    child: _fileSelectionCheckbox(decoration: checkboxDecoration, value: isSelected),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            _getIcon(entry),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(displayName, style: dataStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (showMetadataLabel) ...[
                                    const SizedBox(height: 4),
                                    Text(metadataLabel, style: headerStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (deletePending)
                              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            else
                              ValueListenableBuilder<String?>(
                                valueListenable: _hoveredRowKey,
                                builder: (_, hoveredKey, _) => widget.buildActionsMenu(
                                  _tableCardKey.currentContext,
                                  fullPath,
                                  entry.isFolder,
                                  showRowMenu && (alwaysShowMenu || isSelected || hoveredKey == key),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(valueListenable: widget.deleteRevision, builder: (context, _, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return _buildEmptyState(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final showSize = availableWidth > 500;
        final isMobile = _usesAdaptiveMobileLayout(context);
        final colorScheme = ShadTheme.of(context).colorScheme;
        final showSelectColumn = !isMobile || widget.forceShowSelect;
        final alwaysShowMenu = isMobile;
        final selectableKeys = widget.entries
            .where((entry) => !widget.isDeletePending(_FilePathKey.pathForEntry(widget.currentPath, entry), entry.isFolder))
            .map((entry) => _FilePathKey.keyForEntry(widget.currentPath, entry))
            .toSet();
        final selectedSelectableCount = widget.selected.where(selectableKeys.contains).length;
        final bool? selectAllValue = selectedSelectableCount == 0
            ? false
            : (selectedSelectableCount == selectableKeys.length ? true : null);

        if (isMobile) {
          return _buildMobileList(context, showSelectColumn, alwaysShowMenu, selectAllValue, showSize);
        }

        final sortColumnIndex = (widget.sort.field == FileSortField.name ? 0 : (showSize ? 2 : 1)) + (showSelectColumn ? 1 : 0);
        final sortAscending = widget.sort.ascending;
        final rows = widget.entries.map((entry) {
          final fullPath = _FilePathKey.pathForEntry(widget.currentPath, entry);
          final key = _FilePathKey.keyForEntry(widget.currentPath, entry);
          final isSelected = widget.selected.contains(key);
          final checkboxDecoration = ShadDecoration(
            border: ShadBorder.all(color: colorScheme.border, radius: _fileCheckboxRadius),
          );
          final sizeLabel = showSize ? (_formatEntrySize(entry) ?? "") : "";
          final displayName = _displayNameForEntry(entry);
          final deletePending = widget.isDeletePending(fullPath, entry.isFolder);

          return DataRow(
            onSelectChanged: deletePending
                ? null
                : (_) {
                    widget.onOpen(fullPath, entry.isFolder);
                  },
            color: WidgetStateProperty.resolveWith((states) {
              if (isSelected) {
                return const Color(0xFFF2F1FF);
              }
              if (states.contains(WidgetState.hovered)) {
                return const Color(0xFFF8F8FA);
              }
              return shadCard;
            }),
            cells: [
              if (showSelectColumn)
                DataCell(
                  Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: deletePending ? null : () => widget.onToggleSelected(key, !isSelected),
                      child: _fileSelectionCheckbox(decoration: checkboxDecoration, value: isSelected),
                    ),
                  ),
                ),
              DataCell(
                _hoverRegion(
                  key,
                  Opacity(
                    opacity: deletePending ? 0.45 : 1,
                    child: Row(
                      children: [
                        _getIcon(entry),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(displayName, style: dataStyle, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showSize)
                DataCell(
                  _hoverRegion(
                    key,
                    Container(
                      width: double.infinity,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(sizeLabel, style: dataStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
              DataCell(
                _hoverRegion(
                  key,
                  Container(
                    width: double.infinity,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(entry.updatedAt?.modified() ?? "", style: dataStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              DataCell(
                _hoverRegion(
                  key,
                  deletePending
                      ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                      : ValueListenableBuilder<String?>(
                          valueListenable: _hoveredRowKey,
                          builder: (_, hoveredKey, _) => Center(
                            child: widget.buildActionsMenu(
                              _tableCardKey.currentContext,
                              fullPath,
                              entry.isFolder,
                              alwaysShowMenu || isSelected || hoveredKey == key,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        }).toList();

        final sizeWidth = showSize ? (availableWidth < 760 ? 100.0 : 120.0) : 0.0;
        final modifiedWidth = constraints.maxWidth < 640 ? 140.0 : 170.0;
        final actionWidth = constraints.maxWidth < 640 ? 48.0 : 56.0;
        final selectWidth = showSelectColumn ? (constraints.maxWidth < 640 ? 48.0 : 56.0) : 0.0;
        final fixedWidthTotal = selectWidth + sizeWidth + modifiedWidth + actionWidth;

        if (constraints.maxWidth < fixedWidthTotal + 140) {
          return _buildMobileList(context, widget.forceShowSelect, true, selectAllValue, showSize);
        }

        return _buildTableCard(
          Theme(
            data: Theme.of(context).copyWith(dividerColor: shadBorder),
            child: DataTable2(
              showCheckboxColumn: false,
              columnSpacing: 0,
              horizontalMargin: 0,
              headingRowHeight: filePaneTableHeaderHeight,
              headingRowColor: const WidgetStatePropertyAll(shadCard),
              dataRowColor: const WidgetStatePropertyAll(shadCard),
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
              columns: [
                if (showSelectColumn)
                  DataColumn2(
                    fixedWidth: selectWidth,
                    label: Center(
                      child: ShadTriCheckbox(value: selectAllValue, onChanged: (v) => widget.onToggleAllSelected(v == true)),
                    ),
                  ),
                DataColumn2(
                  label: _getLabel("Name"),
                  size: ColumnSize.L,
                  onSort: (_, ascending) => widget.onSortChanged(FileSort(FileSortField.name, ascending)),
                ),
                if (showSize) DataColumn2(label: _getLabel("Size"), fixedWidth: sizeWidth),
                DataColumn2(
                  label: _getLabel("Modified"),
                  fixedWidth: modifiedWidth,
                  onSort: (_, ascending) => widget.onSortChanged(FileSort(FileSortField.modified, ascending)),
                ),
                DataColumn2(label: const SizedBox.shrink(), fixedWidth: actionWidth),
              ],
              rows: rows,
            ),
          ),
        );
      },
    );
  }
}

class _FileActionsMenuButton extends StatefulWidget {
  const _FileActionsMenuButton({
    super.key,
    required this.items,
    required this.estimatedMenuWidth,
    required this.estimatedMenuHeight,
    required this.showTrigger,
    this.onOpen,
    this.boundaryContext,
  });

  final List<Widget> items;
  final double estimatedMenuWidth;
  final double estimatedMenuHeight;
  final bool showTrigger;
  final VoidCallback? onOpen;
  final BuildContext? boundaryContext;

  @override
  State<_FileActionsMenuButton> createState() => _FileActionsMenuButtonState();
}

class _FileActionsMenuButtonState extends State<_FileActionsMenuButton> {
  static const double _mobileRowMenuTriggerSize = 48;
  late final ShadContextMenuController _controller = ShadContextMenuController();
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncOpenState);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncOpenState);
    _controller.dispose();
    super.dispose();
  }

  void _syncOpenState() {
    if (_menuOpen == _controller.isOpen) {
      return;
    }

    if (!_menuOpen && _controller.isOpen) {
      widget.onOpen?.call();
    }

    setState(() {
      _menuOpen = _controller.isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showTrigger = widget.showTrigger || _menuOpen;
    return AdaptiveShadContextMenu(
      controller: _controller,
      boundaryContext: widget.boundaryContext,
      constraints: const BoxConstraints(minWidth: 200),
      estimatedMenuWidth: widget.estimatedMenuWidth,
      estimatedMenuHeight: widget.estimatedMenuHeight,
      items: widget.items,
      child: IgnorePointer(
        ignoring: !showTrigger,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: showTrigger ? 1 : 0,
          child: ShadGestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _controller.toggle,
            child: const SizedBox(
              width: _mobileRowMenuTriggerSize,
              height: _mobileRowMenuTriggerSize,
              child: Center(child: Icon(LucideIcons.ellipsis, size: 20)),
            ),
          ),
        ),
      ),
    );
  }
}

class ShadTriCheckbox extends StatelessWidget {
  const ShadTriCheckbox({super.key, required this.value, required this.onChanged});

  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool internalBool = value != false;

    final theme = ShadTheme.of(context);
    final effectiveSize = theme.checkboxTheme.size;
    final iconColor = theme.colorScheme.primaryForeground;

    final Widget? effectiveIcon = value == null ? Icon(LucideIcons.minus, size: effectiveSize, color: iconColor) : null;
    final checkboxDecoration = ShadDecoration(
      border: ShadBorder.all(color: ShadTheme.of(context).colorScheme.border, radius: _FileTableViewState._fileCheckboxRadius),
    );
    return Semantics(
      checked: value == true,
      mixed: value == null,
      child: ExcludeSemantics(
        child: ShadCheckbox(
          decoration: checkboxDecoration,
          value: internalBool,
          icon: effectiveIcon,
          onChanged: (_) => onChanged(value == false),
        ),
      ),
    );
  }
}
