import 'package:meshagent_flutter_shadcn/file_preview/file_preview.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';

const Set<String> _unsupportedPreviewExtensions = {'zip', 'rar', '7z', 'tar', 'gz'};
const Set<String> _documentPanePreviewExtensions = {'transcript', 'widget', 'document', 'gallery', 'presentation', 'form'};

PbAttachmentPreviewState powerboardsV1PreviewStateForPath(String path) {
  if (path.startsWith('dataset://')) {
    return PbAttachmentPreviewState.none;
  }

  final kind = classifyFile(path);

  return switch (kind) {
    FileKind.office => PbAttachmentPreviewState.unavailable,
    FileKind.lance => PbAttachmentPreviewState.unsupported,
    FileKind.unknown =>
      _documentPanePreviewExtensions.contains(_extension(path))
          ? PbAttachmentPreviewState.none
          : _unsupportedPreviewExtensions.contains(_extension(path))
          ? PbAttachmentPreviewState.unsupported
          : PbAttachmentPreviewState.unavailable,
    _ => PbAttachmentPreviewState.none,
  };
}

String _extension(String path) {
  final match = RegExp(r'\.([a-z0-9]+)$', caseSensitive: false).firstMatch(path.trim().toLowerCase());
  return match?.group(1) ?? '';
}
