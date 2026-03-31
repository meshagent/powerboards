import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/chat/meshagent_room.dart';

void main() {
  group('MeshagentRoomController mobile tab actions', () {
    test('active files tab is a no-op on mobile', () {
      final controller = MeshagentRoomController()..showFiles();

      controller.selectFilesTab(isMobile: true);

      expect(controller.isFilesShown, isTrue);
      expect(controller.inMeeting, isFalse);
    });

    test('active meet tab is a no-op on mobile', () {
      final controller = MeshagentRoomController()..enterMeeting();

      controller.selectMeetingTab(isMobile: true);

      expect(controller.inMeeting, isTrue);
      expect(controller.isFilesShown, isFalse);
    });

    test('active files tab still hides on desktop', () {
      final controller = MeshagentRoomController()..showFiles();

      controller.selectFilesTab(isMobile: false);

      expect(controller.isFilesShown, isFalse);
    });

    test('active meet tab still exits on desktop', () {
      final controller = MeshagentRoomController()..enterMeeting();

      controller.selectMeetingTab(isMobile: false);

      expect(controller.inMeeting, isFalse);
    });
  });
}
