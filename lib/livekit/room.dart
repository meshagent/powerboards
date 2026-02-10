import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:powerboards/livekit/present_button.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:meshagent_flutter/meshagent_flutter.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:powerboards/powerboards_controller/powerboards_controller.dart';

import 'package:powerboards/livekit/change_device_button.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/powerboards_dialog.dart';

class ConnectionInfo {
  String provider = "livekit";
  String device = "";
  String room = "";
  String username = "";
  String accessToken = "";

  Map<String, dynamic> toJSON() {
    return <String, dynamic>{"provider": provider, "device": device, "room": room, "username": username, "accessToken": accessToken};
  }
}

class VideoRoomModel extends InheritedWidget {
  const VideoRoomModel({
    super.key,
    required this.room,
    required this.chatID,
    required this.localParticipant,
    required this.participantCount,
    required this.activeSpeakers,
    required super.child,
  });

  final List<lk.Participant> activeSpeakers;

  final lk.Room? room;
  final String chatID;
  final int participantCount;
  final lk.LocalParticipant? localParticipant;

  static VideoRoomModel? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<VideoRoomModel>();
  }

  static VideoRoomModel of(BuildContext context) {
    return maybeOf(context)!;
  }

  bool isMeeting() {
    return false;
  }

  @override
  bool updateShouldNotify(covariant VideoRoomModel oldWidget) {
    Function deepEq = const DeepCollectionEquality().equals;
    bool shouldUpdate =
        !deepEq(activeSpeakers, oldWidget.activeSpeakers) ||
        room != oldWidget.room ||
        participantCount != oldWidget.participantCount ||
        localParticipant != oldWidget.localParticipant;

    return shouldUpdate;
  }
}

extension PowerboardsParticipants on lk.Room {
  lk.RemoteParticipant? get agent {
    return remoteParticipants.values.where((x) => x.identity.endsWith(".agent")).firstOrNull;
  }
}

class VideoRoomProvider extends StatefulWidget {
  const VideoRoomProvider({super.key, required this.room, required this.chatID, required this.child});

  final lk.Room? room;
  final String chatID;
  final Widget child;

  @override
  State<StatefulWidget> createState() => VideoRoomProviderState();
}

class VideoRoomProviderState extends State<VideoRoomProvider> {
  VideoRoomProviderState();

  lk.FastConnectOptions? fastConnectOptions;
  lk.EventsListener<lk.RoomEvent>? _listener;
  List<lk.Participant> activeSpeakers = [];
  Future currentOp = Future.value(0);

  @override
  void initState() {
    super.initState();

    final room = widget.room;

    final l = room?.createListener();
    _listener = l;
    l?.listen((event) {
      if (mounted) {
        setState(() {
          _participantCount = room!.remoteParticipants.length + 1;
        });

        if (event is lk.ActiveSpeakersChangedEvent) {
          for (var speaker in event.speakers.reversed) {
            pushSpeaker(speaker);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();

    _listener?.dispose();
  }

  void pushSpeaker(lk.Participant participant) {
    activeSpeakers = [...activeSpeakers];
    final index = activeSpeakers.indexOf(participant);
    if (index != -1) {
      activeSpeakers.removeAt(index);
    }
    activeSpeakers.insert(0, participant);

    for (var participant in activeSpeakers.where((x) => x.isDisposed).toList()) {
      activeSpeakers.remove(participant);
    }

    if (activeSpeakers.length > 10) {
      activeSpeakers.length = 10;
    }
    if (mounted) {
      setState(() {});
    }
  }

  int _participantCount = 0;
  int get participantCount {
    return _participantCount;
  }

  @override
  Widget build(BuildContext context) {
    return VideoRoomModel(
      activeSpeakers: activeSpeakers,
      room: widget.room,
      chatID: widget.chatID,
      localParticipant: widget.room?.localParticipant,
      participantCount: participantCount,
      child: widget.child,
    );
  }
}

class VideoChatConnectionConfiguration {
  VideoChatConnectionConfiguration({required this.chatID, this.breakout, this.agent});

  final String chatID;
  final String? breakout;
  final String? agent;
}

class VideoChatConnection extends StatefulWidget {
  const VideoChatConnection({super.key, required this.child, this.configuration});

  final Widget child;

  final VideoChatConnectionConfiguration? configuration;

  @override
  State createState() => VideoChatConnectionState();
}

class VideoChatConnectionState extends State<VideoChatConnection> {
  Future<bool>? _roomConnectFuture;

  ConnectionInfo? connection;
  String? roomSID;

  lk.Room? room;
  Future pendingConnections = Future.value(null);
  String? _breakoutRoom;
  final childKey = GlobalKey();
  late final FocusNode focusNode;

  @override
  void initState() {
    super.initState();

    focusNode = FocusNode();
  }

  @override
  void dispose() {
    super.dispose();

    final room = this.room;
    if (room != null) {
      room.disconnect().whenComplete(() => room.dispose());
      this.room = null;
    }
  }

  void hangup() {
    debugPrint("hanging up");
    final room = this.room;

    if (room != null) {
      pendingConnections = pendingConnections.whenComplete(() async {
        debugPrint("pending connection finished");
        final local = room.localParticipant;
        if (local != null) {
          debugPrint("disabling connection ${local.isCameraEnabled()}");

          await local.setCameraEnabled(false);
          await local.setMicrophoneEnabled(false);

          if (local.videoTrackPublications.isNotEmpty) {
            for (final track in local.videoTrackPublications) {
              track.track?.mediaStreamTrack.stop();
              track.track?.stop();
              track.track?.dispose();
            }
          }
          if (local.audioTrackPublications.isNotEmpty) {
            for (final track in local.audioTrackPublications) {
              track.track?.mediaStreamTrack.stop();
              track.track?.stop();
              track.track?.dispose();
            }
          }
        } else {
          debugPrint("no local participant");
        }

        await room.disconnect().whenComplete(() => room.dispose()).catchError((err) {
          debugPrint("unable to disconnect $err");
        });
      });

      _roomConnectFuture = null;

      this.room = null;
      roomSID = null;
      connection = null;

      setState(() {});
    }
  }

  void addRemovedParticipantDialog() {
    final dialogs = Controller.ofType<DialogController>(context);
    PowerboardsDialog? dialog;
    dialog = PowerboardsDialog(
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('You have been removed from the room by the host.'),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  dialogs.remove(dialog!);
                },
                child: const Text('Return to room'),
              ),
            ],
          ),
        ),
      ),
    );
    dialogs.add(dialog);
  }

  Future<void> setRoomFromDoc(
    String id,
    RoomClient roomClient,
    String? breakoutRoom, {
    bool enableLocalTracks = true,
    bool video = true,
    bool audio = true,
    required String? agentID,
  }) async {
    final info = await roomClient.livekit.getConnectionInfo(breakoutRoom: breakoutRoom);

    return await _setRoom(
      info.url,
      info.token,
      agentID: agentID,
      id,
      breakoutRoom,
      enableLocalTracks: enableLocalTracks,
      enableVideo: video,
      enableAudio: audio,
    );
  }

  Future<void> _setRoom(
    String url,
    String accessToken,
    String id,
    String? breakoutRoom, {
    bool enableLocalTracks = true,
    bool enableVideo = true,
    bool enableAudio = true,
    required String? agentID,
  }) async {
    if (id != roomSID || breakoutRoom != _breakoutRoom) {
      final room = this.room;

      if (room != null) {
        pendingConnections = pendingConnections.whenComplete(
          () async => await room.disconnect().whenComplete(() => room.dispose()).catchError((err) {
            debugPrint("unable to disconnect $err");
          }),
        );
      }

      _roomConnectFuture = null;
      _breakoutRoom = breakoutRoom;
      roomSID = id;

      connection = ConnectionInfo()
        ..accessToken = accessToken
        ..device = const Uuid().v4().toString()
        ..room = roomSID!;

      final preferences = await SharedPreferences.getInstance();
      final preferedVideoDeviceId = preferences.getString("videoInput");
      final preferedAudioInputDeviceId = preferences.getString("audioInput");
      final preferedAudioOutputDeviceId = preferences.getString("audioOutput");

      final roomOptions = lk.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultScreenShareCaptureOptions: const lk.ScreenShareCaptureOptions(useiOSBroadcastExtension: true, preferCurrentTab: false),
        defaultCameraCaptureOptions: lk.CameraCaptureOptions(deviceId: preferedVideoDeviceId),
        defaultAudioCaptureOptions: lk.AudioCaptureOptions(deviceId: preferedAudioInputDeviceId),
        defaultAudioOutputOptions: lk.AudioOutputOptions(deviceId: preferedAudioOutputDeviceId),
      );

      const connectOptions = lk.ConnectOptions(
        autoSubscribe: true,
        timeouts: lk.Timeouts(
          connection: Duration(seconds: 30),
          debounce: Duration(milliseconds: 100),
          publish: Duration(seconds: 10),
          peerConnection: Duration(seconds: 30),
          iceRestart: Duration(seconds: 30),
        ),
      );

      final newRoom =
          // ignore: deprecated_member_use
          lk.Room(roomOptions: roomOptions, connectOptions: connectOptions);
      this.room = newRoom;

      Future.microtask(() {
        if (!mounted) return;

        setState(() {});
      });

      _ensureRoomConnect(
        url,
        accessToken,
        newRoom,
        null,
        enableLocalTracks: enableLocalTracks,
        enableVideo: enableVideo,
        enableAudio: enableAudio,
        agentID: agentID,
      );
    }
  }

  Future<bool> _ensureRoomConnect(
    String url,
    String token,
    lk.Room room,
    lk.FastConnectOptions? fastConnectOptions, {
    bool enableLocalTracks = true,
    bool enableVideo = true,
    bool enableAudio = true,
    required String? agentID,
  }) {
    if (_roomConnectFuture == null) {
      final completer = Completer<bool>();

      pendingConnections = pendingConnections.whenComplete(() async {
        await room.connect(url, token, fastConnectOptions: fastConnectOptions);

        var handled = false;

        room.addListener(() async {
          if (room.localParticipant != null && !handled) {
            handled = true;
            if (enableLocalTracks) {
              final isVideoDisabled = !enableVideo;
              final isAudioDisabled = !enableAudio;

              if (!isVideoDisabled) {
                try {
                  await room.localParticipant!.setCameraEnabled(true);
                  if (room.localParticipant?.videoTrackPublications[0].muted == true) {
                    debugPrint("camera was not enabled, restarting");
                    await room.localParticipant?.videoTrackPublications[0].track?.restartTrack();
                  }
                } catch (err) {
                  debugPrint("Unable to enable video $err");
                }
              }

              if (!isAudioDisabled) {
                try {
                  await room.localParticipant!.setMicrophoneEnabled(true);
                } catch (err) {
                  debugPrint("Unable to enable audio $err");
                }
              }
            }

            completer.complete(true);
          }
        });

        await completer.future;
      });

      _roomConnectFuture = completer.future;
    }

    return _roomConnectFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return VideoRoomProvider(room: room, chatID: roomSID ?? '', child: widget.child);
  }
}

class CameraToggle extends StatefulWidget {
  const CameraToggle({super.key});

  @override
  State<StatefulWidget> createState() => _CameraToggleState();
}

class _CameraToggleState extends State<CameraToggle> {
  bool state = false;

  Function? unsubscribe;
  VideoRoomModel? _model;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final model = VideoRoomModel.maybeOf(context);
    final local = model?.room?.localParticipant;

    if (_model != model) {
      _model = model;

      updateState();
      unsubscribe?.call();

      local?.addListener(updateState);
      model?.room?.addListener(updateState);

      unsubscribe = () {
        local?.removeListener(updateState);
        model?.room?.removeListener(updateState);
      };
    }
  }

  @override
  void dispose() {
    super.dispose();

    unsubscribe?.call();
  }

  void updateState() {
    if (mounted && _model != null) {
      final local = _model!.room?.localParticipant;
      final isCameraEnabled = state = local?.isCameraEnabled() ?? false;

      setState(() {
        state = isCameraEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = VideoRoomModel.maybeOf(context);
    final local = model?.room?.localParticipant;

    return RoomToolbarButton(
      text: state ? "Turn off camera" : "Turn on camera",
      on: state,
      onColor: ShadTheme.of(context).colorScheme.foreground,
      onForeground: ShadTheme.of(context).colorScheme.background,
      offColor: Colors.red,
      offForeground: Colors.white,
      icon: state ? LucideIcons.video : LucideIcons.videoOff,
      onPressed: local == null
          ? null
          : () {
              final value = !state;

              setState(() {
                local.setCameraEnabled(value);
                state = value;
              });
            },
    );
  }
}

class MicToggle extends StatefulWidget {
  const MicToggle({super.key});

  @override
  State<StatefulWidget> createState() => _MicToggleState();
}

class _MicToggleState extends State<MicToggle> {
  bool state = false;

  Function? unsubscribe;
  VideoRoomModel? _model;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final model = VideoRoomModel.maybeOf(context);
    final local = model?.room?.localParticipant;

    if (_model != model) {
      _model = model;

      updateState();
      unsubscribe?.call();

      local?.addListener(updateState);
      model?.room?.addListener(updateState);
      unsubscribe = () {
        local?.removeListener(updateState);
        model?.room?.removeListener(updateState);
      };
    }
  }

  @override
  void dispose() {
    super.dispose();

    unsubscribe?.call();
  }

  void updateState() {
    if (mounted && _model != null) {
      final local = _model!.room?.localParticipant;
      final isMicrophoneEnabled = state = local?.isMicrophoneEnabled() ?? false;

      setState(() {
        state = isMicrophoneEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = VideoRoomModel.maybeOf(context);
    final local = model?.room?.localParticipant;

    return RoomToolbarButton(
      text: state ? "Turn off microphone" : "Turn on microphone",
      on: state,
      onColor: ShadTheme.of(context).colorScheme.foreground,
      onForeground: ShadTheme.of(context).colorScheme.background,
      offColor: Colors.red,
      offForeground: Colors.white,
      icon: state ? LucideIcons.mic : LucideIcons.micOff,
      onPressed: local == null
          ? null
          : () {
              final value = !state;
              setState(() {
                local.setMicrophoneEnabled(value);
                state = value;
              });
            },
    );
  }
}

class ChangeSettings extends StatelessWidget {
  const ChangeSettings({super.key, this.kind});

  final String? kind;

  void _selectVideoInput(BuildContext context, lk.MediaDevice device) async {
    final room = VideoRoomModel.maybeOf(context)?.room;
    final track = room?.localParticipant?.videoTrackPublications.firstOrNull?.track;

    try {
      await room?.setVideoInputDevice(device);

      // workaround for livekit client issue - switchCamera not called by room.setVideoInputDevice
      // https://github.com/livekit/client-sdk-flutter/issues/863
      await track?.restartTrack(lk.CameraCaptureOptions(deviceId: device.deviceId));
    } catch (err) {
      debugPrint("Unable to set video input device $err");
    }
  }

  void _selectAudioInput(BuildContext context, lk.MediaDevice device) async {
    final room = VideoRoomModel.maybeOf(context)?.room;
    await room?.setAudioInputDevice(device);
  }

  void _selectAudioOutput(BuildContext context, lk.MediaDevice device) async {
    final room = VideoRoomModel.maybeOf(context)?.room;

    await room?.setAudioOutputDevice(device);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeDeviceButton(
      kind: kind,
      onChangeVideoInput: (device) => _selectVideoInput(context, device),
      onChangeAudioInput: (device) => _selectAudioInput(context, device),
      onChangeAudioOutput: (device) => _selectAudioOutput(context, device),
      renderButton: (MenuController controller) {
        return Tooltip(
          message: "Change device",
          child: ShadIconButton.outline(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            icon: const Icon(LucideIcons.settings),
          ),
        );
      },
    );
  }
}

class RoomToolbarButton extends StatelessWidget {
  const RoomToolbarButton({
    required this.text,
    required this.icon,
    this.onPressed,
    this.onColor = const Color.fromRGBO(47, 45, 87, 1),
    this.offColor = Colors.transparent,
    this.onForeground = Colors.white,
    this.offForeground = Colors.black,
    super.key,
    this.on = false,
  });

  final void Function()? onPressed;
  final String text;
  final Color onColor;
  final Color offColor;
  final Color onForeground;
  final Color offForeground;
  final IconData icon;

  final bool on;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: text,
      child: ShadIconButton(
        onPressed: onPressed,
        backgroundColor: on ? onColor : offColor,
        foregroundColor: on ? onForeground : (onPressed != null ? offForeground : disabledToolIconColor),
        icon: Icon(icon, size: 22),
      ),
    );
  }
}

class ShareScreen extends StatelessWidget {
  const ShareScreen({super.key});

  void onPressed(BuildContext context) async {
    final local = VideoRoomModel.maybeOf(context)?.room?.localParticipant;
    final on = local?.isScreenShareEnabled() ?? false;
    await local?.setScreenShareEnabled(!on);
  }

  bool canShareScreen() {
    return !lk.lkPlatformIsMobile();
  }

  @override
  Widget build(BuildContext context) {
    final room = VideoRoomModel.maybeOf(context)?.room;
    if (room == null || !canShareScreen()) {
      return SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        final on = room.localParticipant?.isScreenShareEnabled() ?? false;
        return PresentButton(onPressed: () => onPressed(context), on: on);
      },
    );
  }
}
