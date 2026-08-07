import 'dart:convert';

const String powerboardsFolderChatContextKind = 'powerboards_folder_context';
const int powerboardsFolderChatContextVersion = 1;

enum PowerboardsChatLinkKind { folder, filePreview }

class PowerboardsChatLinkTarget {
  const PowerboardsChatLinkTarget({required this.kind, required this.storagePath});

  final PowerboardsChatLinkKind kind;
  final String storagePath;
}

class PowerboardsFolderChatContext {
  const PowerboardsFolderChatContext({
    required this.storagePath,
    required this.displayName,
    this.visibleDirectChildren = const <PowerboardsFolderChatEntry>[],
  });

  final String storagePath;
  final String displayName;
  final List<PowerboardsFolderChatEntry> visibleDirectChildren;

  String get workspacePath => storagePath.isEmpty ? '/data' : '/data/$storagePath';

  String get folderLink {
    return Uri(
      scheme: 'powerboards',
      host: 'files',
      queryParameters: storagePath.isEmpty ? null : <String, String>{'path': storagePath},
    ).toString();
  }

  String fileLink(String filePath) {
    return Uri(
      scheme: 'powerboards',
      host: 'preview',
      queryParameters: <String, String>{'path': normalizePowerboardsFolderStoragePath(filePath)},
    ).toString();
  }
}

class PowerboardsFolderChatEntry {
  const PowerboardsFolderChatEntry({required this.storagePath, required this.name, required this.isFolder, this.sizeBytes});

  final String storagePath;
  final String name;
  final bool isFolder;
  final int? sizeBytes;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'storage_path': storagePath,
      'name': name,
      'type': isFolder ? 'folder' : 'file',
      if (!isFolder && sizeBytes != null) 'size_bytes': sizeBytes,
    };
  }
}

String normalizePowerboardsFolderStoragePath(String path) {
  return path.trim().split('/').map((segment) => segment.trim()).where((segment) => segment.isNotEmpty && segment != '.').join('/');
}

String powerboardsFolderChatContextDataUrl(
  String storagePath, {
  String? displayName,
  Iterable<PowerboardsFolderChatEntry> visibleDirectChildren = const <PowerboardsFolderChatEntry>[],
}) {
  final normalizedPath = normalizePowerboardsFolderStoragePath(storagePath);
  final normalizedDisplayName = displayName?.trim();
  final resolvedDisplayName = normalizedDisplayName != null && normalizedDisplayName.isNotEmpty
      ? normalizedDisplayName
      : normalizedPath.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? 'Files';
  final context = PowerboardsFolderChatContext(storagePath: normalizedPath, displayName: resolvedDisplayName);
  final directChildren = visibleDirectChildren.toList(growable: false);
  final document = <String, Object>{
    'kind': powerboardsFolderChatContextKind,
    'version': powerboardsFolderChatContextVersion,
    'display_name': context.displayName,
    'storage_path': context.storagePath,
    'workspace_path': context.workspacePath,
    'visible_direct_children': <Map<String, Object?>>[for (final child in directChildren) child.toJson()],
    'instructions': <String>[
      'This attachment identifies a live Powerboards folder, not a file.',
      'The visible_direct_children array is an authoritative snapshot from the same storage API used by the Files UI when this folder was attached.',
      'For questions such as "what is here" or "what is in this folder", report the direct children exactly as files or folders. Do not collapse recursive descendants into the direct-child count.',
      'Inspect ${context.workspacePath} at response time so newly created, changed, or deleted files are reflected.',
      'If live inspection conflicts with the snapshot, do not confidently call the folder empty. Recheck the exact workspace_path and explain any remaining discrepancy.',
      'You may read, create, and update files within ${context.workspacePath} when the user asks.',
      'Recursively ignore every hidden entry whose basename begins with a dot, including .placeholder. Do not count, summarize, or mention hidden entries.',
      'When referencing this folder, use a Markdown link to ${context.folderLink}.',
      'When referencing a visible file, use a Markdown link whose URL is powerboards://preview?path=<storage-path>. Include the full storage path relative to /data, not only the basename, and percent-encode it as a query value.',
      'File-link URLs must not contain raw spaces. Encode every space in the path as %20 so Markdown preserves the complete filename.',
      'Use only paths within ${context.workspacePath} for this folder context.',
    ],
  };
  final encoded = base64Encode(utf8.encode(jsonEncode(document)));
  return 'data:text/plain;base64,$encoded';
}

String powerboardsFolderFilesRoutePath(String storagePath) {
  final normalizedPath = normalizePowerboardsFolderStoragePath(storagePath);
  return normalizedPath.isEmpty ? '' : '$normalizedPath/';
}

String powerboardsResolveChatFilePreviewPath(String storagePath, {String? activeFolderStoragePath}) {
  final normalizedPath = normalizePowerboardsFolderStoragePath(storagePath);
  final normalizedFolderPath = normalizePowerboardsFolderStoragePath(activeFolderStoragePath ?? '');
  if (normalizedPath.isEmpty || normalizedFolderPath.isEmpty) {
    return normalizedPath;
  }
  if (normalizedPath == normalizedFolderPath || normalizedPath.startsWith('$normalizedFolderPath/') || normalizedPath.contains('/')) {
    return normalizedPath;
  }
  return '$normalizedFolderPath/$normalizedPath';
}

String powerboardsCanonicalizeMalformedPreviewMarkdownLinks(String markdown) {
  final previewLinkPattern = RegExp(r'(\]\()(powerboards://preview\?[^)\r\n]*)(\))', caseSensitive: false);
  final malformedPercentPattern = RegExp(r'%(?![0-9A-Fa-f]{2})');

  return markdown.replaceAllMapped(previewLinkPattern, (match) {
    final destination = match.group(2)!;
    if (!destination.contains(RegExp(r'\s')) && !malformedPercentPattern.hasMatch(destination)) {
      return match.group(0)!;
    }

    final target = powerboardsChatLinkTargetFromUrl(destination);
    if (target == null || target.kind != PowerboardsChatLinkKind.filePreview || target.storagePath.isEmpty) {
      return match.group(0)!;
    }

    final canonicalDestination = Uri(
      scheme: 'powerboards',
      host: 'preview',
      queryParameters: <String, String>{'path': target.storagePath},
    ).toString();
    return '${match.group(1)}$canonicalDestination${match.group(3)}';
  });
}

String powerboardsLinkPlainFolderReferencesInMarkdown(String markdown, PowerboardsFolderChatContext folderContext) {
  final references = <({String label, String destination})>[
    (label: folderContext.displayName, destination: folderContext.folderLink),
    for (final child in folderContext.visibleDirectChildren)
      (
        label: child.name,
        destination: child.isFolder
            ? PowerboardsFolderChatContext(storagePath: child.storagePath, displayName: child.name).folderLink
            : folderContext.fileLink(child.storagePath),
      ),
  ];
  references.sort((left, right) => right.label.length.compareTo(left.label.length));
  if (references.isEmpty) {
    return markdown;
  }

  final protectedMarkdown = RegExp(
    r'```[\s\S]*?```|`[^`\r\n]*`|\[[^\]\r\n]*\]\([^\)\r\n]*\)|(?:https?|powerboards)://[^\s<>]+',
    caseSensitive: false,
  );
  final result = StringBuffer();
  var offset = 0;
  for (final match in protectedMarkdown.allMatches(markdown)) {
    result.write(_powerboardsLinkPlainReferenceSegment(markdown.substring(offset, match.start), references));
    result.write(match.group(0));
    offset = match.end;
  }
  result.write(_powerboardsLinkPlainReferenceSegment(markdown.substring(offset), references));
  return result.toString();
}

String powerboardsLinkAssistantFolderReferencesInMarkdown(
  String markdown, {
  required Iterable<String> contextAttachmentPaths,
  String Function(String path)? resolveAttachmentPath,
}) {
  var transformed = markdown;
  for (final path in contextAttachmentPaths) {
    final resolvedPath = resolveAttachmentPath?.call(path) ?? path;
    final folderContext = powerboardsFolderChatContextFromDataUrl(resolvedPath);
    if (folderContext != null) {
      transformed = powerboardsLinkPlainFolderReferencesInMarkdown(transformed, folderContext);
    }
  }
  return transformed;
}

String _powerboardsLinkPlainReferenceSegment(String segment, List<({String label, String destination})> references) {
  final referencesByLabel = <String, ({String label, String destination})>{
    for (final reference in references)
      if (reference.label.trim().isNotEmpty) reference.label.trim().toLowerCase(): reference,
  };
  if (referencesByLabel.isEmpty) {
    return segment;
  }
  final labels = referencesByLabel.values.map((reference) => RegExp.escape(reference.label.trim())).join('|');
  final pattern = RegExp('(?<![A-Za-z0-9_./-])(?:$labels)(?![A-Za-z0-9_./-])', caseSensitive: false);
  return segment.replaceAllMapped(pattern, (match) {
    final label = match.group(0)!;
    final reference = referencesByLabel[label.toLowerCase()]!;
    return '[${_powerboardsEscapeMarkdownLinkLabel(label)}](${reference.destination})';
  });
}

String _powerboardsEscapeMarkdownLinkLabel(String label) {
  return label.replaceAll(r'\', r'\\').replaceAll('[', r'\[').replaceAll(']', r'\]');
}

PowerboardsFolderChatContext? powerboardsFolderChatContextFromDataUrl(String value) {
  final normalized = value.trim();
  for (final encodedPayload in _powerboardsFolderContextPayloadCandidates(normalized)) {
    try {
      final decoded = utf8.decode(base64Decode(encodedPayload));
      final json = jsonDecode(decoded);
      if (json is! Map<String, dynamic> ||
          json['kind'] != powerboardsFolderChatContextKind ||
          json['version'] != powerboardsFolderChatContextVersion) {
        continue;
      }

      final storagePath = normalizePowerboardsFolderStoragePath(json['storage_path'] as String? ?? '');
      final displayName = (json['display_name'] as String? ?? '').trim();
      return PowerboardsFolderChatContext(
        storagePath: storagePath,
        displayName: displayName.isEmpty
            ? storagePath.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? 'Files'
            : displayName,
        visibleDirectChildren: _powerboardsFolderEntriesFromDocument(json),
      );
    } on FormatException {
      continue;
    } on TypeError {
      continue;
    }
  }
  return null;
}

List<PowerboardsFolderChatEntry> _powerboardsFolderEntriesFromDocument(Map<String, dynamic> document) {
  final rawChildren = document['visible_direct_children'];
  if (rawChildren is! List) {
    return const <PowerboardsFolderChatEntry>[];
  }

  return [
    for (final rawChild in rawChildren)
      if (rawChild is Map)
        () {
          final child = Map<String, dynamic>.from(rawChild);
          final storagePath = normalizePowerboardsFolderStoragePath(child['storage_path'] as String? ?? '');
          final name = (child['name'] as String? ?? '').trim();
          final sizeBytes = child['size_bytes'];
          return PowerboardsFolderChatEntry(
            storagePath: storagePath,
            name: name,
            isFolder: child['type'] == 'folder',
            sizeBytes: sizeBytes is int ? sizeBytes : null,
          );
        }(),
  ].where((entry) => entry.storagePath.isNotEmpty && entry.name.isNotEmpty).toList(growable: false);
}

String powerboardsResolveFolderChatContextDataUrl(String value, {required String Function(String storagePath) resolvePath}) {
  for (final encodedPayload in _powerboardsFolderContextPayloadCandidates(value.trim())) {
    try {
      final document = jsonDecode(utf8.decode(base64Decode(encodedPayload)));
      if (document is! Map<String, dynamic> ||
          document['kind'] != powerboardsFolderChatContextKind ||
          document['version'] != powerboardsFolderChatContextVersion) {
        continue;
      }

      final originalPath = normalizePowerboardsFolderStoragePath(document['storage_path'] as String? ?? '');
      final resolvedPath = normalizePowerboardsFolderStoragePath(resolvePath(originalPath));
      if (resolvedPath.isEmpty || resolvedPath == originalPath) {
        return value;
      }

      final updated = Map<String, dynamic>.from(document)
        ..['storage_path'] = resolvedPath
        ..['display_name'] = resolvedPath.split('/').last
        ..['workspace_path'] = '/data/$resolvedPath';
      if (document['visible_direct_children'] case final List children) {
        updated['visible_direct_children'] = [
          for (final child in children)
            if (child is Map)
              () {
                final next = Map<String, dynamic>.from(child);
                final childPath = normalizePowerboardsFolderStoragePath(next['storage_path'] as String? ?? '');
                if (childPath == originalPath || childPath.startsWith('$originalPath/')) {
                  next['storage_path'] = '$resolvedPath${childPath.substring(originalPath.length)}';
                }
                return next;
              }(),
        ];
      }

      final oldWorkspace = '/data/$originalPath';
      final newWorkspace = '/data/$resolvedPath';
      final oldLink = PowerboardsFolderChatContext(storagePath: originalPath, displayName: '').folderLink;
      final newLink = PowerboardsFolderChatContext(storagePath: resolvedPath, displayName: '').folderLink;
      if (document['instructions'] case final List instructions) {
        updated['instructions'] = [
          for (final entry in instructions)
            if (entry is String) entry.replaceAll(oldWorkspace, newWorkspace).replaceAll(oldLink, newLink) else entry,
        ];
      }
      return 'data:text/plain;base64,${base64Encode(utf8.encode(jsonEncode(updated)))}';
    } on FormatException {
      continue;
    } on TypeError {
      continue;
    }
  }
  return value;
}

Iterable<String> _powerboardsFolderContextPayloadCandidates(String value) sync* {
  final forms = <String>{value};
  try {
    forms.add(Uri.decodeFull(value));
  } on FormatException {
    // The original form may still contain a valid, non-escaped data URL.
  } on ArgumentError {
    // The original form may still contain a valid, non-escaped data URL.
  }

  const markers = <String>['data:text/plain;base64,', 'plain;base64,'];
  final candidates = <String>{};
  for (final form in forms) {
    for (final marker in markers) {
      final markerIndex = form.indexOf(marker);
      if (markerIndex >= 0) {
        candidates.add(form.substring(markerIndex + marker.length));
      }
    }

    final unwrapped = form.startsWith('room:///')
        ? form.substring('room:///'.length)
        : form.startsWith('/')
        ? form.substring(1)
        : form;
    if (RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(unwrapped)) {
      candidates.add(unwrapped);
    }
  }

  yield* candidates;
}

PowerboardsChatLinkTarget? powerboardsChatLinkTargetFromUrl(String value) {
  final normalized = value.trim();
  if (normalized.startsWith('powerboards://') && RegExp(r'%(?![0-9A-Fa-f]{2})').hasMatch(normalized)) {
    return _powerboardsChatLinkTargetFromMalformedProductUrl(normalized);
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null) {
    return _powerboardsChatLinkTargetFromMalformedProductUrl(normalized);
  }
  if (uri.scheme != 'powerboards') {
    return null;
  }

  final queryPath = uri.queryParameters['path'];
  final rawPath = queryPath ?? uri.pathSegments.join('/');
  final path = normalizePowerboardsFolderStoragePath(_decodePowerboardsChatLinkPath(rawPath));
  if (uri.host == 'files') {
    return PowerboardsChatLinkTarget(kind: PowerboardsChatLinkKind.folder, storagePath: path);
  }
  if (uri.host == 'preview' && path.isNotEmpty) {
    return PowerboardsChatLinkTarget(kind: PowerboardsChatLinkKind.filePreview, storagePath: path);
  }
  return null;
}

PowerboardsChatLinkTarget? _powerboardsChatLinkTargetFromMalformedProductUrl(String value) {
  const productPrefix = 'powerboards://';
  if (!value.startsWith(productPrefix)) {
    return null;
  }

  final remainder = value.substring(productPrefix.length);
  final queryStart = remainder.indexOf('?');
  final host = queryStart < 0 ? remainder : remainder.substring(0, queryStart);
  final query = queryStart < 0 ? '' : remainder.substring(queryStart + 1);
  String? rawPath;
  for (final component in query.split('&')) {
    if (component.startsWith('path=')) {
      rawPath = component.substring('path='.length);
      break;
    }
  }

  final path = normalizePowerboardsFolderStoragePath(_decodePowerboardsChatLinkPath(rawPath ?? ''));
  if (host == 'files') {
    return PowerboardsChatLinkTarget(kind: PowerboardsChatLinkKind.folder, storagePath: path);
  }
  if (host == 'preview' && path.isNotEmpty) {
    return PowerboardsChatLinkTarget(kind: PowerboardsChatLinkKind.filePreview, storagePath: path);
  }
  return null;
}

String _decodePowerboardsChatLinkPath(String value) {
  var decoded = value.replaceAll(RegExp(r'%\s'), '%20').replaceAllMapped(RegExp(r'%(?![0-9A-Fa-f]{2})'), (_) => '%25');
  // Uri.queryParameters already decodes once. Some generated Markdown links
  // escape the percent sign too, so allow one additional decoding pass.
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      final next = Uri.decodeComponent(decoded);
      if (next == decoded) {
        break;
      }
      decoded = next;
    } on FormatException {
      break;
    } on ArgumentError {
      break;
    }
  }
  return decoded;
}

extension _LastOrNull<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
