import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:path/path.dart' as p;

const String _folderPlaceholderName = '.placeholder';

String powerboardsNormalizeStoragePath(String path) {
  final trimmed = path.trim().replaceAll(RegExp(r'^/+|/+$'), '');
  if (trimmed.isEmpty) {
    return '';
  }

  final normalized = p.posix.normalize(trimmed);
  return normalized == '.' ? '' : normalized;
}

bool powerboardsV1CanUseMoveDestination({
  required String sourceRoom,
  required String destinationRoom,
  required String initialPath,
  required String destinationPath,
  Iterable<String> sourceFolderPaths = const <String>[],
}) {
  if (sourceRoom != destinationRoom) {
    return true;
  }

  final normalizedInitialPath = powerboardsNormalizeStoragePath(initialPath);
  final normalizedDestinationPath = powerboardsNormalizeStoragePath(
    destinationPath,
  );
  if (normalizedDestinationPath == normalizedInitialPath) {
    return false;
  }

  for (final sourceFolderPath in sourceFolderPaths) {
    final normalizedSourceFolder = powerboardsNormalizeStoragePath(
      sourceFolderPath,
    );
    if (normalizedSourceFolder.isEmpty) {
      continue;
    }
    if (normalizedDestinationPath == normalizedSourceFolder ||
        normalizedDestinationPath.startsWith('$normalizedSourceFolder/')) {
      return false;
    }
  }

  return true;
}

bool powerboardsV1ShouldConfirmCrossRoomLinkedMove({
  required String sourceRoom,
  required String destinationRoom,
  required bool copyFilesInstead,
  required bool containsLinkedAttachments,
}) {
  return !copyFilesInstead && containsLinkedAttachments && sourceRoom.trim().toLowerCase() != destinationRoom.trim().toLowerCase();
}

@visibleForTesting
String powerboardsV1ConflictCopyName(
  String originalName, {
  required bool folder,
  required int copyNumber,
}) {
  assert(copyNumber > 0);
  final prefix = copyNumber == 1 ? 'Copy of ' : 'Copy $copyNumber of ';
  if (folder) {
    return '$prefix$originalName';
  }

  final dotIndex = originalName.lastIndexOf('.');
  final hasExtension = dotIndex > 0;
  final stem = hasExtension
      ? originalName.substring(0, dotIndex)
      : originalName;
  final extension = hasExtension ? originalName.substring(dotIndex) : '';
  return '$prefix$stem$extension';
}

Future<String> powerboardsResolveStorageDestinationPath({
  required StorageClient storage,
  required String destinationFolder,
  required String sourcePath,
  required bool folder,
}) async {
  final sourceName = p.posix.basename(
    powerboardsNormalizeStoragePath(sourcePath),
  );
  var copyNumber = 0;

  while (true) {
    final candidateName = copyNumber == 0
        ? sourceName
        : powerboardsV1ConflictCopyName(
            sourceName,
            folder: folder,
            copyNumber: copyNumber,
          );
    final candidatePath = _joinStoragePath(destinationFolder, candidateName);
    if (!await storage.exists(candidatePath)) {
      return candidatePath;
    }
    copyNumber += 1;
  }
}

Future<String> powerboardsTransferStoragePath({
  required StorageClient sourceStorage,
  required StorageClient destinationStorage,
  required String sourcePath,
  required String destinationFolder,
  required bool folder,
  required bool move,
}) async {
  final destinationPath = await powerboardsResolveStorageDestinationPath(
    storage: destinationStorage,
    destinationFolder: destinationFolder,
    sourcePath: sourcePath,
    folder: folder,
  );

  if (move && identical(sourceStorage, destinationStorage)) {
    await sourceStorage.move(sourcePath, destinationPath, overwrite: false);
    return destinationPath;
  }

  var copied = false;
  try {
    await _copyStoragePath(
      sourceStorage: sourceStorage,
      destinationStorage: destinationStorage,
      sourcePath: sourcePath,
      destinationPath: destinationPath,
      folder: folder,
    );
    copied = true;

    if (move) {
      await sourceStorage.delete(sourcePath, recursive: folder ? true : null);
    }
  } catch (_) {
    if (!copied) {
      await _deletePartialCopy(
        destinationStorage,
        destinationPath,
        folder: folder,
      );
    }
    rethrow;
  }

  return destinationPath;
}

Future<void> _copyStoragePath({
  required StorageClient sourceStorage,
  required StorageClient destinationStorage,
  required String sourcePath,
  required String destinationPath,
  required bool folder,
}) async {
  if (!folder) {
    await _copyStorageFile(
      sourceStorage: sourceStorage,
      destinationStorage: destinationStorage,
      sourcePath: sourcePath,
      destinationPath: destinationPath,
    );
    return;
  }

  final entries = await sourceStorage.list(sourcePath);
  if (entries.isEmpty) {
    await destinationStorage.uploadStream(
      _joinStoragePath(destinationPath, _folderPlaceholderName),
      const Stream<Uint8List>.empty(),
      overwrite: false,
      size: 0,
    );
    return;
  }

  for (final entry in entries) {
    await _copyStoragePath(
      sourceStorage: sourceStorage,
      destinationStorage: destinationStorage,
      sourcePath: _joinStoragePath(sourcePath, entry.name),
      destinationPath: _joinStoragePath(destinationPath, entry.name),
      folder: entry.isFolder,
    );
  }
}

Future<void> _copyStorageFile({
  required StorageClient sourceStorage,
  required StorageClient destinationStorage,
  required String sourcePath,
  required String destinationPath,
}) async {
  final iterator = StreamIterator<BinaryContent>(
    await sourceStorage.downloadStream(sourcePath),
  );
  try {
    if (!await iterator.moveNext()) {
      throw StateError('The source file did not provide download metadata.');
    }

    final metadata = iterator.current;
    if (metadata.headers['kind'] != 'start') {
      throw StateError('The source file provided invalid download metadata.');
    }

    final size = metadata.headers['size'];
    final name = metadata.headers['name'];
    final mimeType = metadata.headers['mime_type'];
    if (size is! int || size < 0 || name is! String || mimeType is! String) {
      throw StateError(
        'The source file provided incomplete download metadata.',
      );
    }

    Stream<Uint8List> chunks() async* {
      while (await iterator.moveNext()) {
        final chunk = iterator.current;
        if (chunk.headers['kind'] != 'data') {
          throw StateError(
            'The source file provided an invalid download chunk.',
          );
        }
        yield chunk.data;
      }
    }

    await destinationStorage.uploadStream(
      destinationPath,
      chunks(),
      overwrite: false,
      size: size,
      name: p.posix.basename(destinationPath),
      mimeType: mimeType,
    );
  } finally {
    await iterator.cancel();
  }
}

Future<void> _deletePartialCopy(
  StorageClient storage,
  String path, {
  required bool folder,
}) async {
  try {
    if (await storage.exists(path)) {
      await storage.delete(path, recursive: folder ? true : null);
    }
  } catch (_) {}
}

String _joinStoragePath(String parent, String child) {
  final normalizedParent = powerboardsNormalizeStoragePath(parent);
  final normalizedChild = powerboardsNormalizeStoragePath(child);
  if (normalizedParent.isEmpty) {
    return normalizedChild;
  }
  if (normalizedChild.isEmpty) {
    return normalizedParent;
  }
  return '$normalizedParent/$normalizedChild';
}
