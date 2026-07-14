import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_button.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_header.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_layout_values.dart';
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
    bool showWebServerPreview = false,
    bool webServerPreviewActive = false,
    VoidCallback? onPreviewWebServer,
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
                hasSelection: false,
                selectedCount: 0,
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
                showWebServerPreview: showWebServerPreview,
                webServerPreviewActive: webServerPreviewActive,
                onPreviewWebServer: onPreviewWebServer,
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

  testWidgets('files toolbar shows direct root actions outside mobile mode', (tester) async {
    var folderCreates = 0;
    var webServerInstalls = 0;
    var textFileCreates = 0;
    var uploads = 0;

    await pumpToolbar(
      tester,
      width: 900,
      responsiveMode: PbFilesResponsiveMode.docked,
      currentPath: '',
      onCreateFolder: () => folderCreates += 1,
      onInstallWebServer: () => webServerInstalls += 1,
      onCreateTextFile: () => textFileCreates += 1,
      onUpload: () => uploads += 1,
    );

    expect(find.text('New folder'), findsOneWidget);
    expect(find.text('New text file'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('New website'), findsOneWidget);
    expect(find.text('Preview'), findsNothing);
    expect(find.text('Create'), findsNothing);

    await tester.tap(find.text('New folder'));
    await tester.tap(find.text('New text file'));
    await tester.tap(find.text('Upload'));
    await tester.tap(find.text('New website'));

    expect(folderCreates, 1);
    expect(webServerInstalls, 1);
    expect(textFileCreates, 1);
    expect(uploads, 1);
  });

  testWidgets('files toolbar uses stacked direct actions in shell-mobile overlay mode', (tester) async {
    var folderCreates = 0;
    var webServerInstalls = 0;
    var textFileCreates = 0;
    var uploads = 0;

    await pumpToolbar(
      tester,
      width: 560,
      responsiveMode: PbFilesResponsiveMode.overlay,
      currentPath: '',
      onCreateFolder: () => folderCreates += 1,
      onInstallWebServer: () => webServerInstalls += 1,
      onCreateTextFile: () => textFileCreates += 1,
      onUpload: () => uploads += 1,
    );

    expect(find.text('Create'), findsNothing);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('New text file'), findsOneWidget);
    expect(find.text('New website'), findsOneWidget);
    expect(find.text('Preview'), findsNothing);

    await tester.tap(find.text('New folder'));
    await tester.tap(find.text('New text file'));
    await tester.tap(find.text('Upload'));
    await tester.tap(find.text('New website'));

    expect(folderCreates, 1);
    expect(webServerInstalls, 1);
    expect(textFileCreates, 1);
    expect(uploads, 1);
  });

  testWidgets('files toolbar uses stacked direct actions in mobile mode', (tester) async {
    var folderCreates = 0;
    var webServerInstalls = 0;
    var textFileCreates = 0;
    var uploads = 0;

    await pumpToolbar(
      tester,
      width: 560,
      responsiveMode: PbFilesResponsiveMode.mobile,
      currentPath: '',
      onCreateFolder: () => folderCreates += 1,
      onInstallWebServer: () => webServerInstalls += 1,
      onCreateTextFile: () => textFileCreates += 1,
      onUpload: () => uploads += 1,
    );

    expect(find.text('Create'), findsNothing);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('New text file'), findsOneWidget);
    expect(find.text('New website'), findsOneWidget);
    expect(find.text('Preview'), findsNothing);

    await tester.tap(find.text('New folder'));
    await tester.tap(find.text('New text file'));
    await tester.tap(find.text('Upload'));
    await tester.tap(find.text('New website'));

    expect(folderCreates, 1);
    expect(webServerInstalls, 1);
    expect(textFileCreates, 1);
    expect(uploads, 1);
  });

  testWidgets('files toolbar hides install web server away from the Files root', (tester) async {
    var folderCreates = 0;

    await pumpToolbar(
      tester,
      width: 900,
      responsiveMode: PbFilesResponsiveMode.docked,
      currentPath: 'nested',
      onCreateFolder: () => folderCreates += 1,
      onCreateTextFile: () {},
      onUpload: () {},
    );

    await tester.tap(find.text('New folder'));
    await tester.pump();

    expect(folderCreates, 1);
    expect(find.text('New website'), findsNothing);
    expect(find.text('Preview'), findsNothing);
    expect(find.text('Create'), findsNothing);
  });

  testWidgets('files toolbar shows an active web server preview action at the website root', (tester) async {
    var previews = 0;

    await pumpToolbar(
      tester,
      width: 900,
      responsiveMode: PbFilesResponsiveMode.docked,
      currentPath: 'website',
      onCreateFolder: () {},
      onCreateTextFile: () {},
      onUpload: () {},
      showWebServerPreview: true,
      webServerPreviewActive: true,
      onPreviewWebServer: () => previews += 1,
    );

    expect(find.text('New website'), findsNothing);
    expect(find.text('Preview'), findsOneWidget);

    final uploadRect = tester.getRect(find.text('Upload'));
    final previewRect = tester.getRect(find.text('Preview'));
    final filterRect = tester.getRect(find.text('Filter...'));
    expect(uploadRect.left, lessThan(previewRect.left));
    expect(previewRect.left, lessThan(filterRect.left));

    final previewButton = tester.widget<PbButton>(find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Preview'));
    expect(previewButton.onPressed, isNotNull);
    expect(previewButton.backgroundColor, PbColors.statusOnline);

    await tester.tap(find.text('Preview'));
    expect(previews, 1);
  });

  testWidgets('files toolbar collapses preview before primary actions can crowd the filter', (tester) async {
    await pumpToolbar(
      tester,
      width: 760,
      responsiveMode: PbFilesResponsiveMode.docked,
      currentPath: 'website',
      onCreateFolder: () {},
      onCreateTextFile: () {},
      onUpload: () {},
      showWebServerPreview: true,
      webServerPreviewActive: true,
      onPreviewWebServer: () {},
    );

    expect(tester.takeException(), isNull);
    expect(find.text('New folder'), findsOneWidget);
    expect(find.text('New text file'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Preview'), findsNothing);
    expect(find.text('Filter...'), findsOneWidget);
  });

  testWidgets('files toolbar keeps primary actions in one row before preview on mobile', (tester) async {
    await pumpToolbar(
      tester,
      width: 560,
      responsiveMode: PbFilesResponsiveMode.mobile,
      currentPath: 'website',
      onCreateFolder: () {},
      onCreateTextFile: () {},
      onUpload: () {},
      showWebServerPreview: true,
      webServerPreviewActive: true,
      onPreviewWebServer: () {},
    );

    expect(tester.takeException(), isNull);

    final folderRect = tester.getRect(find.text('New folder'));
    final textFileRect = tester.getRect(find.text('New text file'));
    final uploadRect = tester.getRect(find.text('Upload'));
    final previewRect = tester.getRect(find.text('Preview'));
    final filterRect = tester.getRect(find.text('Filter...'));

    expect(folderRect.top, textFileRect.top);
    expect(textFileRect.top, uploadRect.top);
    expect(folderRect.right, lessThan(textFileRect.left));
    expect(textFileRect.right, lessThan(uploadRect.left));
    expect(previewRect.top, greaterThan(uploadRect.bottom));
    expect(filterRect.top, greaterThan(previewRect.bottom));
  });

  testWidgets('files toolbar shows a disabled web server preview action when the site is not ready', (tester) async {
    await pumpToolbar(
      tester,
      width: 900,
      responsiveMode: PbFilesResponsiveMode.docked,
      currentPath: 'website',
      onCreateFolder: () {},
      onCreateTextFile: () {},
      onUpload: () {},
      showWebServerPreview: true,
      webServerPreviewActive: false,
    );

    final previewButton = tester.widget<PbButton>(find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Preview'));
    expect(previewButton.onPressed, isNull);
    expect(previewButton.backgroundColor, PbColors.surfacePanelSoft);
  });

  testWidgets('files toolbar hides web server preview away from the website root', (tester) async {
    await pumpToolbar(
      tester,
      width: 900,
      responsiveMode: PbFilesResponsiveMode.docked,
      currentPath: 'website/assets',
      onCreateFolder: () {},
      onCreateTextFile: () {},
      onUpload: () {},
    );

    expect(find.text('Preview'), findsNothing);
  });
}
