import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class DeviceManager extends StatefulWidget {
  const DeviceManager({super.key, required this.child});

  final Widget child;

  @override
  State createState() => _DeviceManagerState();
}

class _DeviceManagerState extends State<DeviceManager> {
  bool _loaded = false;
  List<MediaDevice> _devices = [];
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _load();

    _subscription = Hardware.instance.onDeviceChange.stream.listen((devices) {
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

  Future<void> _refreshDevices() async {
    _devices = await _getDevices();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Container();
    }

    return DeviceManagerProvider(devices: _devices, refreshDevices: _refreshDevices, child: widget.child);
  }
}

class DeviceManagerProvider extends InheritedWidget {
  const DeviceManagerProvider({super.key, required this.devices, required this.refreshDevices, required super.child});

  final List<MediaDevice> devices;
  final Future<void> Function() refreshDevices;

  static DeviceManagerProvider? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DeviceManagerProvider>();
  }

  static DeviceManagerProvider of(BuildContext context) {
    return maybeOf(context)!;
  }

  bool get canTurnOnMicrophone {
    return devices.where((d) => d.kind == "audioinput").isNotEmpty;
  }

  bool get canTurnOnCamera {
    return devices.where((d) => d.kind == "videoinput").isNotEmpty;
  }

  @override
  bool updateShouldNotify(DeviceManagerProvider oldWidget) {
    return devices != oldWidget.devices;
  }
}
