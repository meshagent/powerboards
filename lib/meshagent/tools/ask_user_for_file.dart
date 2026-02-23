import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:meshagent/agent.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_flutter_shadcn/ui/ui.dart';
import 'package:mime/mime.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

final askUserForFileSchema = {
  "type": "object",
  "additionalProperties": false,
  "required": ["title", "description"],
  "properties": {
    "title": {"type": "string", "description": "a very short description suitable for a dialog title"},
    "description": {
      "type": "string",
      "description": "helpful information that explains why this information is being collected and how it will be used",
    },
  },
};

class AskUserForFile extends FunctionTool {
  AskUserForFile({
    required this.context,
    super.name = "ask_user_for_file",
    super.description = "ask the user for a file (will be accessible as a blob url to other tools)",
    super.title = "ask user for file",
  }) : super(inputSchema: askUserForFileSchema);

  final BuildContext context;

  @override
  Future<FileChunk> execute(ToolContext context, Map<String, dynamic> arguments) async {
    final result = await showShadDialog<FilePickerResult>(
      context: this.context,
      builder: (context) {
        return ControlledForm(
          builder: (context, controller, formKey) => ShadDialog(
            crossAxisAlignment: CrossAxisAlignment.start,
            title: Text(arguments["title"]),
            actions: [
              ShadButton.secondary(
                onTapDown: (_) {
                  Navigator.of(context).pop({"user_feedback": "this is not helpful"});
                },
                child: const Text("This is Not Helpful"),
              ),
              ShadButton(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(dialogTitle: arguments["title"], withData: true);
                  if (context.mounted) {
                    Navigator.of(context).pop(result);
                  }
                },
                child: const Text("Continue"),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [Text(arguments["description"] ?? "")],
              ),
            ),
          ),
        );
      },
    );

    if (result == null) {
      throw Exception("The user cancelled the request");
    } else if (result.files.isEmpty) {
      throw Exception("The user did not pick any files");
    } else {
      final file = result.files[0];

      return FileChunk(data: file.bytes!, name: file.name, mimeType: lookupMimeType(file.name) ?? "application/octet-stream");
    }
  }
}
