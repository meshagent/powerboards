import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_data.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_layout_values.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_files_page.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_svg_icon.dart';

void main() {
  Future<void> pumpMainPanel(
    WidgetTester tester, {
    required String currentPath,
    bool showWebServerPreview = false,
    bool hasActiveFilter = false,
  }) async {
    final filterController = TextEditingController();
    addTearDown(filterController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 900,
            child: PbFilesMainPanel(
              currentPath: currentPath,
              folderLabelForPath: (path) => path,
              items: const <PbFilesItemData>[],
              selectedIds: const <String>{},
              sortKey: PbFilesSortKey.updated,
              sortDirectionDescending: true,
              filterController: filterController,
              filterEnabled: false,
              hasActiveFilter: hasActiveFilter,
              roomPanelExpanded: false,
              responsiveMode: PbFilesResponsiveMode.docked,
              previewFileId: null,
              keyboardPreviewFileId: null,
              keyboardPreviewDirection: 0,
              savingIds: const <String>{},
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
              showWebServerPreview: showWebServerPreview,
              onFilesDropped: (_) {},
              onOpenRecentFiles: () {},
              onRoomPanelToggle: () {},
              onItemPressed: (_) {},
              onBrowseFolder: (_) {},
              onRemoveProcessingRow: (_) {},
              onLinkedThreadPressed: (_, thread) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('main panel hardcodes the website landing empty state at the website root', (tester) async {
    await pumpMainPanel(tester, currentPath: 'website', showWebServerPreview: true);

    expect(find.text('Add files here'), findsOneWidget);
    expect(find.text('No files here yet. Add code or docs to edit and preview as a site or app.'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is PbSvgIcon && widget.assetName == 'website-empty-state'), findsOneWidget);
  });

  testWidgets('main panel keeps the website landing empty state during preview flag refreshes', (tester) async {
    await pumpMainPanel(tester, currentPath: 'website');

    expect(find.text('Add files here'), findsOneWidget);
    expect(find.text('No files here yet. Add code or docs to edit and preview as a site or app.'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is PbSvgIcon && widget.assetName == 'website-empty-state'), findsOneWidget);
  });

  testWidgets('main panel keeps generic empty state for nested website folders', (tester) async {
    await pumpMainPanel(tester, currentPath: 'website/assets');

    expect(find.text('Add files here'), findsOneWidget);
    expect(find.text('No files here yet. Start adding documents and media to share, or discuss.'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is PbSvgIcon && widget.assetName == 'image'), findsOneWidget);
  });

  testWidgets('main panel keeps the no-results empty state when the website root is filtered', (tester) async {
    await pumpMainPanel(tester, currentPath: 'website', showWebServerPreview: true, hasActiveFilter: true);

    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('No results here yet. Clear the filter or try a different keyword.'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is PbSvgIcon && widget.assetName == 'logs'), findsOneWidget);
  });
}
