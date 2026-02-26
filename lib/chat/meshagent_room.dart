import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:http/http.dart';
import 'package:meshagent_flutter_shadcn/file_preview/markdown.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/shell/shell_agent.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter/meshagent_flutter.dart';
import 'package:meshagent_flutter_auth/meshagent_flutter_auth.dart';
import 'package:meshagent_flutter_dev/developer_console.dart';
import 'package:meshagent_flutter_shadcn/file_preview/file_preview.dart';
import 'package:meshagent_flutter_shadcn/meetings/meetings.dart';
import 'package:meshagent_flutter_shadcn/voice/voice.dart';

import 'package:powerboards/chat/hangup_button.dart';
import 'package:powerboards/livekit/room.dart' as room;
import 'package:powerboards/meshagent/agent_option.dart';
import 'package:powerboards/meshagent/agents_dropdown.dart';
import 'package:powerboards/meshagent/file_table_view.dart';
import 'package:powerboards/meshagent/grant.dart' as grant;
import 'package:powerboards/meshagent/loader.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/options_menu.dart';
import 'package:powerboards/meshagent/thread_view.dart';
import 'package:powerboards/meshagent/tool_connection_scope.dart';
import 'package:powerboards/meshagent/tools/ui_toolkit.dart';
import 'package:powerboards/meshagent/wait_for_agent_participant_builder.dart';
import 'package:powerboards/nav/leave_meeting.dart';
import 'package:powerboards/nav/nav.dart';
import 'package:powerboards/nav/update_room_perms_dialog.dart';
import 'package:powerboards/powerboards_controller/powerboards_controller.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/avatar_menu_button.dart';
import 'package:powerboards/ui/keyboard_safe.dart';
import 'package:powerboards/ui/meeting_view.dart';
import 'package:powerboards/ui/resizable_split_view.dart';

const defaultDebugSize = 0.4;

class ParticipantsButton extends StatefulWidget {
  const ParticipantsButton({super.key, required this.participants, required this.localParticipant});

  final List<RemoteParticipant> participants;
  final LocalParticipant? localParticipant;

  @override
  State createState() => _ParticipantsButtonState();
}

class _ParticipantsButtonState extends State<ParticipantsButton> {
  late final popoverController = ShadPopoverController();

  @override
  void dispose() {
    popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final tt = theme.textTheme;
    final nameSet = <String>{};

    for (final participant in widget.participants) {
      final name = participant.getAttribute("name") as String?;

      if (participant.role != 'agent' && name != null && name.isNotEmpty) {
        nameSet.add(name);
      }
    }

    final user = MeshagentAuth.current.getUser();
    final myEmail = ((user?['email'] as String?) ?? "").toLowerCase().trim();

    if (widget.localParticipant != null) {
      final name = widget.localParticipant!.getAttribute("name") as String?;

      if (name != null && name.isNotEmpty) {
        nameSet.add(name);
      }
    }

    if (nameSet.isEmpty) {
      return SizedBox.shrink();
    }

    return ShadPopover(
      controller: popoverController,
      popover: (context) => Container(
        width: 250,
        padding: const .symmetric(vertical: 8),
        child: Column(
          spacing: 16,
          mainAxisSize: .min,
          mainAxisAlignment: .start,
          crossAxisAlignment: .start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text("People in this room", style: tt.large),
            ),
            Column(
              spacing: 8,
              mainAxisSize: .min,
              mainAxisAlignment: .start,
              crossAxisAlignment: .start,
              children: nameSet.sorted((a, b) => a.toLowerCase().compareTo(b.toLowerCase())).map((name) {
                final isMe = name.toLowerCase().trim() == myEmail;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(LucideIcons.user, size: 16),
                      SizedBox(width: 8),
                      Flexible(child: Text(isMe ? "$name (You)" : name, overflow: .ellipsis)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      child: ShadButton.outline(leading: Icon(LucideIcons.users), onPressed: popoverController.toggle, child: Text("+${nameSet.length}")),
    );
  }
}

class InviteUserButton extends StatelessWidget {
  const InviteUserButton({super.key, required this.projectId, required this.roomName});

  final String projectId;
  final String roomName;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Tooltip(
      message: "Invite user",
      child: ShadButton.outline(
        leading: Icon(LucideIcons.userPlus),
        onPressed: () async {
          final room = await getMeshagentClient().getRoom(name: roomName, projectId: projectId);

          if (context.mounted) {
            await showUpdateRoomPermsDialog(context, projectId: projectId, room: room);
          }
        },
        child: isMobile ? null : Text("Invite"),
      ),
    );
  }
}

class MeetButton extends StatelessWidget {
  const MeetButton({super.key, required this.controller});

  final MeshagentRoomController controller;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Tooltip(
      message: "Meet",
      child: (controller.inMeeting ? ShadButton.new : ShadButton.outline)(
        leading: Icon(LucideIcons.video),
        onPressed: () {
          if (controller.inMeeting) {
            controller.exitMeeting();
          } else {
            controller.enterMeeting();
          }
        },
        child: isMobile ? null : Text("Meet"),
      ),
    );
  }
}

class FilesButton extends StatelessWidget {
  const FilesButton({super.key, required this.controller});

  final MeshagentRoomController controller;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return controller.isFilesShown
        ? Tooltip(
            message: "Hide files",
            child: ShadButton(leading: Icon(LucideIcons.files), onPressed: controller.hideFiles, child: isMobile ? null : Text("Files")),
          )
        : Tooltip(
            message: "Show files",
            child: ShadButton.outline(
              leading: Icon(LucideIcons.files),
              onPressed: controller.showFiles,
              child: isMobile ? null : Text("Files"),
            ),
          );
  }
}

class BackButton extends StatelessWidget {
  const BackButton({super.key, required this.projectId});

  final String projectId;

  void _goBack(BuildContext context) {
    final pid = fromUUID(projectId);

    context.go("/p/$pid");
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: "Back",
      child: ShadIconButton.ghost(
        icon: const Icon(LucideIcons.arrowLeft),
        onPressed: () async {
          final videoRoom = room.VideoRoomModel.maybeOf(context)?.room;
          final meetingViewController = Controller.ofType<MeetingViewController>(context);

          if (videoRoom != null) {
            final leave = await showLeaveMeeting(context);

            if (leave) {
              if (context.mounted) {
                meetingViewController.resetToLobby();

                _goBack(context);
              }
            }
          } else {
            _goBack(context);
          }
        },
      ),
    );
  }
}

class MeshagentRoomController extends Controller {
  bool _isFilesShown = false;
  bool _isDebugShown = false;
  bool _inMeeting = false;

  bool get isFilesShown => _isFilesShown;
  bool get isDebugShown => _isDebugShown;
  bool get inMeeting => _inMeeting;

  void showFiles() {
    _isFilesShown = true;
    _inMeeting = false;
    notifyListeners();
  }

  void hideFiles() {
    _isFilesShown = false;
    notifyListeners();
  }

  void showDebug() {
    _isDebugShown = true;
    notifyListeners();
  }

  void hideDebug() {
    _isDebugShown = false;
    notifyListeners();
  }

  void enterMeeting() {
    _inMeeting = true;
    _isFilesShown = false;
    notifyListeners();
  }

  void exitMeeting() {
    _inMeeting = false;
    notifyListeners();
  }
}

class ActionsRow extends StatelessWidget {
  const ActionsRow({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return SizedBox.shrink();
    }

    final act = [...actions];

    bool found = false;

    for (var i = 0; i < act.length; i++) {
      if (act[i] is Spacer) {
        found = true;
        break;
      }
    }

    if (!found) {
      for (var i = 0; i < act.length; i++) {
        if (act[i] is ParticipantsButton) {
          act.insert(i + 1, Spacer());
          found = true;
          break;
        }
      }
    }

    if (!found) {
      for (var i = 0; i < act.length; i++) {
        if (act[i] is AgentsDropdown) {
          act.insert(i + 1, Spacer());
          found = true;
          break;
        }
      }
    }

    if (!found) {
      act.insert(0, Spacer());
    }

    return SizedBox(
      height: headerHeight,
      child: Padding(
        padding: .symmetric(horizontal: 10),
        child: Row(spacing: 8, crossAxisAlignment: .center, children: act),
      ),
    );
  }
}

class MeshagentRoom extends StatefulWidget {
  const MeshagentRoom({super.key, required this.projectId, required this.projects, required this.room, this.service});

  final String projectId;
  final Resource<List<Project>> projects;
  final RoomClient room;
  final String? service;

  @override
  State createState() => MeshagentRoomState();
}

class MeshagentRoomState extends State<MeshagentRoom> {
  final videoChatKey = GlobalKey();

  final MeshagentRoomController controller = MeshagentRoomController();

  final List<RoomEvent> events = [];

  late final isOwner = Resource(() => grant.amIOwnerOfRoom(projectId: widget.projectId, roomName: widget.room.roomName!));
  late final canViewDeveloperLogs = Resource(
    () => grant.canViewDeveloperLogs(projectId: widget.projectId, roomName: widget.room.roomName!, userId: "me"),
  );
  late final canViewStorage = Resource(
    () => grant.canViewStorage(projectId: widget.projectId, roomName: widget.room.roomName!, userId: "me"),
  );

  @override
  void initState() {
    super.initState();

    customViewers["thread"] = ({Key? key, required RoomClient room, required String filename, required Uri url}) {
      return MeshagentThreadView(client: room, participantNames: [], documentPath: filename, joinMeeting: _joinMeeting, services: services);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromUrl();
    });
  }

  void _initializeFromUrl() {
    final state = PathRouteMatch.of(context);
    final currentUri = state.uri;
    final path = currentUri.queryParameters['p'];

    if (path != null && path.isNotEmpty) {
      controller.showFiles();
    }
  }

  late final services = Resource<List<ServiceSpec>>(() async {
    final projectId = widget.projectId;
    final services = (await getMeshagentClient().listRoomServices(
      projectId: projectId,
      roomName: widget.room.roomName!,
    )).where((x) => x.agents.isNotEmpty).toList();
    services.sort(_compareServices);
    return services;
  });

  List<ServiceSpec> _supportedServices(List<ServiceSpec> all) {
    final supported = all.where(isSupportedServiceType).toList();
    supported.sort(_compareServices);
    return supported;
  }

  String _serviceSortKey(ServiceSpec s) => s.agents.firstOrNull?.name ?? s.metadata.name;
  int _compareServices(ServiceSpec a, ServiceSpec b) => _serviceSortKey(a).compareTo(_serviceSortKey(b));

  String _serviceId(ServiceSpec s) => s.metadata.annotations["meshagent.service.id"] ?? "";
  String _serviceType(ServiceSpec s) => s.agents.firstOrNull?.annotations["meshagent.agent.type"] ?? "[Unspecified]";
  bool _isChatBot(ServiceSpec s) => _serviceType(s).toLowerCase() == "chatbot";

  ServiceSpec? _selectedService(List<ServiceSpec> supported) {
    if (widget.service != null) {
      return supported.firstWhereOrNull((s) => _serviceId(s) == widget.service);
    }

    return supported.firstWhereOrNull(_isChatBot) ?? supported.firstOrNull;
  }

  void updatePath(BuildContext context, String? path) {
    controller.showFiles();

    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (!isMobile) {
      final state = PathRouteMatch.of(context);
      final currentUri = state.uri;

      final updatedQueryParameters = Map<String, String>.from(currentUri.queryParameters);
      if (path == null) {
        updatedQueryParameters.remove('p');
      } else {
        updatedQueryParameters['p'] = path;
      }

      final newUri = currentUri.replace(queryParameters: updatedQueryParameters);

      context.go(newUri.toString());
    }
  }

  String getDocumentPath(String userId, String? agent) {
    if (agent != null) {
      return '.threads/$agent/main.thread';
    } else {
      return '.threads/main.thread';
    }
  }

  List<Widget> meetingActions(BuildContext context) {
    final meetingViewController = Controller.ofType<MeetingViewController>(context);
    final model = room.VideoRoomModel.maybeOf(context);
    return model?.room == null
        ? []
        : [
            HangupButton(
              onPressed: () {
                meetingViewController.endMeeting();
                //onCancel();
              },
            ),
            room.MicToggle(),
            room.CameraToggle(),
            room.ChangeSettings(),
            room.ShareScreen(),
            MeetingToolkits(room: widget.room),
            Spacer(),
          ];
  }

  Future<void> showManageAgents() async {
    await showShadDialog(
      context: context,
      builder: (context) => ManageAgentsDialog(projectId: widget.projectId, room: widget.room),
    );
    if (!mounted) return;
    services.refresh();
  }

  Widget _buildAgentsActionRow(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (!isMobile) return const SizedBox.shrink();

    if (!services.state.isReady) return const SizedBox.shrink();

    final supported = _supportedServices(services.state.value!);
    final selected = _selectedService(supported);

    return Align(
      alignment: AlignmentGeometry.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: AgentsDropdown(
          projectId: widget.projectId,
          room: widget.room,
          selectedService: selected,
          services: supported,
          onOpen: services.refresh,
          onManageAgents: isOwner.state.value != true ? null : showManageAgents,
        ),
      ),
    );
  }

  Widget _buildErrorArea(BuildContext context, String error, List<Widget> actions) {
    return Column(
      children: [
        ActionsRow(actions: actions),
        _buildAgentsActionRow(context),
        Expanded(
          child: Center(child: ShadAlert.destructive(title: Text(error))),
        ),
      ],
    );
  }

  Widget _buildShellArea(BuildContext context, ServiceSpec service, List<Widget> actions) {
    final command = service.metadata.annotations["meshagent.service.shell.command"];

    return Column(
      children: [
        ActionsRow(actions: actions),
        _buildAgentsActionRow(context),
        Expanded(
          child: Builder(
            builder: (context) {
              if (command == null) {
                return Center(child: ShadAlert.destructive(title: Text("Shell agent must have command")));
              }
              return ShellAgent(key: ValueKey(service.id), command: command, room: widget.room, service: service);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatArea(BuildContext context, String? agentName, List<Widget> actions) {
    final user = MeshagentAuth.current.getUser();
    final userId = user!['id'] as String;

    return Column(
      children: [
        ActionsRow(actions: actions),
        _buildAgentsActionRow(context),
        Expanded(
          child: MeshagentThreadView(
            services: services,
            agentName: agentName,
            key: ValueKey(getDocumentPath(userId, agentName)),
            client: widget.room,
            documentPath: getDocumentPath(userId, agentName),
            participantNames: [user["email"], ?agentName],
            joinMeeting: _joinMeeting,
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceArea(BuildContext context, String agentName, List<Widget> actions) {
    return Column(
      children: [
        ActionsRow(actions: actions),
        _buildAgentsActionRow(context),
        Expanded(
          child: WaitForAgentParticipantBuilder(
            key: ValueKey(agentName),
            room: widget.room,
            agentName: agentName,
            builder: (context, participant) => Column(
              children: [
                Expanded(
                  child: Center(
                    child: participant == null
                        ? ShadButton.outline(child: Text("Start Voice Session"))
                        : ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 500, maxHeight: 500),
                            child: VoiceAgentCaller(meeting: MeetingController.of(context), participant: participant),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeetingTranscriberArea(BuildContext context, String agentName, List<Widget> actions) {
    return WaitForAgentParticipantBuilder(
      key: ValueKey(agentName),
      room: widget.room,
      agentName: agentName,
      builder: (context, participant) => Column(
        children: [
          ActionsRow(actions: actions),
          _buildAgentsActionRow(context),
          Expanded(
            child: participant == null
                ? Center(child: CircularProgressIndicator(key: loadingKey))
                : controller.inMeeting
                ? _buildChatArea(context, null, [])
                : Center(
                    child: ShadButton.outline(
                      onPressed: () {
                        _joinMeeting();
                      },
                      child: Text("Start Meeting"),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesArea(BuildContext context, List<Widget> actions) {
    return Column(
      children: [
        ActionsRow(actions: actions),
        Expanded(child: FileManagerView(client: widget.room, hideSystem: true)),
      ],
    );
  }

  Widget _buildMeeting(BuildContext context, String? agentName, List<Widget> actions) {
    return Column(
      children: [
        ActionsRow(actions: actions),
        Expanded(
          child: MeetingView(room: widget.room, onCancel: _leaveMeeting, joinMeeting: _joinMeeting, agentName: agentName),
        ),
      ],
    );
  }

  void _leaveMeeting() {
    final navController = Controller.ofType<NavController>(context);
    navController.showNav();
    controller.exitMeeting();
  }

  void _joinMeeting() {
    final meetingViewController = Controller.ofType<MeetingViewController>(context);

    meetingViewController.resetToLobby();
    controller.enterMeeting();
  }

  Widget _buildAgentArea(BuildContext context, List<Widget> actions) {
    return SignalBuilder(
      builder: (context, _) {
        if (!services.state.isReady) {
          return Center(child: CircularProgressIndicator(key: loadingKey));
        }

        final all = services.state.value!;
        final supported = _supportedServices(all);
        final service = _selectedService(supported);

        if (supported.isEmpty) {
          return _buildErrorArea(context, "No supported agents installed", actions);
        }

        if (service == null) {
          return _buildErrorArea(context, "Agent is not installed ${widget.service}", actions);
        }

        final type = _serviceType(service);
        if (type == "ChatBot") {
          return _buildChatArea(context, service.agents[0].name, actions);
        } else if (type == "VoiceBot") {
          return _buildVoiceArea(context, service.agents[0].name, actions);
        } else if (type == "MeetingTranscriber") {
          return _buildMeetingTranscriberArea(context, service.agents[0].name, actions);
        } else if (type == "Shell") {
          return _buildShellArea(context, service, actions);
        } else if (service.metadata.annotations["meshagent.service.readme"] != null) {
          return MarkdownViewer(markdown: service.metadata.annotations["meshagent.service.readme"] ?? "");
        } else {
          return _buildErrorArea(context, "Agent type '$type' is not currently supported by Powerboards", actions);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rb = ResponsiveBreakpoints.of(context);
    final isMobile = rb.isMobile;
    final isSmallDisplay = rb.smallerOrEqualTo("chromebook");

    return RoomParticipantsBuilder(
      room: widget.room,
      builder: (context, participants) {
        return MeetingScope(
          client: widget.room,
          builder: (context, meeting) => SignalBuilder(
            builder: (context, _) => !services.state.isReady || !canViewStorage.state.isReady
                ? Center(child: CircularProgressIndicator())
                : room.VideoChatConnection(
                    key: videoChatKey,
                    child: ControllerBuilder(
                      controller: controller,
                      builder: (context) {
                        final filesVisible = canViewStorage.state.value == true && controller.isFilesShown;
                        final split = filesVisible || controller.inMeeting;

                        if (services.state.value!.isEmpty) {
                          return SafeArea(
                            child: Column(
                              children: [
                                ActionsRow(
                                  actions: [
                                    if (isSmallDisplay) BackButton(projectId: widget.projectId),
                                    Spacer(),
                                    InviteUserButton(projectId: widget.projectId, roomName: widget.room.roomName!),
                                    if (!isMobile) ...[
                                      RoomOptionsMenu(
                                        projectId: widget.projectId,
                                        room: widget.room,
                                        roomController: controller,
                                        isOwner: isOwner,
                                        canViewDeveloperLogs: canViewDeveloperLogs,
                                      ),
                                      UserAvatarMenuButton(projectId: widget.projectId, projects: widget.projects),
                                    ],
                                  ],
                                ),
                                Expanded(
                                  child: Center(
                                    child: SignalBuilder(
                                      builder: (context, _) => Column(
                                        spacing: 16,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "Welcome to your room",
                                            style: ShadTheme.of(context).textTheme.h1,
                                            textAlign: TextAlign.center,
                                          ),
                                          if (isOwner.hasValue && isOwner.state.value == true) ...[
                                            Text(
                                              "Install an agent in this room to get started",
                                              style: ShadTheme.of(context).textTheme.p,
                                              textAlign: TextAlign.center,
                                            ),
                                            ShadButton(
                                              onPressed: () async {
                                                await showShadDialog(
                                                  context: context,
                                                  builder: (context) => ManageAgentsDialog(
                                                    room: widget.room,
                                                    projectId: widget.projectId,
                                                    onServiceChanged: () {
                                                      services.refresh();
                                                    },
                                                  ),
                                                );
                                              },
                                              child: Text("Install an Agent"),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ToolConnectionScope(
                          tools: [UIToolkit(context, room: widget.room)],
                          builder: (context, error) {
                            if (isMobile) {
                              final actions = [
                                BackButton(projectId: widget.projectId),
                                Spacer(),
                                (split ? ShadButton.outline : ShadButton.new)(
                                  onPressed: () {
                                    setState(() {
                                      controller.exitMeeting();
                                      controller.hideFiles();
                                    });
                                  },
                                  leading: Icon(LucideIcons.messageCircle),
                                ),
                                if (canViewStorage.state.value == true) FilesButton(controller: controller),
                                MeetButton(controller: controller),
                                InviteUserButton(projectId: widget.projectId, roomName: widget.room.roomName!),
                              ];

                              return KeyboardSafe(
                                child: SafeArea(
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: controller.inMeeting
                                            ? _buildMeeting(context, null, actions)
                                            : filesVisible
                                            ? _buildFilesArea(context, actions)
                                            : _buildAgentArea(context, actions),
                                      ),
                                      ActionsRow(actions: [...meetingActions(context)]),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final supported = _supportedServices(services.state.value!);
                            final selected = _selectedService(supported);
                            final actions = [
                              ...meetingActions(context),

                              if (canViewStorage.state.value == true) FilesButton(controller: controller),
                              MeetButton(controller: controller),
                              InviteUserButton(projectId: widget.projectId, roomName: widget.room.roomName!),
                              RoomOptionsMenu(
                                projectId: widget.projectId,
                                room: widget.room,
                                roomController: controller,
                                isOwner: isOwner,
                                canViewDeveloperLogs: canViewDeveloperLogs,
                              ),
                              UserAvatarMenuButton(projectId: widget.projectId, projects: widget.projects),
                            ];

                            return RoomDeveloperLogsListener(
                              events: events,
                              client: widget.room,
                              child: ShadResizablePanelGroup(
                                axis: Axis.vertical,
                                showHandle: true,
                                children: [
                                  ShadResizablePanel(
                                    id: "top",
                                    defaultSize: 1 - defaultDebugSize,
                                    child: ResizableSplitView(
                                      allowCollapse: room.VideoRoomModel.maybeOf(context)?.room != null,
                                      split: split,
                                      area1: _buildAgentArea(context, [
                                        if (isSmallDisplay) BackButton(projectId: widget.projectId),

                                        AgentsDropdown(
                                          projectId: widget.projectId,
                                          room: widget.room,
                                          selectedService: selected,
                                          services: supported,
                                          onOpen: services.refresh,
                                          onManageAgents: isOwner.state.value != true ? null : showManageAgents,
                                        ),

                                        ParticipantsButton(participants: participants, localParticipant: widget.room.localParticipant),

                                        if (!split) ...actions,
                                      ]),
                                      area2: !split
                                          ? Container()
                                          : filesVisible
                                          ? _buildFilesArea(context, actions)
                                          : controller.inMeeting
                                          ? _buildMeeting(context, null, actions)
                                          : _buildAgentArea(context, actions),
                                    ),
                                  ),

                                  if (controller.isDebugShown)
                                    ShadResizablePanel(
                                      id: "bottom",
                                      defaultSize: defaultDebugSize,
                                      minSize: 0,
                                      child: Visibility(
                                        visible: controller.isDebugShown,
                                        child: Column(
                                          children: [
                                            Row(children: [Expanded(child: SizedBox())]),
                                            Expanded(
                                              child: RoomDeveloperConsole(
                                                pricing: null,
                                                events: events,
                                                room: widget.room,
                                                shellImage: "${MeshagentConfig.current!.imageTagPrefix}cli:{SERVER_VERSION}-esgz",
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _ResourceFetcher<T> extends StatefulWidget {
  const _ResourceFetcher({super.key, required this.uri, required this.builder, required this.mapper});

  final T Function(Uint8List data) mapper;
  final Widget Function(BuildContext context, T? data, Object? error) builder;

  final Uri uri;

  @override
  State createState() => _ResourceFetcherState<T>();
}

class _ResourceFetcherState<T> extends State<_ResourceFetcher<T>> {
  @override
  void initState() {
    super.initState();

    get(widget.uri).then((value) {
      setState(() {
        data = widget.mapper(value.bodyBytes);
      });
    });
  }

  T? data;
  Object? error;

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, data, error);
  }
}

class WidgetConfig {
  const WidgetConfig({required this.initialJson, required this.schema});

  final Map<String, dynamic> initialJson;
  final MeshSchema schema;
}
