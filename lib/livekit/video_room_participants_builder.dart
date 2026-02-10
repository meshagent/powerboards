import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

class VideoRoomParticipantsBuilder extends StatefulWidget {
  const VideoRoomParticipantsBuilder({super.key, required this.room, required this.builder});

  final lk.Room room;
  final Widget Function(BuildContext context, List<lk.Participant> participants) builder;

  @override
  State createState() => _VideoRoomParticipantsBuilderState();
}

class _VideoRoomParticipantsBuilderState extends State<VideoRoomParticipantsBuilder> {
  List<lk.Participant> participants = [];

  @override
  void initState() {
    super.initState();
    participants = [if (widget.room.localParticipant != null) widget.room.localParticipant!, ...widget.room.remoteParticipants.values];
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
    List<lk.Participant> participants = [];

    for (var p in widget.room.remoteParticipants.values) {
      final isRecorder = p.identity.endsWith(".agent-recorder");
      final isTranscriber = p.identity.endsWith(".agent-transcriber");

      if (!isRecorder && !isTranscriber) {
        participants.add(p);
      }
    }

    // add our selves
    if (widget.room.localParticipant != null) {
      participants.add(widget.room.localParticipant!);
    }

    return participants;
  }

  void _onRoomChanged() {
    setState(() {
      participants = _getParticipants();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, participants);
  }
}
