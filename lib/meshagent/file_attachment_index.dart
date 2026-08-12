import 'dart:convert';
import 'dart:typed_data';

import 'package:meshagent/datasets_client.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:path/path.dart' as p;

import 'thread_display_name.dart';

const String powerboardsFileAttachmentIndexPath = '.powerboards/file-attachment-index.json';
Future<void> _powerboardsFileAttachmentLinkWriteQueue = Future<void>.value();
final PowerboardsThreadAttachmentReconcileQueue _powerboardsThreadAttachmentReconcileQueue = PowerboardsThreadAttachmentReconcileQueue();

class PowerboardsThreadAttachmentReconcileQueue {
  Future<void> _pending = Future<void>.value();

  Future<void> run(Future<void> Function() reconcile) {
    final operation = _pending.catchError((_) {}).then((_) => reconcile());
    _pending = operation.catchError((_) {});
    return operation;
  }
}

class PowerboardsFileAttachmentLink {
  const PowerboardsFileAttachmentLink({
    required this.filePath,
    required this.threadPath,
    required this.threadName,
    required this.createdBy,
    required this.createdAt,
    this.inheritedFromCopy,
  });

  factory PowerboardsFileAttachmentLink.fromJson(Map<String, dynamic> json) {
    final filePath = json['file_path'];
    final threadPath = json['thread_path'];
    final threadName = json['thread_name'];
    final createdBy = json['created_by'];
    final createdAt = json['created_at'];
    final inheritedFromCopy = json['inherited_from_copy'];

    return PowerboardsFileAttachmentLink(
      filePath: filePath is String ? normalizePowerboardsAttachmentPath(filePath) : '',
      threadPath: threadPath is String ? normalizePowerboardsThreadAttachmentPath(threadPath) : '',
      threadName: threadName is String ? threadName.trim() : '',
      createdBy: createdBy is String ? createdBy.trim() : '',
      createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
      inheritedFromCopy: inheritedFromCopy is bool ? inheritedFromCopy : null,
    );
  }

  final String filePath;
  final String threadPath;
  final String threadName;
  final String createdBy;
  final DateTime? createdAt;
  final bool? inheritedFromCopy;

  PowerboardsFileAttachmentLink copyWith({String? filePath, bool? inheritedFromCopy}) {
    return PowerboardsFileAttachmentLink(
      filePath: filePath ?? this.filePath,
      threadPath: threadPath,
      threadName: threadName,
      createdBy: createdBy,
      createdAt: createdAt,
      inheritedFromCopy: inheritedFromCopy ?? this.inheritedFromCopy,
    );
  }

  String get threadDisplayName {
    if (threadName.trim().isNotEmpty) {
      return threadName.trim();
    }
    return defaultThreadDisplayNameFromPath(threadPath);
  }

  Map<String, dynamic> toJson() {
    return {
      'file_path': filePath,
      'thread_path': threadPath,
      'thread_name': threadName,
      'created_by': createdBy,
      'created_at': createdAt?.toUtc().toIso8601String(),
      if (inheritedFromCopy != null) 'inherited_from_copy': inheritedFromCopy,
    };
  }
}

String normalizePowerboardsAttachmentPath(String path) {
  return path.trim().split('/').where((segment) => segment.isNotEmpty).join('/');
}

String powerboardsStorageAttachmentPathFromUrl(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty || trimmed.startsWith('data:')) {
    return '';
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.scheme.isNotEmpty) {
    if (uri.scheme != 'room') {
      return '';
    }

    final segments = [
      if (uri.host.trim().isNotEmpty) uri.host.trim(),
      ...uri.pathSegments.map((segment) => segment.trim()).where((segment) => segment.isNotEmpty),
    ];
    final roomPath = normalizePowerboardsAttachmentPath(segments.join('/'));
    return roomPath.isEmpty ? '' : roomPath;
  }

  if (!isPowerboardsStorageAttachmentPath(trimmed)) {
    return '';
  }
  return normalizePowerboardsAttachmentPath(trimmed);
}

String normalizePowerboardsThreadAttachmentPath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  if (trimmed.contains('://')) {
    return trimmed;
  }

  return normalizePowerboardsAttachmentPath(trimmed);
}

String powerboardsThreadAttachmentMatchKey(String path) {
  final normalizedThreadPath = normalizePowerboardsThreadAttachmentPath(path);
  if (normalizedThreadPath.isEmpty) {
    return '';
  }

  return normalizePowerboardsAttachmentPath(normalizedThreadPath);
}

bool isPowerboardsStorageAttachmentPath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (trimmed.startsWith('data:')) {
    return false;
  }
  if (trimmed.contains('://')) {
    return false;
  }
  return true;
}

Future<List<PowerboardsFileAttachmentLink>> loadPowerboardsFileAttachmentLinks(RoomClient room) async {
  try {
    final content = await room.storage.download(powerboardsFileAttachmentIndexPath);
    final decoded = jsonDecode(utf8.decode(content.data));
    if (decoded is! Map<String, dynamic>) {
      return const <PowerboardsFileAttachmentLink>[];
    }

    final rawLinks = decoded['links'];
    if (rawLinks is! List) {
      return const <PowerboardsFileAttachmentLink>[];
    }

    return rawLinks
        .whereType<Map>()
        .map((raw) => PowerboardsFileAttachmentLink.fromJson(Map<String, dynamic>.from(raw)))
        .where((link) => link.filePath.isNotEmpty && link.threadPath.isNotEmpty)
        .toList(growable: false);
  } catch (_) {
    return const <PowerboardsFileAttachmentLink>[];
  }
}

Future<void> recordPowerboardsFileAttachmentLinks({
  required RoomClient room,
  required String threadPath,
  required String threadName,
  required String createdBy,
  required Iterable<String> attachmentPaths,
}) async {
  final operation = _powerboardsFileAttachmentLinkWriteQueue
      .catchError((_) {})
      .then(
        (_) => _recordPowerboardsFileAttachmentLinks(
          room: room,
          threadPath: threadPath,
          threadName: threadName,
          createdBy: createdBy,
          attachmentPaths: attachmentPaths,
        ),
      );
  _powerboardsFileAttachmentLinkWriteQueue = operation.catchError((_) {});
  await operation;
}

Future<void> registerPowerboardsFileAttachmentTransfer({
  required RoomClient sourceRoom,
  required RoomClient destinationRoom,
  required String sourcePath,
  required String destinationPath,
  required bool folder,
  required bool move,
}) async {
  final operation = _powerboardsFileAttachmentLinkWriteQueue
      .catchError((_) {})
      .then(
        (_) => _registerPowerboardsFileAttachmentTransfer(
          sourceRoom: sourceRoom,
          destinationRoom: destinationRoom,
          sourcePath: sourcePath,
          destinationPath: destinationPath,
          folder: folder,
          move: move,
        ),
      );
  _powerboardsFileAttachmentLinkWriteQueue = operation.catchError((_) {});
  await operation;
}

Future<void> _registerPowerboardsFileAttachmentTransfer({
  required RoomClient sourceRoom,
  required RoomClient destinationRoom,
  required String sourcePath,
  required String destinationPath,
  required bool folder,
  required bool move,
}) async {
  final normalizedSourcePath = normalizePowerboardsAttachmentPath(sourcePath);
  final normalizedDestinationPath = normalizePowerboardsAttachmentPath(destinationPath);
  if (normalizedSourcePath.isEmpty || normalizedDestinationPath.isEmpty) {
    return;
  }

  final sourceLinks = await loadPowerboardsFileAttachmentLinks(sourceRoom);
  final transferredLinks = sourceLinks
      .where((link) => _powerboardsAttachmentPathIsTransferred(link.filePath, normalizedSourcePath, folder: folder))
      .map(
        (link) => link.copyWith(
          filePath: powerboardsTransferredAttachmentPath(
            path: link.filePath,
            sourcePath: normalizedSourcePath,
            destinationPath: normalizedDestinationPath,
            folder: folder,
          ),
          inheritedFromCopy: move ? link.inheritedFromCopy : true,
        ),
      )
      .toList(growable: false);
  if (transferredLinks.isEmpty) {
    return;
  }

  if (identical(sourceRoom, destinationRoom)) {
    final nextLinks = move
        ? sourceLinks
              .map(
                (link) => _powerboardsAttachmentPathIsTransferred(link.filePath, normalizedSourcePath, folder: folder)
                    ? link.copyWith(
                        filePath: powerboardsTransferredAttachmentPath(
                          path: link.filePath,
                          sourcePath: normalizedSourcePath,
                          destinationPath: normalizedDestinationPath,
                          folder: folder,
                        ),
                      )
                    : link,
              )
              .toList(growable: false)
        : powerboardsFileAttachmentLinksAfterSameRoomTransfer(
            links: sourceLinks,
            sourcePath: normalizedSourcePath,
            destinationPath: normalizedDestinationPath,
            folder: folder,
            move: false,
          );
    Object? rowRewriteError;
    StackTrace? rowRewriteStackTrace;
    if (move) {
      try {
        await _rewritePowerboardsThreadAttachmentRows(
          room: sourceRoom,
          threadPaths: transferredLinks.map((link) => link.threadPath),
          sourcePath: normalizedSourcePath,
          destinationPath: normalizedDestinationPath,
          folder: folder,
        );
      } catch (error, stackTrace) {
        rowRewriteError = error;
        rowRewriteStackTrace = stackTrace;
      }
    }
    await _writePowerboardsFileAttachmentLinks(sourceRoom, nextLinks);
    if (rowRewriteError != null) {
      Error.throwWithStackTrace(rowRewriteError, rowRewriteStackTrace!);
    }
    return;
  }

  final destinationLinks = await loadPowerboardsFileAttachmentLinks(destinationRoom);
  await _writePowerboardsFileAttachmentLinks(destinationRoom, <PowerboardsFileAttachmentLink>[...destinationLinks, ...transferredLinks]);
}

Future<void> _rewritePowerboardsThreadAttachmentRows({
  required RoomClient room,
  required Iterable<String> threadPaths,
  required String sourcePath,
  required String destinationPath,
  required bool folder,
}) async {
  await reconcilePowerboardsThreadAttachmentPaths(
    threadPaths: threadPaths,
    reconcileThreadPath: (threadPath) => reconcilePowerboardsThreadAttachmentRows(
      room: room,
      threadPath: threadPath,
      resolvePath: (path) {
        if (!_powerboardsAttachmentPathIsTransferred(path, sourcePath, folder: folder)) {
          return path;
        }
        return powerboardsTransferredAttachmentPath(path: path, sourcePath: sourcePath, destinationPath: destinationPath, folder: folder);
      },
    ),
  );
}

Future<void> reconcilePowerboardsThreadAttachmentPaths({
  required Iterable<String> threadPaths,
  required Future<void> Function(String threadPath) reconcileThreadPath,
}) async {
  final uniqueThreadPaths = threadPaths.map(normalizePowerboardsThreadAttachmentPath).where((path) => path.isNotEmpty).toSet();
  for (final threadPath in uniqueThreadPaths) {
    try {
      await reconcileThreadPath(threadPath);
    } catch (error) {
      if (powerboardsIsMissingThreadAttachmentTableError(error)) {
        continue;
      }
      rethrow;
    }
  }
}

bool powerboardsIsMissingThreadAttachmentTableError(Object error) {
  if (error is! RoomServerException) {
    return false;
  }
  final status = error.statusCode ?? error.code;
  if (status == 404) {
    return true;
  }
  final message = error.message.toLowerCase();
  return message.contains('table') &&
      (message.contains('not found') || message.contains('does not exist') || message.contains('no such table'));
}

Future<void> reconcilePowerboardsThreadAttachmentRows({
  required RoomClient room,
  required String threadPath,
  required String Function(String path) resolvePath,
}) {
  return _powerboardsThreadAttachmentReconcileQueue.run(
    () => _reconcilePowerboardsThreadAttachmentRows(room: room, threadPath: threadPath, resolvePath: resolvePath),
  );
}

Future<void> _reconcilePowerboardsThreadAttachmentRows({
  required RoomClient room,
  required String threadPath,
  required String Function(String path) resolvePath,
}) async {
  final thread = _powerboardsThreadDatasetRef(threadPath);
  if (thread == null) {
    return;
  }

  final batches = await room.datasets.search(table: thread.table, namespace: thread.namespace);
  for (final batch in batches) {
    for (final row in batch.toRows()) {
      final itemId = row['item_id']?.toString().trim() ?? '';
      final data = _powerboardsThreadRowData(row['data']);
      if (itemId.isEmpty || data == null) {
        continue;
      }
      final rewrittenData = powerboardsRewriteThreadAttachmentDataWithResolver(data: data, resolvePath: resolvePath);
      if (rewrittenData == null) {
        continue;
      }
      await room.datasets.update(
        table: thread.table,
        namespace: thread.namespace,
        where: "item_id = '${itemId.replaceAll("'", "''")}'",
        values: powerboardsThreadAttachmentDatasetUpdateValues(rewrittenData),
      );
    }
  }
}

DatasetRecord powerboardsThreadAttachmentDatasetUpdateValues(Map<String, dynamic> data) {
  return <String, Object?>{'data': DatasetJson(data)};
}

({List<String>? namespace, String table})? _powerboardsThreadDatasetRef(String threadPath) {
  var path = threadPath.trim();
  if (path.startsWith('dataset://')) {
    path = path.substring('dataset://'.length);
  } else if (path.startsWith('dataset:/')) {
    path = path.substring('dataset:/'.length);
  } else {
    return null;
  }
  final parts = path.split('/').map((part) => part.trim()).where((part) => part.isNotEmpty).toList(growable: false);
  if (parts.isEmpty) {
    return null;
  }
  return (namespace: parts.length == 1 ? null : parts.sublist(0, parts.length - 1), table: parts.last);
}

Map<String, dynamic>? _powerboardsThreadRowData(Object? raw) {
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      return null;
    }
  }
  return null;
}

Map<String, dynamic>? powerboardsRewriteThreadAttachmentData({
  required Map<String, dynamic> data,
  required String sourcePath,
  required String destinationPath,
  required bool folder,
}) {
  final normalizedSourcePath = normalizePowerboardsAttachmentPath(sourcePath);
  final normalizedDestinationPath = normalizePowerboardsAttachmentPath(destinationPath);
  if (normalizedSourcePath.isEmpty || normalizedDestinationPath.isEmpty) {
    return null;
  }

  return powerboardsRewriteThreadAttachmentDataWithResolver(
    data: data,
    resolvePath: (path) {
      if (!_powerboardsAttachmentPathIsTransferred(path, normalizedSourcePath, folder: folder)) {
        return path;
      }
      return powerboardsTransferredAttachmentPath(
        path: path,
        sourcePath: normalizedSourcePath,
        destinationPath: normalizedDestinationPath,
        folder: folder,
      );
    },
  );
}

Map<String, dynamic>? powerboardsRewriteThreadAttachmentDataWithResolver({
  required Map<String, dynamic> data,
  required String Function(String path) resolvePath,
}) {
  final rewritten = _rewritePowerboardsThreadAttachmentValue(data, resolvePath: resolvePath);
  return rewritten.changed ? Map<String, dynamic>.from(rewritten.value as Map) : null;
}

({Object? value, bool changed}) _rewritePowerboardsThreadAttachmentValue(
  Object? value, {
  required String Function(String path) resolvePath,
  bool attachmentEntry = false,
}) {
  if (value is List) {
    var changed = false;
    final rewritten = <Object?>[];
    for (final item in value) {
      final result = _rewritePowerboardsThreadAttachmentValue(item, resolvePath: resolvePath, attachmentEntry: attachmentEntry);
      rewritten.add(result.value);
      changed = changed || result.changed;
    }
    return (value: changed ? rewritten : value, changed: changed);
  }
  if (value is! Map) {
    return (value: value, changed: false);
  }

  final map = Map<String, dynamic>.from(value);
  var changed = false;
  final isFileContent = map['type'] == 'file';
  if ((attachmentEntry || isFileContent) && map['url'] is String) {
    final originalUrl = map['url'] as String;
    final originalPath = powerboardsStorageAttachmentPathFromUrl(originalUrl);
    final rewrittenPath = originalPath.isEmpty ? originalPath : normalizePowerboardsAttachmentPath(resolvePath(originalPath));
    if (rewrittenPath.isNotEmpty && rewrittenPath != originalPath) {
      map['url'] = _powerboardsTransferredAttachmentUrl(originalUrl, rewrittenPath);
      map['name'] = p.posix.basename(rewrittenPath);
      changed = true;
    }
  }

  for (final entry in map.entries.toList(growable: false)) {
    final result = _rewritePowerboardsThreadAttachmentValue(
      entry.value,
      resolvePath: resolvePath,
      attachmentEntry: entry.key == 'attachments',
    );
    if (result.changed) {
      map[entry.key] = result.value;
      changed = true;
    }
  }
  return (value: changed ? map : value, changed: changed);
}

String _powerboardsTransferredAttachmentUrl(String originalUrl, String destinationPath) {
  if (!originalUrl.trim().startsWith('room:')) {
    return destinationPath;
  }
  final encodedPath = destinationPath.split('/').map(Uri.encodeComponent).join('/');
  return 'room:///$encodedPath';
}

List<PowerboardsFileAttachmentLink> powerboardsFileAttachmentLinksAfterSameRoomTransfer({
  required Iterable<PowerboardsFileAttachmentLink> links,
  required String sourcePath,
  required String destinationPath,
  required bool folder,
  required bool move,
}) {
  final existing = links.toList(growable: false);
  if (move) {
    return existing;
  }

  final normalizedSourcePath = normalizePowerboardsAttachmentPath(sourcePath);
  final normalizedDestinationPath = normalizePowerboardsAttachmentPath(destinationPath);
  if (normalizedSourcePath.isEmpty || normalizedDestinationPath.isEmpty) {
    return existing;
  }
  return <PowerboardsFileAttachmentLink>[
    ...existing,
    for (final link in existing)
      if (_powerboardsAttachmentPathIsTransferred(link.filePath, normalizedSourcePath, folder: folder))
        link.copyWith(
          filePath: powerboardsTransferredAttachmentPath(
            path: link.filePath,
            sourcePath: normalizedSourcePath,
            destinationPath: normalizedDestinationPath,
            folder: folder,
          ),
          inheritedFromCopy: true,
        ),
  ];
}

bool _powerboardsAttachmentPathIsTransferred(String path, String sourcePath, {required bool folder}) {
  final normalizedPath = normalizePowerboardsAttachmentPath(path);
  return normalizedPath == sourcePath || (folder && normalizedPath.startsWith('$sourcePath/'));
}

String powerboardsTransferredAttachmentPath({
  required String path,
  required String sourcePath,
  required String destinationPath,
  required bool folder,
}) {
  final normalizedPath = normalizePowerboardsAttachmentPath(path);
  final normalizedSourcePath = normalizePowerboardsAttachmentPath(sourcePath);
  final normalizedDestinationPath = normalizePowerboardsAttachmentPath(destinationPath);
  if (normalizedPath == normalizedSourcePath) {
    return normalizedDestinationPath;
  }
  if (!folder || !normalizedPath.startsWith('$normalizedSourcePath/')) {
    return normalizedPath;
  }
  return '$normalizedDestinationPath/${normalizedPath.substring(normalizedSourcePath.length + 1)}';
}

Future<void> _recordPowerboardsFileAttachmentLinks({
  required RoomClient room,
  required String threadPath,
  required String threadName,
  required String createdBy,
  required Iterable<String> attachmentPaths,
}) async {
  final normalizedThreadPath = normalizePowerboardsThreadAttachmentPath(threadPath);
  if (normalizedThreadPath.isEmpty) {
    return;
  }

  final normalizedAttachments = attachmentPaths.map(powerboardsStorageAttachmentPathFromUrl).where((path) => path.isNotEmpty).toSet();
  if (normalizedAttachments.isEmpty) {
    return;
  }

  final now = DateTime.now().toUtc();
  final existing = await loadPowerboardsFileAttachmentLinks(room);
  final linksByKey = <String, PowerboardsFileAttachmentLink>{
    for (final link in existing) '${link.filePath}\n${powerboardsThreadAttachmentMatchKey(link.threadPath)}': link,
  };

  for (final filePath in normalizedAttachments) {
    final key = '$filePath\n${powerboardsThreadAttachmentMatchKey(normalizedThreadPath)}';
    final existing = linksByKey[key];
    final normalizedCreatedBy = createdBy.trim();

    linksByKey[key] = PowerboardsFileAttachmentLink(
      filePath: filePath,
      threadPath: normalizedThreadPath,
      threadName: threadName.trim().isNotEmpty ? threadName.trim() : existing?.threadName ?? '',
      createdBy: normalizedCreatedBy.isNotEmpty ? normalizedCreatedBy : existing?.createdBy ?? '',
      createdAt: existing?.createdAt ?? now,
      inheritedFromCopy: false,
    );
  }

  await _writePowerboardsFileAttachmentLinks(room, linksByKey.values);
}

Future<void> _writePowerboardsFileAttachmentLinks(RoomClient room, Iterable<PowerboardsFileAttachmentLink> candidateLinks) async {
  final linksByKey = <String, PowerboardsFileAttachmentLink>{};
  for (final link in candidateLinks) {
    final filePath = normalizePowerboardsAttachmentPath(link.filePath);
    final threadPath = normalizePowerboardsThreadAttachmentPath(link.threadPath);
    if (filePath.isEmpty || threadPath.isEmpty) {
      continue;
    }
    linksByKey['$filePath\n${powerboardsThreadAttachmentMatchKey(threadPath)}'] = link.copyWith(filePath: filePath);
  }

  final links = linksByKey.values.toList()
    ..sort((left, right) {
      final rightCreatedAt = right.createdAt?.millisecondsSinceEpoch ?? 0;
      final leftCreatedAt = left.createdAt?.millisecondsSinceEpoch ?? 0;
      return rightCreatedAt.compareTo(leftCreatedAt);
    });
  final cappedLinks = links.take(500).toList(growable: false);
  final data = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'version': 1,
        'links': [for (final link in cappedLinks) link.toJson()],
      }),
    ),
  );

  await room.storage.uploadStream(
    powerboardsFileAttachmentIndexPath,
    Stream<Uint8List>.value(data),
    overwrite: true,
    size: data.length,
    mimeType: 'application/json',
  );
}
