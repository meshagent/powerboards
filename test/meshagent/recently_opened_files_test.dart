import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/meshagent/file_table_view.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_data.dart';

void main() {
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
