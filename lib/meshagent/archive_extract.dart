import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart' as archive;
import 'package:collection/collection.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:powerboards/meshagent/path.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_archive_extract.dart';

const String _archiveToolImage = 'meshagent/python:default';
const String _storageFolderPlaceholderFileName = '.placeholder';
const int powerboardsClientSideZipExtractionMaxBytes = 32 * 1024 * 1024;

class PowerboardsArchiveExtractResult {
  const PowerboardsArchiveExtractResult({
    required this.targetFolderPath,
    required this.firstPreviewPath,
    this.extractedEntries = const [],
    this.failedEntries = const [],
  });

  final String targetFolderPath;
  final String? firstPreviewPath;
  final List<PowerboardsArchiveExtractedEntry> extractedEntries;
  final List<PowerboardsArchiveExtractFailedEntry> failedEntries;

  bool get hasFailures => failedEntries.isNotEmpty;

  int get extractedFileCount => extractedEntries.where((entry) => !entry.folder).length;
  int get failedFileCount => failedEntries.where((entry) => !entry.folder).length;
}

class PowerboardsArchiveExtractedEntry {
  const PowerboardsArchiveExtractedEntry({required this.path, required this.folder, required this.sizeBytes});

  final String path;
  final bool folder;
  final int sizeBytes;
}

class PowerboardsArchiveExtractFailedEntry {
  const PowerboardsArchiveExtractFailedEntry({
    required this.path,
    required this.folder,
    required this.sizeBytes,
    required this.errorDescription,
  });

  final String path;
  final bool folder;
  final int sizeBytes;
  final String errorDescription;
}

typedef PowerboardsArchiveEntryExtractedCallback = FutureOr<void> Function(PowerboardsArchiveExtractedEntry entry);
typedef PowerboardsArchiveStorageUploadCallback =
    Future<void> Function(String path, Stream<Uint8List> chunks, {required bool overwrite, required int size});

Future<PbArchiveInspectionResult> inspectPowerboardsArchive({
  required RoomClient room,
  required String archivePath,
  required String targetFolderName,
}) async {
  if (_isZipArchivePath(archivePath)) {
    if (await _shouldUseServerSideZipArchive(room: room, archivePath: archivePath)) {
      final payload = await _runPowerboardsArchiveTool(room: room, mode: 'inspect', archivePath: archivePath, targetPath: null);
      return _inspectionFromPayload(payload, fallbackTargetFolderName: targetFolderName);
    }

    try {
      final zip = await _loadPowerboardsZipArchive(room: room, archivePath: archivePath);
      return inspectPowerboardsZipArchiveBytesForTesting(
        zip.bytes,
        targetFolderName: targetFolderName,
        archiveSizeBytes: zip.archiveSizeBytes,
      );
    } on _ArchiveInspectionLimitException catch (error) {
      return error.toInspectionResult(targetFolderName: targetFolderName);
    } catch (_) {
      // Fall back to the container inspector for unusual ZIP metadata or storage
      // conditions that the lightweight central-directory reader cannot handle.
    }
  }

  final payload = await _runPowerboardsArchiveTool(room: room, mode: 'inspect', archivePath: archivePath, targetPath: null);
  return _inspectionFromPayload(payload, fallbackTargetFolderName: targetFolderName);
}

Future<PowerboardsArchiveExtractResult> extractPowerboardsArchive({
  required RoomClient room,
  required String archivePath,
  required String targetFolderPath,
  PowerboardsArchiveEntryExtractedCallback? onEntryExtracted,
}) async {
  if (_isZipArchivePath(archivePath) && !await _shouldUseServerSideZipArchive(room: room, archivePath: archivePath)) {
    return _extractPowerboardsZipArchive(
      room: room,
      archivePath: archivePath,
      targetFolderPath: targetFolderPath,
      onEntryExtracted: onEntryExtracted,
    );
  }

  return _extractPowerboardsArchiveWithTool(
    room: room,
    archivePath: archivePath,
    targetFolderPath: targetFolderPath,
    onEntryExtracted: onEntryExtracted,
  );
}

Future<PowerboardsArchiveExtractResult> _extractPowerboardsArchiveWithTool({
  required RoomClient room,
  required String archivePath,
  required String targetFolderPath,
  PowerboardsArchiveEntryExtractedCallback? onEntryExtracted,
}) async {
  final payload = await _runPowerboardsArchiveTool(room: room, mode: 'extract', archivePath: archivePath, targetPath: targetFolderPath);
  final inspection = _inspectionFromPayload(payload, fallbackTargetFolderName: targetFolderPath.split('/').last);
  if (!inspection.browsable) {
    throw StateError(inspection.overLimitReason ?? 'Archive cannot be extracted for preview.');
  }

  final result = PowerboardsArchiveExtractResult(
    targetFolderPath: targetFolderPath,
    firstPreviewPath: inspection.firstPreviewPath,
    extractedEntries: [
      for (final entry in inspection.entries)
        PowerboardsArchiveExtractedEntry(path: entry.path, folder: entry.folder, sizeBytes: entry.sizeBytes),
    ],
  );

  for (final entry in result.extractedEntries) {
    await onEntryExtracted?.call(entry);
  }

  return result;
}

Future<String> resolvePowerboardsArchiveExtractTargetPath({
  required RoomClient room,
  required String archivePath,
  required String targetFolderName,
}) async {
  final parent = parentPath(archivePath);
  final baseName = _safeStorageFolderName(targetFolderName);

  for (var attempt = 0; attempt < 100; attempt++) {
    final candidateName = attempt == 0 ? baseName : '$baseName ${attempt + 1}';
    final candidatePath = joinPaths(parent, candidateName);
    StorageEntry? existing;
    try {
      existing = await room.storage.stat(candidatePath);
    } catch (_) {
      existing = null;
    }
    if (existing == null && !await _powerboardsStoragePathHasChildren(room: room, path: candidatePath)) {
      return candidatePath;
    }
  }

  return joinPaths(parent, '$baseName ${DateTime.now().millisecondsSinceEpoch}');
}

Future<bool> _powerboardsStoragePathHasChildren({required RoomClient room, required String path}) async {
  try {
    return (await room.storage.list(path)).isNotEmpty;
  } catch (_) {
    return false;
  }
}

PbArchiveInspectionResult _inspectionFromPayload(Map<String, dynamic> payload, {required String fallbackTargetFolderName}) {
  final variant = payload['variant'] == 'browsable' ? PbArchiveInspectionVariant.browsable : PbArchiveInspectionVariant.overLimit;
  final entries = <PbArchiveExtractEntry>[];
  final rawEntries = payload['entries'];
  if (rawEntries is List) {
    for (final rawEntry in rawEntries) {
      if (rawEntry is! Map) {
        continue;
      }
      final entry = Map<String, dynamic>.from(rawEntry);
      final path = entry['path'];
      final folder = entry['folder'];
      final sizeBytes = entry['size_bytes'];
      if (path is! String || path.trim().isEmpty || folder is! bool) {
        continue;
      }
      entries.add(PbArchiveExtractEntry.fromPath(path: path, sizeBytes: sizeBytes is int ? sizeBytes : 0, folder: folder));
    }
  }

  return PbArchiveInspectionResult(
    variant: variant,
    targetFolderName: _stringValue(payload['target_folder_name']) ?? fallbackTargetFolderName,
    archiveSizeBytes: _intValue(payload['archive_size_bytes']),
    expandedSizeBytes: _intValue(payload['expanded_size_bytes']),
    fileCount: _intValue(payload['file_count']),
    folderCount: _intValue(payload['folder_count']),
    maxDepth: _intValue(payload['max_depth']),
    firstPreviewPath: _stringValue(payload['first_preview_path']),
    overLimitReason: _stringValue(payload['over_limit_reason']),
    entries: entries,
  );
}

Future<Map<String, dynamic>> _runPowerboardsArchiveTool({
  required RoomClient room,
  required String mode,
  required String archivePath,
  required String? targetPath,
}) async {
  String? containerId;
  try {
    final args = [mode, _storagePathToContainerPath(archivePath), if (targetPath != null) _storagePathToContainerPath(targetPath)];
    containerId = await room.containers.run(
      image: _archiveToolImage,
      command: 'python3 -c ${_shellQuote(_archiveToolScript)} ${args.map(_shellQuote).join(' ')}',
      mountPath: '/data',
      workingDir: '/data',
      private: true,
    );

    final exitCode = await room.containers.waitForExit(containerId: containerId);
    final output = await _containerLogs(room: room, containerId: containerId);
    final payload = _parseLastJsonObject(output);
    if (payload != null) {
      return payload;
    }
    throw StateError('Archive tool exited with code $exitCode without a result.');
  } finally {
    if (containerId != null) {
      try {
        await room.containers.deleteContainer(containerId: containerId);
      } catch (_) {}
    }
  }
}

Future<String> _containerLogs({required RoomClient room, required String containerId}) async {
  final logs = room.containers.logs(containerId: containerId);
  final buffer = StringBuffer();
  await for (final chunk in logs.stream) {
    buffer.write(chunk);
  }
  await logs.result;
  return buffer.toString();
}

Map<String, dynamic>? _parseLastJsonObject(String output) {
  final lines = output.split('\n').map((line) => line.trim()).where((line) => line.startsWith('{') && line.endsWith('}')).toList();
  for (final line in lines.reversed) {
    final decoded = jsonDecode(line);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  }
  return null;
}

String _storagePathToContainerPath(String path) {
  return '/data/${path.trim().split('/').where((segment) => segment.isNotEmpty).join('/')}';
}

String _safeStorageFolderName(String value) {
  final trimmed = value.trim().replaceAll(RegExp(r'[/\\]+'), ' ');
  final collapsed = trimmed.replaceAll(RegExp(r'\s+'), ' ');
  return collapsed.isEmpty ? 'extracted archive' : collapsed;
}

String _shellQuote(String value) {
  if (value.isEmpty) {
    return "''";
  }
  return "'${value.replaceAll("'", r"'\''")}'";
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int _intValue(Object? value) {
  return value is int ? value : 0;
}

bool _isZipArchivePath(String path) {
  return path.trim().toLowerCase().endsWith('.zip');
}

Future<bool> _shouldUseServerSideZipArchive({required RoomClient room, required String archivePath}) async {
  try {
    final storageEntry = await room.storage.stat(archivePath);
    return storageEntry != null &&
        !storageEntry.isFolder &&
        storageEntry.size != null &&
        storageEntry.size! > powerboardsClientSideZipExtractionMaxBytes;
  } catch (_) {
    return false;
  }
}

Future<_LoadedZipArchive> _loadPowerboardsZipArchive({required RoomClient room, required String archivePath}) async {
  final storageEntry = await room.storage.stat(archivePath);
  if (storageEntry == null || storageEntry.isFolder) {
    throw _ArchiveInspectionLimitException(reason: 'The archive could not be inspected.', archiveSizeBytes: 0);
  }

  final storageSize = storageEntry.size;
  if (storageSize != null && storageSize > PbArchiveExtractLimits.archiveMaxBytes) {
    throw _ArchiveInspectionLimitException(reason: 'This archive is larger than the 100 MB preview limit.', archiveSizeBytes: storageSize);
  }

  final content = await room.storage.download(archivePath);
  final archiveSizeBytes = storageSize ?? content.data.length;
  if (archiveSizeBytes > PbArchiveExtractLimits.archiveMaxBytes) {
    throw _ArchiveInspectionLimitException(
      reason: 'This archive is larger than the 100 MB preview limit.',
      archiveSizeBytes: archiveSizeBytes,
    );
  }

  return _LoadedZipArchive(bytes: content.data, archiveSizeBytes: archiveSizeBytes);
}

Future<PowerboardsArchiveExtractResult> _extractPowerboardsZipArchive({
  required RoomClient room,
  required String archivePath,
  required String targetFolderPath,
  PowerboardsArchiveEntryExtractedCallback? onEntryExtracted,
}) async {
  final zip = await _loadPowerboardsZipArchive(room: room, archivePath: archivePath);
  final targetFolderName = targetFolderPath.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? targetFolderPath.trim();
  final inspection = inspectPowerboardsZipArchiveBytesForTesting(
    zip.bytes,
    targetFolderName: targetFolderName,
    archiveSizeBytes: zip.archiveSizeBytes,
  );
  if (!inspection.browsable) {
    throw StateError(inspection.overLimitReason ?? 'Archive cannot be extracted for preview.');
  }

  final extractedFiles = extractPowerboardsZipArchiveFilesForTesting(zip.bytes, inspection: inspection);
  return uploadPowerboardsZipArchiveFilesForTesting(
    targetFolderPath: targetFolderPath,
    inspection: inspection,
    files: extractedFiles,
    uploadStream: (path, chunks, {required overwrite, required size}) =>
        room.storage.uploadStream(path, chunks, overwrite: overwrite, size: size),
    onEntryExtracted: onEntryExtracted,
  );
}

// Visible for tests.
Future<PowerboardsArchiveExtractResult> uploadPowerboardsZipArchiveFilesForTesting({
  required String targetFolderPath,
  required PbArchiveInspectionResult inspection,
  required List<PowerboardsZipExtractedFile> files,
  required PowerboardsArchiveStorageUploadCallback uploadStream,
  PowerboardsArchiveEntryExtractedCallback? onEntryExtracted,
}) async {
  final extractedFilePaths = files.map((file) => file.path).toSet();
  final extractedEntries = <PowerboardsArchiveExtractedEntry>[];
  final failedEntries = <PowerboardsArchiveExtractFailedEntry>[];
  for (final entry in inspection.entries.where((entry) => entry.folder)) {
    final hasChildFile = extractedFilePaths.any((path) => path.startsWith('${entry.path}/'));
    if (hasChildFile) {
      continue;
    }
    final extractedEntry = PowerboardsArchiveExtractedEntry(path: entry.path, folder: true, sizeBytes: 0);
    try {
      await uploadStream(
        joinPaths(joinPaths(targetFolderPath, entry.path), _storageFolderPlaceholderFileName),
        Stream<Uint8List>.empty(),
        overwrite: false,
        size: 0,
      );
    } catch (error) {
      failedEntries.add(PowerboardsArchiveExtractFailedEntry(path: entry.path, folder: true, sizeBytes: 0, errorDescription: '$error'));
      continue;
    }

    extractedEntries.add(extractedEntry);
    await onEntryExtracted?.call(extractedEntry);
  }

  for (final file in files) {
    final extractedEntry = PowerboardsArchiveExtractedEntry(path: file.path, folder: false, sizeBytes: file.bytes.length);
    try {
      await uploadStream(
        joinPaths(targetFolderPath, file.path),
        Stream<Uint8List>.value(file.bytes),
        overwrite: false,
        size: file.bytes.length,
      );
    } catch (error) {
      failedEntries.add(
        PowerboardsArchiveExtractFailedEntry(path: file.path, folder: false, sizeBytes: file.bytes.length, errorDescription: '$error'),
      );
      continue;
    }

    extractedEntries.add(extractedEntry);
    await onEntryExtracted?.call(extractedEntry);
  }

  final successfulFilePaths = {for (final entry in extractedEntries.where((entry) => !entry.folder)) entry.path};
  return PowerboardsArchiveExtractResult(
    targetFolderPath: targetFolderPath,
    firstPreviewPath: _firstSuccessfulPreviewPath(inspection: inspection, successfulFilePaths: successfulFilePaths),
    extractedEntries: extractedEntries,
    failedEntries: failedEntries,
  );
}

String? _firstSuccessfulPreviewPath({required PbArchiveInspectionResult inspection, required Set<String> successfulFilePaths}) {
  if (successfulFilePaths.isEmpty) {
    return null;
  }

  final preferredPath = inspection.firstPreviewPath?.trim();
  if (preferredPath != null && preferredPath.isNotEmpty && successfulFilePaths.contains(preferredPath)) {
    return preferredPath;
  }

  final firstImage = inspection.entries.firstWhereOrNull(
    (entry) =>
        entry.previewable &&
        successfulFilePaths.contains(entry.path) &&
        _zipPreviewImageExtensions.contains(_extensionForPath(entry.path)) &&
        entry.sizeBytes <= PbArchiveExtractLimits.autoPreviewImageMaxBytes,
  );
  if (firstImage != null) {
    return firstImage.path;
  }

  return inspection.entries.firstWhereOrNull((entry) => entry.previewable && successfulFilePaths.contains(entry.path))?.path;
}

// Visible for tests.
PbArchiveInspectionResult inspectPowerboardsZipArchiveBytesForTesting(
  Uint8List bytes, {
  required String targetFolderName,
  required int archiveSizeBytes,
}) {
  if (archiveSizeBytes > PbArchiveExtractLimits.archiveMaxBytes) {
    throw _ArchiveInspectionLimitException(
      reason: 'This archive is larger than the 100 MB preview limit.',
      archiveSizeBytes: archiveSizeBytes,
    );
  }

  final data = ByteData.sublistView(bytes);
  final eocdOffset = _findZipEndOfCentralDirectory(data);
  if (eocdOffset == null) {
    throw _ArchiveInspectionLimitException(reason: 'The archive could not be inspected.', archiveSizeBytes: archiveSizeBytes);
  }

  final diskNumber = _uint16(data, eocdOffset + 4);
  final centralDirectoryDisk = _uint16(data, eocdOffset + 6);
  final entryCountOnDisk = _uint16(data, eocdOffset + 8);
  final entryCount = _uint16(data, eocdOffset + 10);
  final centralDirectorySize = _uint32(data, eocdOffset + 12);
  final centralDirectoryOffset = _uint32(data, eocdOffset + 16);

  if (diskNumber != 0 || centralDirectoryDisk != 0 || entryCountOnDisk != entryCount) {
    throw _ArchiveInspectionLimitException(reason: 'This archive uses multi-part ZIP metadata.', archiveSizeBytes: archiveSizeBytes);
  }
  if (entryCount == 0xffff || centralDirectorySize == 0xffffffff || centralDirectoryOffset == 0xffffffff) {
    throw _ArchiveInspectionLimitException(reason: 'This archive uses ZIP64 metadata.', archiveSizeBytes: archiveSizeBytes);
  }
  if (centralDirectoryOffset + centralDirectorySize > bytes.length) {
    throw _ArchiveInspectionLimitException(reason: 'The archive could not be inspected.', archiveSizeBytes: archiveSizeBytes);
  }

  final entries = <String, _ArchiveEntryInspectionData>{};
  final filePaths = <String>[];
  var expandedSizeBytes = 0;
  var offset = centralDirectoryOffset;
  final centralDirectoryEnd = centralDirectoryOffset + centralDirectorySize;

  for (var index = 0; index < entryCount && offset < centralDirectoryEnd; index++) {
    if (offset + 46 > bytes.length || _uint32(data, offset) != 0x02014b50) {
      throw _ArchiveInspectionLimitException(reason: 'The archive could not be inspected.', archiveSizeBytes: archiveSizeBytes);
    }

    final generalPurposeFlag = _uint16(data, offset + 8);
    final compressedSize = _uint32(data, offset + 20);
    final uncompressedSize = _uint32(data, offset + 24);
    final nameLength = _uint16(data, offset + 28);
    final extraLength = _uint16(data, offset + 30);
    final commentLength = _uint16(data, offset + 32);
    final externalAttributes = _uint32(data, offset + 38);
    final nameOffset = offset + 46;
    final nextOffset = nameOffset + nameLength + extraLength + commentLength;

    if (nextOffset > bytes.length || nextOffset > centralDirectoryEnd) {
      throw _ArchiveInspectionLimitException(reason: 'The archive could not be inspected.', archiveSizeBytes: archiveSizeBytes);
    }
    if ((generalPurposeFlag & 0x0001) != 0) {
      throw _ArchiveInspectionLimitException(
        reason: 'This archive contains encrypted files, which cannot be previewed.',
        archiveSizeBytes: archiveSizeBytes,
      );
    }
    if (compressedSize == 0xffffffff || uncompressedSize == 0xffffffff) {
      throw _ArchiveInspectionLimitException(reason: 'This archive uses ZIP64 metadata.', archiveSizeBytes: archiveSizeBytes);
    }

    final nameBytes = bytes.sublist(nameOffset, nameOffset + nameLength);
    final rawPath = (generalPurposeFlag & 0x0800) != 0 ? utf8.decode(nameBytes) : latin1.decode(nameBytes);
    final unixMode = (externalAttributes >> 16) & 0xf000;
    if (unixMode == 0xa000) {
      throw _ArchiveInspectionLimitException(
        reason: 'Archive contains symbolic links, which cannot be previewed safely.',
        archiveSizeBytes: archiveSizeBytes,
      );
    }

    final path = _normalizedArchiveEntryPath(rawPath, archiveSizeBytes: archiveSizeBytes);
    final folder = rawPath.replaceAll('\\', '/').endsWith('/') || unixMode == 0x4000;
    if (folder) {
      _putArchiveFolder(entries, path, archiveSizeBytes: archiveSizeBytes);
      offset = nextOffset;
      continue;
    }

    _addArchiveParentDirs(entries, path, archiveSizeBytes: archiveSizeBytes);
    entries[path] = _ArchiveEntryInspectionData(path: path, folder: false, sizeBytes: uncompressedSize);
    filePaths.add(path);
    expandedSizeBytes += uncompressedSize;
    offset = nextOffset;
  }

  final fileCount = filePaths.length;
  final folderCount = entries.values.where((entry) => entry.folder).length;
  final maxDepth = entries.keys.map((path) => path.split('/').length).fold<int>(0, math.max);
  final maxFileSize = entries.values.where((entry) => !entry.folder).map((entry) => entry.sizeBytes).fold<int>(0, math.max);
  final reasons = <String>[];
  if (expandedSizeBytes > PbArchiveExtractLimits.expandedMaxBytes) {
    reasons.add('expanded size');
  }
  if (fileCount > PbArchiveExtractLimits.fileCountMax) {
    reasons.add('file count');
  }
  if (folderCount > PbArchiveExtractLimits.folderCountMax) {
    reasons.add('folder count');
  }
  if (maxDepth > PbArchiveExtractLimits.folderDepthMax) {
    reasons.add('folder depth');
  }
  if (maxFileSize > PbArchiveExtractLimits.singleFileMaxBytes) {
    reasons.add('single file size');
  }

  final firstImage = filePaths.firstWhereOrNull(
    (path) =>
        _zipPreviewImageExtensions.contains(_extensionForPath(path)) &&
        entries[path]!.sizeBytes <= PbArchiveExtractLimits.autoPreviewImageMaxBytes,
  );
  final firstFile = filePaths.firstWhereOrNull((path) => entries[path]!.sizeBytes <= PbArchiveExtractLimits.singleFileMaxBytes);
  final sortedEntries = entries.values.toList()
    ..sort((left, right) {
      final depthResult = left.path.split('/').length.compareTo(right.path.split('/').length);
      if (depthResult != 0) {
        return depthResult;
      }
      if (left.folder != right.folder) {
        return left.folder ? -1 : 1;
      }
      return left.path.toLowerCase().compareTo(right.path.toLowerCase());
    });

  return PbArchiveInspectionResult(
    variant: reasons.isEmpty ? PbArchiveInspectionVariant.browsable : PbArchiveInspectionVariant.overLimit,
    targetFolderName: targetFolderName,
    archiveSizeBytes: archiveSizeBytes,
    expandedSizeBytes: expandedSizeBytes,
    fileCount: fileCount,
    folderCount: folderCount,
    maxDepth: maxDepth,
    firstPreviewPath: firstImage ?? firstFile,
    overLimitReason: reasons.isEmpty ? null : 'This archive exceeds the preview limits for ${reasons.join(', ')}.',
    entries: reasons.isEmpty
        ? sortedEntries
              .map((entry) => PbArchiveExtractEntry.fromPath(path: entry.path, sizeBytes: entry.sizeBytes, folder: entry.folder))
              .toList(growable: false)
        : const [],
  );
}

// Visible for tests.
List<PowerboardsZipExtractedFile> extractPowerboardsZipArchiveFilesForTesting(
  Uint8List bytes, {
  required PbArchiveInspectionResult inspection,
}) {
  if (!inspection.browsable) {
    throw StateError(inspection.overLimitReason ?? 'Archive cannot be extracted for preview.');
  }

  final allowedEntries = {for (final entry in inspection.entries.where((entry) => !entry.folder)) entry.path: entry};
  final extractedFiles = <PowerboardsZipExtractedFile>[];
  final seenPaths = <String>{};
  final decodedArchive = archive.ZipDecoder().decodeBytes(bytes);

  for (final archiveFile in decodedArchive) {
    final normalizedPath = _normalizedArchiveEntryPath(archiveFile.name, archiveSizeBytes: inspection.archiveSizeBytes);
    if (archiveFile.isDirectory) {
      continue;
    }
    if (archiveFile.isSymbolicLink) {
      throw StateError('Archive contains symbolic links, which cannot be previewed safely.');
    }

    final expectedEntry = allowedEntries[normalizedPath];
    if (expectedEntry == null) {
      throw StateError('Archive contents changed after inspection.');
    }

    final fileBytes = archiveFile.readBytes();
    if (fileBytes == null || fileBytes.length != expectedEntry.sizeBytes) {
      throw StateError('Archive contents changed after inspection.');
    }

    extractedFiles.add(PowerboardsZipExtractedFile(path: normalizedPath, bytes: fileBytes));
    seenPaths.add(normalizedPath);
  }

  if (seenPaths.length != allowedEntries.length || allowedEntries.keys.any((path) => !seenPaths.contains(path))) {
    throw StateError('Archive contents changed after inspection.');
  }

  return extractedFiles;
}

const Set<String> _zipPreviewImageExtensions = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.bmp'};

class PowerboardsZipExtractedFile {
  const PowerboardsZipExtractedFile({required this.path, required this.bytes});

  final String path;
  final Uint8List bytes;
}

class _LoadedZipArchive {
  const _LoadedZipArchive({required this.bytes, required this.archiveSizeBytes});

  final Uint8List bytes;
  final int archiveSizeBytes;
}

class _ArchiveEntryInspectionData {
  const _ArchiveEntryInspectionData({required this.path, required this.folder, required this.sizeBytes});

  final String path;
  final bool folder;
  final int sizeBytes;
}

class _ArchiveInspectionLimitException implements Exception {
  const _ArchiveInspectionLimitException({required this.reason, required this.archiveSizeBytes});

  final String reason;
  final int archiveSizeBytes;

  PbArchiveInspectionResult toInspectionResult({required String targetFolderName}) {
    return PbArchiveInspectionResult(
      variant: PbArchiveInspectionVariant.overLimit,
      targetFolderName: targetFolderName,
      archiveSizeBytes: archiveSizeBytes,
      expandedSizeBytes: 0,
      fileCount: 0,
      folderCount: 0,
      maxDepth: 0,
      overLimitReason: reason,
      entries: const [],
    );
  }
}

int? _findZipEndOfCentralDirectory(ByteData data) {
  if (data.lengthInBytes < 22) {
    return null;
  }

  final minimumOffset = math.max(0, data.lengthInBytes - 22 - 0xffff);
  for (var offset = data.lengthInBytes - 22; offset >= minimumOffset; offset--) {
    if (_uint32(data, offset) == 0x06054b50) {
      return offset;
    }
  }
  return null;
}

void _putArchiveFolder(Map<String, _ArchiveEntryInspectionData> entries, String path, {required int archiveSizeBytes}) {
  final existing = entries[path];
  if (existing != null && !existing.folder) {
    throw _ArchiveInspectionLimitException(
      reason: 'Archive contains a file and folder with the same path.',
      archiveSizeBytes: archiveSizeBytes,
    );
  }
  entries[path] = _ArchiveEntryInspectionData(path: path, folder: true, sizeBytes: 0);
}

void _addArchiveParentDirs(Map<String, _ArchiveEntryInspectionData> entries, String path, {required int archiveSizeBytes}) {
  final parts = path.split('/');
  for (var index = 0; index < parts.length - 1; index++) {
    _putArchiveFolder(entries, parts.take(index + 1).join('/'), archiveSizeBytes: archiveSizeBytes);
  }
}

String _normalizedArchiveEntryPath(String rawPath, {required int archiveSizeBytes}) {
  final path = rawPath.replaceAll('\\', '/').replaceAll(RegExp(r'^/+|/+$'), '');
  if (path.isEmpty || path == '.') {
    throw _ArchiveInspectionLimitException(reason: 'Archive contains an empty file path.', archiveSizeBytes: archiveSizeBytes);
  }
  if (rawPath.startsWith('/') || rawPath.startsWith('\\')) {
    throw _ArchiveInspectionLimitException(reason: 'Archive contains an absolute file path.', archiveSizeBytes: archiveSizeBytes);
  }
  if (rawPath.codeUnits.any((unit) => unit < 32)) {
    throw _ArchiveInspectionLimitException(
      reason: 'Archive contains a file path with control characters.',
      archiveSizeBytes: archiveSizeBytes,
    );
  }

  final normalizedParts = <String>[];
  for (final part in path.split('/')) {
    if (part.isEmpty || part == '.') {
      continue;
    }
    if (part == '..') {
      throw _ArchiveInspectionLimitException(
        reason: 'Archive contains a path that would leave the extract folder.',
        archiveSizeBytes: archiveSizeBytes,
      );
    }
    normalizedParts.add(part);
  }

  final normalized = normalizedParts.join('/');
  if (normalized.isEmpty) {
    throw _ArchiveInspectionLimitException(reason: 'Archive contains an empty file path.', archiveSizeBytes: archiveSizeBytes);
  }
  if (normalized.length > 512) {
    throw _ArchiveInspectionLimitException(
      reason: 'Archive contains a file path that is too long to preview safely.',
      archiveSizeBytes: archiveSizeBytes,
    );
  }
  return normalized;
}

String _extensionForPath(String path) {
  final name = path.split('/').last.toLowerCase();
  final index = name.lastIndexOf('.');
  return index <= 0 ? '' : name.substring(index);
}

int _uint16(ByteData data, int offset) => data.getUint16(offset, Endian.little);

int _uint32(ByteData data, int offset) => data.getUint32(offset, Endian.little);

const String _archiveToolScript = r'''
import json
import os
import posixpath
import shutil
import sys
import tarfile
import zipfile

ARCHIVE_MAX_BYTES = 100 * 1024 * 1024
EXPANDED_MAX_BYTES = 250 * 1024 * 1024
FILE_COUNT_MAX = 100
FOLDER_COUNT_MAX = 50
FOLDER_DEPTH_MAX = 6
AUTO_PREVIEW_IMAGE_MAX_BYTES = 12 * 1024 * 1024
SINGLE_FILE_MAX_BYTES = 25 * 1024 * 1024
IMAGE_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.bmp'}


def emit(payload):
    print(json.dumps(payload, separators=(',', ':')), flush=True)


def over_limit(reason, archive_size=0, expanded_size=0, file_count=0, folder_count=0, max_depth=0, entries=None):
    emit({
        'variant': 'overLimit',
        'target_folder_name': '',
        'archive_size_bytes': archive_size,
        'expanded_size_bytes': expanded_size,
        'file_count': file_count,
        'folder_count': folder_count,
        'max_depth': max_depth,
        'first_preview_path': None,
        'over_limit_reason': reason,
        'entries': entries or [],
    })


def normalized_entry_path(raw_path):
    if not isinstance(raw_path, str):
        raise ValueError('Archive contains an invalid file path.')
    path = raw_path.replace('\\', '/').strip('/')
    if not path or path == '.':
        raise ValueError('Archive contains an empty file path.')
    if raw_path.startswith('/') or raw_path.startswith('\\'):
        raise ValueError('Archive contains an absolute file path.')
    if any(ord(ch) < 32 for ch in raw_path):
        raise ValueError('Archive contains a file path with control characters.')
    normalized = posixpath.normpath(path)
    if normalized == '.' or normalized.startswith('../') or normalized == '..' or '/../' in f'/{normalized}/':
        raise ValueError('Archive contains a path that would leave the extract folder.')
    if len(normalized) > 512:
        raise ValueError('Archive contains a file path that is too long to preview safely.')
    return normalized


def archive_kind(archive_path):
    lower = archive_path.lower()
    if lower.endswith('.zip'):
        return 'zip'
    if lower.endswith('.tar.gz') or lower.endswith('.tgz'):
        return 'tar.gz'
    if lower.endswith('.tar'):
        return 'tar'
    raise ValueError('This archive format is not supported for extraction preview.')


def add_parent_dirs(entries, path):
    parts = path.split('/')[:-1]
    for index in range(len(parts)):
        folder_path = '/'.join(parts[:index + 1])
        existing = entries.get(folder_path)
        if existing is not None and not existing['folder']:
            raise ValueError('Archive contains a file and folder with the same path.')
        entries[folder_path] = {'path': folder_path, 'folder': True, 'size_bytes': 0}


def inspect_archive(archive_path):
    archive_size = os.path.getsize(archive_path)
    entries = {}
    file_paths = []
    expanded_size = 0
    kind = archive_kind(archive_path)

    if archive_size > ARCHIVE_MAX_BYTES:
        return {
            'variant': 'overLimit',
            'archive_size_bytes': archive_size,
            'expanded_size_bytes': 0,
            'file_count': 0,
            'folder_count': 0,
            'max_depth': 0,
            'first_preview_path': None,
            'over_limit_reason': 'This archive is larger than the 100 MB preview limit.',
            'entries': [],
        }

    if kind == 'zip':
        with zipfile.ZipFile(archive_path) as archive:
            members = archive.infolist()
            for member in members:
                unix_mode = (member.external_attr >> 16) & 0o170000
                if unix_mode == 0o120000:
                    raise ValueError('Archive contains symbolic links, which cannot be previewed safely.')
                path = normalized_entry_path(member.filename)
                if member.is_dir():
                    entries[path] = {'path': path, 'folder': True, 'size_bytes': 0}
                    continue
                add_parent_dirs(entries, path)
                size = int(member.file_size)
                entries[path] = {'path': path, 'folder': False, 'size_bytes': size}
                file_paths.append(path)
                expanded_size += size
    else:
        mode = 'r:gz' if kind == 'tar.gz' else 'r:'
        with tarfile.open(archive_path, mode) as archive:
            members = archive.getmembers()
            for member in members:
                path = normalized_entry_path(member.name)
                if member.isdir():
                    entries[path] = {'path': path, 'folder': True, 'size_bytes': 0}
                    continue
                if not member.isfile():
                    raise ValueError('Archive contains links or special files, which cannot be previewed safely.')
                add_parent_dirs(entries, path)
                size = int(member.size)
                entries[path] = {'path': path, 'folder': False, 'size_bytes': size}
                file_paths.append(path)
                expanded_size += size

    file_count = len(file_paths)
    folder_count = sum(1 for entry in entries.values() if entry['folder'])
    max_depth = max((len(path.split('/')) for path in entries), default=0)
    max_file_size = max((entry['size_bytes'] for entry in entries.values() if not entry['folder']), default=0)
    reasons = []
    if expanded_size > EXPANDED_MAX_BYTES:
        reasons.append('expanded size')
    if file_count > FILE_COUNT_MAX:
        reasons.append('file count')
    if folder_count > FOLDER_COUNT_MAX:
        reasons.append('folder count')
    if max_depth > FOLDER_DEPTH_MAX:
        reasons.append('folder depth')
    if max_file_size > SINGLE_FILE_MAX_BYTES:
        reasons.append('single file size')

    sorted_entries = sorted(entries.values(), key=lambda entry: (entry['path'].count('/'), not entry['folder'], entry['path'].lower()))
    first_image = next((
        path for path in file_paths
        if os.path.splitext(path)[1].lower() in IMAGE_EXTENSIONS and entries[path]['size_bytes'] <= AUTO_PREVIEW_IMAGE_MAX_BYTES
    ), None)
    first_file = next((path for path in file_paths if entries[path]['size_bytes'] <= SINGLE_FILE_MAX_BYTES), None)

    return {
        'variant': 'overLimit' if reasons else 'browsable',
        'archive_size_bytes': archive_size,
        'expanded_size_bytes': expanded_size,
        'file_count': file_count,
        'folder_count': folder_count,
        'max_depth': max_depth,
        'first_preview_path': first_image or first_file,
        'over_limit_reason': 'This archive exceeds the preview limits for ' + ', '.join(reasons) + '.' if reasons else None,
        'entries': [] if reasons else sorted_entries,
    }


def copy_zip(archive_path, target_path, allowed_paths):
    with zipfile.ZipFile(archive_path) as archive:
        for member in archive.infolist():
            path = normalized_entry_path(member.filename)
            if member.is_dir():
                os.makedirs(os.path.join(target_path, *path.split('/')), exist_ok=True)
                continue
            if path not in allowed_paths:
                continue
            destination = os.path.join(target_path, *path.split('/'))
            os.makedirs(os.path.dirname(destination), exist_ok=True)
            with archive.open(member) as source, open(destination, 'wb') as target:
                shutil.copyfileobj(source, target)


def copy_tar(archive_path, target_path, mode, allowed_paths):
    with tarfile.open(archive_path, mode) as archive:
        for member in archive.getmembers():
            path = normalized_entry_path(member.name)
            if member.isdir():
                os.makedirs(os.path.join(target_path, *path.split('/')), exist_ok=True)
                continue
            if not member.isfile() or path not in allowed_paths:
                continue
            destination = os.path.join(target_path, *path.split('/'))
            os.makedirs(os.path.dirname(destination), exist_ok=True)
            source = archive.extractfile(member)
            if source is None:
                continue
            with source, open(destination, 'wb') as target:
                shutil.copyfileobj(source, target)


def main():
    mode = sys.argv[1]
    archive_path = sys.argv[2]
    target_path = sys.argv[3] if len(sys.argv) > 3 else None
    try:
        result = inspect_archive(archive_path)
        result['target_folder_name'] = os.path.basename(target_path or '')
        if mode == 'extract':
            if result['variant'] != 'browsable':
                emit(result)
                return 2
            if target_path is None:
                raise ValueError('No extract folder was provided.')
            if os.path.exists(target_path):
                if not os.path.isdir(target_path):
                    raise ValueError('The extract folder already exists.')
            else:
                os.makedirs(target_path, exist_ok=False)
            allowed_paths = {entry['path'] for entry in result['entries'] if not entry['folder']}
            kind = archive_kind(archive_path)
            if kind == 'zip':
                copy_zip(archive_path, target_path, allowed_paths)
            elif kind == 'tar.gz':
                copy_tar(archive_path, target_path, 'r:gz', allowed_paths)
            else:
                copy_tar(archive_path, target_path, 'r:', allowed_paths)
        emit(result)
        return 0
    except Exception as exc:
        archive_size = os.path.getsize(archive_path) if os.path.exists(archive_path) else 0
        over_limit(str(exc), archive_size=archive_size)
        return 1


sys.exit(main())
''';
