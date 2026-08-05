import 'dart:convert';
import 'dart:typed_data';

import 'package:meshagent/room_server_client.dart';

import 'file_attachment_index.dart';

const String powerboardsFileReferenceRegistryPath = '.powerboards/file-reference-registry.json';
Future<void> _powerboardsFileReferenceWriteQueue = Future<void>.value();
final Map<String, Future<void>> _powerboardsFileTransferRegistrations = <String, Future<void>>{};

enum PowerboardsFileTransferOperation { move, copy }

class PowerboardsFileReference {
  const PowerboardsFileReference({
    required this.sourceRoomName,
    required this.sourcePath,
    required this.destinationRoomName,
    required this.destinationPath,
    required this.operation,
    required this.folder,
    required this.updatedAt,
  });

  factory PowerboardsFileReference.fromJson(Map<String, dynamic> json) {
    final operationName = json['operation'];
    return PowerboardsFileReference(
      sourceRoomName: (json['source_room'] as String? ?? '').trim(),
      sourcePath: normalizePowerboardsAttachmentPath(json['source_path'] as String? ?? ''),
      destinationRoomName: (json['destination_room'] as String? ?? '').trim(),
      destinationPath: normalizePowerboardsAttachmentPath(json['destination_path'] as String? ?? ''),
      operation: operationName == PowerboardsFileTransferOperation.copy.name
          ? PowerboardsFileTransferOperation.copy
          : PowerboardsFileTransferOperation.move,
      folder: json['folder'] == true,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '')?.toUtc(),
    );
  }

  final String sourceRoomName;
  final String sourcePath;
  final String destinationRoomName;
  final String destinationPath;
  final PowerboardsFileTransferOperation operation;
  final bool folder;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'source_room': sourceRoomName,
      'source_path': sourcePath,
      'destination_room': destinationRoomName,
      'destination_path': destinationPath,
      'operation': operation.name,
      'folder': folder,
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }
}

class PowerboardsFileReferenceResolution {
  const PowerboardsFileReferenceResolution({required this.roomName, required this.path});

  final String roomName;
  final String path;
}

Future<List<PowerboardsFileReference>> loadPowerboardsFileReferences(RoomClient room) async {
  try {
    final content = await room.storage.download(powerboardsFileReferenceRegistryPath);
    final decoded = jsonDecode(utf8.decode(content.data));
    if (decoded is! Map<String, dynamic>) {
      return const <PowerboardsFileReference>[];
    }

    final rawReferences = decoded['references'];
    if (rawReferences is! List) {
      return const <PowerboardsFileReference>[];
    }

    return rawReferences
        .whereType<Map>()
        .map((raw) => PowerboardsFileReference.fromJson(Map<String, dynamic>.from(raw)))
        .where(
          (reference) =>
              reference.sourceRoomName.isNotEmpty &&
              reference.sourcePath.isNotEmpty &&
              reference.destinationRoomName.isNotEmpty &&
              reference.destinationPath.isNotEmpty,
        )
        .toList(growable: false);
  } catch (_) {
    return const <PowerboardsFileReference>[];
  }
}

PowerboardsFileReferenceResolution powerboardsResolveFileReference({
  required String roomName,
  required String path,
  required Iterable<PowerboardsFileReference> references,
}) {
  var currentRoomName = roomName.trim();
  var currentPath = normalizePowerboardsAttachmentPath(path);
  final visited = <String>{};

  for (var hop = 0; hop < 32; hop += 1) {
    final visitKey = '${currentRoomName.toLowerCase()}\n$currentPath';
    if (!visited.add(visitKey)) {
      break;
    }

    final candidates = references.where(
      (reference) =>
          reference.operation == PowerboardsFileTransferOperation.move &&
          _roomNamesMatch(reference.sourceRoomName, currentRoomName) &&
          _referenceContainsPath(reference, currentPath),
    );
    final reference = candidates.fold<PowerboardsFileReference?>(
      null,
      (best, candidate) => best == null || candidate.sourcePath.length > best.sourcePath.length ? candidate : best,
    );
    if (reference == null) {
      break;
    }

    currentPath = powerboardsTransferredAttachmentPath(
      path: currentPath,
      sourcePath: reference.sourcePath,
      destinationPath: reference.destinationPath,
      folder: reference.folder,
    );
    currentRoomName = reference.destinationRoomName;
  }

  return PowerboardsFileReferenceResolution(roomName: currentRoomName, path: currentPath);
}

bool powerboardsPathWasCreatedByCopy({
  required String roomName,
  required String path,
  required Iterable<PowerboardsFileReference> references,
}) {
  final normalizedRoomName = roomName.trim();
  final normalizedPath = normalizePowerboardsAttachmentPath(path);
  if (normalizedRoomName.isEmpty || normalizedPath.isEmpty) {
    return false;
  }

  for (final reference in references) {
    if (reference.operation != PowerboardsFileTransferOperation.copy) {
      continue;
    }

    final resolvedDestination = powerboardsResolveFileReference(
      roomName: reference.destinationRoomName,
      path: reference.destinationPath,
      references: references,
    );
    if (!_roomNamesMatch(resolvedDestination.roomName, normalizedRoomName)) {
      continue;
    }

    if (normalizedPath == resolvedDestination.path || (reference.folder && normalizedPath.startsWith('${resolvedDestination.path}/'))) {
      return true;
    }
  }

  return false;
}

bool powerboardsFileReferenceMatchesCurrentPath({
  required String originalRoomName,
  required String originalPath,
  required String currentRoomName,
  required String currentPath,
  required Iterable<PowerboardsFileReference> references,
}) {
  final normalizedCurrentPath = normalizePowerboardsAttachmentPath(currentPath);
  if (normalizedCurrentPath.isEmpty) {
    return false;
  }

  final resolution = powerboardsResolveFileReference(roomName: originalRoomName, path: originalPath, references: references);
  return _roomNamesMatch(resolution.roomName, currentRoomName) && resolution.path == normalizedCurrentPath;
}

Future<void> registerPowerboardsFileTransfer({
  required RoomClient sourceRoom,
  required RoomClient destinationRoom,
  required String sourceRoomName,
  required String destinationRoomName,
  required String sourcePath,
  required String destinationPath,
  required bool folder,
  required bool move,
}) async {
  final normalizedSourcePath = normalizePowerboardsAttachmentPath(sourcePath);
  final normalizedDestinationPath = normalizePowerboardsAttachmentPath(destinationPath);
  final normalizedSourceRoomName = sourceRoomName.trim();
  final normalizedDestinationRoomName = destinationRoomName.trim();
  if (normalizedSourceRoomName.isEmpty ||
      normalizedDestinationRoomName.isEmpty ||
      normalizedSourcePath.isEmpty ||
      normalizedDestinationPath.isEmpty) {
    return;
  }

  final registrationKey = [
    identityHashCode(sourceRoom),
    identityHashCode(destinationRoom),
    normalizedSourceRoomName.toLowerCase(),
    normalizedDestinationRoomName.toLowerCase(),
    normalizedSourcePath,
    normalizedDestinationPath,
    folder,
    move,
  ].join('\n');
  final pendingRegistration = _powerboardsFileTransferRegistrations[registrationKey];
  if (pendingRegistration != null) {
    await pendingRegistration;
    return;
  }

  final reference = PowerboardsFileReference(
    sourceRoomName: normalizedSourceRoomName,
    sourcePath: normalizedSourcePath,
    destinationRoomName: normalizedDestinationRoomName,
    destinationPath: normalizedDestinationPath,
    operation: move ? PowerboardsFileTransferOperation.move : PowerboardsFileTransferOperation.copy,
    folder: folder,
    updatedAt: DateTime.now().toUtc(),
  );

  final operation = _powerboardsFileReferenceWriteQueue.catchError((_) {}).then((_) async {
    await _recordPowerboardsFileReference(sourceRoom, reference);
    if (!identical(sourceRoom, destinationRoom)) {
      await _recordPowerboardsFileReference(destinationRoom, reference);
    }
    await registerPowerboardsFileAttachmentTransfer(
      sourceRoom: sourceRoom,
      destinationRoom: destinationRoom,
      sourcePath: normalizedSourcePath,
      destinationPath: normalizedDestinationPath,
      folder: folder,
      move: move,
    );
  });
  _powerboardsFileReferenceWriteQueue = operation.catchError((_) {});
  _powerboardsFileTransferRegistrations[registrationKey] = operation;
  try {
    await operation;
  } finally {
    if (identical(_powerboardsFileTransferRegistrations[registrationKey], operation)) {
      _powerboardsFileTransferRegistrations.remove(registrationKey);
    }
  }
}

Future<void> _recordPowerboardsFileReference(RoomClient room, PowerboardsFileReference reference) async {
  final existing = await loadPowerboardsFileReferences(room);
  var recordedReference = reference;
  for (final candidate in existing) {
    if (_sameReference(candidate, reference) && candidate.folder && !reference.folder) {
      recordedReference = PowerboardsFileReference(
        sourceRoomName: reference.sourceRoomName,
        sourcePath: reference.sourcePath,
        destinationRoomName: reference.destinationRoomName,
        destinationPath: reference.destinationPath,
        operation: reference.operation,
        folder: true,
        updatedAt: reference.updatedAt,
      );
      break;
    }
  }
  final references =
      <PowerboardsFileReference>[
        for (final candidate in existing)
          if (!_sameReference(candidate, recordedReference) && !_moveDestinationReplacesSource(candidate, recordedReference)) candidate,
        recordedReference,
      ]..sort((left, right) {
        final rightUpdatedAt = right.updatedAt?.millisecondsSinceEpoch ?? 0;
        final leftUpdatedAt = left.updatedAt?.millisecondsSinceEpoch ?? 0;
        return rightUpdatedAt.compareTo(leftUpdatedAt);
      });
  final cappedReferences = references.take(500).toList(growable: false);
  final data = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'version': 1,
        'references': [for (final candidate in cappedReferences) candidate.toJson()],
      }),
    ),
  );

  await room.storage.uploadStream(
    powerboardsFileReferenceRegistryPath,
    Stream<Uint8List>.value(data),
    overwrite: true,
    size: data.length,
    mimeType: 'application/json',
  );
}

bool _referenceContainsPath(PowerboardsFileReference reference, String path) {
  return path == reference.sourcePath || (reference.folder && path.startsWith('${reference.sourcePath}/'));
}

bool _sameReference(PowerboardsFileReference left, PowerboardsFileReference right) {
  return _roomNamesMatch(left.sourceRoomName, right.sourceRoomName) &&
      left.sourcePath == right.sourcePath &&
      _roomNamesMatch(left.destinationRoomName, right.destinationRoomName) &&
      left.destinationPath == right.destinationPath &&
      left.operation == right.operation;
}

bool _moveDestinationReplacesSource(PowerboardsFileReference existing, PowerboardsFileReference next) {
  return next.operation == PowerboardsFileTransferOperation.move &&
      existing.operation == PowerboardsFileTransferOperation.move &&
      _roomNamesMatch(existing.sourceRoomName, next.destinationRoomName) &&
      existing.sourcePath == next.destinationPath;
}

bool _roomNamesMatch(String left, String right) => left.trim().toLowerCase() == right.trim().toLowerCase();
