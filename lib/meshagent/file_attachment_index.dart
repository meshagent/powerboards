import 'dart:convert';
import 'dart:typed_data';

import 'package:meshagent/room_server_client.dart';

import 'thread_display_name.dart';

const String powerboardsFileAttachmentIndexPath = '.powerboards/file-attachment-index.json';

class PowerboardsFileAttachmentLink {
  const PowerboardsFileAttachmentLink({
    required this.filePath,
    required this.threadPath,
    required this.threadName,
    required this.createdBy,
    required this.createdAt,
  });

  factory PowerboardsFileAttachmentLink.fromJson(Map<String, dynamic> json) {
    final filePath = json['file_path'];
    final threadPath = json['thread_path'];
    final threadName = json['thread_name'];
    final createdBy = json['created_by'];
    final createdAt = json['created_at'];

    return PowerboardsFileAttachmentLink(
      filePath: filePath is String ? normalizePowerboardsAttachmentPath(filePath) : '',
      threadPath: threadPath is String ? normalizePowerboardsThreadAttachmentPath(threadPath) : '',
      threadName: threadName is String ? threadName.trim() : '',
      createdBy: createdBy is String ? createdBy.trim() : '',
      createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
    );
  }

  final String filePath;
  final String threadPath;
  final String threadName;
  final String createdBy;
  final DateTime? createdAt;

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
    linksByKey['$filePath\n${powerboardsThreadAttachmentMatchKey(normalizedThreadPath)}'] = PowerboardsFileAttachmentLink(
      filePath: filePath,
      threadPath: normalizedThreadPath,
      threadName: threadName.trim(),
      createdBy: createdBy.trim(),
      createdAt: now,
    );
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
