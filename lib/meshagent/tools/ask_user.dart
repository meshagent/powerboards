import 'package:flutter/material.dart';
import 'package:meshagent/agent.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_flutter_shadcn/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

final askUserSchema = {
  "type": "object",
  "additionalProperties": false,
  "required": ["subject", "form", "help"],
  "properties": {
    "subject": {"type": "string", "description": "a very short description suitable for a dialog title"},
    "help": {
      "type": "string",
      "description": "helpful information that explains why this information is being collected and how it will be used",
    },
    "form": {
      "type": "array",
      "items": {
        "anyOf": [
          {
            "type": "object",
            "additionalProperties": false,
            "required": ["input"],
            "properties": {
              "input": {
                "type": "object",
                "additionalProperties": false,
                "required": ["multiline", "name", "description", "default_value"],
                "properties": {
                  "name": {"type": "string"},
                  "description": {"type": "string"},
                  "multiline": {"type": "boolean"},
                  "default_value": {"type": "string"},
                },
              },
            },
          },
          {
            "type": "object",
            "additionalProperties": false,
            "required": ["checkbox"],
            "properties": {
              "checkbox": {
                "type": "object",
                "additionalProperties": false,
                "required": ["name", "description", "default_value"],
                "properties": {
                  "name": {"type": "string"},
                  "description": {"type": "string"},
                  "default_value": {"type": "boolean"},
                },
              },
            },
          },
          {
            "type": "object",
            "additionalProperties": false,
            "required": ["radio_group"],
            "description":
                "allows the user to select a single option from a list of options. best for multiple choice questions or surveys",
            "properties": {
              "radio_group": {
                "type": "object",
                "additionalProperties": false,
                "required": ["name", "default_value", "description", "options"],
                "properties": {
                  "name": {"type": "string"},
                  "description": {"type": "string"},
                  "default_value": {"type": "string"},
                  "options": {
                    "type": "array",
                    "items": {
                      "type": "object",
                      "additionalProperties": false,
                      "required": ["name", "value"],
                      "properties": {
                        "name": {"type": "string"},
                        "value": {"type": "string"},
                      },
                    },
                  },
                },
              },
            },
          },
          {
            "type": "object",
            "additionalProperties": false,
            "required": ["select"],
            "properties": {
              "select": {
                "type": "object",
                "additionalProperties": false,
                "required": ["name", "options", "description", "default_value"],
                "properties": {
                  "name": {"type": "string"},
                  "description": {"type": "string"},
                  "default_value": {"type": "string"},
                  "options": {
                    "type": "array",
                    "items": {
                      "type": "object",
                      "additionalProperties": false,
                      "required": ["name", "value"],
                      "properties": {
                        "name": {"type": "string"},
                        "value": {"type": "string"},
                      },
                    },
                  },
                },
              },
            },
          },
        ],
      },
    },
  },
};

class AskUser extends Tool {
  AskUser({required this.context, super.name = "ask_user", super.description = "ask the user a question", super.title = "ask user"})
    : super(inputSchema: askUserSchema);

  final BuildContext context;
  // final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Widget form(BuildContext context, Map<String, dynamic> form) {
    return JsonForm(json: form);
  }

  @override
  Future<Chunk> execute(ToolContext context, Map<String, dynamic> arguments) async {
    final result = await showShadDialog<Map<String, dynamic>>(
      context: this.context,
      builder: (context) {
        return ControlledForm(
          builder: (context, controller, formKey) => ShadDialog(
            crossAxisAlignment: CrossAxisAlignment.start,
            title: Text(arguments["subject"]),
            actions: [
              ShadButton.secondary(
                onTapDown: (_) {
                  Navigator.of(context).pop({"user_feedback": "this is not helpful"});
                },
                child: const Text("This is Not Helpful"),
              ),
              ShadButton(
                onTapDown: (_) {
                  if (!formKey.currentState!.saveAndValidate()) {
                    return;
                  }

                  final formData = formKey.currentState!.value;

                  final output = <String, dynamic>{};
                  for (var key in formData.keys) {
                    output[key.toString()] = formData[key];
                  }

                  Navigator.of(context).pop({"result": output});
                },
                child: const Text("OK"),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [Text(arguments["help"] ?? ""), form(context, arguments)],
              ),
            ),
          ),
        );
      },
    );

    if (result == null) {
      throw Exception("The user cancelled the request");
    } else if (result["user_feedback"] != null) {
      throw Exception("The user cancelled the request");
    }
    return JsonChunk(json: result["result"]);
  }
}

class JsonForm extends StatefulWidget {
  const JsonForm({super.key, required this.json});

  final Map<String, dynamic> json;

  @override
  State createState() => _JsonFormState();
}

class _JsonFormState extends State<JsonForm> {
  Widget buildFilePathInput(BuildContext context, Map<String, dynamic> field) {
    return ShadInputFormField(id: field["name"], label: Text(field["name"]), description: Text(field["description"]));
  }

  Widget buildInputField(BuildContext context, Map<String, dynamic> field) {
    return ShadInputFormField(
      initialValue: field["default_value"] ?? "",
      id: field["name"],
      label: Text(field["name"]),
      description: Text(field["description"]),
      maxLines: field["multiline"] == true ? null : 1,
      minLines: field["multiline"] == true ? 3 : 1,
    );
  }

  Widget buildSelectField(BuildContext context, Map<String, dynamic> field) {
    return ShadSelectFormField<String>(
      id: field["name"],
      label: Text(field["name"]),
      initialValue: field["default_value"] ?? (field["options"] as List).first["value"],
      description: Text(field["description"]),
      selectedOptionBuilder: (context, value) => Text(value),
      options: [for (final option in field["options"]) ShadOption<String>(value: option["value"], child: Text(option["name"]))],
    );
  }

  Widget buildRadioGroup(BuildContext context, Map<String, dynamic> field) {
    return ShadRadioGroupFormField<String>(
      id: field["name"],
      label: Text(field["name"]),
      initialValue: field["default_value"] ?? (field["options"] as List).first["value"],
      description: Text(field["description"]),
      items: [for (final option in field["options"]) ShadRadio<String>(value: option["value"], label: Text(option["name"]))],
    );
  }

  Widget buildCheckbox(BuildContext context, Map<String, dynamic> field) {
    return ShadCheckboxFormField(
      id: field["name"],
      label: Text(field["name"]),
      initialValue: field["default_value"] == true,
      description: Text(field["description"]),
    );
  }

  Widget buildField(BuildContext context, Map<String, dynamic> field) {
    if (field["file_path"] != null) {
      return buildFilePathInput(context, field["file_path"]);
    } else if (field["input"] != null) {
      return buildInputField(context, field["input"]);
    } else if (field["select"] != null) {
      return buildSelectField(context, field["select"]);
    } else if (field["checkbox"] != null) {
      return buildCheckbox(context, field["checkbox"]);
    } else if (field["radio_group"] != null) {
      return buildRadioGroup(context, field["radio_group"]);
    }
    throw Exception("Invalid field");
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [for (final field in widget.json["form"] as List) buildField(context, field)],
    );
  }
}
