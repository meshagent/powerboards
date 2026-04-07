import 'package:collection/collection.dart';
import 'package:meshagent/meshagent.dart';
import 'package:path/path.dart' as p;

const String _defaultUntitledThreadName = 'New Chat';
const int _maxThreadDisplayNameLength = 64;
final RegExp _uuidPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', caseSensitive: false);

bool isThreadFileName(String fileName) => fileName.toLowerCase().endsWith('.thread');

bool isThreadPath(String path) => isThreadFileName(p.posix.basename(path));

bool shouldReadThreadDocumentForDisplayName(String path) {
  return p.posix.basename(path).toLowerCase() != 'main.thread';
}

String threadFileDisplayNameFromPath(String path, {String? threadDisplayName}) {
  final resolvedName = (threadDisplayName?.trim().isNotEmpty ?? false) ? threadDisplayName!.trim() : defaultThreadDisplayNameFromPath(path);
  return resolvedName.toLowerCase().endsWith('.thread') ? resolvedName : '$resolvedName.thread';
}

String defaultThreadDisplayNameFromPath(String path) {
  final basename = p.posix.basename(path);
  final rawName = basename.endsWith('.thread') ? basename.substring(0, basename.length - '.thread'.length) : basename;
  final trimmed = rawName.trim();
  if (trimmed.isEmpty) {
    return _defaultUntitledThreadName;
  }

  if (_isUuidLike(trimmed)) {
    return _defaultUntitledThreadName;
  }

  final normalized = trimmed.replaceAll(RegExp(r'[_-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return _defaultUntitledThreadName;
  }

  return normalized
      .split(' ')
      .where((segment) => segment.isNotEmpty)
      .map((segment) => segment.length == 1 ? segment.toUpperCase() : '${segment[0].toUpperCase()}${segment.substring(1)}')
      .join(' ');
}

bool shouldBackfillThreadDisplayName(String? displayName) {
  final trimmed = displayName?.trim();
  return trimmed == null || trimmed.isEmpty || trimmed == _defaultUntitledThreadName;
}

String? deriveThreadDisplayNameFromDocument(MeshDocument document) {
  final messagesElement = document.root.getChildren().whereType<MeshElement>().firstWhereOrNull((child) => child.tagName == 'messages');
  if (messagesElement == null) {
    return null;
  }

  for (final child in messagesElement.getChildren().whereType<MeshElement>()) {
    if (child.tagName != 'message') {
      continue;
    }

    final text = child.getAttribute('text');
    if (text is! String) {
      continue;
    }

    final firstLine = text.split(RegExp(r'\r?\n')).map((line) => line.trim()).firstWhereOrNull((line) => line.isNotEmpty);
    if (firstLine == null) {
      continue;
    }

    final normalized = firstLine.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      continue;
    }

    return normalized.length <= _maxThreadDisplayNameLength
        ? normalized
        : '${normalized.substring(0, _maxThreadDisplayNameLength - 1).trimRight()}…';
  }

  return null;
}

bool _isUuidLike(String value) {
  return _uuidPattern.hasMatch(value);
}
