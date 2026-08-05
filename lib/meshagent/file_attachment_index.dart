import 'dart:convert';
import 'dart:typed_data';

import 'package:meshagent/room_server_client.dart';

import 'thread_display_name.dart';

const String powerboardsFileAttachmentIndexPath = '.powerboards/file-attachment-index.json';
Future<void> _powerboardsFileAttachmentLinkWriteQueue = Future<void>.value();

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
  if (identical(sourceRoom, destinationRoom)) {
    if (move) {
      return;
    }
    await _writePowerboardsFileAttachmentLinks(
      sourceRoom,
      powerboardsFileAttachmentLinksAfterSameRoomTransfer(
        links: sourceLinks,
        sourcePath: normalizedSourcePath,
        destinationPath: normalizedDestinationPath,
        folder: folder,
        move: false,
      ),
    );
    return;
  }

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

  final destinationLinks = await loadPowerboardsFileAttachmentLinks(destinationRoom);
  await _writePowerboardsFileAttachmentLinks(destinationRoom, <PowerboardsFileAttachmentLink>[...destinationLinks, ...transferredLinks]);
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
