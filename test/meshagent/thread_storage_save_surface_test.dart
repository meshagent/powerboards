import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/meshagent/thread_storage_save_surface.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  test('Keep both chooses deterministic dash-number suffixes without replacing', () async {
    final existingPaths = <String>{'selected images/purple-dog-in-new-york.png', 'selected images/purple-dog-in-new-york-2.png'};

    expect(
      await powerboardsV1NextAvailableSavePath(
        'selected images/purple-dog-in-new-york.png',
        exists: (path) async => existingPaths.contains(path),
      ),
      'selected images/purple-dog-in-new-york-3.png',
    );
    expect(
      await powerboardsV1NextAvailableSavePath(
        'selected images/purple-dog-in-new-york-2.png',
        exists: (path) async => existingPaths.contains(path),
      ),
      'selected images/purple-dog-in-new-york-3.png',
    );
  });

  testWidgets('generated-image save conflict offers only Keep both and Replace', (tester) async {
    PowerboardsV1SaveConflictResolution? resolution;

    await tester.pumpWidget(
      ShadApp(
        home: Builder(
          builder: (context) => Material(
            child: TextButton(
              onPressed: () async {
                resolution = await showPowerboardsV1SaveConflictResolution(context, fullPath: 'selected images/purple-dog-in-new-york.png');
              },
              child: const Text('Open conflict'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open conflict'));
    await tester.pumpAndSettle();

    expect(find.text('File already exists'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Keep both'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);

    await tester.tap(find.text('Keep both'));
    await tester.pumpAndSettle();
    expect(resolution, PowerboardsV1SaveConflictResolution.keepBoth);
  });
}
