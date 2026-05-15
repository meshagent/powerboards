import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:localstorage/localstorage.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';

enum PowerboardsUiMode { legacy, v1 }

const String _powerboardsUiModeStorageKey = 'powerboards.uiMode';

PowerboardsUiMode _parsePowerboardsUiMode(String? value) {
  return switch (value) {
    'v1' => PowerboardsUiMode.v1,
    _ => PowerboardsUiMode.legacy,
  };
}

String powerboardsUiModeStorageValue(PowerboardsUiMode mode) {
  return switch (mode) {
    PowerboardsUiMode.legacy => 'legacy',
    PowerboardsUiMode.v1 => 'v1',
  };
}

PowerboardsUiMode getStoredPowerboardsUiMode() {
  final rawValue = localStorage.getItem(_powerboardsUiModeStorageKey);
  return _parsePowerboardsUiMode(rawValue is String ? rawValue : null);
}

final Signal<PowerboardsUiMode> powerboardsUiModeSignal = Signal<PowerboardsUiMode>(getStoredPowerboardsUiMode());

void setPowerboardsUiMode(PowerboardsUiMode mode) {
  localStorage.setItem(_powerboardsUiModeStorageKey, powerboardsUiModeStorageValue(mode));
  powerboardsUiModeSignal.value = mode;
}

bool powerboardsUsesDesktopUiPreview(BuildContext context) {
  return powerboardsUiModeSignal.value == PowerboardsUiMode.v1 && !powerboardsUsesNativeMobileDialogLayout(context);
}
