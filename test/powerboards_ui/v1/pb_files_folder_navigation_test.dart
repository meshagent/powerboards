import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_data.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_files_page.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  test('every non-folder file type is eligible for the side file-preview pane', () {
    for (final fileType in PbAttachmentFileType.values) {
      final item = PbFilesItemData(
        id: 'file-${fileType.name}',
        title: 'sample-${fileType.name}',
        type: fileType.defaultDisplayLabel,
        thread: '',
        creator: 'Tester',
        creatorInitials: 'T',
        updatedLabel: 'Now',
        updatedSort: 1,
        parentPath: '',
        fileType: fileType,
        kind: PbFilesItemKind.file,
      );
      expect(item.canPreview, isTrue, reason: fileType.name);
    }

    final folder = PbFilesItemData(
      id: 'folder',
      title: 'Folder',
      type: 'Folder',
      thread: '',
      creator: 'Tester',
      creatorInitials: 'T',
      updatedLabel: 'Now',
      updatedSort: 1,
      parentPath: '',
      folderPath: 'folder',
      fileType: PbAttachmentFileType.folder,
      kind: PbFilesItemKind.folder,
    );
    expect(folder.canPreview, isFalse);
  });

  testWidgets('browsing a folder closes the active file preview instead of previewing the folder', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previewFile = PbFilesItemData.fromFileName(
      id: 'active-preview',
      title: 'active-preview.md',
      thread: 'Preview test',
      creator: 'Tester',
      creatorInitials: 'T',
      updatedLabel: 'Now',
      updatedSort: 1,
      parentPath: '',
      previewState: PbAttachmentPreviewState.unsupported,
    );
    final previewOpenChanges = <bool>[];

    await tester.pumpWidget(
      ShadApp(
        home: Material(
          child: PbFilesPage(
            roomPanelCollapsed: false,
            onRoomPanelCollapsedChanged: (_) {},
            roomPanelWidth: 360,
            onRoomPanelWidthChanged: (_) {},
            initialPreviewFile: previewFile,
            initialPreviewOpen: true,
            onPreviewFileChanged: (_) {},
            onPreviewOpenChanged: previewOpenChanges.add,
            filePreviewFullscreen: false,
            onFilePreviewFullscreenChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Preview samples').first);
    await tester.pumpAndSettle();

    expect(previewOpenChanges, contains(false));
    expect(find.text('Preview samples'), findsWidgets);
    expect(find.text('active-preview.md'), findsNothing);
  });
}
