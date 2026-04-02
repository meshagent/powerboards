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

const String _defaultDeviceLabelPrefix = 'Default - ';
const String _builtInDeviceLabelSuffix = ' (Built-in)';
const String _disabledDeviceDescription = 'Check your device settings';
const List<String> _builtInDeviceLabelPrefixes = [
  'macbook ',
  'built-in ',
  'internal ',
];

bool _isDefaultAliasDevice(MediaDevice device) {
  return device.deviceId == 'default' ||
      device.label.trim().startsWith(_defaultDeviceLabelPrefix);
}

String _normalizedDeviceLabel(String label) {
  var trimmedLabel = label.trim();
  if (trimmedLabel.startsWith(_defaultDeviceLabelPrefix)) {
    trimmedLabel = trimmedLabel
        .substring(_defaultDeviceLabelPrefix.length)
        .trim();
  }

  if (_shouldStripBuiltInSuffix(trimmedLabel)) {
    return trimmedLabel
        .substring(0, trimmedLabel.length - _builtInDeviceLabelSuffix.length)
        .trim();
  }

  return trimmedLabel;
}

bool _shouldStripBuiltInSuffix(String label) {
  if (!label.endsWith(_builtInDeviceLabelSuffix)) {
    return false;
  }

  final normalizedLabel = label.toLowerCase();
  return !_builtInDeviceLabelPrefixes.any(
    (prefix) => normalizedLabel.startsWith(prefix),
  );
}

String _deviceLabel(MediaDevice? device, String fallbackPrefix) {
  final trimmedLabel = device?.label.trim();
  if (trimmedLabel != null && trimmedLabel.isNotEmpty) {
    return _normalizedDeviceLabel(trimmedLabel);
  }

  return 'Default $fallbackPrefix';
}

MediaDevice? _matchingPhysicalDevice(
  MediaDevice device,
  List<MediaDevice> devices,
) {
  final normalizedLabel = _normalizedDeviceLabel(device.label);
  final groupId = device.groupId?.trim();

  return devices.firstWhereOrNull((candidate) {
    if (candidate.kind != device.kind ||
        candidate.deviceId == device.deviceId ||
        _isDefaultAliasDevice(candidate)) {
      return false;
    }

    final candidateGroupId = candidate.groupId?.trim();
    if (groupId != null && groupId.isNotEmpty && candidateGroupId == groupId) {
      return true;
    }

    return _normalizedDeviceLabel(candidate.label) == normalizedLabel;
  });
}

List<MediaDevice> _menuDevices(List<MediaDevice> devices) {
  return devices
      .where((device) {
        if (!_isDefaultAliasDevice(device)) {
          return true;
        }

        return _matchingPhysicalDevice(device, devices) == null;
      })
      .toList(growable: false);
}

MediaDevice? _selectedMenuDevice(
  List<MediaDevice> devices,
  String? selectedDeviceId,
) {
  final visibleDevices = _menuDevices(devices);
  if (visibleDevices.isEmpty) {
    return null;
  }

  if (selectedDeviceId == null || selectedDeviceId.isEmpty) {
    return visibleDevices.first;
  }

  final exactDevice = devices.firstWhereOrNull(
    (device) => device.deviceId == selectedDeviceId,
  );
  if (exactDevice == null) {
    return visibleDevices.first;
  }

  return _matchingPhysicalDevice(exactDevice, visibleDevices) ??
      visibleDevices.firstWhereOrNull(
        (device) => device.deviceId == exactDevice.deviceId,
      ) ??
      visibleDevices.first;
}

String _describeDeviceSwitchError(String label, Object error) {
  final message = '$error';
  if (message.contains('NotAllowedError')) {
    return '$label access was blocked by the browser or system.';
  }
  if (message.contains('NotFoundError')) {
    return 'The selected ${label.toLowerCase()} was not found.';
  }
  return 'Unable to switch ${label.toLowerCase()}: $message';
}

class ChangeDeviceButton extends StatefulWidget {
  const ChangeDeviceButton({
    super.key,
    required this.onChangeVideoInput,
    required this.onChangeAudioInput,
    required this.onChangeAudioOutput,
    required this.renderButton,
    this.kind,
    this.presentation = ChangeDeviceButtonPresentation.contextMenu,
    this.selectedVideoInputDeviceId,
    this.selectedAudioInputDeviceId,
    this.selectedAudioOutputDeviceId,
  });

  final String? kind;

  final Future<void> Function(MediaDevice device) onChangeVideoInput;
  final Future<void> Function(MediaDevice device) onChangeAudioInput;
  final Future<void> Function(MediaDevice device) onChangeAudioOutput;
  final Widget Function(VoidCallback onPressed) renderButton;
  final ChangeDeviceButtonPresentation presentation;
  final String? Function()? selectedVideoInputDeviceId;
  final String? Function()? selectedAudioInputDeviceId;
  final String? Function()? selectedAudioOutputDeviceId;

  @override
  ChangeDeviceButtonState createState() => ChangeDeviceButtonState();
}

class ChangeDeviceButtonState extends State<ChangeDeviceButton> {
  static const BoxConstraints _desktopDialogConstraints = BoxConstraints(
    maxWidth: 540,
  );
  static const BoxConstraints _menuConstraints = BoxConstraints(
    minWidth: 220,
    maxWidth: 320,
  );
  static const double _topLevelItemHeight = 52;

  bool _loaded = false;
  late SharedPreferences _preferences;
  late List<MediaDevice> _devices;
  StreamSubscription? _subscription;
  final ShadContextMenuController _controller = ShadContextMenuController();
  bool _syncingUnavailableSelections = false;

  @override
  void initState() {
    super.initState();
    _load();

    _subscription = Hardware.instance.onDeviceChange.stream.listen((
      List<MediaDevice> devices,
    ) {
      _devices = _sanitizeDevices(devices);
      if (mounted) {
        setState(() {});
      }
      unawaited(_syncUnavailableSelections());
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

    await _syncUnavailableSelections();
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
    await _syncUnavailableSelections();
    if (mounted) {
      setState(() {});
    }
  }

  String? _selectedDeviceIdForPreferenceKey(String key) {
    return switch (key) {
      "videoInput" =>
        widget.selectedVideoInputDeviceId?.call() ??
            _preferences.getString(key),
      "audioInput" =>
        widget.selectedAudioInputDeviceId?.call() ??
            _preferences.getString(key),
      "audioOutput" =>
        widget.selectedAudioOutputDeviceId?.call() ??
            _preferences.getString(key),
      _ => _preferences.getString(key),
    };
  }

  String? Function()? _selectedDeviceIdGetterForPreferenceKey(String key) {
    return switch (key) {
      "videoInput" => widget.selectedVideoInputDeviceId,
      "audioInput" => widget.selectedAudioInputDeviceId,
      "audioOutput" => widget.selectedAudioOutputDeviceId,
      _ => null,
    };
  }

  Future<void> _updateDevice(
    String key,
    MediaDevice device,
    Future<void> Function(MediaDevice) onChange,
  ) async {
    await onChange(device);
    final selectedDeviceIdGetter = _selectedDeviceIdGetterForPreferenceKey(key);
    if (selectedDeviceIdGetter != null &&
        selectedDeviceIdGetter() != device.deviceId) {
      throw StateError('Unable to switch $key to ${device.deviceId}');
    }
    await _preferences.setString(key, device.deviceId);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _syncUnavailableSelection({
    required String preferenceKey,
    required List<MediaDevice> devices,
    required Future<void> Function(MediaDevice) onChange,
  }) async {
    final visibleDevices = _menuDevices(devices);
    final selectedDeviceId = _selectedDeviceIdForPreferenceKey(preferenceKey);
    final selectedDevice = selectedDeviceId == null
        ? null
        : devices.firstWhereOrNull(
            (device) => device.deviceId == selectedDeviceId,
          );

    if (visibleDevices.isEmpty) {
      if (_preferences.containsKey(preferenceKey)) {
        await _preferences.remove(preferenceKey);
      }
      return;
    }

    if (selectedDeviceId == null ||
        selectedDeviceId.isEmpty ||
        selectedDevice != null) {
      return;
    }

    final fallbackDevice = visibleDevices.first;
    await onChange(fallbackDevice);
    await _preferences.setString(preferenceKey, fallbackDevice.deviceId);
  }

  Future<void> _syncUnavailableSelections() async {
    if (!_loaded || _syncingUnavailableSelections) {
      return;
    }

    _syncingUnavailableSelections = true;
    try {
      await _syncUnavailableSelection(
        preferenceKey: "videoInput",
        devices: _devices
            .where((device) => device.kind == "videoinput")
            .toList(growable: false),
        onChange: widget.onChangeVideoInput,
      );
      await _syncUnavailableSelection(
        preferenceKey: "audioInput",
        devices: _devices
            .where((device) => device.kind == "audioinput")
            .toList(growable: false),
        onChange: widget.onChangeAudioInput,
      );
      await _syncUnavailableSelection(
        preferenceKey: "audioOutput",
        devices: _devices
            .where((device) => device.kind == "audiooutput")
            .toList(growable: false),
        onChange: widget.onChangeAudioOutput,
      );
    } finally {
      _syncingUnavailableSelections = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> onChangeVideoInput(MediaDevice device) =>
      _updateDevice("videoInput", device, widget.onChangeVideoInput);
  Future<void> onChangeAudioInput(MediaDevice device) =>
      _updateDevice("audioInput", device, widget.onChangeAudioInput);
  Future<void> onChangeAudioOutput(MediaDevice device) =>
      _updateDevice("audioOutput", device, widget.onChangeAudioOutput);

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
          selectedVideoInputDeviceId: widget.selectedVideoInputDeviceId,
          selectedAudioInputDeviceId: widget.selectedAudioInputDeviceId,
          selectedAudioOutputDeviceId: widget.selectedAudioOutputDeviceId,
          syncUnavailableSelections: _syncUnavailableSelections,
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

    final videoInput = _selectedDeviceIdForPreferenceKey("videoInput");
    final audioInput = _selectedDeviceIdForPreferenceKey("audioInput");
    final audioOutput = _selectedDeviceIdForPreferenceKey("audioOutput");

    final videoInputs = _devices.where((d) => d.kind == "videoinput").toList();
    final audioInputs = _devices.where((d) => d.kind == "audioinput").toList();
    final audioOutputs = _devices
        .where((d) => d.kind == "audiooutput")
        .toList();

    final visibleVideoInputs = _menuDevices(videoInputs);
    final visibleAudioInputs = _menuDevices(audioInputs);
    final visibleAudioOutputs = _menuDevices(audioOutputs);

    final selectedVideoDevice = _selectedMenuDevice(videoInputs, videoInput);
    final selectedAudioInputDevice = _selectedMenuDevice(
      audioInputs,
      audioInput,
    );
    final selectedAudioOutputDevice = _selectedMenuDevice(
      audioOutputs,
      audioOutput,
    );

    return AdaptiveShadContextMenu(
      controller: _controller,
      boundaryContext: context,
      constraints: _menuConstraints,
      estimatedMenuWidth: _menuConstraints.maxWidth,
      estimatedMenuHeight: _estimatedTopLevelMenuHeight(
        includeCamera: widget.kind == null || widget.kind == "camera",
        includeMicrophone: widget.kind == null || widget.kind == "mic",
        includeSpeakers:
            (kIsWeb && widget.kind == null) || widget.kind == "mic",
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
            devices: visibleVideoInputs,
            selectedDevice: selectedVideoDevice,
            onChange: onChangeVideoInput,
            icon: LucideIcons.video,
            disabledIcon: LucideIcons.videoOff,
            disabledLabel: "Camera disabled",
            disabledDescription: _disabledDeviceDescription,
          ),
        if (widget.kind == null || widget.kind == "mic")
          _buildDeviceMenuItem(
            context,
            label: "Microphone",
            devices: visibleAudioInputs,
            selectedDevice: selectedAudioInputDevice,
            onChange: onChangeAudioInput,
            icon: LucideIcons.mic,
            disabledIcon: LucideIcons.micOff,
            disabledLabel: "Microphone disabled",
            disabledDescription: _disabledDeviceDescription,
          ),
        if ((kIsWeb && widget.kind == null) || widget.kind == "mic")
          _buildDeviceMenuItem(
            context,
            label: "Speakers",
            devices: visibleAudioOutputs,
            selectedDevice: selectedAudioOutputDevice,
            onChange: onChangeAudioOutput,
            icon: LucideIcons.volume2,
            disabledIcon: LucideIcons.volumeOff,
            disabledLabel: "Speakers disabled",
            disabledDescription: _disabledDeviceDescription,
          ),
      ],
      child: widget.renderButton(_handlePressed),
    );
  }

  double _estimatedTopLevelMenuHeight({
    required bool includeCamera,
    required bool includeMicrophone,
    required bool includeSpeakers,
  }) {
    final itemCount = [
      includeCamera,
      includeMicrophone,
      includeSpeakers,
    ].where((include) => include).length;
    return itemCount * _topLevelItemHeight + 8.0;
  }

  Widget _buildDeviceMenuItem(
    BuildContext context, {
    required String label,
    required List<MediaDevice> devices,
    required MediaDevice? selectedDevice,
    required Future<void> Function(MediaDevice device) onChange,
    required IconData icon,
    required IconData disabledIcon,
    required String disabledLabel,
    required String disabledDescription,
  }) {
    final theme = ShadTheme.of(context);
    final selectedLabel = _deviceLabel(selectedDevice, label);
    final submenuItems = devices
        .map(
          (device) => ShadContextMenuItem(
            height: 40,
            onPressed: () =>
                unawaited(_runDeviceChange(label, onChange, device)),
            trailing: device.deviceId == selectedDevice?.deviceId
                ? const Icon(LucideIcons.check, size: 16)
                : null,
            child: Text(
              _deviceLabel(device, label),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(growable: false);

    if (selectedDevice == null) {
      return ShadContextMenuItem(
        enabled: true,
        closeOnTap: false,
        height: _topLevelItemHeight,
        leading: Icon(
          disabledIcon,
          size: 18,
          color: theme.colorScheme.destructive,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              disabledLabel,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.colorScheme.destructive),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                disabledDescription,
                style: theme.textTheme.muted.copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.destructive,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
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
              child: Text(
                selectedLabel,
                style: theme.textTheme.muted.copyWith(fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _runDeviceChange(
    String label,
    Future<void> Function(MediaDevice) onChange,
    MediaDevice device,
  ) async {
    try {
      await onChange(device);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ShadToaster.maybeOf(context)?.show(
        ShadToast.destructive(
          description: Text(_describeDeviceSwitchError(label, error)),
        ),
      );
      debugPrint('Unable to switch device ${device.deviceId}: $error');
    }
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
    required this.syncUnavailableSelections,
    required this.dialogConstraints,
    this.selectedVideoInputDeviceId,
    this.selectedAudioInputDeviceId,
    this.selectedAudioOutputDeviceId,
  });

  final BuildContext boundaryContext;
  final String? kind;
  final SharedPreferences preferences;
  final List<MediaDevice> initialDevices;
  final Future<void> Function(MediaDevice) onChangeVideoInput;
  final Future<void> Function(MediaDevice) onChangeAudioInput;
  final Future<void> Function(MediaDevice) onChangeAudioOutput;
  final Future<void> Function() syncUnavailableSelections;
  final BoxConstraints dialogConstraints;
  final String? Function()? selectedVideoInputDeviceId;
  final String? Function()? selectedAudioInputDeviceId;
  final String? Function()? selectedAudioOutputDeviceId;

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
      unawaited(_syncAfterDeviceChange());
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

  Future<void> _syncAfterDeviceChange() async {
    await widget.syncUnavailableSelections();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoInput =
        widget.selectedVideoInputDeviceId?.call() ??
        widget.preferences.getString("videoInput");
    final audioInput =
        widget.selectedAudioInputDeviceId?.call() ??
        widget.preferences.getString("audioInput");
    final audioOutput =
        widget.selectedAudioOutputDeviceId?.call() ??
        widget.preferences.getString("audioOutput");

    final videoInputs = _devices
        .where((device) => device.kind == "videoinput")
        .toList();
    final audioInputs = _devices
        .where((device) => device.kind == "audioinput")
        .toList();
    final audioOutputs = _devices
        .where((device) => device.kind == "audiooutput")
        .toList();

    final visibleVideoInputs = _menuDevices(videoInputs);
    final visibleAudioInputs = _menuDevices(audioInputs);
    final visibleAudioOutputs = _menuDevices(audioOutputs);

    final selectedVideoDevice = _selectedMenuDevice(videoInputs, videoInput);
    final selectedAudioInputDevice = _selectedMenuDevice(
      audioInputs,
      audioInput,
    );
    final selectedAudioOutputDevice = _selectedMenuDevice(
      audioOutputs,
      audioOutput,
    );

    Widget rowSeparator() =>
        Divider(height: 1, color: ShadTheme.of(context).colorScheme.border);

    return PowerboardsShadDialog.listPicker(
      title: const Text("Device settings"),
      description: const Text("Choose your camera, microphone, and speakers."),
      constraints: widget.dialogConstraints,
      expandDesktopActions: true,
      actions: [
        ShadButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("Done"),
        ),
      ],
      child: Padding(
        padding: powerboardsDialogScrollableListPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.kind == null || widget.kind == "camera") ...[
              _DeviceSettingsRow(
                boundaryContext: widget.boundaryContext,
                label: "Camera",
                devices: visibleVideoInputs,
                selectedDevice: selectedVideoDevice,
                onChange: (device) async {
                  await widget.onChangeVideoInput(device);
                  setState(() {});
                },
                icon: LucideIcons.video,
                disabledIcon: LucideIcons.videoOff,
                disabledLabel: "Camera disabled",
                disabledDescription: _disabledDeviceDescription,
              ),
              if (widget.kind == null || widget.kind == "mic") rowSeparator(),
            ],
            if (widget.kind == null || widget.kind == "mic") ...[
              _DeviceSettingsRow(
                boundaryContext: widget.boundaryContext,
                label: "Microphone",
                devices: visibleAudioInputs,
                selectedDevice: selectedAudioInputDevice,
                onChange: (device) async {
                  await widget.onChangeAudioInput(device);
                  setState(() {});
                },
                icon: LucideIcons.mic,
                disabledIcon: LucideIcons.micOff,
                disabledLabel: "Microphone disabled",
                disabledDescription: _disabledDeviceDescription,
              ),
              if ((kIsWeb && widget.kind == null) || widget.kind == "mic")
                rowSeparator(),
            ],
            if ((kIsWeb && widget.kind == null) || widget.kind == "mic")
              _DeviceSettingsRow(
                boundaryContext: widget.boundaryContext,
                label: "Speakers",
                devices: visibleAudioOutputs,
                selectedDevice: selectedAudioOutputDevice,
                onChange: (device) async {
                  await widget.onChangeAudioOutput(device);
                  setState(() {});
                },
                icon: LucideIcons.volume2,
                disabledIcon: LucideIcons.volumeOff,
                disabledLabel: "Speakers disabled",
                disabledDescription: _disabledDeviceDescription,
              ),
          ],
        ),
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
    required this.disabledIcon,
    required this.disabledLabel,
    required this.disabledDescription,
  });

  final BuildContext boundaryContext;
  final String label;
  final List<MediaDevice> devices;
  final MediaDevice? selectedDevice;
  final Future<void> Function(MediaDevice) onChange;
  final IconData icon;
  final IconData disabledIcon;
  final String disabledLabel;
  final String disabledDescription;

  @override
  State<_DeviceSettingsRow> createState() => _DeviceSettingsRowState();
}

class _DeviceSettingsRowState extends State<_DeviceSettingsRow> {
  static const BoxConstraints _menuConstraints = BoxConstraints(
    minWidth: 260,
    maxWidth: 420,
  );
  static const double _rowIconSize = 20;
  final ShadContextMenuController _controller = ShadContextMenuController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = _deviceLabel(widget.selectedDevice, widget.label);
    final hasOptions =
        widget.selectedDevice != null && widget.devices.isNotEmpty;
    final theme = ShadTheme.of(context);
    final isDisabled = widget.selectedDevice == null;
    final disabledColor = theme.colorScheme.destructive;

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
            onPressed: () => unawaited(_runDeviceChange(device)),
            trailing: device.deviceId == widget.selectedDevice?.deviceId
                ? const Icon(LucideIcons.check, size: 18)
                : null,
            child: Text(
              _deviceLabel(device, widget.label),
              overflow: TextOverflow.ellipsis,
            ),
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
          title: isDisabled ? widget.disabledLabel : widget.label,
          description: isDisabled ? widget.disabledDescription : selectedLabel,
          titleColor: isDisabled ? disabledColor : null,
          descriptionColor: isDisabled ? disabledColor : null,
          leading: Icon(
            isDisabled ? widget.disabledIcon : widget.icon,
            size: _rowIconSize,
            color: isDisabled ? disabledColor : shadForeground,
          ),
          trailing: hasOptions
              ? Icon(
                  LucideIcons.chevronsUpDown,
                  size: 21,
                  color: shadSecondaryForeground,
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _runDeviceChange(MediaDevice device) async {
    try {
      await widget.onChange(device);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ShadToaster.maybeOf(context)?.show(
        ShadToast.destructive(
          description: Text(_describeDeviceSwitchError(widget.label, error)),
        ),
      );
      debugPrint('Unable to switch device ${device.deviceId}: $error');
    }
  }
}
