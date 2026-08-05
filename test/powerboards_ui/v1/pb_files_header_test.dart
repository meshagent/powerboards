import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_header.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_layout_values.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_button.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';

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
    String currentPath = '',
    required VoidCallback onCreateFolder,
    VoidCallback? onInstallWebServer,
    required VoidCallback onCreateTextFile,
    required VoidCallback onUpload,
    VoidCallback? onAskCurrentFolder,
    PbFilesToolbarTrailingAction? trailingAction,
    bool showWebServerPreview = false,
    bool webServerPreviewActive = false,
    VoidCallback? onPreviewWebServer,
    bool hasSelection = false,
    int selectedCount = 0,
    VoidCallback? onMoveSelection,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
                hasSelection: hasSelection,
                selectedCount: selectedCount,
                currentPath: currentPath,
                filterController: filterController,
                filterEnabled: true,
                responsiveMode: responsiveMode,
                padding: const PbFilesPanelPadding(left: 0, right: 0),
                onFilterChanged: (_) {},
                onCreateFolder: onCreateFolder,
                onInstallWebServer: onInstallWebServer,
                onCreateTextFile: onCreateTextFile,
                onUpload: onUpload,
                onAskCurrentFolder: onAskCurrentFolder,
                trailingAction: trailingAction,
                showWebServerPreview: showWebServerPreview,
                webServerPreviewActive: webServerPreviewActive,
                onPreviewWebServer: onPreviewWebServer,
                onClearSelection: () {},
                onMoveSelection: onMoveSelection,
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
    expect(find.text('Ask agent'), findsOneWidget);

    await tester.tap(find.text('New folder'));
    await tester.tap(find.text('New text file'));
    await tester.tap(find.text('Upload'));

    expect(folderCreates, 1);
    expect(textFileCreates, 1);
    expect(uploads, 1);
  });

  testWidgets('files toolbar runs Ask agent for the currently viewed folder', (tester) async {
    var asks = 0;

    await pumpToolbar(
      tester,
      width: 1080,
      responsiveMode: PbFilesResponsiveMode.docked,
      onCreateFolder: () {},
      onCreateTextFile: () {},
      onUpload: () {},
      onAskCurrentFolder: () => asks += 1,
    );

    final askAgentFinder = find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Ask agent');
    expect(askAgentFinder, findsOneWidget);
    await tester.tap(askAgentFinder);
    expect(asks, 1);
  });

  testWidgets('files toolbar keeps Ask agent immediately before a trailing website action', (tester) async {
    var asks = 0;
    var websites = 0;

    await pumpToolbar(
      tester,
      width: 1080,
      responsiveMode: PbFilesResponsiveMode.docked,
      onCreateFolder: () {},
      onCreateTextFile: () {},
      onUpload: () {},
      onAskCurrentFolder: () => asks += 1,
      trailingAction: PbFilesToolbarTrailingAction(label: 'New website', iconAssetName: 'folder-plus', onPressed: () => websites += 1),
    );

    final uploadRect = tester.getRect(find.text('Upload'));
    final askRect = tester.getRect(find.text('Ask agent'));
    final websiteRect = tester.getRect(find.text('New website'));
    final filterRect = tester.getRect(find.text('Filter...'));
    expect(uploadRect.left, lessThan(askRect.left));
    expect(askRect.left, lessThan(websiteRect.left));
    expect(websiteRect.left, lessThan(filterRect.left));
    expect(askRect.top, websiteRect.top);

    await tester.tap(find.text('Ask agent'));
    await tester.tap(find.text('New website'));
    expect(asks, 1);
    expect(websites, 1);
  });

  testWidgets('five-action toolbar combines creation actions before crowding the filter', (tester) async {
    var folderCreates = 0;

    await pumpToolbar(
      tester,
      width: 900,
      responsiveMode: PbFilesResponsiveMode.docked,
      onCreateFolder: () => folderCreates += 1,
      onCreateTextFile: () {},
      onUpload: () {},
      onAskCurrentFolder: () {},
      trailingAction: const PbFilesToolbarTrailingAction(label: 'New website', iconAssetName: 'folder-plus', onPressed: null),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('New folder'), findsNothing);
    expect(find.text('New text file'), findsNothing);

    final createRect = tester.getRect(find.text('Create'));
    final uploadRect = tester.getRect(find.text('Upload'));
    final askRect = tester.getRect(find.text('Ask agent'));
    final websiteRect = tester.getRect(find.text('New website'));
    final filterRect = tester.getRect(find.text('Filter...'));
    expect(createRect.left, lessThan(uploadRect.left));
    expect(uploadRect.left, lessThan(askRect.left));
    expect(askRect.left, lessThan(websiteRect.left));
    expect(websiteRect.left, lessThan(filterRect.left));
    expect((createRect.center.dy - filterRect.center.dy).abs(), lessThanOrEqualTo(1));

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New folder'));
    await tester.pumpAndSettle();
    expect(folderCreates, 1);
  });

  testWidgets('five-action toolbar progressively compacts buttons without wrapping the filter', (tester) async {
    await pumpToolbar(
      tester,
      width: 650,
      responsiveMode: PbFilesResponsiveMode.docked,
      onCreateFolder: () {},
      onCreateTextFile: () {},
      onUpload: () {},
      onAskCurrentFolder: () {},
      trailingAction: const PbFilesToolbarTrailingAction(label: 'New website', iconAssetName: 'folder-plus', onPressed: null),
    );

    expect(tester.takeException(), isNull);
    final createButton = find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Create');
    final uploadButton = find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Upload');
    final askButton = find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Ask agent');
    final websiteButton = find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'New website');
    expect(createButton, findsOneWidget);
    expect(uploadButton, findsOneWidget);
    expect(askButton, findsOneWidget);
    expect(websiteButton, findsOneWidget);

    final createRect = tester.getRect(createButton);
    final uploadRect = tester.getRect(uploadButton);
    final askRect = tester.getRect(askButton);
    final websiteRect = tester.getRect(websiteButton);
    final filterRect = tester.getRect(find.text('Filter...'));
    expect(createRect.left, lessThan(uploadRect.left));
    expect(uploadRect.left, lessThan(askRect.left));
    expect(askRect.left, lessThan(websiteRect.left));
    expect(websiteRect.left, lessThan(filterRect.left));
    expect((websiteRect.center.dy - filterRect.center.dy).abs(), lessThanOrEqualTo(1));
  });

  testWidgets('stacked v1 toolbar includes the trailing website action after Ask agent', (tester) async {
    await pumpToolbar(
      tester,
      width: 560,
      responsiveMode: PbFilesResponsiveMode.overlay,
      onCreateFolder: () {},
      onCreateTextFile: () {},
      onUpload: () {},
      onAskCurrentFolder: () {},
      trailingAction: const PbFilesToolbarTrailingAction(label: 'New website', iconAssetName: 'folder-plus', onPressed: null),
    );

    expect(tester.takeException(), isNull);
    final createRect = tester.getRect(find.text('Create'));
    final uploadRect = tester.getRect(find.text('Upload'));
    final askRect = tester.getRect(find.text('Ask agent'));
    final websiteRect = tester.getRect(find.text('New website'));
    final filterRect = tester.getRect(find.text('Filter...'));
    expect(createRect.top, uploadRect.top);
    expect(uploadRect.top, askRect.top);
    expect(askRect.top, websiteRect.top);
    expect(createRect.left, lessThan(uploadRect.left));
    expect(uploadRect.left, lessThan(askRect.left));
    expect(askRect.left, lessThan(websiteRect.left));
    expect(filterRect.top, greaterThan(websiteRect.bottom));
  });

  testWidgets('files toolbar uses wide create actions in shell-mobile overlay mode', (tester) async {
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

    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Ask agent'), findsOneWidget);
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

    await tester.tap(find.text('Upload'));

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
    expect(find.text('Ask agent'), findsOneWidget);
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

  testWidgets('files toolbar hides Ask agent for a single selection', (tester) async {
    await pumpToolbar(
      tester,
      width: 900,
      responsiveMode: PbFilesResponsiveMode.docked,
      onCreateFolder: () {},
      onCreateTextFile: () {},
      onUpload: () {},
      hasSelection: true,
      selectedCount: 1,
    );

    expect(find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Ask agent'), findsNothing);
  });

  testWidgets('files toolbar hides Ask agent for multiple selections', (tester) async {
    await pumpToolbar(
      tester,
      width: 900,
      responsiveMode: PbFilesResponsiveMode.docked,
      onCreateFolder: () {},
      onCreateTextFile: () {},
      onUpload: () {},
      hasSelection: true,
      selectedCount: 2,
    );

    expect(find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Ask agent'), findsNothing);
  });

  testWidgets('files toolbar exposes Move to in Flutter spec order', (tester) async {
    var moves = 0;
    await pumpToolbar(
      tester,
      width: 900,
      responsiveMode: PbFilesResponsiveMode.docked,
      onCreateFolder: () {},
      onCreateTextFile: () {},
      onUpload: () {},
      hasSelection: true,
      selectedCount: 2,
      onMoveSelection: () => moves += 1,
    );

    final moveButton = find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Move to');
    expect(moveButton, findsOneWidget);
    final deselectButton = find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Deselect');
    final downloadButton = find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Download');
    final deleteButton = find.text('Delete');
    expect(tester.getTopLeft(deselectButton).dx, lessThan(tester.getTopLeft(moveButton).dx));
    expect(tester.getTopLeft(moveButton).dx, lessThan(tester.getTopLeft(downloadButton).dx));
    expect(tester.getTopLeft(downloadButton).dx, lessThan(tester.getTopLeft(deleteButton).dx));

    await tester.tap(moveButton);
    expect(moves, 1);
  });

  testWidgets('files toolbar exposes the website install action only at the Files root', (tester) async {
    var installs = 0;
    await pumpToolbar(
      tester,
      width: 1080,
      responsiveMode: PbFilesResponsiveMode.docked,
      onCreateFolder: () {},
      onInstallWebServer: () => installs += 1,
      onCreateTextFile: () {},
      onUpload: () {},
    );

    await tester.tap(find.text('New website'));
    expect(installs, 1);

    await pumpToolbar(
      tester,
      width: 1080,
      responsiveMode: PbFilesResponsiveMode.docked,
      currentPath: 'nested',
      onCreateFolder: () {},
      onInstallWebServer: () => installs += 1,
      onCreateTextFile: () {},
      onUpload: () {},
    );
    expect(find.text('New website'), findsNothing);
  });

  testWidgets('files toolbar styles and invokes the active website preview action', (tester) async {
    var previews = 0;
    await pumpToolbar(
      tester,
      width: 1080,
      responsiveMode: PbFilesResponsiveMode.docked,
      currentPath: 'website',
      onCreateFolder: () {},
      onCreateTextFile: () {},
      onUpload: () {},
      showWebServerPreview: true,
      webServerPreviewActive: true,
      onPreviewWebServer: () => previews += 1,
    );

    final previewFinder = find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Preview');
    final previewButton = tester.widget<PbButton>(previewFinder);
    expect(previewButton.backgroundColor, PbColors.statusOnline);
    await tester.tap(previewFinder);
    expect(previews, 1);
  });
}
