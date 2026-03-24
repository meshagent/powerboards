import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart';
import 'package:meshagent_flutter_shadcn/file_preview/markdown.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/shell/shell_agent.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter/meshagent_flutter.dart';
import 'package:meshagent_flutter_auth/meshagent_flutter_auth.dart';
import 'package:meshagent_flutter_dev/developer_console.dart';
import 'package:meshagent_flutter_shadcn/file_preview/file_preview.dart';
import 'package:meshagent_flutter_shadcn/meetings/meetings.dart';
import 'package:meshagent_flutter_shadcn/viewers/builder.dart';
import 'package:meshagent_flutter_shadcn/voice/voice.dart';

import 'package:powerboards/chat/hangup_button.dart';
import 'package:powerboards/livekit/room.dart' as room;
import 'package:powerboards/meshagent/agent_participants.dart';
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
import 'package:powerboards/ui/pane_header_action_scope.dart';
import 'package:powerboards/ui/resizable_split_view.dart';
import 'package:powerboards/ui/sweep_status_text.dart';

const defaultDebugSize = 0.4;
final meetingHeaderTitleStyle = GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600);
const double _meetingToolbarCompactThreshold = 440;
const double _meetingToolbarPreferredExpandedWidth = 400;
const double _meetingToolbarPreferredCompactWidth = 320;

EdgeInsetsGeometry _paneHeaderButtonPadding({required bool compact}) {
  if (compact) {
    return const EdgeInsets.symmetric(horizontal: 0);
  }

  return const EdgeInsets.symmetric(horizontal: 10);
}

class ParticipantsButton extends StatefulWidget {
  const ParticipantsButton({super.key, required this.participants, required this.localParticipant});

  final List<RemoteParticipant> participants;
  final LocalParticipant? localParticipant;

  @override
  State createState() => _ParticipantsButtonState();
}

class _ParticipantsButtonState extends State<ParticipantsButton> {
  late final popoverController = ShadPopoverController();
  final statesController = ShadStatesController();

  String _initialFromText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return "U";

    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  String _initialsFromName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return "U";

    final localPart = trimmed.split("@").first;
    final parts = localPart.split(RegExp(r"[._\- ]+")).where((part) => part.isNotEmpty).toList();

    if (parts.length >= 2) {
      return "${_initialFromText(parts[0])}${_initialFromText(parts[1])}";
    }

    if (parts.length == 1) {
      return _initialFromText(parts[0]);
    }

    return _initialFromText(trimmed);
  }

  Widget _buildOverlapAvatars(List<String> names, Set<ShadState> states) {
    const avatarSize = 38.0;
    const overlapOffset = 24.0;
    final width = avatarSize + (names.length - 1) * overlapOffset;
    final hovered = states.contains(ShadState.hovered);

    return SizedBox(
      width: width,
      height: avatarSize,
      child: Stack(
        children: List.generate(names.length, (index) {
          final name = names[index];
          return Positioned(
            left: index * overlapOffset,
            child: Tooltip(
              message: name,
              child: UserAvatarCircle(initials: _initialsFromName(name), size: avatarSize, hovered: hovered),
            ),
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final nameSet = <String>{};
    final myName = (widget.localParticipant?.getAttribute("name") as String?)?.trim().toLowerCase();

    for (final participant in widget.participants) {
      final name = participant.getAttribute("name") as String?;

      if (participant.role != 'agent' && name != null && name.isNotEmpty && (myName == null || name.trim().toLowerCase() != myName)) {
        nameSet.add(name);
      }
    }

    if (nameSet.isEmpty) {
      return SizedBox.shrink();
    }

    final sortedNames = nameSet.sorted((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final trigger = sortedNames.length <= 3
        ? ValueListenableBuilder(
            valueListenable: statesController,
            builder: (BuildContext context, Set<ShadState> states, Widget? child) {
              return ShadButton.ghost(
                statesController: statesController,
                hoverBackgroundColor: cs.background,
                padding: .zero,
                onPressed: popoverController.toggle,
                decoration: ShadDecoration(shape: .circle),
                child: _buildOverlapAvatars(sortedNames, states),
              );
            },
          )
        : ShadButton.outline(leading: Icon(LucideIcons.users), onPressed: popoverController.toggle, child: Text("+${nameSet.length}"));

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
              child: Text("People here right now", style: tt.large),
            ),
            Column(
              spacing: 8,
              mainAxisSize: .min,
              mainAxisAlignment: .start,
              crossAxisAlignment: .start,
              children: sortedNames.map((name) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(LucideIcons.user, size: 16),
                      SizedBox(width: 8),
                      Flexible(child: Text(name, overflow: .ellipsis)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      child: trigger,
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
    final compact = CompactHeaderActions.compactOf(context);
    final buttonWidth = isMobile || compact ? desktopPaneHeaderCompactButtonWidth : desktopPaneHeaderInviteButtonWidth;
    final buttonPadding = _paneHeaderButtonPadding(compact: isMobile || compact);

    return Tooltip(
      message: "Invite user",
      child: SizedBox(
        width: buttonWidth,
        child: ShadButton.outline(
          padding: buttonPadding,
          leading: Icon(LucideIcons.userPlus),
          onPressed: () async {
            final room = await getMeshagentClient().getRoom(name: roomName, projectId: projectId);

            if (context.mounted) {
              await showUpdateRoomPermsDialog(context, projectId: projectId, room: room);
            }
          },
          child: isMobile || compact ? null : Text("Invite"),
        ),
      ),
    );
  }
}

class MeetButton extends StatelessWidget {
  const MeetButton({super.key, required this.controller, required this.meetingSessionActive});

  final MeshagentRoomController controller;
  final bool meetingSessionActive;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final compact = CompactHeaderActions.compactOf(context);
    final buttonWidth = isMobile || compact ? desktopPaneHeaderCompactButtonWidth : desktopPaneHeaderMeetButtonWidth;
    final buttonPadding = _paneHeaderButtonPadding(compact: isMobile || compact);

    final buttonBuilder = controller.inMeeting
        ? ShadButton.new
        : meetingSessionActive
        ? ShadButton.destructive
        : ShadButton.outline;

    return Tooltip(
      message: "Meet",
      child: SizedBox(
        width: buttonWidth,
        child: buttonBuilder(
          padding: buttonPadding,
          leading: Icon(LucideIcons.video),
          onPressed: () {
            if (controller.inMeeting) {
              controller.exitMeeting();
            } else {
              controller.enterMeeting();
            }
          },
          child: isMobile || compact ? null : Text("Meet"),
        ),
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
    final compact = CompactHeaderActions.compactOf(context);
    final buttonWidth = isMobile || compact ? desktopPaneHeaderCompactButtonWidth : desktopPaneHeaderFilesButtonWidth;
    final buttonPadding = _paneHeaderButtonPadding(compact: isMobile || compact);

    return controller.isFilesShown
        ? Tooltip(
            message: "Hide files",
            child: SizedBox(
              width: buttonWidth,
              child: ShadButton(
                padding: buttonPadding,
                leading: Icon(LucideIcons.files),
                onPressed: controller.hideFiles,
                child: isMobile || compact ? null : Text("Files"),
              ),
            ),
          )
        : Tooltip(
            message: "Show files",
            child: SizedBox(
              width: buttonWidth,
              child: ShadButton.outline(
                padding: buttonPadding,
                leading: Icon(LucideIcons.files),
                onPressed: controller.showFiles,
                child: isMobile || compact ? null : Text("Files"),
              ),
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
    if (_isFilesShown && !_inMeeting) {
      return;
    }
    _isFilesShown = true;
    _inMeeting = false;
    notifyListeners();
  }

  void hideFiles() {
    if (!_isFilesShown) {
      return;
    }
    _isFilesShown = false;
    notifyListeners();
  }

  void showChat() {
    if (!_isFilesShown && !_inMeeting) {
      return;
    }
    _isFilesShown = false;
    _inMeeting = false;
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
    if (_inMeeting && !_isFilesShown) {
      return;
    }
    _inMeeting = true;
    _isFilesShown = false;
    notifyListeners();
  }

  void exitMeeting() {
    if (!_inMeeting) {
      return;
    }
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

    final spacerIndex = act.indexWhere((widget) => widget is Spacer);
    final leadingActions = spacerIndex == -1 ? const <Widget>[] : act.take(spacerIndex).toList(growable: false);
    final trailingActions = spacerIndex == -1 ? act : act.skip(spacerIndex + 1).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final state = resolvePaneHeaderActionState(constraints, leadingWidth: 320, minimumLeadingWidth: 220, actions: trailingActions);
        final visibleTrailingActions = visiblePaneHeaderActions(trailingActions, overflowCollapsed: state.overflowCollapsed);

        return CompactHeaderActions(
          state: state,
          child: SizedBox(
            height: headerHeight,
            child: Center(
              child: SizedBox(
                height: desktopPaneHeaderContentHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (leadingActions.isNotEmpty)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: leadingActions),
                            ),
                          ),
                        ),
                      if (leadingActions.isEmpty && visibleTrailingActions.isNotEmpty) const Spacer(),
                      if (visibleTrailingActions.isNotEmpty)
                        Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: visibleTrailingActions),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

class _ResolvedAgentSelection {
  const _ResolvedAgentSelection({required this.routeId, required this.service, required this.developmentParticipant});

  final String? routeId;
  final ServiceSpec? service;
  final RemoteParticipant? developmentParticipant;
}

class MeshagentRoomState extends State<MeshagentRoom> {
  final videoChatKey = GlobalKey();
  final Map<String, String> _selectedThreadPathByAgentKey = <String, String>{};
  static const Duration _roomResourceTimeout = Duration(seconds: 30);

  final MeshagentRoomController controller = MeshagentRoomController();
  int _newThreadResetVersion = 0;
  String _lastRoomStatusText = "Connecting to room";
  String? _lastSyncedRoutePath;
  StreamSubscription<RoomStatusEvent>? _roomStatusSubscription;

  final List<RoomEvent> events = [];

  late final isOwner = Resource(
    () => grant
        .amIOwnerOfRoom(projectId: widget.projectId, roomName: widget.room.roomName!)
        .timeout(_roomResourceTimeout, onTimeout: () => throw TimeoutException("Timed out while checking room ownership.")),
  );
  late final canViewDeveloperLogs = Resource(
    () => grant
        .canViewDeveloperLogs(projectId: widget.projectId, roomName: widget.room.roomName!, userId: "me")
        .timeout(_roomResourceTimeout, onTimeout: () => throw TimeoutException("Timed out while loading developer log permissions.")),
  );
  late final canViewStorage = Resource(
    () => grant
        .canViewStorage(projectId: widget.projectId, roomName: widget.room.roomName!, userId: "me")
        .timeout(_roomResourceTimeout, onTimeout: () => throw TimeoutException("Timed out while loading storage permissions.")),
  );

  @override
  void initState() {
    super.initState();

    _roomStatusSubscription = widget.room.events.where((event) => event is RoomStatusEvent).cast<RoomStatusEvent>().listen((event) {
      final status = event.description.trim();
      if (status.isEmpty || !mounted) {
        return;
      }
      setState(() {
        _lastRoomStatusText = status;
      });
    });

    customViewers["thread"] = ({Key? key, required RoomClient room, required String filename, required Uri url}) {
      return MeshagentThreadView(client: room, participantNames: [], documentPath: filename, joinMeeting: _joinMeeting);
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncViewWithRoute();
  }

  void _syncViewWithRoute() {
    final state = PathRouteMatch.of(context);
    final currentUri = state.uri;
    final path = currentUri.queryParameters['p'];

    if (path == _lastSyncedRoutePath) {
      return;
    }
    _lastSyncedRoutePath = path;

    if (path != null && path.isNotEmpty) {
      controller.showFiles();
    }
  }

  late final services = Resource<List<ServiceSpec>>(() async {
    final services = (await widget.room.services.list().timeout(
      _roomResourceTimeout,
      onTimeout: () => throw TimeoutException("Timed out while loading room services."),
    )).where((x) => x.agents.isNotEmpty).toList();
    services.sort(_compareServices);
    return services;
  });

  @override
  void dispose() {
    _roomStatusSubscription?.cancel();
    _roomStatusSubscription = null;
    super.dispose();
  }

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
  String? _serviceAgentName(ServiceSpec service) {
    final name = service.agents.firstOrNull?.name;
    if (name == null) {
      return null;
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  List<RemoteParticipant> _developmentParticipants(List<ServiceSpec> supported) {
    final serviceAgentNames = <String>{};
    for (final service in supported) {
      final name = _serviceAgentName(service);
      if (name != null) {
        serviceAgentNames.add(name);
      }
    }

    final seenNames = <String>{};
    final participants = <RemoteParticipant>[];
    for (final participant in widget.room.messaging.remoteParticipants) {
      if (!isChatOrVoiceBotParticipant(participant)) {
        continue;
      }

      final name = participantDisplayName(participant);
      if (name == null || serviceAgentNames.contains(name) || !seenNames.add(name)) {
        continue;
      }

      participants.add(participant);
    }

    participants.sort((a, b) {
      final left = participantDisplayName(a) ?? "";
      final right = participantDisplayName(b) ?? "";
      return left.toLowerCase().compareTo(right.toLowerCase());
    });

    return participants;
  }

  _ResolvedAgentSelection _resolveSelectedAgent(List<ServiceSpec> supported) {
    final requestedRouteId = widget.service;
    if (requestedRouteId != null) {
      final service = supported.firstWhereOrNull((candidate) => _serviceId(candidate) == requestedRouteId);
      if (service != null) {
        return _ResolvedAgentSelection(routeId: requestedRouteId, service: service, developmentParticipant: null);
      }

      final participantName = developmentAgentNameFromRoute(requestedRouteId);
      if (participantName != null) {
        final participant = _developmentParticipants(
          supported,
        ).firstWhereOrNull((candidate) => participantDisplayName(candidate) == participantName);
        return _ResolvedAgentSelection(
          routeId: developmentAgentRouteId(participantName),
          service: null,
          developmentParticipant: participant,
        );
      }

      final legacyParticipantId = legacyDevelopmentAgentParticipantIdFromRoute(requestedRouteId);
      if (legacyParticipantId != null) {
        final participant = widget.room.messaging.remoteParticipants.firstWhereOrNull(
          (candidate) => candidate.id == legacyParticipantId && isChatOrVoiceBotParticipant(candidate),
        );
        final participantName = participant == null ? null : participantDisplayName(participant);
        return _ResolvedAgentSelection(
          routeId: participantName == null ? requestedRouteId : developmentAgentRouteId(participantName),
          service: null,
          developmentParticipant: participant,
        );
      }

      return _ResolvedAgentSelection(routeId: requestedRouteId, service: null, developmentParticipant: null);
    }

    final defaultService = supported.firstWhereOrNull(_isChatBot) ?? supported.firstOrNull;
    if (defaultService != null) {
      return _ResolvedAgentSelection(routeId: _serviceId(defaultService), service: defaultService, developmentParticipant: null);
    }

    final participant = _developmentParticipants(supported).firstOrNull;
    if (participant != null) {
      final participantName = participantDisplayName(participant);
      if (participantName != null) {
        return _ResolvedAgentSelection(
          routeId: developmentAgentRouteId(participantName),
          service: null,
          developmentParticipant: participant,
        );
      }
    }

    return const _ResolvedAgentSelection(routeId: null, service: null, developmentParticipant: null);
  }

  bool _hasVisibleAgents(List<ServiceSpec> supported) {
    if (supported.isNotEmpty) {
      return true;
    }

    return _developmentParticipants(supported).isNotEmpty;
  }

  String? _selectedThreadAgentKey(List<ServiceSpec> supported) {
    return _resolveSelectedAgent(supported).routeId;
  }

  String? _selectedThreadPathForAgentKey(String? agentKey) {
    if (agentKey == null) {
      return null;
    }

    return _selectedThreadPathByAgentKey[agentKey];
  }

  void _setSelectedThreadPath(String? agentKey, String? path) {
    if (agentKey == null) {
      return;
    }

    setState(() {
      if (path == null || path.trim().isEmpty) {
        _selectedThreadPathByAgentKey.remove(agentKey);
        _newThreadResetVersion++;
      } else {
        _selectedThreadPathByAgentKey[agentKey] = path;
      }
    });
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

  String? _normalizedThreadDocumentDir(String? threadDir) {
    if (threadDir == null) {
      return null;
    }

    final trimmed = threadDir.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed.endsWith("/") ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  String? _resolvedThreadListPath(String? threadListPath, {String? threadDir}) {
    if (threadListPath != null) {
      final trimmed = threadListPath.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    final normalizedThreadDir = _normalizedThreadDocumentDir(threadDir);
    if (normalizedThreadDir == null) {
      return null;
    }

    return "$normalizedThreadDir/index.threadl";
  }

  String getDocumentPath(String? agent, {String? threadDir}) {
    final normalizedThreadDir = _normalizedThreadDocumentDir(threadDir);
    if (normalizedThreadDir != null) {
      return "$normalizedThreadDir/main.thread";
    }

    if (agent != null) {
      return '.threads/$agent/main.thread';
    } else {
      return '.threads/main.thread';
    }
  }

  List<Widget> _meetingToolbarControls(BuildContext context, {bool compact = false}) {
    final model = room.VideoRoomModel.maybeOf(context);
    if (model?.room == null) {
      return [];
    }

    return [
      HangupButton(
        onPressed: () {
          _leaveMeeting();
        },
      ),
      room.MicToggle(),
      room.CameraToggle(),
      room.ChangeSettings(),
      room.ShareScreen(compact: compact),
      MeetingToolkits(room: widget.room, compact: compact),
    ];
  }

  List<Widget> meetingActions(BuildContext context) {
    final controls = _meetingToolbarControls(context);
    if (controls.isEmpty) {
      return controls;
    }

    return [...controls, Spacer()];
  }

  bool _isMeetingSessionActive(BuildContext context) {
    final meetingViewController = Controller.ofType<MeetingViewController>(context);
    final videoRoom = room.VideoRoomModel.maybeOf(context)?.room;
    return meetingViewController.state == MeetingViewState.joined && videoRoom != null;
  }

  void _syncSecondaryPaneVisibility({required bool canViewStorageAllowed}) {
    final shouldHideFiles = controller.isFilesShown && !canViewStorageAllowed;

    if (!shouldHideFiles) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (shouldHideFiles) {
        controller.hideFiles();
      }
    });
  }

  List<Widget> _meetingPaneActions(BuildContext context, {required bool canViewStorageAllowed}) {
    final meetingSessionActive = _isMeetingSessionActive(context);
    final activeMeetingPane = meetingSessionActive && controller.inMeeting;
    return [
      if (canViewStorageAllowed)
        PaneHeaderActionItem(
          expandedWidth: desktopPaneHeaderFilesButtonWidth,
          compactWidth: desktopPaneHeaderCompactButtonWidth,
          overflowOnCompact: activeMeetingPane,
          child: FilesButton(controller: controller),
        ),
      PaneHeaderActionItem(
        expandedWidth: desktopPaneHeaderMeetButtonWidth,
        compactWidth: desktopPaneHeaderCompactButtonWidth,
        overflowOnCompact: activeMeetingPane,
        child: MeetButton(controller: controller, meetingSessionActive: meetingSessionActive),
      ),
      PaneHeaderActionItem(
        expandedWidth: desktopPaneHeaderInviteButtonWidth,
        compactWidth: desktopPaneHeaderCompactButtonWidth,
        overflowOnCompact: !activeMeetingPane,
        child: InviteUserButton(projectId: widget.projectId, roomName: widget.room.roomName!),
      ),
      PaneHeaderActionItem(
        expandedWidth: desktopPaneHeaderOptionsButtonWidth,
        compactWidth: desktopPaneHeaderOptionsButtonWidth,
        child: RoomOptionsMenu(
          projectId: widget.projectId,
          room: widget.room,
          roomController: controller,
          isOwner: isOwner,
          canViewDeveloperLogs: canViewDeveloperLogs,
          boundaryContext: context,
          showMeetingPaneEntriesInOverflow: activeMeetingPane,
          showFilesAction: canViewStorageAllowed,
          showMeetAction: true,
        ),
      ),
      PaneHeaderActionItem(
        expandedWidth: desktopPaneHeaderAvatarButtonWidth,
        compactWidth: desktopPaneHeaderAvatarButtonWidth,
        child: UserAvatarMenuButton(projectId: widget.projectId, projects: widget.projects, boundaryContext: context),
      ),
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

  Widget _buildAgentsActionRow(BuildContext context, {Widget? mobileBelowDropdown}) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (!isMobile) return const SizedBox.shrink();

    if (!services.state.isReady) return const SizedBox.shrink();

    final supported = _supportedServices(services.state.value!);
    final selected = _resolveSelectedAgent(supported);
    final dropdown = AgentsDropdown(
      projectId: widget.projectId,
      room: widget.room,
      selectedService: selected.service,
      selectedAgentRouteId: selected.routeId,
      services: supported,
      onOpen: services.refresh,
      onManageAgents: isOwner.state.value != true ? null : showManageAgents,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            dropdown,
            if (mobileBelowDropdown != null) ...[const SizedBox(height: 10), mobileBelowDropdown],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileThreadGetStartedActions(BuildContext context, {required VoidCallback onNewThread, VoidCallback? onViewAll}) {
    final theme = ShadTheme.of(context);
    final createActionStyle = GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: theme.colorScheme.foreground);
    final secondaryActionStyle = GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: onViewAll == null ? theme.colorScheme.mutedForeground.withValues(alpha: 0.7) : theme.colorScheme.mutedForeground,
    );
    const outerHorizontalInset = 8.0;
    const pillRadius = 999.0;

    Widget pill({required VoidCallback? onTap, required Widget child}) {
      return Material(
        color: theme.colorScheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(pillRadius),
          side: BorderSide(color: theme.colorScheme.border.withValues(alpha: onTap == null ? 0.75 : 1)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(pillRadius),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(child: child),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: outerHorizontalInset),
      child: Row(
        children: [
          Expanded(
            child: pill(
              onTap: onNewThread,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.messageSquarePlus, size: 16, color: theme.colorScheme.foreground),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text("New thread", maxLines: 1, overflow: TextOverflow.visible, softWrap: false, style: createActionStyle),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: pill(
              onTap: onViewAll,
              child: Text("View all", maxLines: 1, overflow: TextOverflow.visible, softWrap: false, style: secondaryActionStyle),
            ),
          ),
        ],
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

  Widget _buildRoomLoading(BuildContext context, {required String title}) {
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
                text: title,
                style: ShadTheme.of(context).textTheme.p.copyWith(fontWeight: FontWeight.w700),
              ),
              SweepStatusText(text: _lastRoomStatusText, style: ShadTheme.of(context).textTheme.muted),
              SizedBox(height: 2),
              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(key: loadingKey)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _emptyRoomHeaderActions({required bool isSmallDisplay, required bool isMobile}) {
    return [
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
          boundaryContext: context,
        ),
        UserAvatarMenuButton(projectId: widget.projectId, projects: widget.projects, boundaryContext: context),
      ],
    ];
  }

  Widget _buildRoomInitializationError(BuildContext context, {required String title, required Object? error}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ShadAlert.destructive(
            title: Text(title),
            description: Text("$error"),
            trailing: ShadButton.outline(
              onPressed: () {
                services.refresh();
                canViewStorage.refresh();
                canViewDeveloperLogs.refresh();
                isOwner.refresh();
              },
              child: Text("Retry"),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShellArea(BuildContext context, ServiceSpec service, List<Widget> actions) {
    final command = service.metadata.annotations["meshagent.service.shell.command"];

    return Column(
      children: [
        ActionsRow(actions: actions),
        _buildDesktopSecondaryControlSpacer(context),
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

  Widget _buildChatArea(
    BuildContext context,
    String? agentName,
    List<Widget> actions, {
    bool showEmbeddedThreadList = true,
    ChatThreadDisplayMode threadDisplayMode = ChatThreadDisplayMode.singleThread,
    String? threadListPath,
    String? threadDir,
    String? selectedThreadPath,
    ValueChanged<String?>? onSelectedThreadPathChanged,
  }) {
    final user = MeshagentAuth.current.getUser();
    final userEmail = user?["email"];
    final cs = ShadTheme.of(context).colorScheme;
    final documentPath = getDocumentPath(agentName, threadDir: threadDir);
    final isMultiThread = threadDisplayMode == ChatThreadDisplayMode.multiThreadComposer;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final chatActions = actions;
    final chatHorizontalInset = isMobile ? 0.0 : desktopPaneChatHorizontalInset;
    final chatBottomInset = isMobile ? 0.0 : desktopPaneBottomInset - 8;
    final resolvedThreadListPath = _resolvedThreadListPath(threadListPath, threadDir: threadDir);
    final hasThreadList = isMultiThread && resolvedThreadListPath != null;
    final showThreadRail = !isMobile && showEmbeddedThreadList && hasThreadList;
    final showInlineThreadList = !isMobile && !showEmbeddedThreadList && hasThreadList;
    final showMobileThreadActions = isMobile && isMultiThread;
    final agentKey = _selectedThreadAgentKey(
      services.state.value == null ? const <ServiceSpec>[] : _supportedServices(services.state.value!),
    );
    final chatView = Padding(
      padding: EdgeInsets.fromLTRB(chatHorizontalInset, 0, chatHorizontalInset, chatBottomInset),
      child: MeshagentThreadView(
        agentName: agentName,
        threadDisplayMode: threadDisplayMode,
        threadListPath: resolvedThreadListPath,
        newThreadResetVersion: _newThreadResetVersion,
        key: ValueKey("thread-view-$documentPath-${selectedThreadPath ?? "composer"}"),
        client: widget.room,
        documentPath: documentPath,
        selectedThreadPath: selectedThreadPath,
        onSelectedThreadPathChanged: onSelectedThreadPathChanged,
        participantNames: [if (userEmail is String && userEmail.isNotEmpty) userEmail, if (agentName != null) agentName],
        joinMeeting: _joinMeeting,
      ),
    );

    return ColoredBox(
      color: isMobile ? cs.card : Colors.transparent,
      child: Column(
        children: [
          ActionsRow(actions: chatActions),
          _buildDesktopChatViewportCutoffSpacer(context),
          _buildAgentsActionRow(
            context,
            mobileBelowDropdown: showMobileThreadActions
                ? _buildMobileThreadGetStartedActions(
                    context,
                    onNewThread: () => onSelectedThreadPathChanged?.call(null),
                    onViewAll: resolvedThreadListPath == null
                        ? null
                        : () => _showMobileThreadPicker(threadListPath: resolvedThreadListPath, agentKey: agentKey, agentName: agentName),
                  )
                : null,
          ),
          Expanded(
            child: showThreadRail
                ? _buildDesktopChatWithThreadRail(
                    context,
                    chatView: chatView,
                    threadListPath: resolvedThreadListPath,
                    agentKey: agentKey,
                    agentName: agentName,
                  )
                : showInlineThreadList
                ? _buildDesktopChatWithInlineThreadList(
                    context,
                    chatView: chatView,
                    threadListPath: resolvedThreadListPath,
                    agentKey: agentKey,
                  )
                : chatView,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopChatWithThreadRail(
    BuildContext context, {
    required Widget chatView,
    required String threadListPath,
    required String? agentKey,
    required String? agentName,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        if (!totalWidth.isFinite || totalWidth < 700) {
          return chatView;
        }

        final railMaxWidth = math.min(360.0, math.max(260.0, totalWidth - 440.0));
        final railWidth = (totalWidth * 0.28).clamp(260.0, railMaxWidth).toDouble();

        return Row(
          children: [
            Expanded(child: chatView),
            SizedBox(
              width: railWidth,
              child: _buildDesktopThreadRail(context, threadListPath: threadListPath, agentKey: agentKey, agentName: agentName),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopChatWithInlineThreadList(
    BuildContext context, {
    required Widget chatView,
    required String threadListPath,
    required String? agentKey,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(420.0, math.max(320.0, constraints.maxWidth * 0.42));

        return Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: _buildDesktopInlineThreadList(context, agentKey: agentKey),
              ),
            ),
            const SizedBox(height: desktopPaneSecondaryRowContentGap),
            Expanded(child: chatView),
          ],
        );
      },
    );
  }

  Widget _buildVoiceArea(BuildContext context, String agentName, List<Widget> actions) {
    return Column(
      children: [
        ActionsRow(actions: actions),
        _buildDesktopChatViewportCutoffSpacer(context),
        _buildAgentsActionRow(context),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => WaitForAgentParticipantBuilder(
              key: ValueKey(agentName),
              room: widget.room,
              agentName: agentName,
              builder: (context, participant) => Column(
                children: [
                  Expanded(
                    child: Center(
                      child: participant == null
                          ? ShadButton(child: Text("Start Voice Session"))
                          : ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
                              child: VoiceAgentCaller(
                                meeting: MeetingController.of(context),
                                participant: participant,
                                emptyStateAvailableWidth: constraints.maxWidth,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
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
          _buildDesktopPaneContentSpacer(context),
          _buildAgentsActionRow(context),
          Expanded(
            child: participant == null
                ? _buildRoomLoading(context, title: "Waiting for transcriber agent to join room")
                : controller.inMeeting
                ? _buildChatArea(context, null, [])
                : Center(
                    child: ShadButton(
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
    final cs = ShadTheme.of(context).colorScheme;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final horizontalInset = isMobile ? 12.0 : 20.0;
    final bottomInset = isMobile ? 8.0 : desktopPaneBottomInset;
    final meetingSessionActive = _isMeetingSessionActive(context);

    return ColoredBox(
      color: isMobile ? cs.card : cs.background,
      child: Column(
        children: [
          if (isMobile) ActionsRow(actions: actions),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalInset, 0, horizontalInset, bottomInset),
              child: FileManagerView(
                client: widget.room,
                services: services,
                hideSystem: true,
                desktopHeaderActions: isMobile ? const [] : actions,
                desktopHeaderActionLeadingWidthFloor: meetingSessionActive ? _meetingActivePaneActionLeadingWidthFloor : 0,
                desktopHeaderActionMinimumLeadingWidth: meetingSessionActive ? 160 : 0,
                desktopHeaderActionReserve: meetingSessionActive ? desktopPaneHeaderActionReserve + 32 : desktopPaneHeaderActionReserve,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeeting(BuildContext context, String? agentName, List<Widget> actions) {
    final cs = ShadTheme.of(context).colorScheme;
    final radius = ShadTheme.of(context).radius.resolve(Directionality.of(context));
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final horizontalInset = isMobile ? 12.0 : 20.0;
    final bottomInset = isMobile ? 8.0 : desktopPaneBottomInset;
    final meetingIsActive = _isMeetingSessionActive(context);

    return ColoredBox(
      color: isMobile ? cs.card : cs.background,
      child: Column(
        children: [
          if (isMobile)
            ActionsRow(actions: actions)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final leadingWidth = meetingIsActive
                    ? _measureActiveMeetingHeaderWidth(constraints.maxWidth)
                    : _measureMeetingHeaderTitleWidth(context, constraints.maxWidth);
                final localActionState = resolvePaneHeaderActionState(
                  constraints,
                  leadingWidth: leadingWidth,
                  minimumLeadingWidth: meetingIsActive ? _meetingToolbarPreferredCompactWidth : 120,
                  reserve: meetingIsActive ? desktopPaneHeaderActionReserve + 32 : desktopPaneHeaderActionReserve,
                  actions: actions,
                  preferCompactBeforeOverflow: meetingIsActive,
                );
                final actionState = localActionState;
                final visibleActions = visiblePaneHeaderActions(actions, overflowCollapsed: actionState.overflowCollapsed);
                return CompactHeaderActions(
                  state: actionState,
                  child: SizedBox(
                    height: headerHeight,
                    child: meetingIsActive
                        ? Center(
                            child: SizedBox(
                              height: desktopPaneHeaderContentHeight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  spacing: desktopPaneHeaderButtonGap,
                                  children: [
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, toolbarConstraints) {
                                          final compactControls = toolbarConstraints.maxWidth < _meetingToolbarCompactThreshold;
                                          return SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              spacing: desktopPaneHeaderButtonGap,
                                              children: _meetingToolbarControls(context, compact: compactControls),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    if (visibleActions.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          spacing: desktopPaneHeaderButtonGap,
                                          children: visibleActions,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: SizedBox(
                              height: desktopPaneHeaderContentHeight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  spacing: desktopPaneHeaderButtonGap,
                                  children: [
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          "Get ready to meet",
                                          style: meetingHeaderTitleStyle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    if (visibleActions.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          spacing: desktopPaneHeaderButtonGap,
                                          children: visibleActions,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalInset, isMobile ? 0 : desktopPaneHeaderToContentOffset, horizontalInset, bottomInset),
              child: ClipRRect(
                borderRadius: radius,
                child: MeetingView(room: widget.room, onCancel: _leaveMeeting, joinMeeting: _joinMeeting, agentName: agentName),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _leaveMeeting() {
    final meetingViewController = Controller.ofType<MeetingViewController>(context);
    final navController = Controller.ofType<NavController>(context);
    meetingViewController.resetToLobby();
    navController.showNav();
    controller.exitMeeting();
  }

  void _joinMeeting() {
    final meetingViewController = Controller.ofType<MeetingViewController>(context);

    meetingViewController.resetToLobby();
    controller.enterMeeting();
  }

  void _showMaximizedChat() {
    controller.showChat();
  }

  Future<void> _showMobileThreadPicker({required String threadListPath, required String? agentKey, required String? agentName}) async {
    await showShadDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);

        Widget footerButton({required VoidCallback onPressed, required Widget child, bool primary = false}) {
          final button = primary ? ShadButton.new : ShadButton.outline;
          return SizedBox(
            width: double.infinity,
            child: button(onPressed: onPressed, child: child),
          );
        }

        return PowerboardsShadDialog(
          useSafeArea: false,
          title: const Text("Threads"),
          description: const Text("Select a thread to view or manage it."),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: math.min(size.width * 0.8, 360.0), maxHeight: math.min(size.height * 0.65, 520.0)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 18),
                    child: MeshagentThreadListPane(
                      key: ValueKey("mobile-threads-${agentKey ?? "none"}"),
                      client: widget.room,
                      agentName: agentName,
                      threadListPath: threadListPath,
                      selectedThreadPath: _selectedThreadPathForAgentKey(agentKey),
                      newThreadResetVersion: _newThreadResetVersion,
                      mobileListTopPadding: 0,
                      mobileListBottomPadding: 0,
                      mobileRowVerticalPadding: 16,
                      mobileUseDialogListStyle: true,
                      showCreateItem: false,
                      onSelectedThreadPathChanged: (path) {
                        _setSelectedThreadPath(agentKey, path);
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    footerButton(
                      primary: true,
                      onPressed: () {
                        _setSelectedThreadPath(agentKey, null);
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text("New Thread"),
                    ),
                    const SizedBox(height: 12),
                    footerButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text("Close")),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopThreadRail(
    BuildContext context, {
    required String threadListPath,
    required String? agentKey,
    required String? agentName,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: FractionallySizedBox(
        widthFactor: 0.72,
        child: Padding(
          padding: const EdgeInsets.only(bottom: desktopPaneBottomInset),
          child: MeshagentThreadListPane(
            key: ValueKey("embedded-threads-${agentKey ?? "none"}"),
            client: widget.room,
            agentName: agentName,
            threadListPath: threadListPath,
            selectedThreadPath: _selectedThreadPathForAgentKey(agentKey),
            newThreadResetVersion: _newThreadResetVersion,
            onSelectedThreadPathChanged: (path) => _setSelectedThreadPath(agentKey, path),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopInlineThreadList(BuildContext context, {required String? agentKey}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, desktopPaneBottomInset),
      child: MeshagentInlineThreadCreatePrompt(
        key: ValueKey("inline-thread-create-${agentKey ?? "none"}"),
        createItemTopPadding: 0,
        onOpen: () => _setSelectedThreadPath(agentKey, null),
        onViewAllThreads: _showMaximizedChat,
      ),
    );
  }

  Widget _buildDesktopPaneContentSpacer(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (isMobile) {
      return const SizedBox.shrink();
    }

    return const SizedBox(height: desktopPaneHeaderToContentOffset);
  }

  Widget _buildDesktopChatViewportCutoffSpacer(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (isMobile) {
      return const SizedBox.shrink();
    }

    return const SizedBox(height: desktopPaneHeaderToChatViewportOffset);
  }

  Widget _buildDesktopSecondaryControlSpacer(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (isMobile) {
      return const SizedBox.shrink();
    }

    return const SizedBox(height: desktopPaneSecondaryControlTopOffset);
  }

  Widget _buildAgentArea(BuildContext context, List<Widget> actions, {bool showEmbeddedThreadList = true}) {
    final cs = ShadTheme.of(context).colorScheme;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return ColoredBox(
      color: isMobile ? cs.card : Colors.transparent,
      child: ChangeNotifierBuilder(
        source: widget.room.messaging,
        builder: (context) => SignalBuilder(
          builder: (context, _) {
            if (!services.state.isReady) {
              if (services.state.hasError) {
                return _buildErrorArea(context, "Unable to load room services: ${services.state.error}", actions);
              }
              return _buildRoomLoading(context, title: "Loading room services");
            }

            final all = services.state.value!;
            final supported = _supportedServices(all);
            final selected = _resolveSelectedAgent(supported);
            final service = selected.service;
            final developmentParticipant = selected.developmentParticipant;

            if (service == null && developmentParticipant == null) {
              final requestedRouteId = widget.service;
              final requestedDevelopmentParticipantName = requestedRouteId == null ? null : developmentAgentNameFromRoute(requestedRouteId);
              final requestedLegacyDevelopmentParticipantId = requestedRouteId == null
                  ? null
                  : legacyDevelopmentAgentParticipantIdFromRoute(requestedRouteId);
              if (requestedDevelopmentParticipantName != null || requestedLegacyDevelopmentParticipantId != null) {
                return _buildErrorArea(context, "Development mode agent is not currently online", actions);
              }

              if (supported.isEmpty) {
                return _buildErrorArea(context, "No supported agents installed", actions);
              }

              return _buildErrorArea(context, "Agent is not installed ${widget.service}", actions);
            }

            if (developmentParticipant != null) {
              final name = participantDisplayName(developmentParticipant);
              if (name == null) {
                return _buildErrorArea(context, "Development mode agent is missing a name", actions);
              }

              final descriptor = participantConversationDescriptor(developmentParticipant);
              final agentKey = selected.routeId;
              if (descriptor?.isVoiceOnly == true) {
                return _buildVoiceArea(context, name, actions);
              }

              if (descriptor?.isChat == true) {
                return _buildChatArea(
                  context,
                  name,
                  actions,
                  showEmbeddedThreadList: showEmbeddedThreadList,
                  threadDisplayMode: descriptor!.chatThreadDisplayMode,
                  threadDir: descriptor.threadDir,
                  threadListPath: descriptor.threadListPath,
                  selectedThreadPath: _selectedThreadPathForAgentKey(agentKey),
                  onSelectedThreadPathChanged: (path) => _setSelectedThreadPath(agentKey, path),
                );
              }

              return _buildErrorArea(context, "Selected development mode agent does not support chat or voice", actions);
            }

            final descriptor = serviceConversationDescriptor(service!, remoteParticipants: widget.room.messaging.remoteParticipants);
            final type = _serviceType(service);
            final agentKey = selected.routeId;
            if (descriptor?.isChat == true) {
              return _buildChatArea(
                context,
                service.agents[0].name,
                actions,
                showEmbeddedThreadList: showEmbeddedThreadList,
                threadDisplayMode: descriptor!.chatThreadDisplayMode,
                threadDir: descriptor.threadDir,
                threadListPath: descriptor.threadListPath,
                selectedThreadPath: _selectedThreadPathForAgentKey(agentKey),
                onSelectedThreadPathChanged: (path) => _setSelectedThreadPath(agentKey, path),
              );
            } else if (descriptor?.isVoiceOnly == true) {
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
        ),
      ),
    );
  }

  double _measureMeetingHeaderTitleWidth(BuildContext context, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: "Get ready to meet", style: meetingHeaderTitleStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();

    return painter.width.clamp(0.0, maxWidth * 0.45);
  }

  double _measureActiveMeetingHeaderWidth(double maxWidth) {
    return _meetingToolbarPreferredExpandedWidth.clamp(0.0, maxWidth);
  }

  static const double _meetingActivePaneActionLeadingWidthFloor = 260;

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
            builder: (context, _) {
              if (!services.state.isReady) {
                if (services.state.hasError) {
                  return _buildRoomInitializationError(context, title: "Unable to load room services", error: services.state.error);
                }

                final actions = _emptyRoomHeaderActions(isSmallDisplay: isSmallDisplay, isMobile: isMobile);
                return SafeArea(
                  child: Column(
                    children: [
                      ActionsRow(actions: actions),
                      Expanded(child: _buildRoomLoading(context, title: "Loading room services")),
                    ],
                  ),
                );
              }

              return room.VideoChatConnection(
                key: videoChatKey,
                child: ControllerBuilder(
                  controller: controller,
                  builder: (context) {
                    return ChangeNotifierBuilder(
                      source: widget.room.messaging,
                      builder: (context) {
                        return SignalBuilder(
                          builder: (context, _) {
                            final canViewStorageAllowed = canViewStorage.state.value == true;
                            final filesVisible = canViewStorageAllowed && controller.isFilesShown;
                            final supported = _supportedServices(services.state.value!);
                            final selected = _resolveSelectedAgent(supported);
                            _syncSecondaryPaneVisibility(canViewStorageAllowed: canViewStorageAllowed);
                            final meetingSessionActive = _isMeetingSessionActive(context);
                            final split = filesVisible || controller.inMeeting;

                            if (!_hasVisibleAgents(supported)) {
                              final actions = _emptyRoomHeaderActions(isSmallDisplay: isSmallDisplay, isMobile: isMobile);
                              final cs = ShadTheme.of(context).colorScheme;
                              return SafeArea(
                                child: ColoredBox(
                                  color: cs.card,
                                  child: Column(
                                    children: [
                                      ActionsRow(actions: actions),
                                      Expanded(
                                        child: SignalBuilder(
                                          builder: (context, _) {
                                            final ownerResolved = isOwner.state.isReady || isOwner.state.hasError;
                                            final canInstallAgent = isOwner.state.value == true;

                                            if (!ownerResolved) {
                                              return _buildRoomLoading(context, title: "Loading room permissions");
                                            }

                                            return Center(
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 520),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(16),
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        "Welcome to your room",
                                                        style: ShadTheme.of(context).textTheme.h1,
                                                        textAlign: TextAlign.center,
                                                      ),
                                                      if (canInstallAgent) ...[
                                                        SizedBox(height: 8),
                                                        Text(
                                                          "Install an agent in this room to get started",
                                                          style: ShadTheme.of(context).textTheme.p,
                                                          textAlign: TextAlign.center,
                                                        ),
                                                        SizedBox(height: 20),
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
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ToolConnectionScope(
                              tools: [UIToolkit(context, room: widget.room)],
                              builder: (context, error) {
                                final cs = ShadTheme.of(context).colorScheme;

                                if (isMobile) {
                                  final actions = [
                                    BackButton(projectId: widget.projectId),
                                    Spacer(),
                                    (split ? ShadButton.outline : ShadButton.new)(
                                      onPressed: () {
                                        controller.showChat();
                                      },
                                      leading: Icon(LucideIcons.messageSquareText),
                                    ),
                                    if (canViewStorageAllowed) FilesButton(controller: controller),
                                    MeetButton(controller: controller, meetingSessionActive: _isMeetingSessionActive(context)),
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
                                          ActionsRow(actions: meetingActions(context)),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final actions = _meetingPaneActions(context, canViewStorageAllowed: canViewStorageAllowed);

                                return RoomDeveloperLogsListener(
                                  events: events,
                                  client: widget.room,
                                  child: ShadResizablePanelGroup(
                                    axis: .vertical,
                                    showHandle: true,
                                    children: [
                                      ShadResizablePanel(
                                        id: "top",
                                        defaultSize: 1 - defaultDebugSize,
                                        child: ResizableSplitView(
                                          allowCollapse: room.VideoRoomModel.maybeOf(context)?.room != null,
                                          minArea1Width: 360,
                                          minArea2Width: 440,
                                          preferredArea2Fraction: meetingSessionActive ? 0.5 : null,
                                          minArea2Fraction: meetingSessionActive ? 0.5 : null,
                                          maxArea2Fraction: meetingSessionActive ? (2 / 3) : null,
                                          split: split,
                                          area1: ColoredBox(
                                            color: cs.card,
                                            child: _buildAgentArea(context, [
                                              if (isSmallDisplay) BackButton(projectId: widget.projectId),

                                              AgentsDropdown(
                                                projectId: widget.projectId,
                                                room: widget.room,
                                                selectedService: selected.service,
                                                selectedAgentRouteId: selected.routeId,
                                                services: supported,
                                                onOpen: services.refresh,
                                                onManageAgents: isOwner.state.value != true ? null : showManageAgents,
                                              ),

                                              ParticipantsButton(
                                                participants: participants,
                                                localParticipant: widget.room.localParticipant,
                                              ),

                                              if (!split) ...actions,
                                            ], showEmbeddedThreadList: !split),
                                          ),
                                          area2: !split
                                              ? Container()
                                              : filesVisible
                                              ? _buildFilesArea(context, actions)
                                              : controller.inMeeting
                                              ? _buildMeeting(context, null, actions)
                                              : _buildAgentArea(context, actions, showEmbeddedThreadList: false),
                                        ),
                                      ),

                                      if (controller.isDebugShown)
                                        ShadResizablePanel(
                                          id: "bottom",
                                          defaultSize: defaultDebugSize,
                                          minSize: 0,
                                          child: RoomDeveloperConsole(
                                            pricing: null,
                                            events: events,
                                            room: widget.room,
                                            shellImage: "${MeshagentConfig.current!.imageTagPrefix}cli:{SERVER_VERSION}-esgz",
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              );
            },
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
  T? data;
  Object? error;

  @override
  void initState() {
    super.initState();

    get(widget.uri).then((value) {
      setState(() {
        data = widget.mapper(value.bodyBytes);
      });
    });
  }

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
