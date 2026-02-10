import 'package:flutter/material.dart';

import 'package:meshagent/meshagent.dart';

class WaitForAgentParticipantBuilder extends StatefulWidget {
  const WaitForAgentParticipantBuilder({required this.room, required this.agentName, required this.builder, super.key});

  final RoomClient room;
  final String agentName;
  final Widget Function(BuildContext context, RemoteParticipant? agent) builder;

  @override
  State createState() => _WaitForAgentParticipantBuilderState();
}

class _WaitForAgentParticipantBuilderState extends State<WaitForAgentParticipantBuilder> {
  RemoteParticipant? _agent;

  void _findAgent() {
    if (!mounted) return;
    setState(() {
      _agent = widget.room.messaging.remoteParticipants.where((p) => p.getAttribute("name") == widget.agentName).firstOrNull;
    });
  }

  @override
  void initState() {
    super.initState();

    widget.room.messaging.addListener(_findAgent);

    _findAgent();
  }

  @override
  void dispose() {
    super.dispose();

    widget.room.messaging.removeListener(_findAgent);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _agent);
  }
}
