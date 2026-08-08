import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/chat/dataset_chat_thread.dart';
import 'package:meshagent_flutter_shadcn/thread_typography.dart';
import 'package:powerboards/powerboards_ui/v1/components/chat/pb_thread_recovery_card.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_shimmer.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('normal uploaded image shows the V1 attachment shimmer before rendering', (tester) async {
    const imageDataUrl =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';

    await tester.pumpWidget(
      ShadApp(
        home: ThreadTypographyOverride(
          attachmentLoadingPlaceholderBuilder: (context, {required borderRadius}) =>
              PbThreadAttachmentLoadingPlaceholder(borderRadius: borderRadius),
          child: const Scaffold(body: ChatThreadImageAttachment(imageId: null, imageUri: imageDataUrl)),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('pb-thread-attachment-loading-shimmer')), findsOneWidget);
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  test('poisoned attachment matching is narrow and excludes moved attachment state', () {
    expect(
      powerboardsV1IsPoisonedAttachmentError('Unsupported image input format. Supported formats are PNG, JPEG, WEBP, and GIF.'),
      isTrue,
    );
    expect(powerboardsV1IsPoisonedAttachmentError('SVG image input is not supported by this provider.'), isTrue);
    expect(
      powerboardsV1IsPoisonedAttachmentError(
        'The image data you provided does not represent a valid image. Please check your input and try again.',
      ),
      isTrue,
    );
    expect(
      powerboardsV1IsPoisonedAttachmentError('Error from OpenAI websocket: No tool output found for function call call_example.'),
      isTrue,
    );
    expect(
      powerboardsV1IsPoisonedAttachmentError(
        "Error from OpenAI websocket: [ObjectParam] [input[4].output] [unknown_parameter] Unknown parameter: 'input[4].output'.",
      ),
      isTrue,
    );
    expect(powerboardsV1IsPoisonedAttachmentError("Unknown parameter: 'temperature'."), isFalse);
    expect(powerboardsV1IsPoisonedAttachmentError('Attachment moved to media/archive/image.png'), isFalse);
    expect(powerboardsV1IsPoisonedAttachmentError('Attachment is unavailable because it was deleted.'), isFalse);
  });

  testWidgets('poisoned attachment recovery offers a working new-thread action', (tester) async {
    var starts = 0;
    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(body: PbThreadPoisonedAttachmentRecoveryCard(onStartNewThread: () => starts += 1)),
      ),
    );

    expect(find.text('There was an error. To continue please create a new thread.'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    final recovery = tester.widget<Container>(find.byKey(const ValueKey('pb-thread-poisoned-attachment-recovery')));
    final decoration = recovery.decoration! as BoxDecoration;
    expect(decoration.color, PbColors.alertSoft);
    expect(decoration.border, isNull);

    final recoveryText = tester.widget<Text>(
      find.descendant(of: find.byKey(const ValueKey('pb-thread-poisoned-attachment-recovery')), matching: find.byType(Text)),
    );
    final link = (recoveryText.textSpan! as TextSpan).children![1] as TextSpan;
    expect(link.text, 'create a new thread');
    expect(link.style!.color, PbColors.alert);
    (link.recognizer! as TapGestureRecognizer).onTap!();
    expect(starts, 1);
  });

  testWidgets('turn-ended attachment rejection uses the V1 recovery card', (tester) async {
    const runtimeError = "This thread can't continue because an attachment format was rejected during post-processing.";
    final rows = <Map<String, Object?>>[
      {
        'item_id': 'turn-ended-1',
        'turn_id': 'turn-1',
        'sequence': 1,
        'timestamp': '2026-08-07T12:00:00Z',
        'data': {
          'type': 'meshagent.agent.turn.ended',
          'thread_id': 'dataset://threads/svg-attachment',
          'turn_id': 'turn-1',
          'error': {'message': runtimeError, 'code': 'invalid_attachment_format'},
        },
      },
    ];

    await tester.pumpWidget(
      ShadApp(
        home: ThreadTypographyOverride(
          poisonedErrorPredicate: powerboardsV1IsPoisonedAttachmentError,
          poisonedErrorBuilder: (context, {required error, required onStartNewThread}) =>
              PbThreadPoisonedAttachmentRecoveryCard(onStartNewThread: onStartNewThread),
          child: Scaffold(
            body: DatasetChatThread(
              path: 'dataset://threads/svg-attachment',
              rowsLoader: ({required namespace, required table}) => Stream.value(rows),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(runtimeError), findsNothing);
    expect(find.byKey(const ValueKey('pb-thread-poisoned-attachment-recovery')), findsOneWidget);
  });
}
