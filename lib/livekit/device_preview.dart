import 'dart:core';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:powerboards/livekit/change_device_button.dart';
import 'package:powerboards/livekit/device_manager.dart';
import 'package:powerboards/theme/theme.dart';

import 'room.dart';

class DevicePreview extends StatelessWidget {
  const DevicePreview({super.key, this.onJoin, this.onCancel});

  final Function(bool enableVideo, bool enableAudio)? onJoin;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return DeviceManager(
      child: _DeviceSettings(onJoin: onJoin, onCancel: onCancel),
    );
  }
}

class _DeviceSettings extends StatefulWidget {
  const _DeviceSettings({this.onJoin, this.onCancel});

  final Function(bool enableVideo, bool enableAudio)? onJoin;
  final VoidCallback? onCancel;

  @override
  State createState() => _DeviceSettingsState();
}

class _DeviceSettingsState extends State<_DeviceSettings> {
  bool _loaded = false;
  bool _audioOn = false;
  bool _videoOn = false;
  bool _audioProcessing = false;
  bool _videoProcessing = false;
  String? _audioDeviceId;
  String? _videoDeviceId;
  LocalAudioTrack? _audio;
  LocalVideoTrack? _video;
  late SharedPreferences _preferences;

  @override
  void initState() {
    super.initState();

    _load();
  }

  @override
  void dispose() {
    _audio?.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _preferences = await SharedPreferences.getInstance();

    _audioDeviceId = _preferences.getString("audioInput");
    _videoDeviceId = _preferences.getString("videoInput");

    await _enableVideo();
    await _enableAudio();

    if (mounted) {
      final deviceManager = DeviceManagerProvider.of(context);
      await deviceManager.refreshDevices();

      setState(() {
        _loaded = true;
      });
    }
  }

  Future<void> _selectAudioInput(MediaDevice? device) async {
    _audioDeviceId = device?.deviceId;
    await _enableAudio();
  }

  Future<void> _selectVideoInput(MediaDevice? device) async {
    _videoDeviceId = device?.deviceId;
    await _enableVideo();
  }

  Future<void> _guardAudioProcessing(Future<void> Function() action) async {
    if (_audioProcessing) return;

    _audioProcessing = true;
    await action();
    _audioProcessing = false;

    if (mounted) {
      final deviceManager = DeviceManagerProvider.of(context);
      if (_audioOn && _audio == null && deviceManager.canTurnOnMicrophone) {
        _enableAudio();
      } else if (!_audioOn && _audio != null) {
        _disableAudio();
      }
    }
  }

  Future<void> _guardVideoProcessing(Future<void> Function() action) async {
    if (_videoProcessing) return;

    _videoProcessing = true;
    await action();
    _videoProcessing = false;

    if (mounted) {
      final deviceManager = DeviceManagerProvider.of(context);
      if (_videoOn && _video == null && deviceManager.canTurnOnCamera) {
        _enableVideo();
      } else if (!_videoOn && _video != null) {
        _disableVideo();
      }
    }
  }

  Future<void> _enableAudio() async {
    setState(() {
      _audioOn = true;
    });

    await _guardAudioProcessing(() async {
      await _audio?.dispose();
      try {
        final track = await LocalAudioTrack.create(AudioCaptureOptions(deviceId: _audioDeviceId));
        if (mounted) {
          setState(() {
            _audio = track;
          });
        } else {
          await track.dispose();
        }
      } catch (error) {
        debugPrint('_enableAudio error $error');
      }
    });
  }

  Future<void> _enableVideo() async {
    setState(() {
      _videoOn = true;
    });

    await _guardVideoProcessing(() async {
      await _video?.dispose();
      try {
        final track = await LocalVideoTrack.createCameraTrack(CameraCaptureOptions(deviceId: _videoDeviceId));
        if (mounted) {
          setState(() {
            _video = track;
          });
        } else {
          await track.dispose();
        }
      } catch (error) {
        debugPrint('_enableVideo error $error');
      }
    });
  }

  Future<void> _disableAudio() async {
    setState(() {
      _audioOn = false;
    });

    await _guardAudioProcessing(() async {
      await _audio?.dispose();
      if (mounted) {
        setState(() {
          _audio = null;
        });
      }
    });
  }

  Future<void> _disableVideo() async {
    setState(() {
      _videoOn = false;
    });

    await _guardVideoProcessing(() async {
      await _video?.dispose();
      if (mounted) {
        setState(() {
          _video = null;
        });
      }
    });
  }

  String get title {
    final deviceManager = DeviceManagerProvider.of(context);
    final cameraState = deviceManager.canTurnOnCamera
        ? _videoOn
              ? "on"
              : "off"
        : "disabled";
    final microphoneState = deviceManager.canTurnOnMicrophone
        ? _audioOn
              ? "on"
              : "off"
        : "disabled";

    if (cameraState == microphoneState) {
      return 'Camera & microphone are $cameraState';
    } else {
      return 'Camera is $cameraState and microphone is $microphoneState';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        var aspectRatio = 3 / 2;
        var width = constraints.maxWidth;
        var height = width / aspectRatio;
        if (constraints.hasBoundedHeight && height > constraints.maxHeight - 150) {
          height = constraints.maxHeight - 150;
          width = height * aspectRatio;
        }

        final deviceManager = DeviceManagerProvider.of(context);
        final videoOn = _videoOn && deviceManager.canTurnOnCamera;
        final audioOn = _audioOn && deviceManager.canTurnOnMicrophone;

        return Column(
          children: [
            Container(
              height: headerHeight,
              alignment: Alignment.center,
              child: _loaded ? Text(key: const Key('device-settings-title'), title, textAlign: TextAlign.center) : null,
            ),
            SizedBox(
              height: height,
              width: width,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  color: Colors.black,
                  foregroundDecoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                  child: _video != null ? VideoTrackRenderer(_video!, fit: VideoViewFit.cover) : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RoomToolbarButton(
                    key: const Key('device-setttings-camera-button'),
                    text: deviceManager.canTurnOnCamera
                        ? videoOn
                              ? "Turn off camera"
                              : "Turn on camera"
                        : "Camera disabled",
                    on: videoOn,
                    onColor: ShadTheme.of(context).colorScheme.foreground,
                    onForeground: ShadTheme.of(context).colorScheme.background,
                    offColor: Colors.red,
                    offForeground: Colors.white,
                    onPressed: deviceManager.canTurnOnCamera
                        ? () {
                            videoOn ? _disableVideo() : _enableVideo();
                          }
                        : null,
                    icon: videoOn ? LucideIcons.video : LucideIcons.videoOff,
                  ),
                  const SizedBox(width: 8),
                  RoomToolbarButton(
                    key: const Key('device-setttings-mic-button'),
                    text: deviceManager.canTurnOnMicrophone
                        ? audioOn
                              ? "Turn off microphone"
                              : "Turn on microphone"
                        : "Microphone disabled",
                    on: audioOn,
                    onColor: ShadTheme.of(context).colorScheme.foreground,
                    onForeground: ShadTheme.of(context).colorScheme.background,
                    offColor: Colors.red,
                    offForeground: Colors.white,
                    onPressed: deviceManager.canTurnOnMicrophone
                        ? () {
                            audioOn ? _disableAudio() : _enableAudio();
                          }
                        : null,
                    icon: audioOn ? LucideIcons.mic : LucideIcons.micOff,
                  ),
                  const SizedBox(width: 8),
                  ChangeDeviceButton(
                    onChangeVideoInput: _selectVideoInput,
                    onChangeAudioInput: _selectAudioInput,
                    onChangeAudioOutput: (_) {},
                    renderButton: (MenuController controller) {
                      return Tooltip(
                        message: "Change device",
                        child: ShadIconButton.outline(
                          onPressed: () {
                            if (controller.isOpen) {
                              controller.close();
                            } else {
                              deviceManager.refreshDevices();
                              controller.open();
                            }
                          },
                          icon: const Icon(LucideIcons.settings),
                        ),
                      );
                    },
                  ),

                  if (widget.onJoin != null) ...[
                    const SizedBox(width: 10),
                    ShadButton(
                      onPressed: () {
                        widget.onJoin?.call(videoOn, audioOn);
                      },
                      child: const Text("Meet Now"),
                    ),
                  ],
                  if (widget.onCancel != null) ...[
                    const SizedBox(width: 10),
                    ShadButton.secondary(
                      onPressed: () {
                        widget.onCancel?.call();
                      },
                      child: const Text("Cancel"),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(child: Container()),
          ],
        );
      },
    );
  }
}
