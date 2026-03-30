import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:powerboards/ui/powerboards_menu_row.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum ChangeDeviceButtonPresentation { contextMenu, dialog }

class ChangeDeviceButton extends StatefulWidget {
  const ChangeDeviceButton({
    super.key,
    required this.onChangeVideoInput,
    required this.onChangeAudioInput,
    required this.onChangeAudioOutput,
    required this.renderButton,
    this.kind,
    this.presentation = ChangeDeviceButtonPresentation.contextMenu,
  });

  final String? kind;

  final Function(MediaDevice device) onChangeVideoInput;
  final Function(MediaDevice device) onChangeAudioInput;
  final Function(MediaDevice device) onChangeAudioOutput;
  final Widget Function(VoidCallback onPressed) renderButton;
  final ChangeDeviceButtonPresentation presentation;

  @override
  ChangeDeviceButtonState createState() => ChangeDeviceButtonState();
}

class ChangeDeviceButtonState extends State<ChangeDeviceButton> {
  static const BoxConstraints _desktopDialogConstraints = BoxConstraints(maxWidth: 540);
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

  Future<void> _showDialog() async {
    await _loadDevices();
    if (!mounted) {
      return;
    }

    await showShadDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _ChangeDeviceDialog(
          boundaryContext: dialogContext,
          kind: widget.kind,
          preferences: _preferences,
          initialDevices: List<MediaDevice>.of(_devices),
          onChangeVideoInput: onChangeVideoInput,
          onChangeAudioInput: onChangeAudioInput,
          onChangeAudioOutput: onChangeAudioOutput,
          dialogConstraints: _desktopDialogConstraints,
        );
      },
    );
  }

  void _handlePressed() {
    switch (widget.presentation) {
      case ChangeDeviceButtonPresentation.contextMenu:
        if (_controller.isOpen) {
          _controller.hide();
        } else {
          _loadDevices();
          _controller.show();
        }
      case ChangeDeviceButtonPresentation.dialog:
        unawaited(_showDialog());
    }
  }

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
      child: widget.renderButton(_handlePressed),
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

class _ChangeDeviceDialog extends StatefulWidget {
  const _ChangeDeviceDialog({
    required this.boundaryContext,
    required this.kind,
    required this.preferences,
    required this.initialDevices,
    required this.onChangeVideoInput,
    required this.onChangeAudioInput,
    required this.onChangeAudioOutput,
    required this.dialogConstraints,
  });

  final BuildContext boundaryContext;
  final String? kind;
  final SharedPreferences preferences;
  final List<MediaDevice> initialDevices;
  final ValueChanged<MediaDevice> onChangeVideoInput;
  final ValueChanged<MediaDevice> onChangeAudioInput;
  final ValueChanged<MediaDevice> onChangeAudioOutput;
  final BoxConstraints dialogConstraints;

  @override
  State<_ChangeDeviceDialog> createState() => _ChangeDeviceDialogState();
}

class _ChangeDeviceDialogState extends State<_ChangeDeviceDialog> {
  late List<MediaDevice> _devices = widget.initialDevices;
  StreamSubscription<List<MediaDevice>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = Hardware.instance.onDeviceChange.stream.listen((devices) {
      if (!mounted) {
        return;
      }

      setState(() {
        _devices = _sanitizeDevices(devices);
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  List<MediaDevice> _sanitizeDevices(List<MediaDevice> devices) {
    return devices.where((device) => device.deviceId.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final videoInput = widget.preferences.getString("videoInput");
    final audioInput = widget.preferences.getString("audioInput");
    final audioOutput = widget.preferences.getString("audioOutput");

    final videoInputs = _devices.where((device) => device.kind == "videoinput").toList();
    final audioInputs = _devices.where((device) => device.kind == "audioinput").toList();
    final audioOutputs = _devices.where((device) => device.kind == "audiooutput").toList();

    final selectedVideoDevice = videoInputs.firstWhereOrNull((device) => device.deviceId == videoInput) ?? videoInputs.firstOrNull;
    final selectedAudioInputDevice = audioInputs.firstWhereOrNull((device) => device.deviceId == audioInput) ?? audioInputs.firstOrNull;
    final selectedAudioOutputDevice = audioOutputs.firstWhereOrNull((device) => device.deviceId == audioOutput) ?? audioOutputs.firstOrNull;

    Widget rowSeparator() => Divider(height: 1, color: ShadTheme.of(context).colorScheme.border);

    return PowerboardsShadDialog.listPicker(
      title: const Text("Device settings"),
      description: const Text("Choose your camera, microphone, and speakers."),
      constraints: widget.dialogConstraints,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.kind == null || widget.kind == "camera") ...[
            _DeviceSettingsRow(
              boundaryContext: widget.boundaryContext,
              label: "Camera",
              devices: videoInputs,
              selectedDevice: selectedVideoDevice,
              onChange: (device) {
                widget.onChangeVideoInput(device);
                setState(() {});
              },
              icon: LucideIcons.video,
              disabledLabel: "Camera disabled",
            ),
            if (widget.kind == null || widget.kind == "mic") rowSeparator(),
          ],
          if (widget.kind == null || widget.kind == "mic") ...[
            _DeviceSettingsRow(
              boundaryContext: widget.boundaryContext,
              label: "Microphone",
              devices: audioInputs,
              selectedDevice: selectedAudioInputDevice,
              onChange: (device) {
                widget.onChangeAudioInput(device);
                setState(() {});
              },
              icon: LucideIcons.mic,
              disabledLabel: "Microphone disabled",
            ),
            if ((kIsWeb && widget.kind == null) || widget.kind == "mic") rowSeparator(),
          ],
          if ((kIsWeb && widget.kind == null) || widget.kind == "mic")
            _DeviceSettingsRow(
              boundaryContext: widget.boundaryContext,
              label: "Speakers",
              devices: audioOutputs,
              selectedDevice: selectedAudioOutputDevice,
              onChange: (device) {
                widget.onChangeAudioOutput(device);
                setState(() {});
              },
              icon: Icons.volume_down,
              disabledLabel: "Speakers disabled",
            ),
        ],
      ),
    );
  }
}

class _DeviceSettingsRow extends StatefulWidget {
  const _DeviceSettingsRow({
    required this.boundaryContext,
    required this.label,
    required this.devices,
    required this.selectedDevice,
    required this.onChange,
    required this.icon,
    required this.disabledLabel,
  });

  final BuildContext boundaryContext;
  final String label;
  final List<MediaDevice> devices;
  final MediaDevice? selectedDevice;
  final ValueChanged<MediaDevice> onChange;
  final IconData icon;
  final String disabledLabel;

  @override
  State<_DeviceSettingsRow> createState() => _DeviceSettingsRowState();
}

class _DeviceSettingsRowState extends State<_DeviceSettingsRow> {
  static const BoxConstraints _menuConstraints = BoxConstraints(minWidth: 260, maxWidth: 420);
  static const double _rowIconSize = 20;
  final ShadContextMenuController _controller = ShadContextMenuController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _deviceLabel(MediaDevice? device, String fallbackPrefix) {
    final trimmedLabel = device?.label.trim();
    if (trimmedLabel != null && trimmedLabel.isNotEmpty) {
      return trimmedLabel;
    }

    return "Default $fallbackPrefix";
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = _deviceLabel(widget.selectedDevice, widget.label);
    final hasOptions = widget.selectedDevice != null && widget.devices.isNotEmpty;

    return AdaptiveShadContextMenu(
      controller: _controller,
      boundaryContext: widget.boundaryContext,
      constraints: _menuConstraints,
      estimatedMenuWidth: _menuConstraints.maxWidth,
      estimatedMenuHeight: widget.devices.length * 44 + 8,
      horizontalPosition: ShadMenuHorizontalPosition.right,
      items: [
        for (final device in widget.devices)
          ShadContextMenuItem(
            height: 44,
            onPressed: () => widget.onChange(device),
            trailing: device.deviceId == widget.selectedDevice?.deviceId ? const Icon(LucideIcons.check, size: 18) : null,
            child: Text(_deviceLabel(device, widget.label), overflow: TextOverflow.ellipsis),
          ),
      ],
      child: InkWell(
        onTap: hasOptions
            ? () {
                if (_controller.isOpen) {
                  _controller.hide();
                } else {
                  _controller.show();
                }
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: PowerboardsMenuRow(
          title: widget.selectedDevice == null ? widget.disabledLabel : widget.label,
          description: widget.selectedDevice == null ? null : selectedLabel,
          leading: Icon(widget.icon, size: _rowIconSize, color: shadForeground),
          trailing: hasOptions ? Icon(LucideIcons.chevronsUpDown, size: 21, color: shadSecondaryForeground) : null,
        ),
      ),
    );
  }
}
