import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:meshagent_flutter_shadcn/meetings/meetings.dart';
import 'package:powerboards/livekit/change_device_button.dart';
import 'package:powerboards/livekit/room.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

lk.LocalTrackPublication<lk.LocalVideoTrack>? _voiceCameraPublication(lk.LocalParticipant? participant) {
  final publication = participant?.getTrackPublicationBySource(lk.TrackSource.camera);
  if (publication is! lk.LocalTrackPublication<lk.LocalVideoTrack>) {
    return null;
  }

  return publication;
}

class VoiceMeetingControls extends StatelessWidget {
  const VoiceMeetingControls({super.key, required this.controller, this.spacing = 8});

  final MeetingController controller;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.livekitRoom,
      builder: (context, _) {
        if (controller.livekitRoom.localParticipant == null) {
          return _VoiceConnectionButton(controller: controller);
        }

        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _VoiceConnectionButton(controller: controller),
            _VoiceMicToggle(controller: controller),
            _VoiceCameraToggle(controller: controller),
            _VoiceChangeSettings(controller: controller),
          ],
        );
      },
    );
  }
}

class _VoiceConnectionButton extends StatelessWidget {
  const _VoiceConnectionButton({required this.controller});

  final MeetingController controller;

  @override
  Widget build(BuildContext context) {
    final room = controller.livekitRoom;

    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        return switch (room.connectionState) {
          lk.ConnectionState.connected => RoomToolbarButton(
            text: "Hangup",
            on: false,
            onColor: ShadTheme.of(context).colorScheme.foreground,
            onForeground: ShadTheme.of(context).colorScheme.background,
            offColor: ShadTheme.of(context).colorScheme.destructive,
            offForeground: Colors.white,
            icon: LucideIcons.phone,
            onPressed: () => unawaited(controller.disconnect()),
          ),
          lk.ConnectionState.disconnected => RoomToolbarButton(
            text: "Connect",
            on: false,
            onColor: ShadTheme.of(context).colorScheme.foreground,
            onForeground: ShadTheme.of(context).colorScheme.background,
            offColor: ShadTheme.of(context).colorScheme.foreground,
            offForeground: ShadTheme.of(context).colorScheme.background,
            icon: LucideIcons.phone,
            onPressed: () => unawaited(controller.connect()),
          ),
          _ => RoomToolbarButton(
            text: "Connecting",
            on: false,
            onColor: ShadTheme.of(context).colorScheme.foreground,
            onForeground: ShadTheme.of(context).colorScheme.background,
            offColor: ShadTheme.of(context).colorScheme.destructive,
            offForeground: Colors.white,
            icon: LucideIcons.phone,
            loading: true,
          ),
        };
      },
    );
  }
}

class _VoiceCameraToggle extends StatefulWidget {
  const _VoiceCameraToggle({required this.controller});

  final MeetingController controller;

  @override
  State<_VoiceCameraToggle> createState() => _VoiceCameraToggleState();
}

class _VoiceCameraToggleState extends State<_VoiceCameraToggle> {
  bool _cameraEnabled = false;
  bool _pending = false;
  bool _processing = false;
  VoidCallback? _unsubscribe;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindListeners();
  }

  @override
  void didUpdateWidget(covariant _VoiceCameraToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _bindListeners();
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  void _bindListeners() {
    _unsubscribe?.call();

    final room = widget.controller.livekitRoom;
    final local = room.localParticipant;
    void updateState() {
      if (!mounted) {
        return;
      }

      setState(() {
        _cameraEnabled = local?.isCameraEnabled() ?? false;
        _pending = widget.controller.pendingLocalMedia.cameraPending;
      });
    }

    room.addListener(updateState);
    local?.addListener(updateState);
    widget.controller.pendingLocalMedia.addListener(updateState);
    _unsubscribe = () {
      room.removeListener(updateState);
      local?.removeListener(updateState);
      widget.controller.pendingLocalMedia.removeListener(updateState);
    };
    updateState();
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

  Future<void> _toggleCamera(lk.LocalParticipant local, bool enabled) async {
    if (_processing) {
      return;
    }

    final toaster = ShadToaster.maybeOf(context);
    setState(() {
      _processing = true;
    });

    try {
      await local.setCameraEnabled(enabled);
    } catch (error) {
      toaster?.show(ShadToast.destructive(description: Text(_describeCameraToggleError(error))));
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _cameraEnabled = local.isCameraEnabled();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.controller.livekitRoom.localParticipant;
    final showEnabled = _cameraEnabled || _pending;

    return RoomToolbarButton(
      text: _pending
          ? "Starting camera"
          : _cameraEnabled
          ? "Turn off camera"
          : "Turn on camera",
      on: showEnabled,
      onColor: ShadTheme.of(context).colorScheme.foreground,
      onForeground: ShadTheme.of(context).colorScheme.background,
      offColor: ShadTheme.of(context).colorScheme.destructive,
      offForeground: Colors.white,
      icon: showEnabled ? LucideIcons.video : LucideIcons.videoOff,
      loading: _pending,
      onPressed: local == null || _processing || _pending ? null : () => unawaited(_toggleCamera(local, !_cameraEnabled)),
    );
  }
}

class _VoiceMicToggle extends StatefulWidget {
  const _VoiceMicToggle({required this.controller});

  final MeetingController controller;

  @override
  State<_VoiceMicToggle> createState() => _VoiceMicToggleState();
}

class _VoiceMicToggleState extends State<_VoiceMicToggle> {
  bool _microphoneEnabled = false;
  bool _pending = false;
  bool _processing = false;
  VoidCallback? _unsubscribe;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindListeners();
  }

  @override
  void didUpdateWidget(covariant _VoiceMicToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _bindListeners();
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  void _bindListeners() {
    _unsubscribe?.call();

    final room = widget.controller.livekitRoom;
    final local = room.localParticipant;
    void updateState() {
      if (!mounted) {
        return;
      }

      setState(() {
        _microphoneEnabled = local?.isMicrophoneEnabled() ?? false;
        _pending = widget.controller.pendingLocalMedia.microphonePending;
      });
    }

    room.addListener(updateState);
    local?.addListener(updateState);
    widget.controller.pendingLocalMedia.addListener(updateState);
    _unsubscribe = () {
      room.removeListener(updateState);
      local?.removeListener(updateState);
      widget.controller.pendingLocalMedia.removeListener(updateState);
    };
    updateState();
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

  Future<void> _toggleMicrophone(lk.LocalParticipant local, bool enabled) async {
    if (_processing) {
      return;
    }

    final toaster = ShadToaster.maybeOf(context);
    setState(() {
      _processing = true;
    });

    try {
      await local.setMicrophoneEnabled(enabled);
    } catch (error) {
      toaster?.show(ShadToast.destructive(description: Text(_describeMicrophoneToggleError(error))));
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _microphoneEnabled = local.isMicrophoneEnabled();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.controller.livekitRoom.localParticipant;
    final showEnabled = _microphoneEnabled || _pending;

    return RoomToolbarButton(
      text: _pending
          ? "Starting microphone"
          : _microphoneEnabled
          ? "Turn off microphone"
          : "Turn on microphone",
      on: showEnabled,
      onColor: ShadTheme.of(context).colorScheme.foreground,
      onForeground: ShadTheme.of(context).colorScheme.background,
      offColor: ShadTheme.of(context).colorScheme.destructive,
      offForeground: Colors.white,
      icon: showEnabled ? LucideIcons.mic : LucideIcons.micOff,
      loading: _pending,
      onPressed: local == null || _processing || _pending ? null : () => unawaited(_toggleMicrophone(local, !_microphoneEnabled)),
    );
  }
}

class _VoiceChangeSettings extends StatelessWidget {
  const _VoiceChangeSettings({required this.controller});

  static const Duration _minimumPendingDuration = Duration(milliseconds: 350);

  final MeetingController controller;

  Future<void> _runWithMinimumPendingDuration(Future<void> Function() action) async {
    final startedAt = DateTime.now();
    await action();
    final remaining = _minimumPendingDuration - DateTime.now().difference(startedAt);
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  Future<void> _runCameraDeviceSwitch(Future<void> Function() action) async {
    final shouldShowPending = controller.livekitRoom.localParticipant?.isCameraEnabled() ?? false;
    if (shouldShowPending) {
      controller.pendingLocalMedia.setCameraPending(true);
    }

    try {
      await _runWithMinimumPendingDuration(action);
    } finally {
      if (shouldShowPending) {
        controller.pendingLocalMedia.setCameraPending(false);
      }
    }
  }

  Future<void> _runMicrophoneDeviceSwitch(Future<void> Function() action) async {
    final shouldShowPending = controller.livekitRoom.localParticipant?.isMicrophoneEnabled() ?? false;
    if (shouldShowPending) {
      controller.pendingLocalMedia.setMicrophonePending(true);
    }

    try {
      await _runWithMinimumPendingDuration(action);
    } finally {
      if (shouldShowPending) {
        controller.pendingLocalMedia.setMicrophonePending(false);
      }
    }
  }

  Future<void> _selectVideoInput(lk.MediaDevice device) async {
    final track = _voiceCameraPublication(controller.livekitRoom.localParticipant)?.track;

    await _runCameraDeviceSwitch(() async {
      await controller.livekitRoom.setVideoInputDevice(device);
      await track?.restartTrack(lk.CameraCaptureOptions(deviceId: device.deviceId));
    });
  }

  Future<void> _selectAudioInput(lk.MediaDevice device) async {
    await _runMicrophoneDeviceSwitch(() => controller.livekitRoom.setAudioInputDevice(device));
  }

  Future<void> _selectAudioOutput(lk.MediaDevice device) async {
    await controller.livekitRoom.setAudioOutputDevice(device);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeDeviceButton(
      presentation: ChangeDeviceButtonPresentation.dialog,
      onChangeVideoInput: _selectVideoInput,
      onChangeAudioInput: _selectAudioInput,
      onChangeAudioOutput: _selectAudioOutput,
      selectedVideoInputDeviceId: () => controller.livekitRoom.selectedVideoInputDeviceId,
      selectedAudioInputDeviceId: () => controller.livekitRoom.selectedAudioInputDeviceId,
      selectedAudioOutputDeviceId: () => controller.livekitRoom.selectedAudioOutputDeviceId,
      renderButton: (onPressed) => Tooltip(
        message: "Device settings",
        child: ShadIconButton.outline(onPressed: onPressed, icon: const Icon(LucideIcons.settings)),
      ),
    );
  }
}
