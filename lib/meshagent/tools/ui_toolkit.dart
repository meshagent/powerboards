import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshagent/agent.dart';
import 'package:powerboards/meshagent/tools/ask_user.dart';
import 'package:powerboards/meshagent/tools/ask_user_for_file.dart';
import 'package:powerboards/meshagent/tools/display_document.dart';
import 'package:powerboards/meshagent/tools/install_webserver_service.dart';
import 'package:powerboards/meshagent/tools/show_alert.dart';
import 'package:powerboards/meshagent/tools/toast.dart';

class UIToolkit extends Toolkit {
  UIToolkit({
    required BuildContext context,
    String? projectId,
    String? roomName,
    InstallWebServerServiceRunner installWebServerService = installPowerboardsWebServerService,
    SaveWebServerSiteFilesRunner saveWebServerSiteFiles = savePowerboardsWebServerSiteFiles,
    FutureOr<void> Function(InstallWebServerServiceResult result)? onWebServerServiceInstalled,
  }) : super(
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
           if (projectId != null && projectId.trim().isNotEmpty && roomName != null && roomName.trim().isNotEmpty) ...[
             InstallWebServerServiceTool(
               projectId: projectId,
               roomName: roomName,
               install: installWebServerService,
               onInstalled: onWebServerServiceInstalled,
             ),
             SaveWebServerSiteFilesTool(projectId: projectId, roomName: roomName, save: saveWebServerSiteFiles),
           ],
         ],
         rules: const [],
       );
}
