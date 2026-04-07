import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:powerboards/livekit/present_button.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:meshagent_flutter/meshagent_flutter.dart';
import 'package:meshagent_flutter_shadcn/theme/colors.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:powerboards/powerboards_controller/powerboards_controller.dart';

import 'package:powerboards/livekit/change_device_button.dart';
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

class PendingLocalMediaState extends ChangeNotifier {
  bool _cameraPending = false;
  bool _microphonePending = false;
  bool _cameraAwaitingEnableConfirmation = false;
  bool _microphoneAwaitingEnableConfirmation = false;
  bool _cameraUnavailable = false;
  bool _microphoneUnavailable = false;

  bool get cameraPending => _cameraPending;
  bool get microphonePending => _microphonePending;
  bool get cameraUnavailable => _cameraUnavailable;
  bool get microphoneUnavailable => _microphoneUnavailable;

  void setCameraPending(bool value, {bool awaitEnableConfirmation = false}) {
    if (_cameraPending == value && _cameraAwaitingEnableConfirmation == awaitEnableConfirmation) {
      return;
    }

    _cameraPending = value;
    _cameraAwaitingEnableConfirmation = value && awaitEnableConfirmation;
    notifyListeners();
  }

  void setMicrophonePending(bool value, {bool awaitEnableConfirmation = false}) {
    if (_microphonePending == value && _microphoneAwaitingEnableConfirmation == awaitEnableConfirmation) {
      return;
    }

    _microphonePending = value;
    _microphoneAwaitingEnableConfirmation = value && awaitEnableConfirmation;
    notifyListeners();
  }

  void setCameraUnavailable(bool value) {
    if (_cameraUnavailable == value) {
      return;
    }

    _cameraUnavailable = value;
    notifyListeners();
  }

  void setMicrophoneUnavailable(bool value) {
    if (_microphoneUnavailable == value) {
      return;
    }

    _microphoneUnavailable = value;
    notifyListeners();
  }

  void setPending({
    required bool cameraPending,
    required bool microphonePending,
    bool cameraAwaitEnableConfirmation = false,
    bool microphoneAwaitEnableConfirmation = false,
  }) {
    if (_cameraPending == cameraPending &&
        _microphonePending == microphonePending &&
        _cameraAwaitingEnableConfirmation == (cameraPending && cameraAwaitEnableConfirmation) &&
        _microphoneAwaitingEnableConfirmation == (microphonePending && microphoneAwaitEnableConfirmation)) {
      return;
    }

    _cameraPending = cameraPending;
    _microphonePending = microphonePending;
    _cameraAwaitingEnableConfirmation = cameraPending && cameraAwaitEnableConfirmation;
    _microphoneAwaitingEnableConfirmation = microphonePending && microphoneAwaitEnableConfirmation;
    notifyListeners();
  }

  void clear() {
    if (!_cameraPending &&
        !_microphonePending &&
        !_cameraAwaitingEnableConfirmation &&
        !_microphoneAwaitingEnableConfirmation &&
        !_cameraUnavailable &&
        !_microphoneUnavailable) {
      return;
    }

    _cameraPending = false;
    _microphonePending = false;
    _cameraAwaitingEnableConfirmation = false;
    _microphoneAwaitingEnableConfirmation = false;
    _cameraUnavailable = false;
    _microphoneUnavailable = false;
    notifyListeners();
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
    required this.pendingLocalMedia,
    required super.child,
  });

  final List<lk.Participant> activeSpeakers;

  final lk.Room? room;
  final String chatID;
  final int participantCount;
  final lk.LocalParticipant? localParticipant;
  final PendingLocalMediaState pendingLocalMedia;

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
        localParticipant != oldWidget.localParticipant ||
        pendingLocalMedia != oldWidget.pendingLocalMedia;

    return shouldUpdate;
  }
}

extension PowerboardsParticipants on lk.Room {
  lk.RemoteParticipant? get agent {
    return remoteParticipants.values.where((x) => x.identity.endsWith(".agent")).firstOrNull;
  }
}

lk.LocalTrackPublication<lk.LocalVideoTrack>? _cameraPublication(lk.LocalParticipant? participant) {
  final publication = participant?.getTrackPublicationBySource(lk.TrackSource.camera);
  if (publication is! lk.LocalTrackPublication<lk.LocalVideoTrack>) {
    return null;
  }

  return publication;
}

class VideoRoomProvider extends StatefulWidget {
  const VideoRoomProvider({super.key, required this.room, required this.chatID, required this.pendingLocalMedia, required this.child});

  final lk.Room? room;
  final String chatID;
  final PendingLocalMediaState pendingLocalMedia;
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
      pendingLocalMedia: widget.pendingLocalMedia,
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
  final PendingLocalMediaState pendingLocalMedia = PendingLocalMediaState();
  lk.Room? _observedRoom;
  lk.LocalParticipant? _observedLocalParticipant;

  @override
  void initState() {
    super.initState();

    focusNode = FocusNode();
  }

  @override
  void dispose() {
    super.dispose();

    _detachPendingLocalMediaListeners();
    pendingLocalMedia.dispose();

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
      pendingLocalMedia.clear();
      _detachPendingLocalMediaListeners();

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

  void _detachPendingLocalMediaListeners() {
    _observedLocalParticipant?.removeListener(_syncPendingLocalMediaState);
    _observedRoom?.removeListener(_syncPendingLocalMediaState);
    _observedLocalParticipant = null;
    _observedRoom = null;
  }

  void _attachPendingLocalMediaListeners(lk.Room? room) {
    if (_observedRoom == room) {
      _syncObservedLocalParticipant();
      _syncPendingLocalMediaState();
      return;
    }

    _detachPendingLocalMediaListeners();
    _observedRoom = room;
    _observedRoom?.addListener(_syncPendingLocalMediaState);
    _syncObservedLocalParticipant();
    _syncPendingLocalMediaState();
  }

  void _syncObservedLocalParticipant() {
    final localParticipant = _observedRoom?.localParticipant;
    if (_observedLocalParticipant == localParticipant) {
      return;
    }

    _observedLocalParticipant?.removeListener(_syncPendingLocalMediaState);
    _observedLocalParticipant = localParticipant;
    _observedLocalParticipant?.addListener(_syncPendingLocalMediaState);
  }

  void _syncPendingLocalMediaState() {
    _syncObservedLocalParticipant();

    final room = _observedRoom;
    if (room == null) {
      pendingLocalMedia.clear();
      return;
    }

    final localParticipant = _observedLocalParticipant;
    if (pendingLocalMedia._cameraAwaitingEnableConfirmation && (localParticipant?.isCameraEnabled() ?? false)) {
      pendingLocalMedia.setCameraPending(false);
    }
    if (localParticipant?.isCameraEnabled() ?? false) {
      pendingLocalMedia.setCameraUnavailable(false);
    }
    if (pendingLocalMedia._microphoneAwaitingEnableConfirmation && (localParticipant?.isMicrophoneEnabled() ?? false)) {
      pendingLocalMedia.setMicrophonePending(false);
    }
    if (localParticipant?.isMicrophoneEnabled() ?? false) {
      pendingLocalMedia.setMicrophoneUnavailable(false);
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
    bool videoUnavailable = false,
    bool audioUnavailable = false,
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
      videoUnavailable: videoUnavailable,
      audioUnavailable: audioUnavailable,
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
    bool videoUnavailable = false,
    bool audioUnavailable = false,
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
      pendingLocalMedia.setCameraUnavailable(videoUnavailable);
      pendingLocalMedia.setMicrophoneUnavailable(audioUnavailable);
      pendingLocalMedia.setPending(
        cameraPending: enableLocalTracks && enableVideo,
        microphonePending: enableLocalTracks && enableAudio,
        cameraAwaitEnableConfirmation: enableLocalTracks && enableVideo,
        microphoneAwaitEnableConfirmation: enableLocalTracks && enableAudio,
      );
      _attachPendingLocalMediaListeners(newRoom);

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
        videoUnavailable: videoUnavailable,
        audioUnavailable: audioUnavailable,
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
    bool videoUnavailable = false,
    bool audioUnavailable = false,
    required String? agentID,
  }) {
    if (_roomConnectFuture == null) {
      final completer = Completer<bool>();

      pendingConnections = pendingConnections.whenComplete(() async {
        try {
          await room.connect(url, token, fastConnectOptions: fastConnectOptions);
        } catch (error) {
          pendingLocalMedia.clear();
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
          rethrow;
        }

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
                  pendingLocalMedia.setCameraUnavailable(false);
                  final cameraPublication = _cameraPublication(room.localParticipant);
                  if (cameraPublication?.muted == true) {
                    debugPrint("camera was not enabled, restarting");
                    await cameraPublication?.track?.restartTrack();
                  }
                  _syncPendingLocalMediaState();
                } catch (err) {
                  pendingLocalMedia.setCameraPending(false);
                  pendingLocalMedia.setCameraUnavailable(true);
                  debugPrint("Unable to enable video $err");
                }
              } else {
                pendingLocalMedia.setCameraPending(false);
                pendingLocalMedia.setCameraUnavailable(videoUnavailable);
              }

              if (!isAudioDisabled) {
                try {
                  await room.localParticipant!.setMicrophoneEnabled(true);
                  pendingLocalMedia.setMicrophoneUnavailable(false);
                  _syncPendingLocalMediaState();
                } catch (err) {
                  pendingLocalMedia.setMicrophonePending(false);
                  pendingLocalMedia.setMicrophoneUnavailable(true);
                  debugPrint("Unable to enable audio $err");
                }
              } else {
                pendingLocalMedia.setMicrophonePending(false);
                pendingLocalMedia.setMicrophoneUnavailable(audioUnavailable);
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
    return ShadToaster(
      child: VideoRoomProvider(room: room, chatID: roomSID ?? '', pendingLocalMedia: pendingLocalMedia, child: widget.child),
    );
  }
}

class CameraToggle extends StatefulWidget {
  const CameraToggle({super.key});

  @override
  State<StatefulWidget> createState() => _CameraToggleState();
}

class _CameraToggleState extends State<CameraToggle> {
  bool state = false;
  bool _pending = false;
  bool _processing = false;
  bool _deviceAvailable = true;

  Function? unsubscribe;
  VideoRoomModel? _model;
  StreamSubscription<List<lk.MediaDevice>>? _deviceSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshDeviceAvailability());
    _deviceSubscription = lk.Hardware.instance.onDeviceChange.stream.listen((devices) {
      _updateDeviceAvailability(devices);
    });
  }

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
      model?.pendingLocalMedia.addListener(updateState);

      unsubscribe = () {
        local?.removeListener(updateState);
        model?.room?.removeListener(updateState);
        model?.pendingLocalMedia.removeListener(updateState);
      };
    }
  }

  @override
  void dispose() {
    super.dispose();

    unsubscribe?.call();
    _deviceSubscription?.cancel();
  }

  Future<void> _refreshDeviceAvailability() async {
    final devices = await lk.Hardware.instance.enumerateDevices();
    _updateDeviceAvailability(devices);
  }

  void _updateDeviceAvailability(List<lk.MediaDevice> devices) {
    final available = devices.any((device) => device.kind == "videoinput" && device.deviceId.isNotEmpty);
    if (!mounted || _deviceAvailable == available) {
      return;
    }

    setState(() {
      _deviceAvailable = available;
    });
  }

  void updateState() {
    if (mounted && _model != null) {
      final local = _model!.room?.localParticipant;
      final isCameraEnabled = state = local?.isCameraEnabled() ?? false;
      final isCameraPending = _model!.pendingLocalMedia.cameraPending;

      setState(() {
        state = isCameraEnabled;
        _pending = isCameraPending;
      });
    }
  }

  String _describeCameraToggleError(Object error) {
    final message = '$error';
    if (message.contains('NotAllowedError')) {
      return 'Camera access was blocked by the browser or system.';
    }
    if (message.contains('NotFoundError')) {
      return 'The selected camera was not found.';
    }
    return 'Unable to change camera state: $message';
  }

  Future<void> _toggleCamera(lk.LocalParticipant local, bool value) async {
    if (_processing) {
      return;
    }

    final toaster = ShadToaster.maybeOf(context);
    setState(() {
      _processing = true;
    });

    try {
      await local.setCameraEnabled(value);
      _model?.pendingLocalMedia.setCameraUnavailable(false);
    } catch (error) {
      _model?.pendingLocalMedia.setCameraUnavailable(true);
      toaster?.show(ShadToast.destructive(description: Text(_describeCameraToggleError(error))));
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          state = local.isCameraEnabled();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = VideoRoomModel.maybeOf(context);
    final local = model?.room?.localParticipant;
    final showPending = _pending;
    final showEnabled = state || showPending;
    final unavailable = ((model?.pendingLocalMedia.cameraUnavailable == true) || !_deviceAvailable) && !showEnabled;
    final toggleColor = unavailable ? ShadTheme.of(context).colorScheme.destructive : ShadTheme.of(context).colorScheme.greenCustom;
    final toggleForeground = unavailable
        ? ShadTheme.of(context).colorScheme.destructiveForeground
        : ShadTheme.of(context).colorScheme.greenCustomForeground;

    return RoomToolbarButton(
      text: showPending
          ? "Starting camera"
          : state
          ? "Turn off camera"
          : "Turn on camera",
      on: showEnabled,
      onColor: toggleColor,
      onForeground: toggleForeground,
      offColor: toggleColor,
      offForeground: toggleForeground,
      icon: showEnabled ? LucideIcons.video : LucideIcons.videoOff,
      loading: showPending,
      onPressed: local == null || _processing || showPending ? null : () => unawaited(_toggleCamera(local, !state)),
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
  bool _pending = false;
  bool _processing = false;
  bool _deviceAvailable = true;

  Function? unsubscribe;
  VideoRoomModel? _model;
  StreamSubscription<List<lk.MediaDevice>>? _deviceSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshDeviceAvailability());
    _deviceSubscription = lk.Hardware.instance.onDeviceChange.stream.listen((devices) {
      _updateDeviceAvailability(devices);
    });
  }

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
      model?.pendingLocalMedia.addListener(updateState);
      unsubscribe = () {
        local?.removeListener(updateState);
        model?.room?.removeListener(updateState);
        model?.pendingLocalMedia.removeListener(updateState);
      };
    }
  }

  @override
  void dispose() {
    super.dispose();

    unsubscribe?.call();
    _deviceSubscription?.cancel();
  }

  Future<void> _refreshDeviceAvailability() async {
    final devices = await lk.Hardware.instance.enumerateDevices();
    _updateDeviceAvailability(devices);
  }

  void _updateDeviceAvailability(List<lk.MediaDevice> devices) {
    final available = devices.any((device) => device.kind == "audioinput" && device.deviceId.isNotEmpty);
    if (!mounted || _deviceAvailable == available) {
      return;
    }

    setState(() {
      _deviceAvailable = available;
    });
  }

  void updateState() {
    if (mounted && _model != null) {
      final local = _model!.room?.localParticipant;
      final isMicrophoneEnabled = state = local?.isMicrophoneEnabled() ?? false;
      final isMicrophonePending = _model!.pendingLocalMedia.microphonePending;

      setState(() {
        state = isMicrophoneEnabled;
        _pending = isMicrophonePending;
      });
    }
  }

  String _describeMicrophoneToggleError(Object error) {
    final message = '$error';
    if (message.contains('NotAllowedError')) {
      return 'Microphone access was blocked by the browser or system.';
    }
    if (message.contains('NotFoundError')) {
      return 'The selected microphone was not found.';
    }
    return 'Unable to change microphone state: $message';
  }

  Future<void> _toggleMicrophone(lk.LocalParticipant local, bool value) async {
    if (_processing) {
      return;
    }

    final toaster = ShadToaster.maybeOf(context);
    setState(() {
      _processing = true;
    });

    try {
      await local.setMicrophoneEnabled(value);
      _model?.pendingLocalMedia.setMicrophoneUnavailable(false);
    } catch (error) {
      _model?.pendingLocalMedia.setMicrophoneUnavailable(true);
      toaster?.show(ShadToast.destructive(description: Text(_describeMicrophoneToggleError(error))));
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          state = local.isMicrophoneEnabled();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = VideoRoomModel.maybeOf(context);
    final local = model?.room?.localParticipant;
    final showPending = _pending;
    final showEnabled = state || showPending;
    final unavailable = ((model?.pendingLocalMedia.microphoneUnavailable == true) || !_deviceAvailable) && !showEnabled;
    final toggleColor = unavailable ? ShadTheme.of(context).colorScheme.destructive : ShadTheme.of(context).colorScheme.greenCustom;
    final toggleForeground = unavailable
        ? ShadTheme.of(context).colorScheme.destructiveForeground
        : ShadTheme.of(context).colorScheme.greenCustomForeground;

    return RoomToolbarButton(
      text: showPending
          ? "Starting microphone"
          : state
          ? "Turn off microphone"
          : "Turn on microphone",
      on: showEnabled,
      onColor: toggleColor,
      onForeground: toggleForeground,
      offColor: toggleColor,
      offForeground: toggleForeground,
      icon: showEnabled ? LucideIcons.mic : LucideIcons.micOff,
      loading: showPending,
      onPressed: local == null || _processing || showPending ? null : () => unawaited(_toggleMicrophone(local, !state)),
    );
  }
}

class ChangeSettings extends StatelessWidget {
  const ChangeSettings({super.key, this.kind});

  static const Duration _minimumPendingDuration = Duration(milliseconds: 350);

  final String? kind;

  Future<void> _runWithMinimumPendingDuration(Future<void> Function() action) async {
    final startedAt = DateTime.now();
    await action();
    final remaining = _minimumPendingDuration - DateTime.now().difference(startedAt);
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  Future<void> _runCameraDeviceSwitch(BuildContext context, Future<void> Function() action) async {
    final model = VideoRoomModel.maybeOf(context);
    final shouldShowPending = model?.localParticipant?.isCameraEnabled() ?? false;
    if (shouldShowPending) {
      model?.pendingLocalMedia.setCameraPending(true);
    }

    try {
      await _runWithMinimumPendingDuration(action);
    } finally {
      if (shouldShowPending) {
        model?.pendingLocalMedia.setCameraPending(false);
      }
    }
  }

  Future<void> _runMicrophoneDeviceSwitch(BuildContext context, Future<void> Function() action) async {
    final model = VideoRoomModel.maybeOf(context);
    final shouldShowPending = model?.localParticipant?.isMicrophoneEnabled() ?? false;
    if (shouldShowPending) {
      model?.pendingLocalMedia.setMicrophonePending(true);
    }

    try {
      await _runWithMinimumPendingDuration(action);
    } finally {
      if (shouldShowPending) {
        model?.pendingLocalMedia.setMicrophonePending(false);
      }
    }
  }

  Future<void> _selectVideoInput(BuildContext context, lk.MediaDevice device) async {
    final room = VideoRoomModel.maybeOf(context)?.room;
    final track = _cameraPublication(room?.localParticipant)?.track;

    await _runCameraDeviceSwitch(context, () async {
      await room?.setVideoInputDevice(device);

      // workaround for livekit client issue - switchCamera not called by room.setVideoInputDevice
      // https://github.com/livekit/client-sdk-flutter/issues/863
      await track?.restartTrack(lk.CameraCaptureOptions(deviceId: device.deviceId));
    });
  }

  Future<void> _selectAudioInput(BuildContext context, lk.MediaDevice device) async {
    final room = VideoRoomModel.maybeOf(context)?.room;
    await _runMicrophoneDeviceSwitch(context, () => room?.setAudioInputDevice(device) ?? Future.value());
  }

  Future<void> _selectAudioOutput(BuildContext context, lk.MediaDevice device) async {
    final room = VideoRoomModel.maybeOf(context)?.room;

    await room?.setAudioOutputDevice(device);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeDeviceButton(
      kind: kind,
      presentation: ChangeDeviceButtonPresentation.dialog,
      onChangeVideoInput: (device) => _selectVideoInput(context, device),
      onChangeAudioInput: (device) => _selectAudioInput(context, device),
      onChangeAudioOutput: (device) => _selectAudioOutput(context, device),
      selectedVideoInputDeviceId: () => VideoRoomModel.maybeOf(context)?.room?.selectedVideoInputDeviceId,
      selectedAudioInputDeviceId: () => VideoRoomModel.maybeOf(context)?.room?.selectedAudioInputDeviceId,
      selectedAudioOutputDeviceId: () => VideoRoomModel.maybeOf(context)?.room?.selectedAudioOutputDeviceId,
      cameraUnavailable: VideoRoomModel.maybeOf(context)?.pendingLocalMedia.cameraUnavailable ?? false,
      microphoneUnavailable: VideoRoomModel.maybeOf(context)?.pendingLocalMedia.microphoneUnavailable ?? false,
      renderButton: (onPressed) {
        return Tooltip(
          message: "Device settings",
          child: ShadIconButton.outline(onPressed: onPressed, icon: const Icon(LucideIcons.settings)),
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
    this.offForeground = const Color(0xFF222222),
    super.key,
    this.on = false,
    this.loading = false,
  });

  final void Function()? onPressed;
  final String text;
  final Color onColor;
  final Color offColor;
  final Color onForeground;
  final Color offForeground;
  final IconData icon;

  final bool on;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final disabled = !on && onPressed == null;
    final foregroundColor = on ? onForeground : (disabled ? Colors.white : offForeground);

    return Tooltip(
      message: text,
      child: ShadIconButton(
        onPressed: onPressed,
        backgroundColor: on ? onColor : (disabled ? theme.colorScheme.destructive : offColor),
        foregroundColor: foregroundColor,
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(foregroundColor)),
              )
            : Icon(icon, size: 22),
      ),
    );
  }
}

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key, this.compact = false});

  bool canShareScreen() {
    return !lk.lkPlatformIsMobile();
  }

  final bool compact;

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  bool _processing = false;

  bool _hasActiveScreenShare(lk.LocalParticipant? local) {
    if (local == null) return false;

    return local.videoTrackPublications.any(
      (publication) => publication.source == lk.TrackSource.screenShareVideo && !publication.muted && publication.track != null,
    );
  }

  String _describeScreenShareError(Object error) {
    final message = '$error';

    if (message.contains('NotAllowedError')) {
      return 'Screen sharing was blocked by the browser or system.';
    }

    if (message.contains('NotFoundError')) {
      return 'No screen source was available to share.';
    }

    if (message.contains('AbortError')) {
      return 'Screen sharing was canceled before it started.';
    }

    return 'Unable to start screen sharing: $message';
  }

  Future<void> _onPressed(BuildContext context) async {
    final local = VideoRoomModel.maybeOf(context)?.room?.localParticipant;
    final toaster = ShadToaster.maybeOf(context);
    if (local == null || _processing) {
      return;
    }

    final on = _hasActiveScreenShare(local);

    setState(() {
      _processing = true;
    });

    try {
      await local.setScreenShareEnabled(!on);
    } catch (error) {
      if (!mounted) return;
      toaster?.show(ShadToast.destructive(description: Text(_describeScreenShareError(error))));
      debugPrint('Unable to toggle screen sharing $error');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _processing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = VideoRoomModel.maybeOf(context)?.room;
    if (room == null || !widget.canShareScreen()) {
      return SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        final on = _hasActiveScreenShare(room.localParticipant);
        return PresentButton(onPressed: _processing ? null : () => _onPressed(context), on: on, compact: widget.compact);
      },
    );
  }
}
