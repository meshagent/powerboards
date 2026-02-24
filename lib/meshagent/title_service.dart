import 'package:meshagent/meshagent.dart';

abstract class TitleService {
  Future<String> generateTitle(RoomClient client, String message);
}

class MeshagentTitleService implements TitleService {
  @override
  Future<String> generateTitle(RoomClient client, String message) async {
    /* Not used
    final response =
        await client.agents.ask(
              agentName: "meshagent.schema_planner",
              arguments: {
                "output_schema": {
                  "type": "object",
                  "additionalProperties": false,
                  "properties": {
                    "title": {"type": "string", "description": "The short title of the post (max 4 words)"},
                  },
                  "required": ["title"],
                },
                "prompt": "Generate a title for the post: $message",
              },
            )
            as JsonContent;

    return response.json['title'];
    */
    return 'Untitled Post';
  }
}
