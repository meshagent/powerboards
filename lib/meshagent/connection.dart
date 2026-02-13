import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter/meshagent_flutter.dart';
import 'package:meshagent_flutter_widgets/meshagent_flutter_widgets.dart';

import 'package:powerboards/meshagent/loader.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/room_ended_card.dart';
import 'package:powerboards/meshagent/room_not_found.dart';
import 'package:powerboards/oauth/oauth.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/ui/main_wrapper.dart';

const String meshagentDomain = String.fromEnvironment('MESHAGENT_DOMAIN');

class MeshagentConnectionResponse {
  MeshagentConnectionResponse({required this.url, required this.token, required this.roomType});

  factory MeshagentConnectionResponse.fromJSON(Map<String, dynamic> json) {
    return MeshagentConnectionResponse(url: json["url"] ?? "", token: json["token"] ?? "", roomType: json["roomType"] ?? "");
  }

  final String url;
  final String token;
  final String roomType;
}

class MeshagentConnectionBuilder extends StatefulWidget {
  const MeshagentConnectionBuilder({
    super.key,
    required this.projectId,
    required this.projects,
    required this.roomName,
    required this.builder,
  });

  final String projectId;
  final Resource<List<Project>> projects;
  final String roomName;

  final Widget Function(BuildContext context, RoomClient client) builder;

  @override
  State createState() => _MeshagentConnectionBuilderState();
}

class _MeshagentConnectionBuilderState extends State<MeshagentConnectionBuilder> {
  Exception? error;
  int conectionNumber = 0;

  Widget _backHeader() {
    final isSmallDisplay = ResponsiveBreakpoints.of(context).smallerOrEqualTo("chromebook");

    if (isSmallDisplay) {
      return Tooltip(
        message: "Back",
        child: ShadIconButton.ghost(icon: const Icon(LucideIcons.arrowLeft), onPressed: () => context.go("/")),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _loadingBody(Widget child) {
    return MainWrapper(
      leftSideBar: _backHeader(),
      projectId: widget.projectId,
      projects: widget.projects,
      child: Center(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShadToaster(
      child: LuauConsoleScope(
        child: RoomConnectionScope(
          key: ValueKey("room-connection-${widget.roomName}-$conectionNumber"),
          authorization: () {
            final client = getMeshagentClient();

            return client.connectRoom(projectId: widget.projectId, roomName: widget.roomName);
          },
          notFoundBuilder: (context) => RoomNotFound(),
          oauthTokenRequestHandler: (RoomClient client, request) async {
            showShadDialog(
              context: context,
              builder: (context) => ShadDialog(
                title: Text("An agent would like permission to use one of your accounts"),
                description: Text("You will be redirected to the third party service to login (${request.authorizationEndpoint})."),
                actions: [
                  ShadButton.destructive(
                    onPressed: () {
                      client.secrets.rejectOAuthAuthorization(requestId: request.requestId, error: "cancelled");

                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel"),
                  ),

                  ShadButton(
                    onPressed: () async {
                      Navigator.of(context).pop();

                      final code = oauth2AuthorizationCode(
                        await oauth2Authenticate(
                          request,
                          Uri.parse("${MeshagentConfig.current?.appUrl}/oauth2/callback"),
                          jsonEncode({"room_name": widget.roomName, "request_id": request.requestId}),
                        ),
                      );

                      client.secrets.provideOAuthAuthorization(requestId: request.requestId, code: code!);
                    },
                    child: Text("Continue"),
                  ),
                ],
              ),
            );
          },
          secretRequestHandler: (RoomClient client, SecretRequest request) async {
            if (!context.mounted) return;

            if (request.type == "git") {
              final secretValue = {};
              final value = await showShadDialog<Map>(
                context: context,
                builder: (context) => ShadDialog.alert(
                  title: Text("Secret requested"),
                  description: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      Text("An agent requested credentials for ${request.url}"),
                      SizedBox(height: 8),
                      ShadInputFormField(
                        label: Text("Username"),
                        obscureText: false,
                        onChanged: (value) => secretValue["username"] = value,
                      ),
                      ShadInputFormField(
                        label: Text("Password / Personal Access Token"),
                        obscureText: true,
                        onChanged: (value) => secretValue["password"] = value,
                      ),
                    ],
                  ),
                  actions: [
                    ShadButton.secondary(onPressed: () => Navigator.of(context).pop(), child: Text("Cancel")),
                    ShadButton(onPressed: () => Navigator.of(context).pop(secretValue), child: Text("Provide")),
                  ],
                ),
              );

              if (value == null) {
                await client.secrets.rejectSecret(requestId: request.requestId, error: "cancelled");
              } else {
                await client.secrets.provideSecret(requestId: request.requestId, data: Uint8List.fromList(utf8.encode(jsonEncode(value))));
              }
            } else {
              String secretValue = "";
              final value = await showShadDialog<String>(
                context: context,
                builder: (context) => ShadDialog.alert(
                  title: Text("Secret requested"),
                  description: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("An agent requested a secret value."),
                      SizedBox(height: 8),
                      Text("Key: ${request.url}"),
                      Text("Type: ${request.type}"),
                      SizedBox(height: 16),
                      ShadInputFormField(label: Text("Secret"), obscureText: true, onChanged: (value) => secretValue = value),
                    ],
                  ),
                  actions: [
                    ShadButton.secondary(onPressed: () => Navigator.of(context).pop(), child: Text("Cancel")),
                    ShadButton(onPressed: () => Navigator.of(context).pop(secretValue), child: Text("Provide")),
                  ],
                ),
              );

              if (value == null) {
                await client.secrets.rejectSecret(requestId: request.requestId, error: "cancelled");
              } else {
                await client.secrets.provideSecret(requestId: request.requestId, data: Uint8List.fromList(utf8.encode(value)));
              }
            }
          },
          authorizingBuilder: (context) => Center(child: CircularProgressIndicator(key: loadingKey)),
          connectingBuilder: (context, client) => Center(child: CircularProgressIndicator(key: loadingKey)),
          doneBuilder: (context, error) {
            return SafeArea(
              child: _loadingBody(
                RoomEndedCard(
                  onReconnect: () {
                    setState(() {
                      conectionNumber += 1;
                    });
                  },
                ),
              ),
            );
          },
          builder: (context, client) {
            return FutureBuilder(
              future: client.ready,
              builder: (context, snapshot) =>
                  snapshot.hasData ? widget.builder(context, client) : Center(child: CircularProgressIndicator(key: loadingKey)),
            );
          },
        ),
      ),
    );
  }
}
