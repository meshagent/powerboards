import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/thread_typography.dart';
import 'package:powerboards/powerboards_ui/v1/components/chat/pb_comment_save_copy_dialog.dart';
import 'package:powerboards/powerboards_ui/v1/components/chat/pb_thread_message_options_menu.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('thread message menu offers Copy and Save a copy as', (tester) async {
    var copies = 0;
    var saves = 0;
    final openStates = <bool>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: pbTheme(),
        home: Scaffold(
          body: Center(
            child: PbThreadMessageOptionsMenu(onCopy: () => copies += 1, onSaveCopyAs: () => saves += 1, onMenuOpenChanged: openStates.add),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Save a copy as...'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(copies, 1);
    expect(openStates, [true, false]);

    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Save a copy as...'));
    await tester.pump();
    expect(saves, 1);
  });

  testWidgets('thread attachment menu offers Open, Download, and Save a copy as in order', (tester) async {
    var opens = 0;
    var downloads = 0;
    var saves = 0;
    final openStates = <bool>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: pbTheme(),
        home: Scaffold(
          body: Center(
            child: PbThreadAttachmentOptionsMenu(
              mine: true,
              onOpen: () => opens += 1,
              onDownload: () => downloads += 1,
              onSaveCopyAs: () => saves += 1,
              onMenuOpenChanged: openStates.add,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Copy'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Save a copy as...'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Open')).dy, lessThan(tester.getTopLeft(find.text('Download')).dy));
    expect(tester.getTopLeft(find.text('Download')).dy, lessThan(tester.getTopLeft(find.text('Save a copy as...')).dy));

    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(opens, 1);

    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Download'));
    await tester.pump();
    expect(downloads, 1);

    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Save a copy as...'));
    await tester.pump();
    expect(saves, 1);
    expect(openStates, [true, false, true, false, true, false]);
  });

  testWidgets('thread typography hook provides the V1 attachment options presentation', (tester) async {
    await tester.pumpWidget(
      ShadApp(
        home: ThreadTypographyOverride(
          attachmentOptionsBuilder:
              (context, {required mine, required onOpen, required onDownload, required onSaveCopyAs, required onMenuOpenChanged}) =>
                  PbThreadAttachmentOptionsMenu(
                    mine: mine,
                    onOpen: onOpen,
                    onDownload: onDownload,
                    onSaveCopyAs: onSaveCopyAs,
                    onMenuOpenChanged: onMenuOpenChanged,
                  ),
          child: Scaffold(
            body: Builder(
              builder: (context) {
                final optionsBuilder = ThreadTypographyOverride.maybeAttachmentOptionsBuilderOf(context)!;
                return optionsBuilder(
                  context,
                  mine: true,
                  onOpen: () {},
                  onDownload: () {},
                  onSaveCopyAs: () {},
                  onMenuOpenChanged: (_) {},
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PbThreadAttachmentOptionsMenu), findsOneWidget);
  });

  testWidgets('thread typography hook replaces only the chat bubble options presentation', (tester) async {
    var saves = 0;

    await tester.pumpWidget(
      ShadApp(
        home: ThreadTypographyOverride(
          messageOptionsBuilder: (context, {required text, required onCopy, required onSaveCopyAs, required onMenuOpenChanged}) =>
              PbThreadMessageOptionsMenu(onCopy: onCopy, onSaveCopyAs: () => saves += 1, onMenuOpenChanged: onMenuOpenChanged),
          child: const Scaffold(body: ChatBubble(mine: false, text: 'Thread comment')),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Thread comment')));
    await tester.pump();

    expect(find.byType(PbThreadMessageOptionsMenu), findsOneWidget);
    expect(find.text('Save a copy as...'), findsNothing);

    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Save a copy as...'), findsOneWidget);

    await tester.tap(find.text('Save a copy as...'));
    await tester.pump();
    expect(saves, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('comment save dialog requires a name and preserves the migrated copy', (tester) async {
    final nameController = TextEditingController();
    addTearDown(nameController.dispose);
    var saves = 0;
    var closes = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: pbTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Stack(
              children: [
                PbCommentSaveCopyDialog(
                  subtitle: 'Save comment as markdown',
                  namePlaceholder: 'Enter a name for your comment',
                  nameController: nameController,
                  fileBrowser: const Center(child: Text('Live destination browser')),
                  canSave: nameController.text.trim().isNotEmpty,
                  saving: false,
                  onNameChanged: (_) => setState(() {}),
                  onCopyAndSave: () => saves += 1,
                  onClose: () => closes += 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Save a copy as...'), findsOneWidget);
    expect(find.text('Save comment as markdown'), findsOneWidget);
    expect(find.text('Enter a name for your comment'), findsOneWidget);
    expect(find.text('Live destination browser'), findsOneWidget);

    final disabledSave = find.ancestor(of: find.text('Save to Files'), matching: find.byType(IgnorePointer));
    expect(tester.widget<IgnorePointer>(disabledSave.first).ignoring, isTrue);

    await tester.enterText(find.byType(TextField), 'launch notes');
    await tester.pump();
    await tester.tap(find.text('Save to Files'));
    expect(saves, 1);

    await tester.tap(find.text('Cancel'));
    expect(closes, 1);
  });

  testWidgets('thread attachment save dialog uses file-specific copy', (tester) async {
    final nameController = TextEditingController(text: 'ibm-logo.svg');
    addTearDown(nameController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: pbTheme(),
        home: Scaffold(
          body: Stack(
            children: [
              PbCommentSaveCopyDialog(
                subtitle: 'Save attachment to Files',
                namePlaceholder: 'Enter a name for your file',
                nameController: nameController,
                fileBrowser: const SizedBox.shrink(),
                canSave: nameController.text.trim().isNotEmpty,
                saving: false,
                onNameChanged: (_) {},
                onCopyAndSave: () {},
                onClose: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Save a copy as...'), findsOneWidget);
    expect(find.text('Save attachment to Files'), findsOneWidget);
    expect(find.text('ibm-logo.svg'), findsOneWidget);
    expect(find.text('Save to Files'), findsOneWidget);
    final saveButton = find.ancestor(of: find.text('Save to Files'), matching: find.byType(IgnorePointer));
    expect(tester.widget<IgnorePointer>(saveButton.first).ignoring, isFalse);
  });
}
