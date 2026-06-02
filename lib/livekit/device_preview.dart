import 'dart:core';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:meshagent_flutter_shadcn/theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:powerboards/livekit/change_device_button.dart';
import 'package:powerboards/livekit/device_manager.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_svg_icon.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_tokens.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_typography.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/powerboards_breakpoints.dart';

import 'room.dart';

const double _v1MeetLobbyHorizontalPaddingLeft = 30;
const double _v1MeetLobbyHorizontalPaddingRight = 28;
const double _v1MeetLobbyMinimumVerticalInset = 24;
const double _v1MeetPreviewCompactBreakpoint = 720;

class DevicePreview extends StatelessWidget {
  const DevicePreview({super.key, this.onJoin, this.onCancel, this.desktopV1Style = false});

  final void Function({
    required bool enableVideo,
    required bool enableAudio,
    required bool videoUnavailable,
    required bool audioUnavailable,
  })?
  onJoin;
  final VoidCallback? onCancel;
  final bool desktopV1Style;

  @override
  Widget build(BuildContext context) {
    return DeviceManager(
      child: _DeviceSettings(onJoin: onJoin, onCancel: onCancel, desktopV1Style: desktopV1Style),
    );
  }
}

class _DeviceSettings extends StatefulWidget {
  const _DeviceSettings({this.onJoin, this.onCancel, this.desktopV1Style = false});

  final void Function({
    required bool enableVideo,
    required bool enableAudio,
    required bool videoUnavailable,
    required bool audioUnavailable,
  })?
  onJoin;
  final VoidCallback? onCancel;
  final bool desktopV1Style;

  @override
  State createState() => _DeviceSettingsState();
}

class _DeviceSettingsState extends State<_DeviceSettings> {
  static const Duration _minimumLobbySwitchPendingDuration = Duration(milliseconds: 350);
  bool _loaded = false;
  bool _audioOn = true;
  bool _videoOn = true;
  bool _audioProcessing = false;
  bool _videoProcessing = false;
  bool _audioUnavailable = false;
  bool _videoUnavailable = false;
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
    return powerboardsIsLandscapePhoneViewport(context);
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
    await Future.wait<void>([_enableVideo(), _enableAudio()]);

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
            _audioUnavailable = false;
          });
        } else {
          await track.dispose();
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _audioOn = false;
            _audio = null;
            _audioUnavailable = true;
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
            _videoUnavailable = false;
          });
        } else {
          await track.dispose();
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _videoOn = false;
            _video = null;
            _videoUnavailable = true;
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
    final cameraAvailable = deviceManager.canTurnOnCamera && !_videoUnavailable;
    final microphoneAvailable = deviceManager.canTurnOnMicrophone && !_audioUnavailable;
    final cameraState = cameraAvailable
        ? _videoPending
              ? "starting"
              : _video != null
              ? "on"
              : "off"
        : "disabled";
    final microphoneState = microphoneAvailable
        ? _audioPending
              ? "starting"
              : _audio != null
              ? "on"
              : "off"
        : "disabled";

    if (cameraState == microphoneState) {
      return 'Camera and microphone are $cameraState';
    } else {
      return 'Camera is $cameraState and microphone is $microphoneState';
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceManager = DeviceManagerProvider.of(context);
    final cameraAvailable = deviceManager.canTurnOnCamera && !_videoUnavailable;
    final microphoneAvailable = deviceManager.canTurnOnMicrophone && !_audioUnavailable;
    final videoOn = _video != null && cameraAvailable;
    final audioOn = _audio != null && microphoneAvailable;
    final videoPending = _videoPending && cameraAvailable;
    final audioPending = _audioPending && microphoneAvailable;

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
    final cameraTooltipText = cameraAvailable ? cameraStatusText : "Camera disabled";
    final audioTooltipText = microphoneAvailable ? audioStatusText : "Microphone disabled";

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final size = MediaQuery.sizeOf(context);
        final isLandscapePhone = _isLandscapePhoneViewport(context);
        final isMobile = size.width < 600;
        final useMobileLobbyLayout = isMobile || isLandscapePhone;
        final statusTextStyle = powerboardsInterTextStyle(fontSize: useMobileLobbyLayout ? 17.6 : 16, fontWeight: FontWeight.w600);
        final maxWidth = constraints.maxWidth;
        final contentHorizontalInset = switch (maxWidth) {
          >= 850 => 0.0,
          >= 520 => 48.0,
          _ => 24.0,
        };
        final contentMaxWidth = math.max(0.0, maxWidth - (contentHorizontalInset * 2));
        final maxHeight = constraints.hasBoundedHeight ? constraints.maxHeight - (useMobileLobbyLayout ? 190 : 150) : double.infinity;

        // Cap the width to 800px - large monitors preview overwhelming
        double width = contentMaxWidth > 800 ? 800 : contentMaxWidth;
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
            cameraUnavailable: _videoUnavailable,
            microphoneUnavailable: _audioUnavailable,
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
                child: ShadIconButton.outline(
                  onPressed: onPressed,
                  decoration: powerboardsAdaptiveMeetingControlButtonDecoration(context),
                  icon: const Icon(LucideIcons.settings),
                ),
              );
            },
          );
        }

        Widget buildV1DeviceSettingsButton() {
          return ChangeDeviceButton(
            onChangeVideoInput: _selectVideoInput,
            onChangeAudioInput: _selectAudioInput,
            onChangeAudioOutput: _selectAudioOutput,
            selectedVideoInputDeviceId: () => _videoDeviceId,
            selectedAudioInputDeviceId: () => _audioDeviceId,
            selectedAudioOutputDeviceId: () => _audioOutputDeviceId ?? Hardware.instance.selectedAudioOutput?.deviceId,
            cameraUnavailable: _videoUnavailable,
            microphoneUnavailable: _audioUnavailable,
            presentation: ChangeDeviceButtonPresentation.dialog,
            desktopV1Style: true,
            renderButton: (onPressed) => _V1MeetDeviceSettingsButton(onPressed: onPressed),
          );
        }

        final availableToggleColor = ShadTheme.of(context).colorScheme.greenCustom;
        final availableToggleForeground = ShadTheme.of(context).colorScheme.greenCustomForeground;
        final unavailableToggleColor = ShadTheme.of(context).colorScheme.destructive;
        final unavailableToggleForeground = ShadTheme.of(context).colorScheme.destructiveForeground;
        final meetNowPending = audioPending || videoPending;
        final meetNowButtonColor = microphoneAvailable ? availableToggleColor : unavailableToggleColor;
        final meetNowButtonForeground = microphoneAvailable ? availableToggleForeground : unavailableToggleForeground;

        Widget buildMeetNowButtonChild() {
          if (!meetNowPending) {
            return const Text("Meet now");
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(meetNowButtonForeground)),
              ),
              const SizedBox(width: 6),
              const Text("Starting"),
            ],
          );
        }

        final previewControls = <Widget>[
          RoomToolbarButton(
            text: audioTooltipText,
            on: audioOn || audioPending,
            onColor: availableToggleColor,
            onForeground: availableToggleForeground,
            offColor: microphoneAvailable ? availableToggleColor : unavailableToggleColor,
            offForeground: microphoneAvailable ? availableToggleForeground : unavailableToggleForeground,
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
            onColor: availableToggleColor,
            onForeground: availableToggleForeground,
            offColor: cameraAvailable ? availableToggleColor : unavailableToggleColor,
            offForeground: cameraAvailable ? availableToggleForeground : unavailableToggleForeground,
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

        final v1PreviewControls = <Widget>[
          buildV1DeviceSettingsButton(),
          _V1MeetControlButton(
            label: audioTooltipText,
            iconAssetName: (audioOn || audioPending) ? 'mic' : 'mic-off',
            available: microphoneAvailable,
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
          ),
          _V1MeetControlButton(
            label: cameraTooltipText,
            iconAssetName: (videoOn || videoPending) ? 'video' : 'video-off',
            available: cameraAvailable,
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
          ),
          if (widget.onJoin != null)
            _V1MeetNowButton(
              loading: meetNowPending,
              available: microphoneAvailable,
              onPressed: meetNowPending
                  ? null
                  : () {
                      widget.onJoin?.call(
                        enableVideo: videoOn,
                        enableAudio: audioOn,
                        videoUnavailable: _videoUnavailable || !cameraAvailable,
                        audioUnavailable: _audioUnavailable || !microphoneAvailable,
                      );
                    },
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

        Widget buildDesktopV1PreviewSection(BoxConstraints previewConstraints, {required bool compact}) {
          final availableWidth = previewConstraints.maxWidth;
          final availableHeight = previewConstraints.hasBoundedHeight ? previewConstraints.maxHeight : double.infinity;
          final inset = compact ? 32.0 : 40.0;
          final preview = Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: PbColors.meetCameraSurface,
              borderRadius: BorderRadius.circular(PbRadii.large),
              border: Border.all(color: PbColors.borderSoft),
              boxShadow: [PbShadows.softFromTextMuted(0.10)],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_video != null) VideoTrackRenderer(_video!, fit: VideoViewFit.cover),
                if (_loaded)
                  Positioned(
                    top: inset,
                    left: inset,
                    right: inset,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: PowerboardsTypography.large.copyWith(color: PbColors.textInverse),
                    ),
                  ),
                Positioned(
                  left: inset,
                  right: inset,
                  bottom: inset,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: v1PreviewControls,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          if (compact) {
            return SizedBox(
              width: availableWidth.isFinite ? math.max(0.0, availableWidth) : null,
              height: availableHeight.isFinite ? math.max(0.0, availableHeight) : null,
              child: preview,
            );
          }

          final fluidWidth = availableHeight.isFinite
              ? math.min(availableWidth * 0.8, availableHeight * aspectRatio)
              : availableWidth * 0.8;
          var previewWidth = math.min(availableWidth, fluidWidth.clamp(800.0, 1120.0));
          var previewHeight = previewWidth / aspectRatio;

          if (availableHeight.isFinite && previewHeight > availableHeight) {
            previewHeight = availableHeight;
            previewWidth = previewHeight * aspectRatio;
          }

          return Center(
            child: SizedBox(width: math.max(0.0, previewWidth), height: math.max(0.0, previewHeight), child: preview),
          );
        }

        if (widget.desktopV1Style && !useMobileLobbyLayout) {
          final compact = constraints.maxWidth <= _v1MeetPreviewCompactBreakpoint;
          final topPadding = compact ? 0.0 : _v1MeetLobbyMinimumVerticalInset;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              _v1MeetLobbyHorizontalPaddingLeft,
              topPadding,
              _v1MeetLobbyHorizontalPaddingRight,
              _v1MeetLobbyMinimumVerticalInset,
            ),
            child: LayoutBuilder(
              builder: (context, paddedConstraints) {
                final previewStack = buildDesktopV1PreviewSection(paddedConstraints, compact: compact);

                return compact ? Align(alignment: Alignment.topCenter, child: previewStack) : Center(child: previewStack);
              },
            ),
          );
        }

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
                    height: powerboardsFooterActionButtonHeight,
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
                  final button = ShadButton(
                    height: powerboardsFooterActionButtonHeight,
                    padding: compactActionButtons ? const EdgeInsets.symmetric(horizontal: 12) : null,
                    backgroundColor: meetNowButtonColor,
                    hoverBackgroundColor: meetNowButtonColor,
                    pressedBackgroundColor: meetNowButtonColor,
                    foregroundColor: meetNowButtonForeground,
                    hoverForegroundColor: meetNowButtonForeground,
                    pressedForegroundColor: meetNowButtonForeground,
                    onPressed: meetNowPending
                        ? null
                        : () {
                            widget.onJoin?.call(
                              enableVideo: videoOn,
                              enableAudio: audioOn,
                              videoUnavailable: _videoUnavailable || !cameraAvailable,
                              audioUnavailable: _audioUnavailable || !microphoneAvailable,
                            );
                          },
                    child: buildMeetNowButtonChild(),
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

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: contentHorizontalInset),
            child: Column(
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
                              ShadButton(
                                height: powerboardsFooterActionButtonHeight,
                                backgroundColor: meetNowButtonColor,
                                hoverBackgroundColor: meetNowButtonColor,
                                pressedBackgroundColor: meetNowButtonColor,
                                foregroundColor: meetNowButtonForeground,
                                hoverForegroundColor: meetNowButtonForeground,
                                pressedForegroundColor: meetNowButtonForeground,
                                onPressed: meetNowPending
                                    ? null
                                    : () {
                                        widget.onJoin?.call(
                                          enableVideo: videoOn,
                                          enableAudio: audioOn,
                                          videoUnavailable: _videoUnavailable || !cameraAvailable,
                                          audioUnavailable: _audioUnavailable || !microphoneAvailable,
                                        );
                                      },
                                child: buildMeetNowButtonChild(),
                              ),
                            if (widget.onCancel != null)
                              ShadButton.outline(
                                height: powerboardsFooterActionButtonHeight,
                                onPressed: () {
                                  widget.onCancel?.call();
                                },
                                child: const Text("Cancel"),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: contentHorizontalInset),
          child: Column(
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
                        height: powerboardsFooterActionButtonHeight,
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
                      final button = ShadButton(
                        padding: compactActionButtons ? const EdgeInsets.symmetric(horizontal: 12) : null,
                        backgroundColor: meetNowButtonColor,
                        hoverBackgroundColor: meetNowButtonColor,
                        pressedBackgroundColor: meetNowButtonColor,
                        foregroundColor: meetNowButtonForeground,
                        hoverForegroundColor: meetNowButtonForeground,
                        pressedForegroundColor: meetNowButtonForeground,
                        onPressed: meetNowPending
                            ? null
                            : () {
                                widget.onJoin?.call(
                                  enableVideo: videoOn,
                                  enableAudio: audioOn,
                                  videoUnavailable: _videoUnavailable || !cameraAvailable,
                                  audioUnavailable: _audioUnavailable || !microphoneAvailable,
                                );
                              },
                        child: buildMeetNowButtonChild(),
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
          ),
        );
      },
    );
  }
}

class _V1MeetDeviceSettingsButton extends StatefulWidget {
  const _V1MeetDeviceSettingsButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<_V1MeetDeviceSettingsButton> createState() => _V1MeetDeviceSettingsButtonState();
}

class _V1MeetDeviceSettingsButtonState extends State<_V1MeetDeviceSettingsButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return _V1MeetButtonFrame(
      label: 'Device settings',
      width: 44,
      backgroundColor: PbColors.surfacePanel,
      foregroundColor: PbColors.textPrimary,
      borderColor: PbColors.borderSoft,
      hovered: _hovered,
      pressed: _pressed,
      onHoverChanged: (hovered) => setState(() => _hovered = hovered),
      onPressedChanged: (pressed) => setState(() => _pressed = pressed),
      onPressed: widget.onPressed,
      child: const PbSvgIcon(assetName: 'settings', size: 22, color: PbColors.textPrimary),
    );
  }
}

class _V1MeetControlButton extends StatefulWidget {
  const _V1MeetControlButton({
    required this.label,
    required this.iconAssetName,
    required this.available,
    required this.loading,
    this.onPressed,
  });

  final String label;
  final String iconAssetName;
  final bool available;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  State<_V1MeetControlButton> createState() => _V1MeetControlButtonState();
}

class _V1MeetControlButtonState extends State<_V1MeetControlButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.available ? PbColors.meetControlAvailable : PbColors.meetControlUnavailable;

    return _V1MeetButtonFrame(
      label: widget.label,
      width: 44,
      backgroundColor: backgroundColor,
      foregroundColor: PbColors.textInverse,
      borderColor: backgroundColor,
      hovered: _hovered,
      pressed: _pressed,
      waiting: widget.loading,
      onHoverChanged: (hovered) => setState(() => _hovered = hovered),
      onPressedChanged: (pressed) => setState(() => _pressed = pressed),
      onPressed: widget.loading ? null : widget.onPressed,
      child: widget.loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(PbColors.textInverse)),
            )
          : PbSvgIcon(assetName: widget.iconAssetName, size: 22, color: PbColors.textInverse),
    );
  }
}

class _V1MeetNowButton extends StatefulWidget {
  const _V1MeetNowButton({required this.available, required this.loading, this.onPressed});

  final bool available;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  State<_V1MeetNowButton> createState() => _V1MeetNowButtonState();
}

class _V1MeetNowButtonState extends State<_V1MeetNowButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.available ? PbColors.meetControlAvailable : PbColors.meetControlUnavailable;

    return _V1MeetButtonFrame(
      label: widget.loading ? 'Starting' : 'Meet now',
      width: 196,
      backgroundColor: backgroundColor,
      foregroundColor: PbColors.textInverse,
      borderColor: backgroundColor,
      hovered: _hovered,
      pressed: _pressed,
      waiting: widget.loading,
      onHoverChanged: (hovered) => setState(() => _hovered = hovered),
      onPressedChanged: (pressed) => setState(() => _pressed = pressed),
      onPressed: widget.loading ? null : widget.onPressed,
      child: widget.loading
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(PbColors.textInverse)),
                ),
                SizedBox(width: 8),
                Text('Starting'),
              ],
            )
          : Text('Meet now', style: PowerboardsTypography.button.copyWith(color: PbColors.textInverse)),
    );
  }
}

class _V1MeetButtonFrame extends StatelessWidget {
  const _V1MeetButtonFrame({
    required this.label,
    required this.width,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.hovered,
    required this.pressed,
    required this.onHoverChanged,
    required this.onPressedChanged,
    required this.child,
    this.waiting = false,
    this.onPressed,
  });

  final String label;
  final double width;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final bool hovered;
  final bool pressed;
  final bool waiting;
  final ValueChanged<bool> onHoverChanged;
  final ValueChanged<bool> onPressedChanged;
  final VoidCallback? onPressed;
  final Widget child;

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final lifted = hovered && !pressed && _enabled;
    final effectiveBackground = hovered && _enabled ? Color.lerp(backgroundColor, PbColors.customBrandInk, 0.06)! : backgroundColor;
    final effectiveBorder = hovered && _enabled ? Color.lerp(borderColor, PbColors.customBrandInk, 0.12)! : borderColor;

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: MouseRegion(
          cursor: waiting
              ? SystemMouseCursors.wait
              : _enabled
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          onEnter: _enabled ? (_) => onHoverChanged(true) : null,
          onExit: (_) {
            onHoverChanged(false);
            onPressedChanged(false);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _enabled ? (_) => onPressedChanged(true) : null,
            onTapUp: _enabled
                ? (_) {
                    onPressedChanged(false);
                    onPressed?.call();
                  }
                : null,
            onTapCancel: _enabled ? () => onPressedChanged(false) : null,
            child: Transform.translate(
              offset: Offset(0, lifted ? -1 : 0),
              child: Opacity(
                opacity: _enabled || waiting ? 1 : 0.46,
                child: AnimatedContainer(
                  duration: PbMotion.state,
                  curve: Curves.easeOut,
                  width: width,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: effectiveBackground,
                    borderRadius: BorderRadius.circular(PbRadii.small),
                    border: Border.all(color: effectiveBorder),
                    boxShadow: pressed
                        ? PbShadows.statePressedInset
                        : lifted
                        ? PbShadows.stateHover
                        : null,
                  ),
                  child: DefaultTextStyle(
                    style: PowerboardsTypography.button.copyWith(color: foregroundColor),
                    child: IconTheme(
                      data: IconThemeData(color: foregroundColor),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
