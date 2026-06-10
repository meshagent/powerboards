import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/meshagent.dart';

void main() {
  group('collectMeshagentRoomsFromGrantPages', () {
    test('keeps paging until a short page even when total is misleading', () async {
      final pages = <RoomsPage>[
        RoomsPage(rooms: [_room('alpha'), _room('beta')], total: 1),
        RoomsPage(rooms: [_room('gamma')], total: 1),
      ];
      final requestedOffsets = <int>[];

      final rooms = await collectMeshagentRoomsFromGrantPages((limit, offset) async {
        expect(limit, 2);
        requestedOffsets.add(offset);
        return pages[requestedOffsets.length - 1];
      }, pageSize: 2);

      expect(requestedOffsets, [0, 2]);
      expect(rooms.map((room) => room.name).toList(), ['alpha', 'beta', 'gamma']);
    });

    test('deduplicates rooms by slug across pages', () async {
      final rooms = await collectMeshagentRoomsFromGrantPages((limit, offset) async {
        switch (offset) {
          case 0:
            return RoomsPage(
              rooms: [
                _room('alpha', displayName: 'Alpha'),
                _room('beta'),
              ],
              total: 4,
            );
          case 2:
            return RoomsPage(rooms: [_room('alpha', displayName: 'Alpha renamed elsewhere')], total: 4);
        }

        throw StateError('Unexpected offset $offset');
      }, pageSize: 2);

      expect(rooms.map((room) => room.name).toList(), ['alpha', 'beta']);
      expect(rooms.first.metadata['displayName'], 'Alpha');
    });
  });
}

Room _room(String roomName, {String? displayName}) {
  return Room(
    id: '$roomName-id',
    name: roomName,
    metadata: displayName == null ? const {} : {'displayName': displayName},
    annotations: const {},
  );
}
