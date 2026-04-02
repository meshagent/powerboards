import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'meeting_participants.dart';

class VideoRoomParticipantsBuilder extends StatefulWidget {
  const VideoRoomParticipantsBuilder({
    super.key,
    required this.room,
    required this.builder,
  });

  final lk.Room room;
  final Widget Function(BuildContext context, List<lk.Participant> participants)
  builder;

  @override
  State createState() => _VideoRoomParticipantsBuilderState();
}

class _VideoRoomParticipantsBuilderState
    extends State<VideoRoomParticipantsBuilder> {
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
    }
  }

  @override
  void dispose() {
    super.dispose();

    widget.room.removeListener(_onRoomChanged);
  }

  List<lk.Participant> _getParticipants() {
    return uniqueMeetingParticipants(widget.room);
  }

  void _onRoomChanged() {
    setState(() {
      participants = _getParticipants();
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, participants);
}
