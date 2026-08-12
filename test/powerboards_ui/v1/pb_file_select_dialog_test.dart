import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_file_select_dialog.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_switcher_dropdown_field.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_button.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_theme.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_typography.dart';

Widget _dialogHarness({
  required bool canAdd,
  required ValueChanged<String> onRoomSelected,
  required VoidCallback onAddPressed,
  required VoidCallback onClose,
}) {
  return MaterialApp(
    theme: pbTheme(),
    home: Scaffold(
      body: Stack(
        children: [
          PbFileSelectDialog(
            rooms: const ['Client Demos', 'Demo Room'],
            selectedRoom: 'Client Demos',
            canAdd: canAdd,
            onRoomSelected: onRoomSelected,
            onAddPressed: onAddPressed,
            onClose: onClose,
            fileBrowser: const Center(child: Text('Live file browser')),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('empty folder status reuses the side-pane list empty typography', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: pbTheme(),
        home: const Scaffold(body: PbFileSelectStatus.empty(message: 'Nothing here yet')),
      ),
    );

    final text = tester.widget<Text>(find.text('Nothing here yet'));
    expect(text.style, same(PowerboardsTypography.listEmptyState));
  });

  testWidgets('file select dialog uses migrated shell and disables Add without a selection', (tester) async {
    var adds = 0;
    var closes = 0;

    await tester.pumpWidget(
      _dialogHarness(canAdd: false, onRoomSelected: (_) {}, onAddPressed: () => adds += 1, onClose: () => closes += 1),
    );

    expect(find.text('Select files'), findsOneWidget);
    expect(find.text('Attach files from this room'), findsOneWidget);
    expect(find.byType(PbSwitcherDropdownField), findsOneWidget);
    expect(find.text('Live file browser'), findsOneWidget);

    final disabledAdd = find.ancestor(of: find.text('Add'), matching: find.byType(IgnorePointer));
    expect(tester.widget<IgnorePointer>(disabledAdd.first).ignoring, isTrue);
    expect(adds, 0);

    await tester.tap(find.text('Cancel'));
    expect(closes, 1);
  });

  testWidgets('file select dialog enables Add and routes room selection through the switcher', (tester) async {
    var adds = 0;
    String? selectedRoom;

    await tester.pumpWidget(
      _dialogHarness(canAdd: true, onRoomSelected: (room) => selectedRoom = room, onAddPressed: () => adds += 1, onClose: () {}),
    );

    await tester.tap(find.text('Add'));
    expect(adds, 1);

    await tester.tap(find.byKey(const ValueKey('pb-file-select-room-switcher')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Demo Room'), findsOneWidget);
    await tester.tap(find.text('Demo Room'));
    await tester.pump();

    expect(selectedRoom, 'Demo Room');
  });

  testWidgets('file select breadcrumb preserves root and segment navigation callbacks', (tester) async {
    var rootPresses = 0;
    int? segmentIndex;

    await tester.pumpWidget(
      MaterialApp(
        theme: pbTheme(),
        home: Scaffold(
          body: PbFileSelectBreadcrumb(
            currentPath: 'assets/launch',
            onRootPressed: () => rootPresses += 1,
            onSegmentPressed: (index) => segmentIndex = index,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Browse'));
    expect(rootPresses, 1);

    await tester.tap(find.text('assets'));
    expect(segmentIndex, 0);
  });

  testWidgets('move destination dialog disables the current location and switches to copy', (tester) async {
    bool? copyFilesInstead;

    await tester.pumpWidget(
      MaterialApp(
        theme: pbTheme(),
        home: Scaffold(
          body: Stack(
            children: [
              PbFilesMoveDestinationDialog(
                rooms: const ['Product', 'Research'],
                selectedRoom: 'Product',
                fileBrowser: const Center(child: Text('Live destination browser')),
                itemCount: 2,
                canConfirm: false,
                onRoomSelected: (_) {},
                onConfirm: (copy) => copyFilesInstead = copy,
                onClose: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Move files to'), findsWidgets);
    expect(find.text('Choose a destination for 2 selected items.'), findsOneWidget);
    expect(find.text('Live destination browser'), findsOneWidget);

    final moveButton = find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Move files to');
    final disabledMove = find.ancestor(of: moveButton, matching: find.byType(IgnorePointer));
    expect(tester.widget<IgnorePointer>(disabledMove.first).ignoring, isTrue);

    await tester.tap(find.byKey(const ValueKey('pb-files-copy-instead-toggle')));
    await tester.pump();
    expect(find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Copy files to'), findsOneWidget);
    expect(copyFilesInstead, isNull);
  });

  testWidgets('move destination dialog confirms the selected operation', (tester) async {
    bool? copyFilesInstead;

    await tester.pumpWidget(
      MaterialApp(
        theme: pbTheme(),
        home: Scaffold(
          body: Stack(
            children: [
              PbFilesMoveDestinationDialog(
                rooms: const ['Product'],
                selectedRoom: 'Product',
                fileBrowser: const SizedBox.shrink(),
                itemCount: 1,
                canConfirm: true,
                onRoomSelected: (_) {},
                onConfirm: (copy) => copyFilesInstead = copy,
                onClose: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('pb-files-copy-instead-toggle')));
    await tester.pump();
    await tester.tap(find.byWidgetPredicate((widget) => widget is PbButton && widget.label == 'Copy files to'));
    expect(copyFilesInstead, isTrue);
  });
}
