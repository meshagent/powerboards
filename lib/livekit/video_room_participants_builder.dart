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

  String _participantDedupKey(lk.Participant participant) {
    final identity = participant.identity;
    if (identity.endsWith(".agent") || identity.endsWith(".agent-recorder") || identity.endsWith(".agent-transcriber")) {
      return identity;
    }

    final name = participant.name.trim().toLowerCase();
    if (name.isNotEmpty) {
      return "user:$name";
    }

    return identity;
  }

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

      participants = _getParticipants();
    }
  }

  @override
  void dispose() {
    super.dispose();

    widget.room.removeListener(_onRoomChanged);
  }

  List<lk.Participant> _getParticipants() {
    final participants = <lk.Participant>[];
    final seenParticipants = <String>{};

    for (final p in widget.room.remoteParticipants.values) {
      final isRecorder = p.identity.endsWith(".agent-recorder");
      final isTranscriber = p.identity.endsWith(".agent-transcriber");

      if (!isRecorder && !isTranscriber && seenParticipants.add(_participantDedupKey(p))) {
        participants.add(p);
      }
    }

    // Add our own participant once, after filtering any stale duplicate name/identity.
    if (widget.room.localParticipant != null) {
      final local = widget.room.localParticipant!;
      if (seenParticipants.add(_participantDedupKey(local))) {
        participants.add(local);
      }
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
