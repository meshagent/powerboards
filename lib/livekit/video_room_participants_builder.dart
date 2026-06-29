import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'meeting_participants.dart';

class VideoRoomParticipantsBuilder extends StatefulWidget {
  const VideoRoomParticipantsBuilder({super.key, required this.room, this.hiddenAgentNames = const [], required this.builder});

  final lk.Room room;
  final List<String> hiddenAgentNames;
  final Widget Function(BuildContext context, List<lk.Participant> participants) builder;

  @override
  State createState() => _VideoRoomParticipantsBuilderState();
}

class _VideoRoomParticipantsBuilderState extends State<VideoRoomParticipantsBuilder> {
  List<lk.Participant> participants = [];

  @override
  void initState() {
    super.initState();
    participants = _getParticipants();
    widget.room.addListener(_onRoomChanged);
  }

  @override
  void didUpdateWidget(covariant VideoRoomParticipantsBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.room != widget.room) {
      oldWidget.room.removeListener(_onRoomChanged);
      widget.room.addListener(_onRoomChanged);

      _onRoomChanged();
    } else if (!_listEquals(oldWidget.hiddenAgentNames, widget.hiddenAgentNames)) {
      _onRoomChanged();
    }
  }

  @override
  void dispose() {
    super.dispose();

    widget.room.removeListener(_onRoomChanged);
  }

  List<lk.Participant> _getParticipants() {
    return uniqueMeetingParticipants(widget.room, hiddenAgentNames: widget.hiddenAgentNames);
  }

  void _onRoomChanged() {
    setState(() {
      participants = _getParticipants();
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, participants);
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
