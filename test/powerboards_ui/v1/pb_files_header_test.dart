import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_header.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_layout_values.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_button.dart';

void main() {
  String labelForPath(String path) {
    return switch (path) {
      'design-references' => 'Design references',
      'design-references/brand-direction' => 'Brand direction',
      'design-references/brand-direction/hero-references' => 'Hero references',
      'design-references/brand-direction/hero-references/preview-real-file-samples-with-a-very-long-final-location' =>
        'Preview real file samples with a very long final location',
      _ => path,
    };
  }

  testWidgets('collapses file breadcrumbs before truncating visible path segments', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              child: PbFilesHeader(
                currentPath: 'design-references/brand-direction/hero-references',
                folderLabelForPath: labelForPath,
                roomPanelExpanded: true,
                padding: const PbFilesPanelPadding(left: 0, right: 0),
                showRoomPanelControls: false,
                onBreadcrumbPressed: (_) {},
                onOpenRecentFiles: () {},
                onRoomPanelToggle: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Design references'), findsNothing);
    expect(find.text('Brand direction'), findsNothing);
    expect(find.text('Hero references'), findsOneWidget);

    final currentLabel = tester.renderObject<RenderParagraph>(find.text('Hero references'));
    expect(currentLabel.didExceedMaxLines, isFalse);
  });

  testWidgets('truncates the final breadcrumb when collapsed path still has no room', (tester) async {
    const currentPath = 'design-references/brand-direction/hero-references/preview-real-file-samples-with-a-very-long-final-location';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 520,
              child: PbFilesHeader(
                currentPath: currentPath,
                folderLabelForPath: labelForPath,
                roomPanelExpanded: false,
                padding: const PbFilesPanelPadding(left: 0, right: 0),
                showRoomPanelControls: true,
                onBreadcrumbPressed: (_) {},
                onOpenRecentFiles: () {},
                onRoomPanelToggle: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Design references'), findsNothing);
    expect(find.text('Brand direction'), findsNothing);
    expect(find.text('Hero references'), findsNothing);
    expect(find.text('Preview real file samples with a very long final location'), findsOneWidget);

    final header = tester.getRect(find.byType(PbFilesHeader));
    final currentLabel = tester.renderObject<RenderParagraph>(find.text('Preview real file samples with a very long final location'));
    final currentLabelRect = tester.getRect(find.text('Preview real file samples with a very long final location'));

    expect(currentLabel.didExceedMaxLines, isTrue);
    expect(currentLabelRect.right, lessThanOrEqualTo(header.right));
  });

  Future<void> pumpToolbar(
    WidgetTester tester, {
    required double width,
    required PbFilesResponsiveMode responsiveMode,
    required VoidCallback onCreateFolder,
    required VoidCallback onCreateTextFile,
    required VoidCallback onUpload,
  }) async {
    final filterController = TextEditingController();
    addTearDown(filterController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: PbFilesToolbar(
                hasSelection: false,
                selectedCount: 0,
                filterController: filterController,
                filterEnabled: true,
                responsiveMode: responsiveMode,
                padding: const PbFilesPanelPadding(left: 0, right: 0),
                onFilterChanged: (_) {},
                onCreateFolder: onCreateFolder,
                onCreateTextFile: onCreateTextFile,
                onUpload: onUpload,
                onClearSelection: () {},
                onDeleteSelection: () {},
                onDownloadSelection: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('files toolbar splits create actions outside mobile mode', (tester) async {
    var folderCreates = 0;
    var textFileCreates = 0;
    var uploads = 0;

    await pumpToolbar(
      tester,
      width: 900,
      responsiveMode: PbFilesResponsiveMode.docked,
      onCreateFolder: () => folderCreates += 1,
      onCreateTextFile: () => textFileCreates += 1,
      onUpload: () => uploads += 1,
    );

    expect(find.text('Create'), findsNothing);
    expect(find.text('New folder'), findsOneWidget);
    expect(find.text('New text file'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);

    await tester.tap(find.text('New folder'));
    await tester.tap(find.text('New text file'));
    await tester.tap(find.text('Upload'));

    expect(folderCreates, 1);
    expect(textFileCreates, 1);
    expect(uploads, 1);
  });

  testWidgets('files toolbar keeps split icon actions for cramped non-mobile mode', (tester) async {
    var folderCreates = 0;
    var textFileCreates = 0;
    var uploads = 0;

    await pumpToolbar(
      tester,
      width: 560,
      responsiveMode: PbFilesResponsiveMode.overlay,
      onCreateFolder: () => folderCreates += 1,
      onCreateTextFile: () => textFileCreates += 1,
      onUpload: () => uploads += 1,
    );

    expect(find.text('Create'), findsNothing);
    expect(find.text('New folder'), findsNothing);
    expect(find.text('New text file'), findsNothing);
    expect(find.text('Upload'), findsNothing);

    final newFolderButton = find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'New folder' && widget.iconOnly);
    final newTextFileButton = find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'New text file' && widget.iconOnly);
    final uploadButton = find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Upload' && widget.iconOnly);

    expect(newFolderButton, findsOneWidget);
    expect(newTextFileButton, findsOneWidget);
    expect(uploadButton, findsOneWidget);

    await tester.tap(newFolderButton);
    await tester.tap(newTextFileButton);
    await tester.tap(uploadButton);

    expect(folderCreates, 1);
    expect(textFileCreates, 1);
    expect(uploads, 1);
  });

  testWidgets('files toolbar keeps combined create menu in mobile mode', (tester) async {
    var folderCreates = 0;
    var textFileCreates = 0;

    await pumpToolbar(
      tester,
      width: 560,
      responsiveMode: PbFilesResponsiveMode.mobile,
      onCreateFolder: () => folderCreates += 1,
      onCreateTextFile: () => textFileCreates += 1,
      onUpload: () {},
    );

    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('New folder'), findsNothing);
    expect(find.text('New text file'), findsNothing);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('New folder'), findsOneWidget);
    expect(find.text('New text file'), findsOneWidget);

    await tester.tap(find.text('New folder'));
    await tester.pumpAndSettle();
    expect(folderCreates, 1);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New text file'));
    await tester.pumpAndSettle();
    expect(textFileCreates, 1);
  });
}
