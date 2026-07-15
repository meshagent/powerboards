import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:powerboards/meshagent/archive_extract.dart';
import 'package:powerboards/meshagent/path.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_archive_extract.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_button.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_progress_bar.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_typography.dart';
import 'package:powerboards/ui/powerboards_toasts.dart';

const Duration _archiveExtractionProgressToastDuration = Duration(days: 1);
const Duration _archiveExtractionCompleteToastDuration = Duration(seconds: 12);
const Duration _archiveExtractionActionToastDuration = Duration(days: 1);

final Set<String> _activeArchiveExtractionJobKeys = <String>{};

typedef PowerboardsArchiveExtractionOpenHandler = void Function(PowerboardsArchiveExtractionOpenTarget target);

class PowerboardsArchiveExtractionOpenTarget {
  const PowerboardsArchiveExtractionOpenTarget({required this.targetFolderPath, required this.firstPreviewPath, required this.result});

  final String targetFolderPath;
  final String? firstPreviewPath;
  final PowerboardsArchiveExtractResult result;

  String? get previewPath {
    final path = firstPreviewPath?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    return joinPaths(targetFolderPath, path);
  }
}

class _ArchiveExtractionToastProgress {
  const _ArchiveExtractionToastProgress({
    required this.completed,
    required this.total,
    required this.indeterminate,
    this.finalizing = false,
  });

  final int completed;
  final int total;
  final bool indeterminate;
  final bool finalizing;

  double? get value {
    if (finalizing) {
      return 1.0;
    }
    if (indeterminate || total <= 0) {
      return null;
    }
    return (completed / total).clamp(0.0, 1.0).toDouble();
  }

  String get label {
    if (finalizing) {
      return 'Finalizing extracted folder';
    }
    if (indeterminate || total <= 0) {
      return 'Preparing extracted folder';
    }
    final visibleCompleted = math.min(completed, total);
    return '$visibleCompleted of $total ${total == 1 ? 'file' : 'files'} completed';
  }
}

Future<PowerboardsArchiveExtractionOpenTarget?> startPowerboardsArchiveExtractionWithToast({
  required BuildContext context,
  required RoomClient room,
  required String archivePath,
  required PbArchiveInspectionResult inspection,
  required PowerboardsArchiveExtractionOpenHandler onOpenResult,
}) async {
  final toaster = ShadToaster.maybeOf(context);
  if (toaster == null || !inspection.browsable) {
    return null;
  }

  final jobKey = _archiveExtractionJobKey(archivePath);
  if (!_activeArchiveExtractionJobKeys.add(jobKey)) {
    toaster.show(
      powerboardsToast(title: 'Extraction already running', description: inspection.targetFolderName, duration: const Duration(seconds: 4)),
    );
    return null;
  }

  final totalEntries = _archiveExtractionProgressTotal(inspection);
  final progress = ValueNotifier(
    _ArchiveExtractionToastProgress(
      completed: 0,
      total: totalEntries,
      indeterminate: !_usesClientSideZipProgress(archivePath: archivePath, inspection: inspection),
    ),
  );
  String? targetFolderPath;
  String? stagingFolderPath;

  toaster.show(
    powerboardsWidgetToast(
      title: const Text('Extracting files into a folder'),
      description: _ArchiveExtractionProgressToast(progress: progress),
      duration: _archiveExtractionProgressToastDuration,
    ),
  );

  try {
    targetFolderPath = await resolvePowerboardsArchiveExtractTargetPath(
      room: room,
      archivePath: archivePath,
      targetFolderName: inspection.targetFolderName,
    );
    stagingFolderPath = await _resolvePowerboardsArchiveExtractionStagingPath(room: room, targetFolderPath: targetFolderPath);

    var completedEntries = 0;
    final result = await extractPowerboardsArchive(
      room: room,
      archivePath: archivePath,
      targetFolderPath: stagingFolderPath,
      onEntryExtracted: (_) {
        if (progress.value.indeterminate) {
          return;
        }
        completedEntries += 1;
        progress.value = _ArchiveExtractionToastProgress(completed: completedEntries, total: totalEntries, indeterminate: false);
      },
    );

    progress.value = _ArchiveExtractionToastProgress(completed: totalEntries, total: totalEntries, indeterminate: false, finalizing: true);

    final publishedResult = _publishArchiveExtractionResult(result: result, targetFolderPath: targetFolderPath);
    if (publishedResult.extractedEntries.isNotEmpty) {
      await room.storage.move(stagingFolderPath, targetFolderPath, overwrite: false);
    } else {
      await _deleteArchiveExtractionStagingFolder(room: room, stagingFolderPath: stagingFolderPath);
    }

    if (!context.mounted) {
      return PowerboardsArchiveExtractionOpenTarget(
        targetFolderPath: targetFolderPath,
        firstPreviewPath: publishedResult.firstPreviewPath,
        result: publishedResult,
      );
    }

    final openTarget = PowerboardsArchiveExtractionOpenTarget(
      targetFolderPath: targetFolderPath,
      firstPreviewPath: publishedResult.firstPreviewPath,
      result: publishedResult,
    );

    final canOpenResult = publishedResult.extractedEntries.isNotEmpty;
    toaster.show(
      powerboardsWidgetToast(
        title: Text(_archiveExtractionCompleteTitle(publishedResult)),
        description: _ArchiveExtractionCompleteToast(
          result: publishedResult,
          inspection: inspection,
          onOpenResult: () => onOpenResult(openTarget),
        ),
        destructive: publishedResult.extractedEntries.isEmpty && publishedResult.hasFailures,
        duration: canOpenResult ? _archiveExtractionActionToastDuration : _archiveExtractionCompleteToastDuration,
      ),
    );
    return openTarget;
  } catch (error) {
    if (stagingFolderPath != null) {
      await _deleteArchiveExtractionStagingFolder(room: room, stagingFolderPath: stagingFolderPath);
    }

    if (context.mounted) {
      toaster.show(
        powerboardsToast(
          title: 'Extraction failed',
          description: 'Please try again or download.',
          destructive: true,
          duration: const Duration(seconds: 8),
        ),
      );
    }
    return null;
  } finally {
    _activeArchiveExtractionJobKeys.remove(jobKey);
  }
}

String _archiveExtractionCompleteTitle(PowerboardsArchiveExtractResult result) {
  if (!result.hasFailures) {
    return 'Files extracted into folder';
  }
  return result.extractedEntries.isEmpty ? 'Extraction failed' : 'Files extracted with issues';
}

String _archiveExtractionCompleteDescription({
  required PowerboardsArchiveExtractResult result,
  required PbArchiveInspectionResult inspection,
}) {
  final failed = result.failedFileCount > 0 ? result.failedFileCount : result.failedEntries.length;
  final extracted = result.extractedFileCount;
  final total = math.max(inspection.fileCount, extracted + failed);
  final failedLabel = failed == 1 ? 'file' : 'files';

  if (!result.hasFailures) {
    return '$extracted of $total ${total == 1 ? 'file' : 'files'} completed.';
  }
  if (extracted > 0) {
    return '$extracted of $total files completed. $failed $failedLabel failed.';
  }
  if (failed > 0) {
    return 'No files were extracted. $failed $failedLabel failed.';
  }
  return 'Some archive entries could not be extracted.';
}

int _archiveExtractionProgressTotal(PbArchiveInspectionResult inspection) {
  final filePaths = {for (final entry in inspection.entries.where((entry) => !entry.folder)) entry.path};
  var total = filePaths.length;
  for (final entry in inspection.entries.where((entry) => entry.folder)) {
    final hasChildFile = filePaths.any((path) => path.startsWith('${entry.path}/'));
    if (!hasChildFile) {
      total += 1;
    }
  }
  return math.max(total, 1);
}

PowerboardsArchiveExtractResult _publishArchiveExtractionResult({
  required PowerboardsArchiveExtractResult result,
  required String targetFolderPath,
}) {
  return PowerboardsArchiveExtractResult(
    targetFolderPath: targetFolderPath,
    firstPreviewPath: result.firstPreviewPath,
    extractedEntries: result.extractedEntries,
    failedEntries: result.failedEntries,
  );
}

Future<String> _resolvePowerboardsArchiveExtractionStagingPath({required RoomClient room, required String targetFolderPath}) async {
  final parent = parentPath(targetFolderPath);
  final parts = targetFolderPath.trim().split('/').where((segment) => segment.isNotEmpty).toList(growable: false);
  final folderName = parts.isEmpty ? 'archive' : parts.last;
  final random = math.Random();

  for (var attempt = 0; attempt < 100; attempt++) {
    final nonce = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final randomSuffix = random.nextInt(0x100000).toRadixString(36);
    final attemptSuffix = attempt == 0 ? '' : '-${attempt + 1}';
    final candidate = joinPaths(parent, '.powerboards-extracting-$nonce-$randomSuffix$attemptSuffix-$folderName');
    if (!await _archiveExtractionStoragePathExists(room: room, path: candidate)) {
      return candidate;
    }
  }

  return joinPaths(parent, '.powerboards-extracting-${DateTime.now().millisecondsSinceEpoch}-$folderName');
}

Future<bool> _archiveExtractionStoragePathExists({required RoomClient room, required String path}) async {
  try {
    if (await room.storage.stat(path) != null) {
      return true;
    }
  } catch (_) {}

  try {
    return (await room.storage.list(path)).isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<void> _deleteArchiveExtractionStagingFolder({required RoomClient room, required String stagingFolderPath}) async {
  try {
    await room.storage.delete(stagingFolderPath, recursive: true);
  } catch (_) {}
}

String _archiveExtractionJobKey(String archivePath) {
  return archivePath.trim().split('/').where((segment) => segment.isNotEmpty).join('/');
}

bool _isZipArchivePath(String archivePath) {
  return archivePath.trim().toLowerCase().endsWith('.zip');
}

bool _usesClientSideZipProgress({required String archivePath, required PbArchiveInspectionResult inspection}) {
  return _isZipArchivePath(archivePath) && inspection.archiveSizeBytes <= powerboardsClientSideZipExtractionMaxBytes;
}

class _ArchiveExtractionProgressToast extends StatelessWidget {
  const _ArchiveExtractionProgressToast({required this.progress});

  final ValueListenable<_ArchiveExtractionToastProgress> progress;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_ArchiveExtractionToastProgress>(
      valueListenable: progress,
      builder: (context, value, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value.label, style: PowerboardsTypography.meta.copyWith(color: PbColors.textMuted)),
            const SizedBox(height: 12),
            _ArchiveExtractionProgressBar(value: value.value),
          ],
        );
      },
    );
  }
}

class _ArchiveExtractionProgressBar extends StatelessWidget {
  const _ArchiveExtractionProgressBar({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    return PbProgressBar(value: value, height: 6, minVisualValue: 0.05);
  }
}

class _ArchiveExtractionCompleteToast extends StatelessWidget {
  const _ArchiveExtractionCompleteToast({required this.result, required this.inspection, required this.onOpenResult});

  final PowerboardsArchiveExtractResult result;
  final PbArchiveInspectionResult inspection;
  final VoidCallback onOpenResult;

  @override
  Widget build(BuildContext context) {
    final canOpen = result.extractedEntries.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _archiveExtractionCompleteDescription(result: result, inspection: inspection),
          style: PowerboardsTypography.meta.copyWith(color: PbColors.textMuted),
        ),
        if (canOpen) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PbTertiaryButton.solid(
              iconAssetName: 'folder',
              label: 'Browse files',
              onPressed: () {
                ShadToaster.of(context).hide();
                onOpenResult();
              },
            ),
          ),
        ],
      ],
    );
  }
}
