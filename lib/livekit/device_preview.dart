import 'dart:core';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:powerboards/livekit/change_device_button.dart';
import 'package:powerboards/livekit/device_manager.dart';

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
  static const Duration _minimumLobbySwitchPendingDuration = Duration(milliseconds: 350);
  bool _loaded = false;
  bool _audioOn = false;
  bool _videoOn = false;
  bool _audioProcessing = false;
  bool _videoProcessing = false;
  String? _audioDeviceId;
  String? _audioOutputDeviceId;
  String? _videoDeviceId;
  LocalAudioTrack? _audio;
  LocalVideoTrack? _video;
  late SharedPreferences _preferences;

  bool get _audioPending => _audioOn && _audio == null;
  bool get _videoPending => _videoOn && _video == null;

  bool _isExpectedMediaAccessError(Object error) {
    final message = '$error';
    return message.contains('NotFoundError: Requested device not found') || message.contains('NotAllowedError: Permission denied');
  }

  String _describeVideoToggleError(Object error) {
    final message = '$error';
    if (message.contains('NotAllowedError')) {
      return 'Camera access was blocked by the browser or system.';
    }
    if (message.contains('NotFoundError')) {
      return 'The selected camera was not found.';
    }
    return 'Unable to change camera state: $message';
  }

  String _describeAudioToggleError(Object error) {
    final message = '$error';
    if (message.contains('NotAllowedError')) {
      return 'Microphone access was blocked by the browser or system.';
    }
    if (message.contains('NotFoundError')) {
      return 'The selected microphone was not found.';
    }
    return 'Unable to change microphone state: $message';
  }

  bool _isLandscapePhoneViewport(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height && size.shortestSide < 600;
  }

  Future<void> _runWithMinimumProcessingDuration(Future<void> Function() action) async {
    final startedAt = DateTime.now();
    await action();
    final remaining = _minimumLobbySwitchPendingDuration - DateTime.now().difference(startedAt);
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  void _showUnavailableCameraToast() {
    ShadToaster.maybeOf(
      context,
    )?.show(ShadToast.destructive(description: const Text('Camera is unavailable. Check your device settings.')));
  }

  void _showUnavailableMicrophoneToast() {
    ShadToaster.maybeOf(
      context,
    )?.show(ShadToast.destructive(description: const Text('Microphone is unavailable. Check your device settings.')));
  }

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
    _audioOutputDeviceId = _preferences.getString("audioOutput");
    _videoDeviceId = _preferences.getString("videoInput");

    if (!mounted) return;
    await _enableVideo();

    if (!mounted) return;
    await _enableAudio();

    if (!mounted) return;
    await _restoreAudioOutputSelection();

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
    await _runWithMinimumProcessingDuration(_enableAudio);
    if (_audioDeviceId == device?.deviceId && _audio == null) {
      throw StateError('Unable to switch microphone to ${device?.deviceId ?? "default"}');
    }
  }

  Future<void> _selectVideoInput(MediaDevice? device) async {
    _videoDeviceId = device?.deviceId;
    await _runWithMinimumProcessingDuration(_enableVideo);
    if (_videoDeviceId == device?.deviceId && _video == null) {
      throw StateError('Unable to switch camera to ${device?.deviceId ?? "default"}');
    }
  }

  Future<void> _selectAudioOutput(MediaDevice device) async {
    _audioOutputDeviceId = device.deviceId;

    if (lkPlatformIs(PlatformType.web)) {
      Hardware.instance.selectedAudioOutput = device;
      return;
    }

    await Hardware.instance.selectAudioOutput(device);
  }

  Future<void> _restoreAudioOutputSelection() async {
    final preferredAudioOutputDeviceId = _audioOutputDeviceId;
    if (preferredAudioOutputDeviceId == null || preferredAudioOutputDeviceId.isEmpty) {
      return;
    }

    final audioOutputs = await Hardware.instance.audioOutputs();
    final preferredAudioOutput = audioOutputs.firstWhereOrNull((device) => device.deviceId == preferredAudioOutputDeviceId);
    if (preferredAudioOutput == null) {
      return;
    }

    await _selectAudioOutput(preferredAudioOutput);
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

  Future<void> _enableAudio({bool showErrors = false}) async {
    setState(() {
      _audioOn = true;
    });

    await _guardAudioProcessing(() async {
      final existingTrack = _audio;
      if (mounted && existingTrack != null) {
        setState(() {
          _audio = null;
        });
      }
      await existingTrack?.dispose();
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
        if (mounted) {
          setState(() {
            _audioOn = false;
            _audio = null;
          });
          if (showErrors) {
            ShadToaster.maybeOf(context)?.show(ShadToast.destructive(description: Text(_describeAudioToggleError(error))));
          }
        }
        if (!_isExpectedMediaAccessError(error)) {
          debugPrint('_enableAudio error $error');
        }
      }
    });
  }

  Future<void> _enableVideo({bool showErrors = false}) async {
    setState(() {
      _videoOn = true;
    });

    await _guardVideoProcessing(() async {
      final existingTrack = _video;
      if (mounted && existingTrack != null) {
        setState(() {
          _video = null;
        });
      }
      await existingTrack?.dispose();
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
        if (mounted) {
          setState(() {
            _videoOn = false;
            _video = null;
          });
          if (showErrors) {
            ShadToaster.maybeOf(context)?.show(ShadToast.destructive(description: Text(_describeVideoToggleError(error))));
          }
        }
        if (!_isExpectedMediaAccessError(error)) {
          debugPrint('_enableVideo error $error');
        }
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
        ? _videoPending
              ? "starting"
              : _video != null
              ? "on"
              : "off"
        : "disabled";
    final microphoneState = deviceManager.canTurnOnMicrophone
        ? _audioPending
              ? "starting"
              : _audio != null
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
    final deviceManager = DeviceManagerProvider.of(context);
    final videoOn = _video != null && deviceManager.canTurnOnCamera;
    final audioOn = _audio != null && deviceManager.canTurnOnMicrophone;
    final videoPending = _videoPending && deviceManager.canTurnOnCamera;
    final audioPending = _audioPending && deviceManager.canTurnOnMicrophone;

    final aspectRatio = 3 / 2;

    final cameraStatusText = videoPending
        ? "Starting camera"
        : videoOn
        ? "Turn off camera"
        : "Turn on camera";
    final audioStatusText = audioPending
        ? "Starting microphone"
        : audioOn
        ? "Turn off microphone"
        : "Turn on microphone";
    final cameraTooltipText = deviceManager.canTurnOnCamera ? cameraStatusText : "Camera disabled";
    final audioTooltipText = deviceManager.canTurnOnMicrophone ? audioStatusText : "Microphone disabled";

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final size = MediaQuery.sizeOf(context);
        final isLandscapePhone = _isLandscapePhoneViewport(context);
        final isMobile = size.width < 600;
        final useMobileLobbyLayout = isMobile || isLandscapePhone;
        final statusTextStyle = GoogleFonts.inter(fontSize: useMobileLobbyLayout ? 17.6 : 16, fontWeight: FontWeight.w600);
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.hasBoundedHeight ? constraints.maxHeight - (useMobileLobbyLayout ? 190 : 150) : double.infinity;

        // Cap the width to 800px - large monitors preview overwhelming
        double width = maxWidth > 800 ? 800 : maxWidth;
        double height = width / aspectRatio;

        if (height > maxHeight) {
          width = maxHeight * aspectRatio;
          height = maxHeight;
        }

        Widget buildDeviceSettingsButton({required bool showLabel}) {
          return ChangeDeviceButton(
            onChangeVideoInput: _selectVideoInput,
            onChangeAudioInput: _selectAudioInput,
            onChangeAudioOutput: _selectAudioOutput,
            selectedVideoInputDeviceId: () => _videoDeviceId,
            selectedAudioInputDeviceId: () => _audioDeviceId,
            selectedAudioOutputDeviceId: () => _audioOutputDeviceId ?? Hardware.instance.selectedAudioOutput?.deviceId,
            presentation: ChangeDeviceButtonPresentation.dialog,
            renderButton: (onPressed) {
              if (showLabel) {
                return ShadButton.outline(
                  onPressed: onPressed,
                  leading: const Icon(LucideIcons.settings),
                  child: const Text("Device settings"),
                );
              }

              return Tooltip(
                message: "Device settings",
                child: ShadIconButton.outline(onPressed: onPressed, icon: const Icon(LucideIcons.settings)),
              );
            },
          );
        }

        final previewControls = <Widget>[
          RoomToolbarButton(
            text: audioTooltipText,
            on: audioOn || audioPending,
            onColor: ShadTheme.of(context).colorScheme.foreground,
            onForeground: ShadTheme.of(context).colorScheme.background,
            offColor: ShadTheme.of(context).colorScheme.destructive,
            offForeground: Colors.white,
            loading: audioPending,
            onPressed: !audioPending
                ? () {
                    if (!deviceManager.canTurnOnMicrophone) {
                      _showUnavailableMicrophoneToast();
                      return;
                    }
                    audioOn ? _disableAudio() : _enableAudio(showErrors: true);
                  }
                : null,
            icon: (audioOn || audioPending) ? LucideIcons.mic : LucideIcons.micOff,
          ),
          RoomToolbarButton(
            text: cameraTooltipText,
            on: videoOn || videoPending,
            onColor: ShadTheme.of(context).colorScheme.foreground,
            onForeground: ShadTheme.of(context).colorScheme.background,
            offColor: ShadTheme.of(context).colorScheme.destructive,
            offForeground: Colors.white,
            loading: videoPending,
            onPressed: !videoPending
                ? () {
                    if (!deviceManager.canTurnOnCamera) {
                      _showUnavailableCameraToast();
                      return;
                    }
                    videoOn ? _disableVideo() : _enableVideo(showErrors: true);
                  }
                : null,
            icon: (videoOn || videoPending) ? LucideIcons.video : LucideIcons.videoOff,
          ),
        ];

        final previewSectionControls = <Widget>[
          ...previewControls,
          if (useMobileLobbyLayout && !isLandscapePhone) buildDeviceSettingsButton(showLabel: false),
        ];

        final previewSection = Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 20,
          children: [
            Container(
              child: _loaded ? Text(title, style: statusTextStyle, textAlign: TextAlign.center) : null,
            ),
            SizedBox(
              height: height,
              width: width,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  color: const Color(0xFF222222),
                  foregroundDecoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                  child: _video != null ? VideoTrackRenderer(_video!, fit: VideoViewFit.cover) : null,
                ),
              ),
            ),
            if (!isLandscapePhone)
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: previewSectionControls,
                ),
              ),
          ],
        );

        if (useMobileLobbyLayout) {
          Widget buildLandscapePhoneFooter() {
            return LayoutBuilder(
              builder: (context, constraints) {
                final compactActionButtons = constraints.maxWidth < 560;
                final actionButtonSpacing = compactActionButtons ? 6.0 : 8.0;
                final footerControls = [...previewControls, buildDeviceSettingsButton(showLabel: false)];
                final useIntrinsicActionButtonWidth = isLandscapePhone;

                Widget buildCancelButton() {
                  final button = ShadButton.outline(
                    padding: compactActionButtons ? const EdgeInsets.symmetric(horizontal: 12) : null,
                    onPressed: () {
                      widget.onCancel?.call();
                    },
                    child: const Text("Cancel"),
                  );

                  if (useIntrinsicActionButtonWidth) {
                    return button;
                  }

                  if (compactActionButtons) {
                    return Expanded(child: button);
                  }

                  return SizedBox(width: 120, child: button);
                }

                Widget buildJoinButton() {
                  final button = ShadButton.destructive(
                    padding: compactActionButtons ? const EdgeInsets.symmetric(horizontal: 12) : null,
                    onPressed: audioPending || videoPending
                        ? null
                        : () {
                            widget.onJoin?.call(videoOn, audioOn);
                          },
                    child: const Text("Meet Now"),
                  );

                  if (compactActionButtons) {
                    return Expanded(child: button);
                  }

                  return SizedBox(width: 120, child: button);
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: footerControls,
                    ),
                    if (widget.onCancel != null || widget.onJoin != null) SizedBox(width: compactActionButtons ? 8 : 12),
                    if (widget.onCancel != null || widget.onJoin != null)
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (widget.onCancel != null) buildCancelButton(),
                            if (widget.onCancel != null && widget.onJoin != null) SizedBox(width: actionButtonSpacing),
                            if (widget.onJoin != null) buildJoinButton(),
                          ],
                        ),
                      ),
                    if (widget.onCancel == null && widget.onJoin == null) const Spacer(),
                  ],
                );
              },
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: Center(child: previewSection)),
              Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom + 12),
                child: isLandscapePhone
                    ? buildLandscapePhoneFooter()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 12,
                        children: [
                          if (widget.onJoin != null)
                            ShadButton.destructive(
                              onPressed: audioPending || videoPending
                                  ? null
                                  : () {
                                      widget.onJoin?.call(videoOn, audioOn);
                                    },
                              child: const Text("Meet Now"),
                            ),
                          if (widget.onCancel != null)
                            ShadButton.outline(
                              onPressed: () {
                                widget.onCancel?.call();
                              },
                              child: const Text("Cancel"),
                            ),
                        ],
                      ),
              ),
            ],
          );
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Container(
              child: _loaded ? Text(title, style: statusTextStyle, textAlign: TextAlign.center) : null,
            ),
            SizedBox(
              height: height,
              width: width,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  color: const Color(0xFF222222),
                  foregroundDecoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                  child: _video != null ? VideoTrackRenderer(_video!, fit: VideoViewFit.cover) : null,
                ),
              ),
            ),
            SizedBox(
              width: width,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactActionButtons = constraints.maxWidth < 560;
                  final actionButtonSpacing = compactActionButtons ? 6.0 : 8.0;
                  final showDesktopDeviceSettingsLabel = !compactActionButtons;
                  final footerControls = [...previewControls, buildDeviceSettingsButton(showLabel: showDesktopDeviceSettingsLabel)];

                  Widget buildCancelButton() {
                    final button = ShadButton.outline(
                      padding: compactActionButtons ? const EdgeInsets.symmetric(horizontal: 12) : null,
                      onPressed: () {
                        widget.onCancel?.call();
                      },
                      child: const Text("Cancel"),
                    );

                    if (compactActionButtons) {
                      return Expanded(child: button);
                    }

                    return SizedBox(width: 120, child: button);
                  }

                  Widget buildJoinButton() {
                    final button = ShadButton.destructive(
                      padding: compactActionButtons ? const EdgeInsets.symmetric(horizontal: 12) : null,
                      onPressed: audioPending || videoPending
                          ? null
                          : () {
                              widget.onJoin?.call(videoOn, audioOn);
                            },
                      child: const Text("Meet Now"),
                    );

                    if (compactActionButtons) {
                      return Expanded(child: button);
                    }

                    return SizedBox(width: 120, child: button);
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.start,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: footerControls,
                      ),
                      if (widget.onCancel != null || widget.onJoin != null) SizedBox(width: compactActionButtons ? 8 : 12),
                      if (widget.onCancel != null || widget.onJoin != null)
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (widget.onCancel != null) buildCancelButton(),
                              if (widget.onCancel != null && widget.onJoin != null) SizedBox(width: actionButtonSpacing),
                              if (widget.onJoin != null) buildJoinButton(),
                            ],
                          ),
                        ),
                      if (widget.onCancel == null && widget.onJoin == null) const Spacer(),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
