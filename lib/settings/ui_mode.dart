import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:localstorage/localstorage.dart';
import 'package:meshagent_flutter_auth/meshagent_auth.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';

enum PowerboardsUiMode { legacy, v1 }

const String _powerboardsUiModeStorageKey = 'powerboards.uiMode';

String _currentPowerboardsUiModeStorageKey() {
  final user = MeshagentAuth.current.getUser();
  final userId = (user?['id'] as String?)?.trim();
  final email = (user?['email'] as String?)?.trim().toLowerCase();
  final storageScope = (userId != null && userId.isNotEmpty) ? userId : (email != null && email.isNotEmpty ? email : null);

  return storageScope == null ? _powerboardsUiModeStorageKey : '$_powerboardsUiModeStorageKey.$storageScope';
}

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
  final scopedRawValue = localStorage.getItem(_currentPowerboardsUiModeStorageKey());
  final legacyRawValue = localStorage.getItem(_powerboardsUiModeStorageKey);
  final rawValue = scopedRawValue is String ? scopedRawValue : legacyRawValue;
  return _parsePowerboardsUiMode(rawValue is String ? rawValue : null);
}

final Signal<PowerboardsUiMode> powerboardsUiModeSignal = Signal<PowerboardsUiMode>(getStoredPowerboardsUiMode());

void syncPowerboardsUiModeFromStorage() {
  final storedMode = getStoredPowerboardsUiMode();
  if (powerboardsUiModeSignal.value != storedMode) {
    powerboardsUiModeSignal.value = storedMode;
  }
}

void setPowerboardsUiMode(PowerboardsUiMode mode) {
  final scopedKey = _currentPowerboardsUiModeStorageKey();
  localStorage.setItem(scopedKey, powerboardsUiModeStorageValue(mode));
  if (scopedKey != _powerboardsUiModeStorageKey) {
    localStorage.removeItem(_powerboardsUiModeStorageKey);
  }
  powerboardsUiModeSignal.value = mode;
}

void resetPowerboardsUiMode() {
  final scopedKey = _currentPowerboardsUiModeStorageKey();
  localStorage.removeItem(scopedKey);
  if (scopedKey != _powerboardsUiModeStorageKey) {
    localStorage.removeItem(_powerboardsUiModeStorageKey);
  }
  powerboardsUiModeSignal.value = PowerboardsUiMode.legacy;
}

bool powerboardsUsesDesktopUiPreview(BuildContext context) {
  syncPowerboardsUiModeFromStorage();
  return powerboardsUiModeSignal.value == PowerboardsUiMode.v1 && !powerboardsUsesNativeMobileDialogLayout(context);
}
