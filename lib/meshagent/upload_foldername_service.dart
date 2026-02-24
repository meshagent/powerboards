import 'package:meshagent/meshagent.dart';

abstract class UploadFoldernameService {
  Future<String> generateFoldername(RoomClient client, String filename);
}

class MeshagentUploadFoldernameService implements UploadFoldernameService {
  @override
  Future<String> generateFoldername(RoomClient client, String filename) async {
    /*
    final response =
        await client.agents.ask(
              agentName: "meshagent.schema_planner",
              arguments: {
                "output_schema": {
                  "type": "object",
                  "additionalProperties": false,
                  "properties": {
                    "folder": {
                      "type": "string",
                      "description":
                          "The folder to upload the file based on the file extension. .gif, .jpg should be in Images folder, .mp4 should be in Videos folder, etc.",
                      "enum": [
                        "Pictures",
                        "Videos",
                        "Audio",
                        "Archives",
                        "Presentations",
                        "Spreadsheets",
                        "Documents",
                        "TextFiles",
                        "CodeFiles",
                        "Other",
                      ],
                    },
                  },
                  "required": ["folder"],
                },
                "prompt": "Generate a directory name for given file: $filename",
              },
            )
            as JsonContent;

    return response.json['folder'];
    */
    return "Uploads";
  }
}
