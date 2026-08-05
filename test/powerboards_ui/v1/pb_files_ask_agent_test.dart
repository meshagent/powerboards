import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/meshagent/file_table_view.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_file_menus.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_data.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_layout_values.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_files_page.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_button.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_svg_icon.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_menu_option.dart';

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
  test('folder Ask agent preserves open and closed side pane states', () {
    for (final initialPaneOpen in [false, true]) {
      for (final responsiveHandoff in [false, true]) {
        var paneOpen = initialPaneOpen;
        if (powerboardsV1FilePromptShouldCleanupSurfaces(isFolder: true, responsiveHandoff: responsiveHandoff)) {
          paneOpen = false;
        }

        expect(paneOpen, initialPaneOpen, reason: 'responsiveHandoff: $responsiveHandoff');
      }
    }
  });

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

  testWidgets('folder row menu exposes Move to when it is wired', (tester) async {
    final folder = _folder('design references', 'Design references');
    var moves = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: PbFilesRowMenu(item: folder, onBrowseFolder: () {}, onMoveTo: () => moves += 1, onDelete: () {}),
          ),
        ),
      ),
    );

    final moveOption = find.byWidgetPredicate((widget) => widget is PbMenuOption && widget.title == 'Move to...');
    expect(moveOption, findsOneWidget);
    expect(tester.widget<PbMenuOption>(moveOption).leadingIconAssetName, 'folder-symlink');
    expect(
      find.descendant(
        of: moveOption,
        matching: find.byWidgetPredicate((widget) => widget is PbSvgIcon && widget.assetName == 'folder-symlink'),
      ),
      findsOneWidget,
    );
    await rootBundle.load('lib/powerboards_ui/v1/assets/icons/folder-symlink.svg');
    await tester.tap(find.text('Move to...'));
    expect(moves, 1);
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
