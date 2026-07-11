import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshagent/agent.dart';
import 'package:powerboards/meshagent/tools/ask_user.dart';
import 'package:powerboards/meshagent/tools/ask_user_for_file.dart';
import 'package:powerboards/meshagent/tools/display_document.dart';
import 'package:powerboards/meshagent/tools/install_webserver_service.dart';
import 'package:powerboards/meshagent/tools/show_alert.dart';
import 'package:powerboards/meshagent/tools/toast.dart';

UIToolkit powerboardsRoomUiToolkit({
  required BuildContext context,
  required bool enableV1WebServerTools,
  required String projectId,
  required String? roomName,
  InstallWebServerServiceRunner installWebServerService = installPowerboardsWebServerService,
  SaveWebServerSiteFilesRunner saveWebServerSiteFiles = savePowerboardsWebServerSiteFiles,
  FutureOr<void> Function(InstallWebServerServiceResult result)? onWebServerServiceInstalled,
  FutureOr<void> Function(SaveWebServerSiteFilesResult result)? onWebServerSiteFilesSaved,
}) {
  return UIToolkit(
    context: context,
    enableV1WebServerTools: enableV1WebServerTools,
    projectId: enableV1WebServerTools ? projectId : null,
    roomName: enableV1WebServerTools ? roomName : null,
    installWebServerService: installWebServerService,
    saveWebServerSiteFiles: saveWebServerSiteFiles,
    onWebServerServiceInstalled: onWebServerServiceInstalled,
    onWebServerSiteFilesSaved: onWebServerSiteFilesSaved,
  );
}

class UIToolkit extends Toolkit {
  UIToolkit({
    required BuildContext context,
    this.enableV1WebServerTools = false,
    String? projectId,
    String? roomName,
    InstallWebServerServiceRunner installWebServerService = installPowerboardsWebServerService,
    SaveWebServerSiteFilesRunner saveWebServerSiteFiles = savePowerboardsWebServerSiteFiles,
    FutureOr<void> Function(InstallWebServerServiceResult result)? onWebServerServiceInstalled,
    FutureOr<void> Function(SaveWebServerSiteFilesResult result)? onWebServerSiteFilesSaved,
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
             ...powerboardsWebServerTools(
               projectId: projectId,
               roomName: roomName,
               enableV1WebServerTools: enableV1WebServerTools,
               install: installWebServerService,
               saveSiteFiles: saveWebServerSiteFiles,
               onInstalled: onWebServerServiceInstalled,
               onSaved: onWebServerSiteFilesSaved,
             ),
           ],
         ],
         rules: const [],
       );

  final bool enableV1WebServerTools;
}
