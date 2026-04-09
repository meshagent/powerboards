import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter/meshagent_flutter.dart';

import 'package:powerboards/meshagent/loader.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/room_ended_card.dart';
import 'package:powerboards/meshagent/room_not_found.dart';
import 'package:powerboards/oauth/oauth.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/powerboards_back_icon_button.dart';
import 'package:powerboards/ui/sweep_status_text.dart';
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
  static const String _defaultConnectionStatusText = "Connecting to room";

  Exception? error;
  int conectionNumber = 0;
  String _lastConnectionStatusText = _defaultConnectionStatusText;
  bool _roomWasConnected = false;

  Widget _backHeader() {
    final isSmallDisplay = ResponsiveBreakpoints.of(context).smallerOrEqualTo("chromebook");

    if (isSmallDisplay) {
      return PowerboardsBackIconButton(onPressed: () => context.go("/"));
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

  Widget _connectionProgress({RoomClient? room, String? fallbackStatusText}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            spacing: 10,
            mainAxisSize: MainAxisSize.min,
            children: [
              SweepStatusText(
                text: "Preparing your room",
                style: ShadTheme.of(context).textTheme.p.copyWith(fontWeight: FontWeight.w700),
              ),
              if (room == null)
                SweepStatusText(text: fallbackStatusText ?? _lastConnectionStatusText, style: ShadTheme.of(context).textTheme.muted)
              else
                StreamBuilder<RoomStatusEvent>(
                  stream: room.events.where((event) => event is RoomStatusEvent).cast<RoomStatusEvent>(),
                  builder: (context, snapshot) {
                    final description = snapshot.data?.description.trim();
                    if (description != null && description.isNotEmpty) {
                      _lastConnectionStatusText = description;
                    }
                    return SweepStatusText(
                      text: (description == null || description.isEmpty) ? _lastConnectionStatusText : description,
                      style: ShadTheme.of(context).textTheme.muted,
                    );
                  },
                ),
              SizedBox(height: 2),
              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(key: loadingKey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _withReservedRoomHeader(Widget child) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isSmallDisplay = ResponsiveBreakpoints.of(context).smallerOrEqualTo("chromebook");
    final content = Column(
      children: [
        SizedBox(
          height: headerHeight,
          child: isSmallDisplay
              ? Padding(
                  padding: isMobile ? powerboardsMobileHorizontalPadding : const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [PowerboardsBackIconButton(onPressed: () => context.go("/"))]),
                )
              : null,
        ),

        Expanded(child: child),
      ],
    );

    if (isMobile) {
      return SafeArea(minimum: powerboardsMobileScreenSafeAreaMinimum, child: content);
    }

    return content;
  }

  void _reconnect() {
    setState(() {
      _roomWasConnected = false;
      conectionNumber += 1;
    });
  }

  Widget _roomDisconnectedCard() {
    return SafeArea(
      minimum: powerboardsMobileScreenSafeAreaMinimum,
      child: _loadingBody(
        RoomEndedCard(
          title: "Disconnected from room",
          description: "You were disconnected from the room due to inactivity.",
          onReconnect: _reconnect,
        ),
      ),
    );
  }

  Widget _roomConnectionFailedCard() {
    return SafeArea(
      minimum: powerboardsMobileScreenSafeAreaMinimum,
      child: _loadingBody(
        RoomEndedCard(title: "Unable to connect to room", description: "Please try reconnecting.", onReconnect: _reconnect),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShadToaster(
      child: RoomConnectionScope(
        key: ValueKey("room-connection-${widget.roomName}-$conectionNumber"),
        authorization: () {
          _lastConnectionStatusText = _defaultConnectionStatusText;
          _roomWasConnected = false;
          final client = getMeshagentClient();

          return client.connectRoom(projectId: widget.projectId, roomName: widget.roomName);
        },
        onReady: (client) {
          _roomWasConnected = true;
        },
        notFoundBuilder: (context) => RoomNotFound(),
        oauthTokenRequestHandler: (RoomClient client, request) async {
          showShadDialog(
            context: context,
            builder: (context) => PowerboardsShadDialog.compact(
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
                        jsonEncode({"project_id": widget.projectId, "room_name": widget.roomName, "request_id": request.requestId}),
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
              builder: (context) => PowerboardsShadDialog.alert(
                title: Text("Secret requested"),
                description: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text("An agent requested credentials for ${request.url}"),
                    SizedBox(height: 8),
                    ShadInputFormField(label: Text("Username"), obscureText: false, onChanged: (value) => secretValue["username"] = value),
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
              builder: (context) => PowerboardsShadDialog.alert(
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
        authorizingBuilder: (context) => _withReservedRoomHeader(_connectionProgress()),
        retryingBuilder: (context, error) => _withReservedRoomHeader(_connectionProgress(fallbackStatusText: "waiting to retry")),
        connectingBuilder: (context, client) => _withReservedRoomHeader(_connectionProgress(room: client)),
        doneBuilder: (context, error) {
          if (_roomWasConnected || error == null) {
            return _roomDisconnectedCard();
          }

          return _roomConnectionFailedCard();
        },
        builder: (context, client) {
          return FutureBuilder(
            future: client.ready,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _roomConnectionFailedCard();
              }

              if (snapshot.connectionState != ConnectionState.done) {
                return _withReservedRoomHeader(_connectionProgress(room: client));
              }

              return widget.builder(context, client);
            },
          );
        },
      ),
    );
  }
}
