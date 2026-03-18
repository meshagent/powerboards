import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChangeDeviceButton extends StatefulWidget {
  const ChangeDeviceButton({
    super.key,
    required this.onChangeVideoInput,
    required this.onChangeAudioInput,
    required this.onChangeAudioOutput,
    required this.renderButton,
    this.kind,
  });

  final String? kind;

  final Function(MediaDevice device) onChangeVideoInput;
  final Function(MediaDevice device) onChangeAudioInput;
  final Function(MediaDevice device) onChangeAudioOutput;
  final Widget Function(ShadContextMenuController controller) renderButton;

  @override
  ChangeDeviceButtonState createState() => ChangeDeviceButtonState();
}

class ChangeDeviceButtonState extends State<ChangeDeviceButton> {
  static const BoxConstraints _menuConstraints = BoxConstraints(minWidth: 220, maxWidth: 320);
  static const double _topLevelItemHeight = 52;

  bool _loaded = false;
  late SharedPreferences _preferences;
  late List<MediaDevice> _devices;
  StreamSubscription? _subscription;
  final ShadContextMenuController _controller = ShadContextMenuController();

  @override
  void initState() {
    super.initState();
    _load();

    _subscription = Hardware.instance.onDeviceChange.stream.listen((List<MediaDevice> devices) {
      _devices = _sanitizeDevices(devices);
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();

    super.dispose();
  }

  Future<void> _load() async {
    _preferences = await SharedPreferences.getInstance();
    _devices = await _getDevices();

    if (mounted) {
      setState(() {
        _loaded = true;
      });
    }
  }

  Future<List<MediaDevice>> _getDevices() async {
    final devices = await Hardware.instance.enumerateDevices();
    return _sanitizeDevices(devices);
  }

  List<MediaDevice> _sanitizeDevices(List<MediaDevice> devices) {
    return devices.where((d) => d.deviceId.isNotEmpty).toList();
  }

  Future<void> _loadDevices() async {
    _devices = await _getDevices();
    if (mounted) {
      setState(() {});
    }
  }

  void _updateDevice(String key, MediaDevice device, Function(MediaDevice) onChange) {
    onChange(device);
    _preferences.setString(key, device.deviceId);
    setState(() {});
  }

  void onChangeVideoInput(MediaDevice device) => _updateDevice("videoInput", device, widget.onChangeVideoInput);
  void onChangeAudioInput(MediaDevice device) => _updateDevice("audioInput", device, widget.onChangeAudioInput);
  void onChangeAudioOutput(MediaDevice device) => _updateDevice("audioOutput", device, widget.onChangeAudioOutput);

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return SizedBox(width: 40);
    }

    final videoInput = _preferences.getString("videoInput");
    final audioInput = _preferences.getString("audioInput");
    final audioOutput = _preferences.getString("audioOutput");

    final videoInputs = _devices.where((d) => d.kind == "videoinput").toList();
    final audioInputs = _devices.where((d) => d.kind == "audioinput").toList();
    final audioOutputs = _devices.where((d) => d.kind == "audiooutput").toList();

    final selectedVideoDevice = videoInputs.firstWhereOrNull((device) => device.deviceId == videoInput) ?? videoInputs.firstOrNull;
    final selectedAudioInputDevice = audioInputs.firstWhereOrNull((device) => device.deviceId == audioInput) ?? audioInputs.firstOrNull;
    final selectedAudioOutputDevice = audioOutputs.firstWhereOrNull((device) => device.deviceId == audioOutput) ?? audioOutputs.firstOrNull;

    return AdaptiveShadContextMenu(
      controller: _controller,
      boundaryContext: context,
      constraints: _menuConstraints,
      estimatedMenuWidth: _menuConstraints.maxWidth,
      estimatedMenuHeight: _estimatedTopLevelMenuHeight(
        includeCamera: widget.kind == null || widget.kind == "camera",
        includeMicrophone: widget.kind == null || widget.kind == "mic",
        includeSpeakers: (kIsWeb && widget.kind == null) || widget.kind == "mic",
      ),
      onHoverArea: (hovering) {
        if (hovering) {
          _loadDevices();
        }
      },
      items: [
        if (widget.kind == null || widget.kind == "camera")
          _buildDeviceMenuItem(
            context,
            label: "Camera",
            devices: videoInputs,
            selectedDevice: selectedVideoDevice,
            onChange: onChangeVideoInput,
            icon: LucideIcons.video,
            disabledLabel: "Camera disabled",
          ),
        if (widget.kind == null || widget.kind == "mic")
          _buildDeviceMenuItem(
            context,
            label: "Microphone",
            devices: audioInputs,
            selectedDevice: selectedAudioInputDevice,
            onChange: onChangeAudioInput,
            icon: LucideIcons.mic,
            disabledLabel: "Microphone disabled",
          ),
        if ((kIsWeb && widget.kind == null) || widget.kind == "mic")
          _buildDeviceMenuItem(
            context,
            label: "Speakers",
            devices: audioOutputs,
            selectedDevice: selectedAudioOutputDevice,
            onChange: onChangeAudioOutput,
            icon: Icons.volume_down,
            disabledLabel: "Speakers disabled",
          ),
      ],
      child: widget.renderButton(_controller),
    );
  }

  double _estimatedTopLevelMenuHeight({required bool includeCamera, required bool includeMicrophone, required bool includeSpeakers}) {
    final itemCount = [includeCamera, includeMicrophone, includeSpeakers].where((include) => include).length;
    return itemCount * _topLevelItemHeight + 8.0;
  }

  Widget _buildDeviceMenuItem(
    BuildContext context, {
    required String label,
    required List<MediaDevice> devices,
    required MediaDevice? selectedDevice,
    required Function(MediaDevice device) onChange,
    required IconData icon,
    required String disabledLabel,
  }) {
    final theme = ShadTheme.of(context);
    final selectedLabel = _deviceLabel(selectedDevice, label);
    final submenuItems = devices
        .map(
          (device) => ShadContextMenuItem(
            height: 40,
            onPressed: () => onChange(device),
            trailing: device.deviceId == selectedDevice?.deviceId ? const Icon(LucideIcons.check, size: 16) : null,
            child: Text(_deviceLabel(device, label), overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(growable: false);

    if (selectedDevice == null) {
      return ShadContextMenuItem(
        enabled: true,
        closeOnTap: false,
        height: _topLevelItemHeight,
        leading: Icon(icon, size: 18),
        child: Text(disabledLabel),
      );
    }

    return ShadContextMenuItem(
      height: _topLevelItemHeight,
      leading: Icon(icon, size: 18),
      items: submenuItems,
      constraints: _menuConstraints,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, overflow: TextOverflow.ellipsis),
          if (selectedLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(selectedLabel, style: theme.textTheme.muted.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
        ],
      ),
    );
  }

  String _deviceLabel(MediaDevice? device, String fallbackPrefix) {
    final trimmedLabel = device?.label.trim();
    if (trimmedLabel != null && trimmedLabel.isNotEmpty) {
      return trimmedLabel;
    }

    return 'Default $fallbackPrefix';
  }
}
