import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_dialog_file_list.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_theme.dart';

void main() {
  testWidgets('visually disabled rows are muted and do not activate', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: pbTheme(),
        home: Scaffold(
          body: SizedBox(
            height: 100,
            child: PbDialogFileList.unframed(
              items: const [
                PbDialogFileListItemData(
                  id: 'source.md',
                  title: 'source.md',
                  iconAssetName: 'file-text',
                  iconColor: Colors.blue,
                  enabled: false,
                  visuallyDisabled: true,
                ),
              ],
              onItemPressed: (_) => presses += 1,
            ),
          ),
        ),
      ),
    );

    final row = find.byKey(const ValueKey('pb-dialog-file-list-row-source.md'));
    final opacity = tester.widget<Opacity>(find.descendant(of: row, matching: find.byType(Opacity)));
    expect(opacity.opacity, 0.42);

    await tester.tap(row);
    expect(presses, 0);
  });

  testWidgets('attach-style multi-selection uses fill and row spacing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: pbTheme(),
        home: Scaffold(
          body: SizedBox(
            height: 180,
            child: PbDialogFileList(
              items: const [
                PbDialogFileListItemData(id: 'first.md', title: 'first.md', iconAssetName: 'file-text', iconColor: Colors.blue),
                PbDialogFileListItemData(id: 'second.png', title: 'second.png', iconAssetName: 'file-image', iconColor: Colors.teal),
              ],
              selectedIds: const {'first.md', 'second.png'},
              showCheckboxes: true,
              framed: false,
              rowMargin: const EdgeInsets.symmetric(horizontal: 28, vertical: 1),
              onToggleSelection: (_) {},
            ),
          ),
        ),
      ),
    );

    for (final id in const ['first.md', 'second.png']) {
      final row = tester.widget<Container>(find.byKey(ValueKey('pb-dialog-file-list-row-$id')));
      final decoration = row.decoration! as BoxDecoration;
      final margin = row.margin! as EdgeInsets;

      expect(decoration.color, isNotNull);
      expect(margin.vertical, 2);
    }
  });
}
