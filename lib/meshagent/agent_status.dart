import 'package:flutter/widgets.dart';
import 'package:meshagent/meshagent.dart';

class AgentStatus extends StatelessWidget {
  const AgentStatus({super.key, required this.agent, this.withText = true});

  final RemoteParticipant? agent;
  final bool withText;

  @override
  Widget build(BuildContext context) {
    final color = agent == null ? const Color(0xFFF5C43D) : const Color(0xFF00a000);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          width: 8,
          height: 8,
        ),
        if (withText) Text(agent == null ? "Initializing" : "Available", style: TextStyle(color: color)),
      ],
    );
  }
}
