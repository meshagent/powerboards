import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/meshagent/file_preview_state.dart';
import 'package:powerboards/meshagent/file_table_view.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_data.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';

void main() {
  test('file manager maps Powerboards-native paths to v1 file type keys', () {
    expect(powerboardsV1FileTypeKeyForPath('.threads/main.thread'), 'thread');
    expect(powerboardsV1FileTypeKeyForPath('transcripts/2026-06-01 12-40 PM.transcript'), 'transcript');
    expect(powerboardsV1FileTypeKeyForPath('widgets/customer-intake.widget'), 'widget');
    expect(powerboardsV1FileTypeKeyForPath('docs/product brief.document'), 'document');
    expect(powerboardsV1FileTypeKeyForPath('slides/roadmap.presentation'), 'presentation');
    expect(powerboardsV1FileTypeKeyForPath('media/moodboard.gallery'), 'image');
    expect(powerboardsV1FileTypeKeyForPath('forms/signup.form'), 'document');
    expect(powerboardsV1FileTypeKeyForPath('notes/plain.md'), isNull);
  });

  test('file manager keeps real v1 preview categories previewable', () {
    expect(powerboardsV1PreviewStateForPath('docs/notes.txt'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('docs/readme.md'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('src/main.dart'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('media/photo.bmp'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('media/sample-image-preview.tiff'), PbAttachmentPreviewState.unavailable);
    expect(powerboardsV1PreviewStateForPath('media/photo.heic'), PbAttachmentPreviewState.unavailable);
    expect(powerboardsV1PreviewStateForPath('media/clip.webm'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('docs/sample.pdf'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('transcripts/live-caption.srt'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('transcripts/live-caption.vtt'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('slides/roadmap.gslides'), PbAttachmentPreviewState.unavailable);
    expect(powerboardsV1PreviewStateForPath('data/results.parquet'), PbAttachmentPreviewState.unavailable);
    expect(powerboardsV1PreviewStateForPath('archive/sample.zip'), PbAttachmentPreviewState.unsupported);
  });

  test('recently opened files move opened file to the front and de-dupe', () {
    final first = _file('first');
    final second = _file('second');
    final third = _file('third');

    final recents = powerboardsV1RecordRecentlyOpenedFile([third, second, first], second);

    expect(recents, [second, third, first]);
  });

  test('recently opened files are capped to seven previewable files', () {
    final opened = _file('opened');
    final previous = [for (var index = 0; index < 9; index++) _file('previous-$index')];

    final recents = powerboardsV1RecordRecentlyOpenedFile(previous, opened);

    expect(recents.map((file) => file.id), ['opened', 'previous-0', 'previous-1', 'previous-2', 'previous-3', 'previous-4', 'previous-5']);
  });

  test('recently opened files ignore folders', () {
    final file = _file('file');
    final folder = _file('folder', kind: PbFilesItemKind.folder);

    final recents = powerboardsV1RecordRecentlyOpenedFile([file], folder);

    expect(recents, [file]);
  });
}

PbFilesItemData _file(String id, {PbFilesItemKind kind = PbFilesItemKind.file}) {
  return PbFilesItemData.fromFileName(
    id: id,
    title: '$id.txt',
    thread: '',
    creator: 'Jesse Park',
    creatorInitials: 'JP',
    updatedLabel: '',
    updatedSort: 0,
    parentPath: '',
    kind: kind,
  );
}
