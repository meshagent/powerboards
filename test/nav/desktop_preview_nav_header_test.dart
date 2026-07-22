import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/nav/desktop_preview_nav_header.dart';
import 'package:powerboards/powerboards_ui/v1/preview/preview_room_rail_menu.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('V1 desktop header renders people supplied by the live room bridge', (tester) async {
    final rooms = Resource<List<Room>>(() async => [Room(id: 'room-1', name: 'product', metadata: const {}, annotations: const {})]);
    final bridge = PreviewRoomRailMenuBridge();
    addTearDown(() {
      exposePreviewRoomRailMenuBridge(null);
      bridge.dispose();
      rooms.dispose();
    });

    await rooms.refresh();
    bridge.configure(
      chatActive: false,
      showDestinations: true,
      showMore: true,
      showRename: true,
      showPermissions: true,
      showManageAgents: false,
      showDeleteRoom: true,
      showKeychain: true,
      showConsoleToggle: false,
      showShutdown: false,
      meetActive: false,
      consoleLabel: 'Developer console',
      whoIsHereNames: const ['Ava Chen', 'Jordan Lee'],
    );
    exposePreviewRoomRailMenuBridge(bridge);

    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(
          body: DesktopPreviewNavHeader(
            projects: [Project(id: 'project-1', name: 'Project')],
            rooms: rooms,
            projectId: 'project-1',
            selectedRoom: 'product',
            canCreateRooms: false,
            onCreateProject: () async {},
            onSelectProject: (_) {},
            onSelectRoom: (_) {},
            avatarInitials: 'DJ',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('AC'), findsOneWidget);
    expect(find.text('JL'), findsOneWidget);

    await tester.tap(find.text('AC'));
    await tester.pumpAndSettle();

    expect(find.text('People here right now'), findsOneWidget);
    expect(find.text('Ava Chen'), findsOneWidget);
    expect(find.text('Jordan Lee'), findsOneWidget);
  });
}
