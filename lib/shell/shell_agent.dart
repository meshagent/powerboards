import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_dev/terminal.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ShellAgent extends StatefulWidget {
  const ShellAgent({super.key, required this.command, required this.room, required this.service});

  final String command;
  final RoomClient room;
  final ServiceSpec service;

  @override
  State createState() => _ShellAgent();
}

class _ShellAgent extends State<ShellAgent> {
  ExecSession? session;

  Future<String?> findContainer() async {
    if (widget.service.container?.onDemand == true) {
      final running = (await widget.room.containers.list()).firstWhereOrNull(
        (x) => x.name == widget.service.metadata.name && x.startedBy.name == widget.room.localParticipant!.getAttribute("name"),
      );
      if (running != null) {
        return running.id;
      }
    } else {
      if (!mounted) return null;
      setState(() {
        connecting = true;
        status = "Waiting for container to start...";
      });
      while (true) {
        if (!mounted) return null;
        final running = (await widget.room.containers.list()).firstWhereOrNull((x) => x.serviceId == widget.service.id);
        if (!mounted) return null;
        if (running != null) {
          return running.id;
        }
        await Future.delayed(Duration(seconds: 1));
      }
    }

    return null;
  }

  Future<String?> runContainer() async {
    final containerId = await findContainer();
    if (containerId != null) {
      return containerId;
    }
    final env = <String, String>{};
    if (widget.service.agents[0].annotations["meshagent.shell.auth"] == "delegate") {
      if (!mounted) return null;
      final check = await showShadDialog(
        context: context,
        builder: (context) => ShadDialog.alert(
          title: Text("Permission Requested"),

          actions: [
            ShadButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text("Cancel"),
            ),
            ShadButton.destructive(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text("Grant Access"),
            ),
          ],
          child: const Padding(
            padding: .symmetric(vertical: 15),
            child: Text("This agent will have the ability to run commands as you inside this room, are you sure you want to continue?"),
          ),
        ),
      );
      if (check != true) {
        return null;
      }
      env["OPENAI_API_KEY"] = (widget.room.protocol.channel as WebSocketProtocolChannel).jwt;
      env["MESHAGENT_TOKEN"] = (widget.room.protocol.channel as WebSocketProtocolChannel).jwt;
    }
    return await widget.room.containers.runService(serviceId: widget.service.id!, env: env);
  }

  String? containerId;

  String status = "";
  bool connecting = false;

  void startSession() async {
    setState(() {
      connecting = true;
      status = "Downloading agent...";
    });
    containerId = await runContainer();
    if (containerId == null) {
      return;
    }
    if (mounted) {
      setState(() {
        connecting = false;
        exec();
      });
    }
  }

  int? result;

  void exec() {
    setState(() {
      ended = false;
      result = null;
      session = widget.room.containers.exec(containerId: containerId!, command: widget.command, tty: true);
      session!.result.then((i) {
        if (mounted) {
          setState(() {
            result = i;
          });
        }
      });
    });
    session!.result.whenComplete(() {
      if (mounted) {
        setState(() {
          ended = true;
        });
      }
    });
  }

  bool ended = false;

  @override
  void initState() {
    super.initState();

    findContainer().then((c) {
      if (c != null) {
        containerId = c;
        if (mounted) {
          exec();
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    session?.kill();
  }

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return Center(
        child: connecting
            ? Column(spacing: 16, mainAxisSize: MainAxisSize.min, children: [Text(status), CircularProgressIndicator()])
            : ShadButton.outline(
                leading: Icon(LucideIcons.play),
                onPressed: () {
                  startSession();
                },
                child: Text("Start"),
              ),
      );
    } else {
      return Column(
        mainAxisSize: .max,
        crossAxisAlignment: .stretch,
        children: [
          if (ended)
            Container(
              color: Colors.red,
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: result != null
                        ? Text("Session ended with exit code: $result", style: TextStyle(color: Colors.white))
                        : Text("Session ended", style: TextStyle(color: Colors.white)),
                  ),
                  ShadButton(
                    leading: Icon(LucideIcons.play),
                    onPressed: () {
                      startSession();
                    },
                    child: Text("Restart"),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ContainerTerminal(key: Key("terminal"), session: session!),
          ),
        ],
      );
    }
  }
}
