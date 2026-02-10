import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:livekit_client/livekit_client.dart';
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
  final Function(MenuController controller) renderButton;

  @override
  ChangeDeviceButtonState createState() => ChangeDeviceButtonState();
}

class ChangeDeviceButtonState extends State<ChangeDeviceButton> {
  bool _loaded = false;
  late SharedPreferences _preferences;
  late List<MediaDevice> _devices;
  StreamSubscription? _subscription;

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

    MenuStyle menuStyle = MenuStyle(
      padding: WidgetStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.symmetric(vertical: 15)),
      shape: WidgetStateProperty.all<OutlinedBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
      backgroundColor: WidgetStateProperty.all<Color>(ShadTheme.of(context).colorScheme.background),
    );

    return MenuAnchor(
      builder: (BuildContext context, MenuController controller, Widget? child) {
        return widget.renderButton(controller);
      },
      style: menuStyle,
      onOpen: _loadDevices,
      menuChildren: [
        if (widget.kind == null || widget.kind == "camera")
          DevicesMenu(
            label: "Camera",
            devices: videoInputs,
            selectedDevice: selectedVideoDevice,
            onChange: onChangeVideoInput,
            icon: LucideIcons.video,
          ),
        if (widget.kind == null || widget.kind == "mic")
          DevicesMenu(
            label: "Microphone",
            devices: audioInputs,
            selectedDevice: selectedAudioInputDevice,
            onChange: onChangeAudioInput,
            icon: LucideIcons.mic,
          ),
        if (kIsWeb && widget.kind == null || widget.kind == "mic")
          DevicesMenu(
            label: "Speakers",
            devices: audioOutputs,
            selectedDevice: selectedAudioOutputDevice,
            onChange: onChangeAudioOutput,
            icon: Icons.volume_down,
          ),
      ],
    );
  }
}

class DevicesMenu extends StatelessWidget {
  const DevicesMenu({
    super.key,
    required this.devices,
    required this.selectedDevice,
    required this.onChange,
    required this.icon,
    required this.label,
  });

  final List<MediaDevice> devices;
  final MediaDevice? selectedDevice;
  final Function(MediaDevice device) onChange;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    MenuStyle menuStyle = MenuStyle(
      padding: WidgetStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.symmetric(vertical: 15)),
      shape: WidgetStateProperty.all<OutlinedBorder>(const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
      backgroundColor: WidgetStateProperty.all<Color>(ShadTheme.of(context).colorScheme.background),
    );

    ButtonStyle submenuButtonStyle = ButtonStyle(
      iconColor: WidgetStateProperty.all<Color>(ShadTheme.of(context).colorScheme.foreground),
      padding: WidgetStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.symmetric(vertical: 15, horizontal: 20)),
      textStyle: WidgetStateProperty.all<TextStyle>(TextStyle(color: ShadTheme.of(context).colorScheme.foreground)),
    );

    TextStyle titleTextStyle = ShadTheme.of(context).textTheme.small.copyWith(fontWeight: FontWeight.w500, height: 2.0);

    TextStyle menuTextStyle = ShadTheme.of(context).textTheme.small;

    final selectedColor = ShadTheme.of(context).colorScheme.accentForeground;
    final disabledColor = ShadTheme.of(context).colorScheme.mutedForeground;

    final disabledTextStyle = ShadTheme.of(context).textTheme.muted;

    return selectedDevice != null
        ? SubmenuButton(
            style: submenuButtonStyle,
            leadingIcon: Icon(icon),
            menuStyle: menuStyle,
            menuChildren: devices.map((device) {
              final isSelected = device.deviceId == selectedDevice!.deviceId;
              return MenuItemButton(
                style: submenuButtonStyle,
                trailingIcon: isSelected ? Icon(Icons.check, color: isSelected ? selectedColor : null, size: 14) : null,
                onPressed: () => onChange(device),
                child: Text(
                  device.label,
                  style: menuTextStyle.copyWith(color: isSelected ? selectedColor : ShadTheme.of(context).colorScheme.foreground),
                ),
              );
            }).toList(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: titleTextStyle),
                Text(selectedDevice!.label, style: menuTextStyle),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: disabledColor),
                const SizedBox(width: 10),
                Text("$label disabled", style: disabledTextStyle),
              ],
            ),
          );
  }
}
