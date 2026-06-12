import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/preview/preview_room_rail_menu.dart';

void main() {
  testWidgets('bridge configuration during build defers notifications until after the frame', (tester) async {
    final bridge = PreviewRoomRailMenuBridge();
    var buildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            ListenableBuilder(
              listenable: bridge,
              builder: (context, _) {
                buildCount += 1;
                return Text('build $buildCount');
              },
            ),
            Builder(
              builder: (context) {
                bridge.configure(
                  chatActive: false,
                  showDestinations: true,
                  showMore: true,
                  showRename: true,
                  showPermissions: true,
                  showManageAgents: true,
                  showDeleteRoom: true,
                  showKeychain: true,
                  showConsoleToggle: false,
                  showShutdown: false,
                  meetActive: false,
                  consoleLabel: 'Developer console',
                );
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(buildCount, 1);

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(buildCount, 2);
  });
}
