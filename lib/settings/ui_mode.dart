import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:localstorage/localstorage.dart';
import 'package:meshagent_flutter_auth/meshagent_auth.dart';
import 'package:powerboards/ui/app_reload.dart';
import 'package:powerboards/ui/powerboards_breakpoints.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:responsive_framework/responsive_framework.dart';

enum PowerboardsUiMode { legacy, v1 }

const String _powerboardsUiModeStorageKey = 'powerboards.uiMode';
const String _powerboardsUiModeQueryParameter = 'ui';
const String _powerboardsUiModeDefaultDefine = 'POWERBOARDS_UI_MODE';
bool _powerboardsUiModeStorageInitialized = false;

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

PowerboardsUiMode? _parseOptionalPowerboardsUiMode(String? value) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return switch (normalized) {
    'legacy' => PowerboardsUiMode.legacy,
    'v1' => PowerboardsUiMode.v1,
    _ => null,
  };
}

String powerboardsUiModeStorageValue(PowerboardsUiMode mode) {
  return switch (mode) {
    PowerboardsUiMode.legacy => 'legacy',
    PowerboardsUiMode.v1 => 'v1',
  };
}

PowerboardsUiMode getStoredPowerboardsUiMode() {
  if (!_powerboardsUiModeStorageInitialized) {
    return getConfiguredPowerboardsUiMode();
  }

  final scopedRawValue = localStorage.getItem(_currentPowerboardsUiModeStorageKey());
  final legacyRawValue = localStorage.getItem(_powerboardsUiModeStorageKey);
  final rawValue = scopedRawValue is String ? scopedRawValue : legacyRawValue;
  return _parsePowerboardsUiMode(rawValue is String ? rawValue : null);
}

PowerboardsUiMode? getQueryParameterPowerboardsUiMode() {
  return _parseOptionalPowerboardsUiMode(Uri.base.queryParameters[_powerboardsUiModeQueryParameter]);
}

PowerboardsUiMode? getDefaultPowerboardsUiMode() {
  return _parseOptionalPowerboardsUiMode(const String.fromEnvironment(_powerboardsUiModeDefaultDefine));
}

@visibleForTesting
PowerboardsUiMode defaultPowerboardsUiModeForPlatform({bool isWeb = kIsWeb}) {
  return isWeb ? PowerboardsUiMode.v1 : PowerboardsUiMode.legacy;
}

PowerboardsUiMode getConfiguredPowerboardsUiMode() {
  return getQueryParameterPowerboardsUiMode() ?? getDefaultPowerboardsUiMode() ?? defaultPowerboardsUiModeForPlatform();
}

bool emailCanPreviewPowerboardsUiMode(String? email) {
  final normalized = email?.trim().toLowerCase();
  return normalized != null && normalized.endsWith('@timu.com');
}

bool currentUserCanPreviewPowerboardsUiMode() {
  final user = MeshagentAuth.current.getUser();
  final email = user?['email'];
  return email is String && emailCanPreviewPowerboardsUiMode(email);
}

PowerboardsUiMode getEffectivePowerboardsUiMode() {
  if (hasStoredPowerboardsUiMode()) {
    return getStoredPowerboardsUiMode();
  }

  return getConfiguredPowerboardsUiMode();
}

final Signal<PowerboardsUiMode> powerboardsUiModeSignal = Signal<PowerboardsUiMode>(getConfiguredPowerboardsUiMode());

void initializePowerboardsUiMode() {
  _powerboardsUiModeStorageInitialized = true;
  powerboardsUiModeSignal.value = getEffectivePowerboardsUiMode();
}

bool hasStoredPowerboardsUiMode() {
  if (!_powerboardsUiModeStorageInitialized) {
    return false;
  }

  final scopedRawValue = localStorage.getItem(_currentPowerboardsUiModeStorageKey());
  final legacyRawValue = localStorage.getItem(_powerboardsUiModeStorageKey);
  return scopedRawValue is String || legacyRawValue is String;
}

void syncPowerboardsUiModeFromStorage({bool resetToLegacyWhenMissing = false}) {
  if (!hasStoredPowerboardsUiMode()) {
    final fallbackMode = resetToLegacyWhenMissing ? PowerboardsUiMode.legacy : getEffectivePowerboardsUiMode();
    if (powerboardsUiModeSignal.value != fallbackMode) {
      powerboardsUiModeSignal.value = fallbackMode;
    }
    return;
  }

  final storedMode = getStoredPowerboardsUiMode();
  if (powerboardsUiModeSignal.value != storedMode) {
    powerboardsUiModeSignal.value = storedMode;
  }
}

void _persistPowerboardsUiMode(PowerboardsUiMode mode, {required bool notifyListeners}) {
  final scopedKey = _currentPowerboardsUiModeStorageKey();
  localStorage.setItem(scopedKey, powerboardsUiModeStorageValue(mode));
  if (scopedKey != _powerboardsUiModeStorageKey) {
    localStorage.removeItem(_powerboardsUiModeStorageKey);
  }
  if (notifyListeners) {
    powerboardsUiModeSignal.value = mode;
  }
}

void setPowerboardsUiMode(PowerboardsUiMode mode) {
  _persistPowerboardsUiMode(mode, notifyListeners: true);
}

void togglePowerboardsUiMode() {
  final nextMode = powerboardsUiModeSignal.value == PowerboardsUiMode.legacy ? PowerboardsUiMode.v1 : PowerboardsUiMode.legacy;
  setPowerboardsUiMode(nextMode);
}

void togglePowerboardsUiModeAndReload() {
  final nextMode = powerboardsUiModeSignal.value == PowerboardsUiMode.legacy ? PowerboardsUiMode.v1 : PowerboardsUiMode.legacy;
  _persistPowerboardsUiMode(nextMode, notifyListeners: !kIsWeb);
  reloadPowerboardsApp();
}

void resetPowerboardsUiMode() {
  final scopedKey = _currentPowerboardsUiModeStorageKey();
  localStorage.removeItem(scopedKey);
  if (scopedKey != _powerboardsUiModeStorageKey) {
    localStorage.removeItem(_powerboardsUiModeStorageKey);
  }
  powerboardsUiModeSignal.value = getConfiguredPowerboardsUiMode();
}

bool powerboardsUsesDesktopUiPreview(BuildContext context) {
  final useMobileNav = ResponsiveBreakpoints.of(context).isMobile || powerboardsIsLandscapePhoneViewport(context);
  return powerboardsUiModeSignal.value == PowerboardsUiMode.v1 && !useMobileNav && !powerboardsUsesNativeMobileDialogLayout(context);
}
