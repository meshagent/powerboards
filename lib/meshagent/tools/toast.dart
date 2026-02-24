import 'package:flutter/material.dart';
import 'package:meshagent/agent.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

final toastSchema = {
  "type": "object",
  "additionalProperties": false,
  "required": ["title", "description"],
  "properties": {
    "title": {"type": "string", "description": "a very short summary suitable for a toast title"},
    "description": {"type": "string", "description": "helpful information that explains what is happening and why"},
  },
};

class Toast extends FunctionTool {
  Toast({
    required this.context,
    super.name = "show_toast",
    super.description = "let the user know something important (will be shown as a toast)",
    super.title = "show user a toast",
  }) : super(inputSchema: toastSchema);

  final BuildContext context;

  @override
  Future<EmptyContent> execute(ToolContext context, Map<String, dynamic> arguments) async {
    final title = arguments["title"];
    final description = arguments["description"];

    ShadToaster.of(this.context).show(
      ShadToast(
        title: Text(title),
        description: Text(description),
        action: ShadButton.outline(child: const Text('Dismiss'), onPressed: () => ShadToaster.of(this.context).hide()),
      ),
    );

    return EmptyContent();
  }
}
