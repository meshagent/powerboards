import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/meshagent/v1_file_preview_source.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_file_preview_state_card.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_room_panel.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_sidepane_item_menu.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';

final Uint8List _validPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABXUlEQVR4AZSQv2rCUBTGP28ITg4Gh/oQLrZLtVhLhW51sfUJKhg7C7bgIn0HM7kZC9WlLkWwW7v0Gdx0ypJMwWDScwpCLkkxXu7Hved85/fljwCtXC53pWnaVzarbUnBAW15lhlCIfiy2/kfQYBzaqikQ1vlWWaYFb7vvxCRBKQxaavMCko7k9pHFMzyP5Ce3mo9YDabSRqNRqhUKnHRKgdIRqFQQLV6Kalev8V0+oZSqSTNchEJ4GacFEVBs3kfsRIHMGnbNh+SEges12sMh4YEcxEJGI9NDAYD9Pt99HpPf9J1HeXyBTabDTOSIgGZTAbdbhftto75/B2GYWAyeYXjOBK4LyIBtdo10uk08vkTFIun+7l/Tw7wwi5/53K5hGmaWCwWYSvu7olUCj9hZ7VaodG4Q6fzCNd1w1bkzqyg9UyO9BZUJ9kes8KyrE9FETeU9k1UkiCPZ5lh9hcAAP//+EBhwQAAAAZJREFUAwCWWX4HYvwB8gAAAABJRU5ErkJggg==',
);
final Uint8List _validJpegBytes = base64Decode(
  '/9j/4AAQSkZJRgABAgAAAQABAAD//gAQTGF2YzYyLjI4LjEwMAD/2wBDAAgEBAQEBAUFBQUFBQYGBgYGBgYGBgYGBgYHBwcICAgHBwcGBgcHCAgICAkJCQgICAgJCQoKCgwMCwsODg4RERT/xABLAAEBAAAAAAAAAAAAAAAAAAAABwEBAAAAAAAAAAAAAAAAAAAAABABAAAAAAAAAAAAAAAAAAAAABEBAAAAAAAAAAAAAAAAAAAAAP/AABEIAAIAAgMBIgACEQADEQD/2gAMAwEAAhEDEQA/AL+AD//Z',
);

void main() {
  const file = PbAttachmentListItemData(title: 'pet-store-hero.jpg', subtitle: 'Image', fileType: PbAttachmentFileType.image);

  test('V1 JPEG structural validation distinguishes valid and malformed historical data', () {
    expect(powerboardsV1JpegDataIsStructurallyValid(_validJpegBytes), isTrue);
    expect(
      powerboardsV1JpegDataIsStructurallyValid(
        Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xc0, 0xa2, 0x0f, 0x08, 0x00, 0x10, 0x00, 0x10, 0x03, 0xff, 0xd9]),
      ),
      isFalse,
    );
  });

  testWidgets('V1 image preview renders a clean state for malformed historical raster bytes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: PowerboardsV1ImageDataPreview(
            data: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xc0, 0xa2, 0x0f, 0x08, 0x00, 0x10, 0x00, 0x10, 0x03, 0xff, 0xd9]),
            path: 'website/assets/pet-store-hero.jpg',
            fit: BoxFit.contain,
            file: file,
            mimeType: 'image/jpeg',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PbFilePreviewStateCard), findsOneWidget);
    expect(find.text('No preview available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('V1 malformed image uses the standard unavailable pane without image controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: PbFilePreviewPane(
              file: file,
              fullscreen: false,
              previewContentChild: PowerboardsV1ImageDataPreview(
                data: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xc0, 0xa2, 0x0f, 0x08, 0x00, 0x10, 0x00, 0x10, 0x03, 0xff, 0xd9]),
                path: 'website/assets/pet-store-hero.jpg',
                fit: BoxFit.contain,
                file: file,
                mimeType: 'image/jpeg',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No preview available'), findsOneWidget);
    expect(find.text('Fit'), findsNothing);
    expect(find.byType(PbFilePreviewStateCard), findsOneWidget);
  });

  testWidgets('V1 image preview renders valid uploaded raster bytes when stored MIME metadata is stale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: PowerboardsV1ImageDataPreview(
            data: _validPngBytes,
            path: 'uploads/photo.png',
            fit: BoxFit.contain,
            file: const PbAttachmentListItemData(title: 'photo.png', subtitle: 'Image', fileType: PbAttachmentFileType.image),
            mimeType: 'image/jpeg',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(PbFilePreviewStateCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('V1 image preview renders genuine uploaded JPEG bytes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: PowerboardsV1ImageDataPreview(
            data: _validJpegBytes,
            path: 'uploads/photo.jpg',
            fit: BoxFit.contain,
            file: const PbAttachmentListItemData(title: 'photo.jpg', subtitle: 'Image', fileType: PbAttachmentFileType.image),
            mimeType: 'image/jpeg',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(PbFilePreviewStateCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('V1 image preview shows an unavailable state for SVG filters', (tester) async {
    final data = Uint8List.fromList(
      utf8.encode('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <filter id="noise"><feTurbulence baseFrequency=".8"/></filter>
  <rect width="24" height="24" filter="url(#noise)"/>
</svg>
'''),
    );

    expect(powerboardsV1SvgContainsUnsupportedPreviewFeature(data), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: PowerboardsV1ImageDataPreview(
            data: data,
            path: 'website/assets/noise.svg',
            fit: BoxFit.contain,
            file: const PbAttachmentListItemData(title: 'noise.svg', subtitle: 'Image', fileType: PbAttachmentFileType.image),
            mimeType: 'image/svg+xml',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PbFilePreviewStateCard), findsOneWidget);
    expect(find.text('No preview available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('V1 valid JPEG keeps controls and the download menu available', (tester) async {
    var downloadCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 600,
            child: PbFilePreviewPane(
              file: file,
              fullscreen: false,
              onDownload: () => downloadCount += 1,
              previewContentChild: PowerboardsV1ImageDataPreview(
                data: _validJpegBytes,
                path: 'website/assets/pet-store-hero.jpg',
                fit: BoxFit.contain,
                file: file,
                mimeType: 'image/jpeg',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('No preview available'), findsNothing);
    expect(find.text('Fit'), findsOneWidget);
    expect(find.byType(PbSidepaneItemMenu), findsOneWidget);

    final downloadMenu = tester.widget<PbSidepaneItemMenu>(find.byType(PbSidepaneItemMenu));
    await tester.pumpWidget(MaterialApp(home: downloadMenu.panelBuilder(() {})));
    await tester.tap(find.text('Download'));

    expect(downloadCount, 1);
    expect(tester.takeException(), isNull);
  });
}
