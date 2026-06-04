import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_header.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_layout_values.dart';

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
}
