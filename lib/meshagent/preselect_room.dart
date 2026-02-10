import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'package:meshagent/meshagent.dart';

import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/settings/selected_room.dart';

class PreselectRoom extends StatefulWidget {
  const PreselectRoom({super.key, required this.projectId, required this.rooms, required this.child});

  final String projectId;
  final Resource<List<Room>> rooms;
  final Widget child;

  @override
  State createState() => _PreselectRoomState();
}

class _PreselectRoomState extends State<PreselectRoom> {
  bool isLoading = true;

  Future<void> _loadRooms() async {
    isLoading = true;

    await widget.rooms.untilReady();

    final items = widget.rooms.state.value ?? [];

    if (!mounted) {
      return;
    }

    if (items.isEmpty) {
      setState(() {
        isLoading = false;
      });
    } else {
      final pid = fromUUID(widget.projectId);
      final roomName = getLastSelectedRoom(widget.projectId);

      final room = items.firstWhereOrNull((room) => room.name == roomName);

      if (room == null) {
        context.go('/p/$pid/r/${items.first.name}');
      } else {
        context.go('/p/$pid/r/${room.name}');
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox.shrink();
    }

    return widget.child;
  }
}
