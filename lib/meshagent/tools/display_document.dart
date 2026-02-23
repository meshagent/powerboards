import 'package:flutter/material.dart';
import 'package:meshagent/agent.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:powerboards/chat/meshagent_room.dart';

final displayDocumentSchema = {
  "type": "object",
  "additionalProperties": false,
  "required": ["path"],
  "properties": {
    "path": {"type": "string"},
  },
};

class DisplayDocument extends FunctionTool {
  DisplayDocument({
    required this.context,
    super.name = "display_document",
    super.description = "display a document to the user",
    super.title = "display document",
  }) : super(inputSchema: displayDocumentSchema);

  final BuildContext context;

  @override
  Future<EmptyChunk> execute(ToolContext context, Map<String, dynamic> arguments) async {
    final path = arguments["path"];

    if (path.isNotEmpty) {
      final state = this.context.findAncestorStateOfType<MeshagentRoomState>();
      if (state != null) {
        state.updatePath(this.context, path);
      }
    }

    return EmptyChunk();
  }
}
