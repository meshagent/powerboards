import 'package:flutter/material.dart';
import 'package:meshagent/agent.dart';
import 'package:powerboards/meshagent/tools/ask_user.dart';
import 'package:powerboards/meshagent/tools/ask_user_for_file.dart';
import 'package:powerboards/meshagent/tools/display_document.dart';
import 'package:powerboards/meshagent/tools/show_alert.dart';
import 'package:powerboards/meshagent/tools/toast.dart';

class UIToolkit extends RemoteToolkit {
  UIToolkit(BuildContext context, {required super.room})
    : super(
        name: "ui",
        title: "ui tools",
        description: "user interface tools",
        tools: [
          AskUser(context: context),
          AskUserForFile(context: context),
          ShowAlert(context: context),
          ShowErrorAlert(context: context),
          Toast(context: context),
          DisplayDocument(context: context),
        ],
      );
}
