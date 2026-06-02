import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class PreviewRoomRailMenuBridge extends ChangeNotifier {
  bool showDestinations = true;
  bool showMore = true;
  bool showRename = true;
  bool showPermissions = true;
  bool showManageAgents = false;
  bool showDeleteRoom = true;
  bool showKeychain = true;
  bool showConsoleToggle = false;
  bool showShutdown = false;
  bool meetActive = false;
  String consoleLabel = 'Developer console';

  VoidCallback? onRenamePressed;
  VoidCallback? onPermissionsPressed;
  VoidCallback? onManageAgentsPressed;
  VoidCallback? onDeleteRoomPressed;
  VoidCallback? onKeychainPressed;
  VoidCallback? onToggleConsolePressed;
  VoidCallback? onShutdownPressed;
  bool _notificationScheduled = false;

  void configure({
    required bool showDestinations,
    required bool showMore,
    required bool showRename,
    required bool showPermissions,
    required bool showManageAgents,
    required bool showDeleteRoom,
    required bool showKeychain,
    required bool showConsoleToggle,
    required bool showShutdown,
    required bool meetActive,
    required String consoleLabel,
    VoidCallback? onRenamePressed,
    VoidCallback? onPermissionsPressed,
    VoidCallback? onManageAgentsPressed,
    VoidCallback? onDeleteRoomPressed,
    VoidCallback? onKeychainPressed,
    VoidCallback? onToggleConsolePressed,
    VoidCallback? onShutdownPressed,
  }) {
    this.onRenamePressed = onRenamePressed;
    this.onPermissionsPressed = onPermissionsPressed;
    this.onManageAgentsPressed = onManageAgentsPressed;
    this.onDeleteRoomPressed = onDeleteRoomPressed;
    this.onKeychainPressed = onKeychainPressed;
    this.onToggleConsolePressed = onToggleConsolePressed;
    this.onShutdownPressed = onShutdownPressed;

    final changed =
        this.showDestinations != showDestinations ||
        this.showMore != showMore ||
        this.showRename != showRename ||
        this.showPermissions != showPermissions ||
        this.showManageAgents != showManageAgents ||
        this.showDeleteRoom != showDeleteRoom ||
        this.showKeychain != showKeychain ||
        this.showConsoleToggle != showConsoleToggle ||
        this.showShutdown != showShutdown ||
        this.meetActive != meetActive ||
        this.consoleLabel != consoleLabel;

    this.showDestinations = showDestinations;
    this.showMore = showMore;
    this.showRename = showRename;
    this.showPermissions = showPermissions;
    this.showManageAgents = showManageAgents;
    this.showDeleteRoom = showDeleteRoom;
    this.showKeychain = showKeychain;
    this.showConsoleToggle = showConsoleToggle;
    this.showShutdown = showShutdown;
    this.meetActive = meetActive;
    this.consoleLabel = consoleLabel;

    if (changed) {
      _notifyListenersSafely();
    }
  }

  void _notifyListenersSafely() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
      return;
    }

    if (_notificationScheduled) {
      return;
    }
    _notificationScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      notifyListeners();
    });
    SchedulerBinding.instance.scheduleFrame();
  }
}

final ValueNotifier<PreviewRoomRailMenuBridge?> previewRoomRailMenuBridgeListenable = ValueNotifier<PreviewRoomRailMenuBridge?>(null);
final ValueNotifier<bool> previewFilePreviewFullscreenListenable = ValueNotifier<bool>(false);
typedef PreviewRoomDisplayNameOverrideCallback =
    void Function({required String projectId, required String roomName, required String displayName});

VoidCallback? _previewRoomListRefreshCallback;
PreviewRoomDisplayNameOverrideCallback? _previewRoomDisplayNameOverrideCallback;

void exposePreviewRoomRailMenuBridge(PreviewRoomRailMenuBridge? bridge) {
  if (identical(previewRoomRailMenuBridgeListenable.value, bridge)) {
    return;
  }

  previewRoomRailMenuBridgeListenable.value = bridge;
}

void setPreviewFilePreviewFullscreen(bool fullscreen) {
  if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _setPreviewFilePreviewFullscreenNow(fullscreen);
    });
    SchedulerBinding.instance.scheduleFrame();
    return;
  }

  _setPreviewFilePreviewFullscreenNow(fullscreen);
}

void _setPreviewFilePreviewFullscreenNow(bool fullscreen) {
  if (previewFilePreviewFullscreenListenable.value == fullscreen) {
    return;
  }

  previewFilePreviewFullscreenListenable.value = fullscreen;
}

void registerPreviewRoomListRefreshCallback(VoidCallback? callback) {
  _previewRoomListRefreshCallback = callback;
}

void registerPreviewRoomDisplayNameOverrideCallback(PreviewRoomDisplayNameOverrideCallback? callback) {
  _previewRoomDisplayNameOverrideCallback = callback;
}

void refreshPreviewRoomList() {
  _previewRoomListRefreshCallback?.call();
}

void overridePreviewRoomDisplayName({required String projectId, required String roomName, required String displayName}) {
  _previewRoomDisplayNameOverrideCallback?.call(projectId: projectId, roomName: roomName, displayName: displayName);
}
