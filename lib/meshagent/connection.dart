import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/powerboards_breakpoints.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter/meshagent_flutter.dart';

import 'package:powerboards/meshagent/loader.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/room_ended_card.dart';
import 'package:powerboards/meshagent/room_not_found.dart';
import 'package:powerboards/powerboards_controller/powerboards_controller.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/settings/ui_mode.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/nav/nav.dart';
import 'package:powerboards/ui/powerboards_back_icon_button.dart';
import 'package:powerboards/ui/sweep_status_text.dart';
import 'package:powerboards/ui/main_wrapper.dart';

class MeshagentConnectionResponse {
  MeshagentConnectionResponse({required this.url, required this.token, required this.roomType});

  factory MeshagentConnectionResponse.fromJSON(Map<String, dynamic> json) {
    return MeshagentConnectionResponse(url: json["url"] ?? "", token: json["token"] ?? "", roomType: json["roomType"] ?? "");
  }

  final String url;
  final String token;
  final String roomType;
}

class _RoomConnectionScopeGlobalKey extends GlobalObjectKey {
  const _RoomConnectionScopeGlobalKey(super.value);
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
  Object _roomConnectionScopeIdentity = Object();
  String _lastConnectionStatusText = _defaultConnectionStatusText;
  bool _roomWasConnected = false;

  @override
  void didUpdateWidget(covariant MeshagentConnectionBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId || oldWidget.roomName != widget.roomName) {
      _roomConnectionScopeIdentity = Object();
      _lastConnectionStatusText = _defaultConnectionStatusText;
      _roomWasConnected = false;
    }
  }

  Widget _backHeader() {
    final isMobile = powerboardsUsesNativeMobileAdaptiveLayout(context);
    final isSmallDisplay = ResponsiveBreakpoints.of(context).smallerOrEqualTo("chromebook");

    if (isMobile) {
      final navController = Controller.maybeOfType<NavController>(context);
      if (navController == null) {
        return const SizedBox.shrink();
      }

      return PowerboardsBackIconButton(onPressed: navController.openMobileRoomList, tooltip: "Open rooms", icon: LucideIcons.menu);
    }

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

  Widget _roomSafeAreaShell(Widget child) {
    final isMobile = powerboardsUsesNativeMobileAdaptiveLayout(context);

    return ColoredBox(
      color: isMobile ? Colors.transparent : shadCard,
      child: SafeArea(minimum: isMobile ? powerboardsMobileScreenSafeAreaMinimum : EdgeInsets.zero, child: child),
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
    final isMobile = powerboardsUsesNativeMobileAdaptiveLayout(context);
    final isSmallDisplay = ResponsiveBreakpoints.of(context).smallerOrEqualTo("chromebook");
    final navController = isMobile ? Controller.maybeOfType<NavController>(context) : null;
    if (powerboardsUsesDesktopUiPreview(context)) {
      return _roomSafeAreaShell(child);
    }

    final content = Column(
      children: [
        SizedBox(
          height: headerHeight,
          child: isMobile
              ? Padding(
                  padding: powerboardsMobileHorizontalPadding,
                  child: Row(
                    children: [
                      if (navController != null)
                        PowerboardsBackIconButton(
                          onPressed: navController.openMobileRoomList,
                          tooltip: "Open rooms",
                          icon: LucideIcons.menu,
                        ),
                    ],
                  ),
                )
              : isSmallDisplay
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [PowerboardsBackIconButton(onPressed: () => context.go("/"))]),
                )
              : null,
        ),
        Expanded(child: child),
      ],
    );
    return _roomSafeAreaShell(content);
  }

  void _reconnect() {
    setState(() {
      _roomWasConnected = false;
      _roomConnectionScopeIdentity = Object();
    });
  }

  Widget _roomDisconnectedCard() {
    return _roomSafeAreaShell(
      _loadingBody(RoomEndedCard(title: "Disconnected from room", description: "The room connection has ended.", onReconnect: _reconnect)),
    );
  }

  Widget _roomConnectionFailedCard() {
    return _roomSafeAreaShell(
      _loadingBody(RoomEndedCard(title: "Unable to connect to room", description: "Please try reconnecting.", onReconnect: _reconnect)),
    );
  }

  Widget _roomDisabledCard() {
    return _roomSafeAreaShell(
      _loadingBody(
        RoomEndedCard(
          title: "Room disabled",
          description: "This room is disabled. An administrator or developer must enable it before anyone can connect.",
          onReconnect: _reconnect,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShadToaster(
      child: RoomConnectionScope(
        key: _RoomConnectionScopeGlobalKey(_roomConnectionScopeIdentity),
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
        authorizingBuilder: (context) => _withReservedRoomHeader(_connectionProgress()),
        retryingBuilder: (context, error) => _withReservedRoomHeader(_connectionProgress(fallbackStatusText: "waiting to retry")),
        connectingBuilder: (context, client) => _withReservedRoomHeader(_connectionProgress(room: client)),
        doneBuilder: (context, error) {
          if (error is RoomDisabledException || (error is RoomServerException && error.statusCode == 423)) {
            return _roomDisabledCard();
          }
          if (_roomWasConnected || error == null) {
            return _roomDisconnectedCard();
          }

          return _roomConnectionFailedCard();
        },
        builder: (context, client) => widget.builder(context, client),
      ),
    );
  }
}
