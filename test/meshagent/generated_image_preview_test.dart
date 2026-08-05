import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/generated_image_preview.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_room_panel.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _NoopProtocolChannel extends ProtocolChannel {
  @override
  void dispose() {}

  @override
  Future<void> sendData(Uint8List data) async {}

  @override
  void start(void Function(Uint8List data) onDataReceived, {void Function()? onDone, void Function(Object? error)? onError}) {}
}

void main() {
  testWidgets('V1 generated image completion actions expose save and copy prompt', (tester) async {
    var saves = 0;
    var copies = 0;

    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(
          body: PowerboardsV1GeneratedImageCompletionActions(onSaveCopy: () => saves += 1, onCopyPrompt: () => copies += 1),
        ),
      ),
    );

    expect(find.text('Save a copy'), findsOneWidget);
    expect(find.text('Copy prompt'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('generated-image-save-copy-action')));
    await tester.tap(find.byKey(const ValueKey('generated-image-copy-prompt-action')));
    expect(saves, 1);
    expect(copies, 1);
  });

  test('partial and completed frames retain one preview identity while changing content revisions', () {
    const partial = PowerboardsV1GeneratedImagePreview(
      generationId: 'generation-1',
      uri: 'data:image/png;base64,partial',
      mimeType: 'image/png',
      status: 'in_progress',
    );
    const completed = PowerboardsV1GeneratedImagePreview(
      generationId: 'generation-1',
      uri: 'data:image/png;base64,completed',
      mimeType: 'image/png',
      status: 'completed',
    );

    expect(partial.sourceKey, completed.sourceKey);
    expect(partial.contentKey, isNot(completed.contentKey));
    expect(partial.file.path, isNull);
    expect(completed.file.path, isNull);
    expect(partial.file.title, 'Generating image…');
    expect(completed.file.title, 'Generated image');
    expect(partial.file.subtitle, 'Generating image');
    expect(completed.file.subtitle, 'Generated image');
  });

  test('generated artifact list items use a prompt-derived title without becoming stored files', () {
    const partial = PowerboardsV1GeneratedImagePreview(
      generationId: 'generation-1',
      status: 'in_progress',
      sourcePrompt: '  Please create an image of a dinosaur chasing a taxi in New York.  ',
      prompt: 'Create a cinematic, photorealistic dinosaur chasing a taxi through New York.',
    );
    const completed = PowerboardsV1GeneratedImagePreview(
      generationId: 'generation-1',
      status: 'completed',
      sourcePrompt: 'Please create an image of a dinosaur chasing a taxi in New York.',
      prompt: 'Create a cinematic, photorealistic dinosaur chasing a taxi through New York.',
    );

    expect(partial.sidepaneFile.title, 'Generating image…');
    expect(partial.sidepaneFile.subtitle, 'Generating image…');
    expect(partial.sidepaneFile.isLoading, isTrue);
    expect(completed.sidepaneFile.title, 'Dinosaur in New York');
    expect(completed.sidepaneFile.subtitle, 'Generated image · Preview and save a copy to Files');
    expect(completed.sidepaneFile.isLoading, isFalse);
    expect(partial.sidepaneFile.sourceKey, completed.sidepaneFile.sourceKey);
    expect(partial.sidepaneFile.path, isNull);
    expect(completed.sidepaneFile.path, isNull);
    expect(completed.sidepaneFile.showAskAgentAction, isFalse);
    expect(completed.sidepaneFile.showSaveCopyAsAction, isTrue);
    expect(completed.file.showAskAgentAction, isFalse);
    expect(completed.file.showSaveCopyAsAction, isTrue);
    expect(completed.file.title, 'Dinosaur in New York');
    expect(completed.suggestedFileName, 'generated-image.png');
    expect(completed.suggestedSaveCopyFileName, 'dinosaur-in-new-york.png');
  });

  test('each generated artifact keeps its own prompt label and stable generation identity', () {
    const elephant = PowerboardsV1GeneratedImagePreview(
      generationId: 'generation-elephant',
      imageId: 'image-elephant',
      status: 'completed',
      sourcePrompt: 'Please create an image of an elephant walking the streets of New York.',
      prompt: 'An elephant walking through New York City.',
    );
    const dog = PowerboardsV1GeneratedImagePreview(
      generationId: 'generation-dog',
      imageId: 'image-dog',
      status: 'completed',
      sourcePrompt: 'Please create an image of the giant purple dog walking the streets of New York.',
      prompt: 'A giant purple dog walking through New York City.',
    );

    expect(elephant.identityKey, 'generation:generation-elephant');
    expect(dog.identityKey, 'generation:generation-dog');
    expect(elephant.sidepaneFile.title, 'Elephant in New York');
    expect(dog.sidepaneFile.title, 'Purple dog in New York');
    expect(elephant.sidepaneFile.title, isNot(dog.sidepaneFile.title));
    expect(dog.file.title, dog.sidepaneFile.title);
    expect(dog.suggestedSaveCopyFileName, 'purple-dog-in-new-york.png');
    expect(dog.prompt, 'A giant purple dog walking through New York City.');
  });

  test('late prompt enrichment changes the card label without changing image content identity', () {
    const beforePrompt = PowerboardsV1GeneratedImagePreview(generationId: 'generation-1', imageId: 'image-1', status: 'completed');
    const afterPrompt = PowerboardsV1GeneratedImagePreview(
      generationId: 'generation-1',
      imageId: 'image-1',
      status: 'completed',
      sourcePrompt: 'Please create an image of a giant purple dog in New York.',
      prompt: 'A giant purple dog walking through New York City.',
    );

    expect(beforePrompt.identityKey, afterPrompt.identityKey);
    expect(beforePrompt.contentKey, afterPrompt.contentKey);
    expect(beforePrompt.sidepaneFile.title, 'Generated image');
    expect(afterPrompt.sidepaneFile.title, 'Purple dog in New York');
  });

  test('generated artifact labels remove shared style prose and fall back safely', () {
    expect(powerboardsV1GeneratedImageArtifactLabel(), 'Generated image');
    expect(
      powerboardsV1GeneratedImageArtifactLabel(
        sourcePrompt: 'Please create an image of a pack of elephants running down a busy street of new york.',
        computedPrompt: 'A cinematic herd of elephants charges through a Manhattan avenue in broad daylight with yellow taxis nearby.',
      ),
      'Pack of elephants in New York',
    );
    expect(
      powerboardsV1GeneratedImageArtifactLabel(
        computedPrompt: 'A cinematic herd of elephants charges through a Manhattan avenue in broad daylight with yellow taxis nearby.',
      ),
      'Herd of elephants',
    );
    expect(
      powerboardsV1GeneratedImageArtifactLabel(
        computedPrompt:
            'Create a cinematic, photorealistic wide-angle image of a gigantic purple dog calmly walking through the streets of New York City.',
      ),
      'Purple dog in New York',
    );
    expect(
      powerboardsV1GeneratedImageArtifactLabel(
        sourcePrompt: 'A cinematic dinosaur sprinting after a yellow taxi through a busy Manhattan avenue at dusk.',
      ),
      'Dinosaur in Manhattan',
    );
    expect(powerboardsV1GeneratedImageArtifactSlug('Purple dog in New York'), 'purple-dog-in-new-york');
  });

  test('ephemeral preview source exposes generating chrome and completed save only at the appropriate stage', () {
    final room = RoomClient(protocolFactory: () => Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);
    const partial = PowerboardsV1GeneratedImagePreview(generationId: 'generation-1', status: 'in_progress');
    const completed = PowerboardsV1GeneratedImagePreview(generationId: 'generation-1', status: 'completed');

    final partialSource = powerboardsV1GeneratedImagePreviewSource(room: room, preview: partial);
    final completedSource = powerboardsV1GeneratedImagePreviewSource(room: room, preview: completed, onSave: () async {});

    expect(partialSource.headerLeading, isA<SizedBox>());
    expect(partialSource.hideToolbarActions, isTrue);
    expect(partialSource.onSave, isNull);
    expect(completedSource.headerLeading, isNull);
    expect(completedSource.hideToolbarActions, isFalse);
    expect(completedSource.onSave, isNotNull);
  });

  testWidgets('ephemeral generated image renders in the V1 file preview pane without a storage path', (tester) async {
    final room = RoomClient(protocolFactory: () => Protocol(channel: _NoopProtocolChannel()));
    addTearDown(room.dispose);
    const preview = PowerboardsV1GeneratedImagePreview(
      generationId: 'generation-1',
      uri: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
      mimeType: 'image/png',
      width: 1,
      height: 1,
    );
    final file = preview.file;
    final source = powerboardsV1GeneratedImagePreviewSource(room: room, preview: preview);

    expect(file.path, isNull);

    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: PbFilePreviewPane(
              file: file,
              fullscreen: false,
              onToggleFullscreen: () {},
              onClose: () {},
              previewContentChild: source.buildChild(false),
              sourceKey: source.sourceKey,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Fit'), findsOneWidget);
    expect(find.byKey(const ValueKey('image-preview-viewport')), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is PbFilePreviewPane && widget.file.path == null), findsOneWidget);
  });
}
