import 'package:flutter/material.dart' show Color;

import '../../models/pb_attachment_file_metadata.dart';
import '../../theme/pb_colors.dart';

typedef PbFilesLinkedThreadHandler = void Function(PbFilesItemData file, String thread);

enum PbFilesSortKey {
  updated('updated', 'Last updated'),
  name('name', 'Name'),
  type('type', 'Type'),
  thread('thread', 'Linked thread'),
  creator('creator', 'Created by');

  const PbFilesSortKey(this.id, this.label);

  final String id;
  final String label;
}

enum PbFilesItemKind { file, folder, processing, processingError }

class PbFilesItemData {
  const PbFilesItemData({
    required this.id,
    required this.title,
    required this.type,
    required this.thread,
    this.linkedThreads = const [],
    required this.creator,
    required this.creatorInitials,
    required this.updatedLabel,
    required this.updatedSort,
    required this.parentPath,
    this.folderPath = '',
    required this.fileType,
    this.kind = PbFilesItemKind.file,
  });

  factory PbFilesItemData.fromFileName({
    required String id,
    required String title,
    String type = '',
    required String thread,
    List<String> linkedThreads = const [],
    required String creator,
    required String creatorInitials,
    required String updatedLabel,
    required int updatedSort,
    required String parentPath,
    String folderPath = '',
    PbAttachmentFileType? fileType,
    String? fileTypeKey,
    PbFilesItemKind kind = PbFilesItemKind.file,
  }) {
    final resolved = PbResolvedAttachmentMetadata.resolve(
      title: title,
      descriptor: type,
      explicitFileType: kind == PbFilesItemKind.folder ? PbAttachmentFileType.folder : fileType,
      explicitFileTypeKey: fileTypeKey,
    );

    return PbFilesItemData(
      id: id,
      title: resolved.displayTitle,
      type: resolved.displayType,
      thread: thread,
      linkedThreads: linkedThreads,
      creator: creator,
      creatorInitials: creatorInitials,
      updatedLabel: updatedLabel,
      updatedSort: updatedSort,
      parentPath: parentPath,
      folderPath: folderPath,
      fileType: resolved.fileType,
      kind: kind,
    );
  }

  final String id;
  final String title;
  final String type;
  final String thread;
  final List<String> linkedThreads;
  final String creator;
  final String creatorInitials;
  final String updatedLabel;
  final int updatedSort;
  final String parentPath;
  final String folderPath;
  final PbAttachmentFileType fileType;
  final PbFilesItemKind kind;

  bool get canPreview => kind == PbFilesItemKind.file;

  List<String> get linkedThreadTargets {
    final rawThreads = linkedThreads.isNotEmpty ? linkedThreads : [thread];
    final seen = <String>{};
    final normalized = <String>[];

    for (final rawThread in rawThreads) {
      final value = rawThread.trim();
      final key = value.toLowerCase();
      if (value.isEmpty || seen.contains(key)) {
        continue;
      }

      seen.add(key);
      normalized.add(value);
    }

    return normalized;
  }

  String get threadLabel {
    final threads = linkedThreadTargets;
    if (threads.length > 1) {
      return 'Multiple';
    }

    return threads.isEmpty ? '-' : threads.first;
  }

  String get iconAssetName {
    if (kind == PbFilesItemKind.folder) {
      return 'folder';
    }

    return fileType.iconAssetName;
  }

  Color get iconColor {
    if (kind == PbFilesItemKind.folder) {
      return PbColors.surfaceRailActive;
    }

    return fileType.iconColor;
  }

  String get filterText {
    return [title, type, ...linkedThreadTargets, creator, updatedLabel].join(' ').toLowerCase();
  }

  String compactMeta({required bool showThread, required bool showCreator}) {
    final parts = <String>[type];
    if (showThread && threadLabel != '-') {
      parts.add(threadLabel);
    }
    if (showCreator) {
      parts.add(creator);
    }
    return parts.join(' / ');
  }

  PbAttachmentListItemData toAttachmentData() {
    return PbAttachmentListItemData(title: title, subtitle: type.isEmpty ? 'File' : type, fileType: fileType);
  }
}
