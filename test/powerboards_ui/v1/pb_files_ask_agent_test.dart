import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_file_menus.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_data.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_layout_values.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_files_page.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_button.dart';

PbFilesItemData _folder(String id, String title) {
  return PbFilesItemData(
    id: id,
    title: title,
    type: 'Folder',
    thread: '',
    creator: 'Tester',
    creatorInitials: 'T',
    updatedLabel: 'Now',
    updatedSort: 1,
    parentPath: '',
    folderPath: id,
    fileType: PbAttachmentFileType.folder,
    kind: PbFilesItemKind.folder,
  );
}

void main() {
  testWidgets('folder row menu places Ask agent between browse and download', (tester) async {
    final folder = _folder('design references/参考', 'Design references');
    var asks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: PbFilesRowMenu(item: folder, onBrowseFolder: () {}, onAskAgent: () => asks += 1, onDownload: () {}),
          ),
        ),
      ),
    );

    final browseTop = tester.getTopLeft(find.text('Browse folder')).dy;
    final askTop = tester.getTopLeft(find.text('Ask agent')).dy;
    final downloadTop = tester.getTopLeft(find.text('Download as zip')).dy;
    expect(browseTop, lessThan(askTop));
    expect(askTop, lessThan(downloadTop));

    await tester.tap(find.text('Ask agent'));
    expect(asks, 1);
  });

  testWidgets('single selected folder does not expose Ask agent in the selection toolbar', (tester) async {
    final folder = _folder('design references/参考', 'Design references');
    final filterController = TextEditingController();
    addTearDown(filterController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 760,
            child: PbFilesMainPanel(
              currentPath: '',
              folderLabelForPath: (path) => path,
              items: [folder],
              selectedIds: {folder.id},
              sortKey: PbFilesSortKey.updated,
              sortDirectionDescending: true,
              filterController: filterController,
              filterEnabled: true,
              hasActiveFilter: false,
              roomPanelExpanded: false,
              responsiveMode: PbFilesResponsiveMode.docked,
              previewFileId: null,
              keyboardPreviewFileId: null,
              keyboardPreviewDirection: 0,
              savingIds: const {},
              onBreadcrumbPressed: (_) {},
              onSortChanged: (_) {},
              onFilterChanged: (_) {},
              onToggleSelection: (_) {},
              onToggleVisibleSelection: () {},
              onClearSelection: () {},
              onDeleteSelection: () {},
              onDownloadSelection: () {},
              onCreateFolder: () {},
              onCreateTextFile: () {},
              onUpload: () {},
              onFilesDropped: (_) {},
              onOpenRecentFiles: () {},
              onRoomPanelToggle: () {},
              onItemPressed: (_) {},
              onBrowseFolder: (_) {},
              onRemoveProcessingRow: (_) {},
              onLinkedThreadPressed: (_, _) {},
              showRoomPanelControls: false,
              enableDropTarget: false,
              onAskAgent: (_) => fail('Selection toolbar must not invoke Ask agent'),
            ),
          ),
        ),
      ),
    );

    expect(find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Ask agent'), findsNothing);
  });

  testWidgets('persistent Files toolbar asks about the Files root without a selection', (tester) async {
    final filterController = TextEditingController();
    addTearDown(filterController.dispose);
    var asks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 760,
            child: PbFilesMainPanel(
              currentPath: '',
              folderLabelForPath: (path) => path.isEmpty ? 'Files' : path.split('/').last,
              items: const [],
              selectedIds: const {},
              sortKey: PbFilesSortKey.updated,
              sortDirectionDescending: true,
              filterController: filterController,
              filterEnabled: true,
              hasActiveFilter: false,
              roomPanelExpanded: false,
              responsiveMode: PbFilesResponsiveMode.docked,
              previewFileId: null,
              keyboardPreviewFileId: null,
              keyboardPreviewDirection: 0,
              savingIds: const {},
              onBreadcrumbPressed: (_) {},
              onSortChanged: (_) {},
              onFilterChanged: (_) {},
              onToggleSelection: (_) {},
              onToggleVisibleSelection: () {},
              onClearSelection: () {},
              onDeleteSelection: () {},
              onDownloadSelection: () {},
              onCreateFolder: () {},
              onCreateTextFile: () {},
              onUpload: () {},
              onAskCurrentFolder: () => asks += 1,
              onFilesDropped: (_) {},
              onOpenRecentFiles: () {},
              onRoomPanelToggle: () {},
              onItemPressed: (_) {},
              onBrowseFolder: (_) {},
              onRemoveProcessingRow: (_) {},
              onLinkedThreadPressed: (_, _) {},
              showRoomPanelControls: false,
              enableDropTarget: false,
            ),
          ),
        ),
      ),
    );

    final askAgentFinder = find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Ask agent');
    expect(askAgentFinder, findsOneWidget);
    await tester.tap(askAgentFinder);
    expect(asks, 1);
  });
}
