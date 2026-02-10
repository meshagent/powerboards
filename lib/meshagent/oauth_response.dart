import 'package:flutter/material.dart';
import 'package:meshagent_flutter/meshagent_flutter.dart';

import 'meshagent.dart';

class OAuthResponsePage extends StatefulWidget {
  const OAuthResponsePage({
    super.key,
    required this.projectId,
    required this.roomName,
    required this.requestId,
    required this.authorizationCode,
  });

  final String projectId;
  final String roomName;
  final String requestId;
  final String authorizationCode;

  @override
  State createState() => _OAuthResponsePage();
}

class _OAuthResponsePage extends State<OAuthResponsePage> {
  String? jwt;
  bool done = false;

  @override
  void initState() {
    super.initState();

    final client = getMeshagentClient();
    client.connectRoom(projectId: widget.projectId, roomName: widget.roomName).then((resp) {
      if (!mounted) return;

      setState(() {
        jwt = resp.jwt;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (jwt == null) {
      return Center(child: CircularProgressIndicator());
    } else if (done == true) {
      return Center(child: Text("You are logged in, you can close this window"));
    } else {
      return RoomConnectionScope(
        authorization: staticAuthorization(
          projectId: widget.projectId,
          roomName: widget.roomName,
          url: MeshagentConfig.current!.getWsUrl(widget.roomName),
          jwt: jwt!,
        ),
        onReady: (room) async {
          await room.secrets.provideOAuthAuthorization(requestId: widget.requestId, code: widget.authorizationCode);
          if (!mounted) return;
          setState(() {
            done = true;
          });
        },
        builder: (context, room) {
          return Center(child: CircularProgressIndicator());
        },
      );
    }
  }
}
