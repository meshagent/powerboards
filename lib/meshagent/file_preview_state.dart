import 'package:meshagent_flutter_shadcn/file_preview/file_preview.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';

const Set<String> _unsupportedPreviewExtensions = {'zip', 'rar', '7z', 'tar', 'gz', 'tgz'};
const Set<String> _unavailablePreviewExtensions = {'tif', 'tiff', 'heic', 'heif'};
const Set<String> _documentPanePreviewExtensions = {'transcript', 'srt', 'vtt', 'widget', 'document', 'gallery', 'presentation', 'form'};
const Set<String> _editableTextPreviewExtensions = {'txt', 'text', 'md', 'markdown', 'mdown', 'mkdn', 'rst', 'log', 'csv', 'tsv'};
const Set<String> _mediaPreviewExtensions = {
  'png',
  'jpg',
  'jpeg',
  'jfif',
  'gif',
  'webp',
  'svg',
  'svgz',
  'heic',
  'heif',
  'tif',
  'tiff',
  'bmp',
  'mp4',
  'mkv',
  'mov',
  'webm',
  'avi',
  'mp3',
  'ogg',
  'wav',
  'm4a',
  'aac',
  'flac',
};
const Set<String> _pagedDocumentPreviewExtensions = {'pdf'};

PbAttachmentPreviewState powerboardsV1PreviewStateForPath(String path) {
  if (path.startsWith('dataset://')) {
    return PbAttachmentPreviewState.none;
  }

  final extension = _extension(path);
  if (_unavailablePreviewExtensions.contains(extension)) {
    return PbAttachmentPreviewState.unavailable;
  }

  if (_editableTextPreviewExtensions.contains(extension) ||
      _mediaPreviewExtensions.contains(extension) ||
      _documentPanePreviewExtensions.contains(extension) ||
      _pagedDocumentPreviewExtensions.contains(extension)) {
    return PbAttachmentPreviewState.none;
  }

  final kind = classifyFile(path);

  return switch (kind) {
    FileKind.office => PbAttachmentPreviewState.unavailable,
    FileKind.parquet => PbAttachmentPreviewState.unavailable,
    FileKind.lance => PbAttachmentPreviewState.unsupported,
    FileKind.unknown =>
      _unsupportedPreviewExtensions.contains(extension) ? PbAttachmentPreviewState.unsupported : PbAttachmentPreviewState.unavailable,
    _ => PbAttachmentPreviewState.none,
  };
}

String _extension(String path) {
  final match = RegExp(r'\.([a-z0-9]+)$', caseSensitive: false).firstMatch(path.trim().toLowerCase());
  return match?.group(1) ?? '';
}
