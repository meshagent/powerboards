import 'package:flutter/material.dart';
import 'package:meshagent/meshagent.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'package:powerboards/meshagent/meshagent.dart';

class RoomsListBuilder extends StatefulWidget {
  const RoomsListBuilder({super.key, required this.projectId, required this.builder});

  final String projectId;
  final Widget Function(BuildContext context, Resource<List<Room>> rooms) builder;

  @override
  State<RoomsListBuilder> createState() => _RoomsListBuilderState();
}

class _RoomsListBuilderState extends State<RoomsListBuilder> {
  late Resource<List<Room>> rooms;

  Resource<List<Room>> _createResource() {
    return Resource<List<Room>>(() {
      return listMeshagentRooms(widget.projectId);
    });
  }

  @override
  void initState() {
    super.initState();

    rooms = _createResource();
  }

  @override
  void didUpdateWidget(RoomsListBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId) {
      rooms.dispose();

      rooms = _createResource();
      rooms.refresh();
    }
  }

  @override
  void dispose() {
    rooms.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, rooms);
  }
}
