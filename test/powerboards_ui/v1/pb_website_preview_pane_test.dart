import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_website_preview_pane.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_svg_icon.dart';

void main() {
  testWidgets('website preview pane uses webserver toolbar actions', (tester) async {
    var openedSite = 0;
    var downloadedZip = 0;
    var closed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PbWebsitePreviewPane(
            title: 'atomant.meshagent.dev',
            previewHtml: '<!doctype html><html><body>Atom Ant</body></html>',
            onOpenSite: () => openedSite += 1,
            onDownloadZip: () => downloadedZip += 1,
            onClose: () => closed += 1,
          ),
        ),
      ),
    );

    expect(find.text('atomant.meshagent.dev'), findsOneWidget);
    expect(find.text('Go to site'), findsOneWidget);
    expect(find.text('Download as ZIP'), findsOneWidget);
    expect(find.text('Ask agent'), findsNothing);
    expect(find.text('Download'), findsNothing);
    expect(find.byWidgetPredicate((widget) => widget is PbSvgIcon && widget.assetName == 'folder-code'), findsOneWidget);

    await tester.tap(find.text('Go to site'));
    await tester.tap(find.text('Download as ZIP'));
    await tester.tap(find.byWidgetPredicate((widget) => widget is PbSvgIcon && widget.assetName == 'x'));

    expect(openedSite, 1);
    expect(downloadedZip, 1);
    expect(closed, 1);
  });

  testWidgets('website preview pane accepts a live route preview url', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PbWebsitePreviewPane(title: 'spacer.meshagent.dev', previewUrl: Uri.parse('https://spacer.meshagent.dev/')),
        ),
      ),
    );

    expect(find.text('spacer.meshagent.dev'), findsOneWidget);
    expect(find.text('Go to site'), findsOneWidget);
    expect(find.text('Download as ZIP'), findsOneWidget);
  });
}
