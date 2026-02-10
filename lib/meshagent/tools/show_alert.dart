import 'package:flutter/material.dart';
import 'package:meshagent/agent.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

final showAlertSchema = {
  "type": "object",
  "additionalProperties": false,
  "required": ["title", "description"],
  "properties": {
    "title": {"type": "string", "description": "a very short summary suitable for an alert title"},
    "description": {"type": "string", "description": "helpful information that explains what happened and why"},
  },
};

class ShowAlert extends Tool {
  ShowAlert({
    required this.context,
    super.name = "show_alert",
    super.description = "let the user know something important (will be shown as an alert)",
    super.title = "show user an alert",
  }) : super(inputSchema: showAlertSchema);

  final BuildContext context;

  @override
  Future<EmptyResponse> execute(ToolContext context, Map<String, dynamic> arguments) async {
    final title = arguments["title"];
    final description = arguments["description"];

    showDialog(
      context: this.context,
      builder: (BuildContext context) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ShadAlert(
              decoration: const ShadDecoration(color: Colors.white),
              icon: Icon(Icons.info_outline),
              title: Text(title),
              description: Text(description),
            ),
          ),
        );
      },
    );

    return EmptyResponse();
  }
}

class ShowErrorAlert extends Tool {
  ShowErrorAlert({
    required this.context,
    super.name = "show_error_alert",
    super.description = "let the user know an error occurred (will be shown as an alert)",
    super.title = "show user an error alert",
  }) : super(inputSchema: showAlertSchema);

  final BuildContext context;

  @override
  Future<EmptyResponse> execute(ToolContext context, Map<String, dynamic> arguments) async {
    final title = arguments["title"];
    final description = arguments["description"];

    showDialog(
      context: this.context,
      builder: (BuildContext context) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ShadAlert.destructive(
              decoration: const ShadDecoration(color: Colors.black),
              icon: Icon(Icons.error_outline),
              title: Text(title),
              description: Text(description),
            ),
          ),
        );
      },
    );

    return EmptyResponse();
  }
}
