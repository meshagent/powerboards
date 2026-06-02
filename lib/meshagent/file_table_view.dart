import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'package:meshagent/document.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/chat/conversation_descriptor.dart' as ma;
import 'package:meshagent_flutter_shadcn/chat/file_prompt_actions.dart';
import 'package:meshagent_flutter_shadcn/file_preview/code.dart';
import 'package:meshagent_flutter_shadcn/file_preview/file_preview.dart';
import 'package:meshagent_flutter_shadcn/storage/pending_storage_deletes.dart';
import 'package:meshagent_flutter_shadcn/storage/transcript_file_name.dart';
import 'package:meshagent_flutter_shadcn/ui/ui.dart';
import 'package:meshagent_flutter_shadcn/viewers/file.dart';

import 'package:powerboards/meshagent/file_breadcrumb_layout.dart';
import 'package:powerboards/meshagent/file_attachment_index.dart';
import 'package:powerboards/meshagent/agent_option.dart';
import 'package:powerboards/meshagent/document_pane.dart';
import 'package:powerboards/meshagent/file_list_primitives.dart';
import 'package:powerboards/meshagent/file_preview_origin.dart';
import 'package:powerboards/meshagent/file_preview_state.dart';
import 'package:powerboards/meshagent/path.dart';
import 'package:powerboards/meshagent/thread_display_name.dart';
import 'package:powerboards/meshagent/share_remote_file.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_file_preview_state_card.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_data.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_drop_target.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_layout_values.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_side_pane.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_upload_progress_popover.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_files_page.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_room_panel.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_room_panel_mount.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';
import 'package:powerboards/powerboards_ui/v1/preview/preview_room_rail_menu.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/settings/format_date.dart';
import 'package:powerboards/settings/ui_mode.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:powerboards/ui/app_context_menu.dart';
import 'package:powerboards/ui/desktop_sidetray_toggle.dart';
import 'package:powerboards/ui/pane_empty_state.dart';
import 'package:powerboards/ui/pane_header_action_scope.dart';
import 'package:powerboards/ui/powerboards_adaptive_input.dart';
import 'package:powerboards/ui/powerboards_breakpoints.dart';
import 'package:powerboards/ui/powerboards_mobile_action_pills.dart';
import 'package:powerboards/ui/powerboards_mobile_overlay_header.dart';
import 'package:powerboards/ui/text_validators.dart';

import 'file_upload.dart';

const Set<String> editExtensions = {"md"};
const String placeholderFileName = ".placeholder";
const double filePaneTableHeaderHeight = 48;

bool _usesAdaptiveMobileLayout(BuildContext context) {
  if (powerboardsUsesDesktopUiPreview(context)) {
    return false;
  }

  return ResponsiveBreakpoints.of(context).isMobile || powerboardsIsLandscapePhoneViewport(context);
}

String _displayFileName(String fileName) {
  return formatTranscriptFileNameForDisplay(fileName);
}

const List<String> _fileSizeUnits = <String>['B', 'KB', 'MB', 'GB', 'TB'];
const int _v1RecentlyOpenedFilesLimit = 7;
const Duration _v1DeleteProcessingStep = Duration(milliseconds: 650);
const Offset _uploadProgressPopoverOffset = Offset(20, -20);

const Map<String, String> _powerboardsV1FileTypeKeysByExtension = {
  'thread': 'thread',
  'transcript': 'transcript',
  'widget': 'widget',
  'document': 'document',
  'presentation': 'presentation',
  'gallery': 'image',
  'form': 'document',
};

@visibleForTesting
String? powerboardsV1FileTypeKeyForPath(String path) {
  final extension = p.extension(path).replaceFirst('.', '').toLowerCase();
  if (extension.isEmpty) {
    return null;
  }

  return _powerboardsV1FileTypeKeysByExtension[extension];
}

String _formatFileSizeBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }

  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < _fileSizeUnits.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  final decimals = value >= 10 || value == value.roundToDouble() ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${_fileSizeUnits[unitIndex]}';
}

enum FileSortField { name, modified }

enum _FileAction { open, download, share, upload, compressFolder, rename, delete }

@visibleForTesting
List<PbFilesItemData> powerboardsV1RecordRecentlyOpenedFile(
  List<PbFilesItemData> current,
  PbFilesItemData item, {
  int limit = _v1RecentlyOpenedFilesLimit,
}) {
  final next = <PbFilesItemData>[];
  if (item.canPreview) {
    next.add(item);
  }

  for (final opened in current) {
    if (!opened.canPreview || opened.id == item.id) {
      continue;
    }
    next.add(opened);
  }

  return next.take(limit).toList(growable: false);
}

String _relocatePathForMove(String currentPath, String sourcePath, String destinationPath) {
  if (currentPath == sourcePath) {
    return destinationPath;
  }

  final sourcePrefix = '$sourcePath/';
  if (!currentPath.startsWith(sourcePrefix)) {
    return currentPath;
  }

  final suffix = currentPath.substring(sourcePrefix.length);
  return destinationPath.isEmpty ? suffix : '$destinationPath/$suffix';
}

class _FileLocation {
  final String folder;
  final String? openedFile;

  const _FileLocation({required this.folder, required this.openedFile});

  @override
  bool operator ==(Object other) => other is _FileLocation && other.folder == folder && other.openedFile == openedFile;

  @override
  int get hashCode => Object.hash(folder, openedFile);

  factory _FileLocation.fromUri(Uri uri) {
    final raw = uri.queryParameters['p'] ?? '';

    if (raw.isEmpty) {
      return const _FileLocation(folder: "", openedFile: null);
    }

    final isFolder = raw.endsWith('/');
    final normalizedPath = joinPaths(raw, '');

    if (isFolder) {
      return _FileLocation(folder: normalizedPath, openedFile: null);
    }

    return _FileLocation(folder: parentPath(normalizedPath), openedFile: normalizedPath);
  }
}

class FileSort {
  final FileSortField field;
  final bool ascending;
  const FileSort(this.field, this.ascending);

  int compare(StorageEntry a, StorageEntry b) {
    // folders before files
    if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;

    int cmp;
    switch (field) {
      case FileSortField.name:
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        break;
      case FileSortField.modified:
        final aDate = a.updatedAt;
        final bDate = b.updatedAt;

        if (aDate == null && bDate == null) {
          cmp = 0;
        } else if (aDate == null) {
          cmp = -1;
        } else if (bDate == null) {
          cmp = 1;
        } else {
          cmp = aDate.compareTo(bDate);
        }
        break;
    }

    return ascending ? cmp : -cmp;
  }
}

class _FilePathKey {
  const _FilePathKey._();

  static String pathForEntry(String currentPath, StorageEntry entry) {
    return joinPaths(currentPath, entry.name);
  }

  static String keyForPath(String path, bool isFolder) {
    return isFolder ? '$path/' : path;
  }

  static String keyForEntry(String currentPath, StorageEntry entry) {
    final path = pathForEntry(currentPath, entry);
    return keyForPath(path, entry.isFolder);
  }

  static String pathFromKey(String key) {
    return key.endsWith('/') ? key.substring(0, key.length - 1) : key;
  }

  static bool isFolderKey(String key) => key.endsWith('/');
}

class _PendingDeleteOperation {
  const _PendingDeleteOperation({required this.handle, required this.displayUntil});

  final PendingStorageDeleteHandle handle;
  final DateTime displayUntil;
}

class FileManagerViewController {
  Future<void> Function()? _createFolderInCurrentLocation;
  void Function()? _createTextFileInCurrentLocation;
  Future<void> Function()? _addFilesInCurrentLocation;
  Future<void> Function()? _shareOpenedFileInCurrentLocation;

  Future<void> createFolderInCurrentLocation() async {
    final action = _createFolderInCurrentLocation;
    if (action == null) {
      return;
    }
    await action();
  }

  void createTextFileInCurrentLocation() {
    _createTextFileInCurrentLocation?.call();
  }

  Future<void> addFilesInCurrentLocation() async {
    final action = _addFilesInCurrentLocation;
    if (action == null) {
      return;
    }
    await action();
  }

  Future<void> shareOpenedFileInCurrentLocation() async {
    final action = _shareOpenedFileInCurrentLocation;
    if (action == null) {
      return;
    }
    await action();
  }
}

class FileManagerView extends StatefulWidget {
  final RoomClient client;
  final String? projectId;
  final Resource<List<ServiceSpec>>? services;
  final bool hideSystem;
  final bool mobileShellOwnsHeader;
  final FileManagerViewController? controller;
  final List<Widget> desktopHeaderLeadingActions;
  final List<Widget> desktopHeaderActions;
  final double desktopHeaderActionLeadingWidthFloor;
  final double desktopHeaderActionMinimumLeadingWidth;
  final double desktopHeaderActionReserve;
  final bool showDesktopSidetrayToggle;
  final bool? v1RoomPanelCollapsed;
  final ValueChanged<bool>? onV1RoomPanelCollapsedChanged;
  final double? v1RoomPanelWidth;
  final ValueChanged<double>? onV1RoomPanelWidthChanged;
  final FutureOr<void> Function(ChatFilePromptAction action, String filePath)? onV1FilePromptRequested;

  const FileManagerView({
    super.key,
    required this.client,
    this.projectId,
    this.services,
    this.hideSystem = false,
    this.mobileShellOwnsHeader = false,
    this.controller,
    this.desktopHeaderLeadingActions = const [],
    this.desktopHeaderActions = const [],
    this.desktopHeaderActionLeadingWidthFloor = 0,
    this.desktopHeaderActionMinimumLeadingWidth = 0,
    this.desktopHeaderActionReserve = desktopPaneHeaderActionReserve,
    this.showDesktopSidetrayToggle = true,
    this.v1RoomPanelCollapsed,
    this.onV1RoomPanelCollapsedChanged,
    this.v1RoomPanelWidth,
    this.onV1RoomPanelWidthChanged,
    this.onV1FilePromptRequested,
  });

  @override
  State<FileManagerView> createState() => _FileManagerViewState();
}

class _FileManagerViewState extends State<FileManagerView> {
  static TextStyle breadcrumbLinkStyle = powerboardsSectionTitleStyle();
  static const String _threadIndexFileName = 'index.threadl';

  _FileLocation _location = const _FileLocation(folder: "", openedFile: null);
  String? get _openedFile => _location.openedFile;
  bool _isDisposing = false;
  bool get _canUpdateUi => mounted && !_isDisposing;

  bool _forceShowSelect = false;
  String _tab = 'preview';
  final popoverController = ShadPopoverController();
  final ShadContextMenuController _collapsedBreadcrumbMenuController = ShadContextMenuController();
  final CodePreviewController _codePreviewController = CodePreviewController();
  late final uploadNotifications = UploadProgressNotifications(popoverController: popoverController);
  final Set<String> _optimisticEmptyTextFiles = <String>{};
  final Set<String> _threadTitleResolutionsInFlight = <String>{};
  MeshDocument? _threadIndexDocument;
  String? _threadIndexPath;
  Map<String, String> _threadDisplayNamesByPath = const <String, String>{};

  late StreamSubscription<RoomEvent> roomSub;

  late final _folderSig = Signal<String>(_location.folder);
  final _sortSig = Signal<FileSort>(const FileSort(FileSortField.name, true));
  final _selectedSig = Signal<Set<String>>(<String>{});
  final TextEditingController _v1FilterController = TextEditingController();
  final OverlayPortalController _v1FilesRoomPanelOverlayController = OverlayPortalController();
  final FocusNode _v1FilesKeyboardFocusNode = FocusNode(debugLabel: 'Files keyboard navigation');
  PbFilesSortKey _v1SortKey = PbFilesSortKey.updated;
  bool _v1SortDirectionDescending = true;
  bool _v1FilesRoomPanelCollapsed = false;
  bool _v1FilesRoomPanelOverlayOpen = false;
  bool _v1FilePreviewFullscreen = false;
  bool _v1RestoreRoomPanelOverlayOnPreviewClose = false;
  String? _v1KeyboardPreviewFileId;
  int _v1KeyboardPreviewDirection = 0;
  bool _v1FilesKeyboardBrowseArmed = false;
  final ValueNotifier<bool> _v1FilesDropTargetActive = ValueNotifier(false);
  PbFilesItemData? _v1PreviewFile;
  List<PbFilesItemData> _v1RecentlyOpenedFiles = const <PbFilesItemData>[];
  final Map<String, PbFilesItemData> _v1FileStateRowsById = <String, PbFilesItemData>{};
  List<PowerboardsFileAttachmentLink> _fileAttachmentLinks = const <PowerboardsFileAttachmentLink>[];
  final Map<String, String> _fileCreatorNamesByPath = <String, String>{};

  PendingStorageDeleteScope get _deleteScope => PendingStorageDeleteScope(projectId: widget.projectId, roomName: widget.client.roomName);
  bool get _effectiveV1FilesRoomPanelCollapsed => widget.v1RoomPanelCollapsed ?? _v1FilesRoomPanelCollapsed;

  void _setV1FilesRoomPanelCollapsed(bool collapsed) {
    if (widget.v1RoomPanelCollapsed != null) {
      if (widget.v1RoomPanelCollapsed != collapsed) {
        widget.onV1RoomPanelCollapsedChanged?.call(collapsed);
      }
      return;
    }

    if (_v1FilesRoomPanelCollapsed == collapsed) {
      return;
    }

    setState(() => _v1FilesRoomPanelCollapsed = collapsed);
  }

  void _setV1FilesDropTargetActive(bool active) {
    if (_isDisposing || _v1FilesDropTargetActive.value == active) {
      return;
    }

    _v1FilesDropTargetActive.value = active;
  }

  bool _isDeletePending(String path, bool isFolder) {
    return PendingStorageDeletes.contains(scope: _deleteScope, path: path, isFolder: isFolder);
  }

  bool _usesDesktopV1FilesBrowser() {
    return mounted && !_usesAdaptiveMobileLayout(context) && powerboardsUsesDesktopUiPreview(context);
  }

  bool _v1DeleteCoversPath({required String deletePath, required bool isFolder, required String candidatePath}) {
    final normalizedDeletePath = PendingStorageDeletes.normalizePath(deletePath);
    final normalizedCandidatePath = PendingStorageDeletes.normalizePath(candidatePath);
    if (normalizedDeletePath == normalizedCandidatePath) {
      return true;
    }

    return isFolder && normalizedDeletePath.isNotEmpty && normalizedCandidatePath.startsWith('$normalizedDeletePath/');
  }

  bool _v1StateRowMatchesPath(PbFilesItemData item, String path, {required bool isFolder}) {
    final normalizedPath = PendingStorageDeletes.normalizePath(path);
    return item.id == _FilePathKey.keyForPath(path, isFolder) || item.id.startsWith('upload-error:$normalizedPath:');
  }

  void _prepareV1PendingDeleteFeedback(Iterable<String> keys) {
    if (!_usesDesktopV1FilesBrowser()) {
      return;
    }

    final targets = [for (final key in keys) (path: _FilePathKey.pathFromKey(key), isFolder: _FilePathKey.isFolderKey(key))];
    if (targets.isEmpty) {
      return;
    }

    final closesPreviewFile =
        _v1PreviewFile != null &&
        targets.any(
          (target) =>
              _v1DeleteCoversPath(deletePath: target.path, isFolder: target.isFolder, candidatePath: _v1PathForItem(_v1PreviewFile!)),
        );
    final closesOpenedFile =
        _openedFile != null &&
        targets.any((target) => _v1DeleteCoversPath(deletePath: target.path, isFolder: target.isFolder, candidatePath: _openedFile!));
    final nextRecentlyOpenedFiles = [
      for (final item in _v1RecentlyOpenedFiles)
        if (!targets.any(
          (target) => _v1DeleteCoversPath(deletePath: target.path, isFolder: target.isFolder, candidatePath: _v1PathForItem(item)),
        ))
          item,
    ];
    final recentFilesChanged = nextRecentlyOpenedFiles.length != _v1RecentlyOpenedFiles.length;
    final stateRowKeys = keys.toSet();
    final stateRowsChanged = stateRowKeys.any(_v1FileStateRowsById.containsKey);

    if (closesPreviewFile || closesOpenedFile || recentFilesChanged || stateRowsChanged) {
      setState(() {
        if (stateRowsChanged) {
          _v1FileStateRowsById.removeWhere((key, _) => stateRowKeys.contains(key));
        }

        if (recentFilesChanged) {
          _v1RecentlyOpenedFiles = nextRecentlyOpenedFiles;
        }

        if (closesPreviewFile || closesOpenedFile) {
          _v1PreviewFile = null;
          _v1FilePreviewFullscreen = false;
          _v1FilesRoomPanelOverlayOpen = false;
          _v1RestoreRoomPanelOverlayOnPreviewClose = false;
          setPreviewFilePreviewFullscreen(false);
        }
      });
    }

    if (closesOpenedFile) {
      _closeFile();
    }
  }

  Future<void> _waitForV1PendingDeleteDisplay(DateTime displayUntil) async {
    final shouldHoldForFeedback = _usesDesktopV1FilesBrowser();
    if (!shouldHoldForFeedback) {
      return;
    }

    await WidgetsBinding.instance.endOfFrame;
    final remaining = displayUntil.difference(DateTime.now());
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  late final storageEntries = Resource<List<StorageEntry>>(() => _getChildren(_folderSig.value), source: _folderSig);

  late final _visibleSortedEntries = Computed<List<StorageEntry>>(() {
    final entries = storageEntries.state.value ?? const <StorageEntry>[];
    final sort = _sortSig.value;

    var visible = entries;
    if (widget.hideSystem) {
      visible = visible.where((e) => !e.name.startsWith('.')).toList();
    }

    final sorted = List<StorageEntry>.from(visible)..sort(sort.compare);
    return sorted;
  });

  late final _visibleKeys = Computed<Set<String>>(() {
    final folder = _folderSig.value;
    final entries = _visibleSortedEntries.value;

    return entries.map((e) => _FilePathKey.keyForEntry(folder, e)).toSet();
  });

  late final _visibleSelected = Computed<Set<String>>(() {
    final raw = _selectedSig.value;
    final visible = _visibleKeys.value;
    // intersection
    return raw.where(visible.contains).toSet();
  });

  late final _visibleSortedFiles = Computed<List<String>>(() {
    final sorted = _visibleSortedEntries.value;
    final folder = _folderSig.value;
    return sorted.where((e) => !e.isFolder).map((e) => joinPaths(folder, e.name)).toList(growable: false);
  });

  @override
  void initState() {
    super.initState();
    roomSub = widget.client.listen(_onRoomEvent);
    _bindController(widget.controller);
    unawaited(_rebindThreadIndexDocument());
    unawaited(_refreshFileAttachmentLinks());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setLocation();
  }

  @override
  void didUpdateWidget(covariant FileManagerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _unbindController(oldWidget.controller);
      _bindController(widget.controller);
    }
  }

  @override
  void dispose() {
    _unbindController(widget.controller);
    _isDisposing = true;
    if (previewFilePreviewFullscreenListenable.value) {
      setPreviewFilePreviewFullscreen(false);
    }
    roomSub.cancel();

    uploadNotifications.dispose();
    _v1FilterController.dispose();
    _v1FilesKeyboardFocusNode.dispose();
    _v1FilesDropTargetActive.dispose();
    _collapsedBreadcrumbMenuController.dispose();
    popoverController.dispose();
    _codePreviewController.dispose();

    _visibleSortedFiles.dispose();
    _visibleSelected.dispose();
    _visibleKeys.dispose();
    _visibleSortedEntries.dispose();

    storageEntries.dispose();
    _sortSig.dispose();
    _selectedSig.dispose();
    _folderSig.dispose();
    unawaited(_closeThreadIndexDocument(refreshUi: false));

    widget.client.localParticipant?.setAttribute("current_file", null);
    super.dispose();
  }

  void _bindController(FileManagerViewController? controller) {
    if (controller == null) {
      return;
    }

    controller._createFolderInCurrentLocation = () => _addFolder(_folderSig.value);
    controller._createTextFileInCurrentLocation = _showNewTextFileDialog;
    controller._addFilesInCurrentLocation = () => _addFiles(_folderSig.value);
    controller._shareOpenedFileInCurrentLocation = () async {
      final openedFile = _openedFile;
      if (openedFile == null || !supportsNativeFileShare) {
        return;
      }
      await _shareFile(openedFile);
    };
  }

  void _unbindController(FileManagerViewController? controller) {
    if (controller == null) {
      return;
    }

    controller._createFolderInCurrentLocation = null;
    controller._createTextFileInCurrentLocation = null;
    controller._addFilesInCurrentLocation = null;
    controller._shareOpenedFileInCurrentLocation = null;
  }

  void _setLocation() {
    final uri = PathRouteMatch.of(context).uri;
    final next = _FileLocation.fromUri(uri);
    if (_location == next) return;

    final folderChanged = _location.folder != next.folder;
    final openedFileChanged = _location.openedFile != next.openedFile;

    if (folderChanged) {
      _folderSig.value = next.folder;
      _selectedSig.value = <String>{};
      _forceShowSelect = false;
      unawaited(_rebindThreadIndexDocument());
    }

    if (openedFileChanged) {
      _forceShowSelect = false;
      widget.client.localParticipant?.setAttribute("current_file", next.openedFile);
      if (next.openedFile != null) {
        unawaited(_refreshCurrentFolder());
      }
    }

    setState(() {
      if (openedFileChanged) {
        _tab = 'preview';
      }
      if (folderChanged || openedFileChanged) {
        _clearV1KeyboardPreviewNavigationState();
      }
      _location = next;
    });
  }

  void _onRoomEvent(RoomEvent event) {
    if (event is FileUpdatedEvent) {
      _rememberFileCreator(event.path, event.participantId);
      if (normalizePowerboardsAttachmentPath(event.path) == powerboardsFileAttachmentIndexPath) {
        unawaited(_refreshFileAttachmentLinks());
      }
      _onFileUpdated(event.path);
      return;
    }

    if (event is FileDeletedEvent) {
      if (normalizePowerboardsAttachmentPath(event.path) == powerboardsFileAttachmentIndexPath) {
        unawaited(_refreshFileAttachmentLinks());
      }
      _onFileDeleted(event.path);
      _removeV1RecentlyOpenedPath(event.path);
      return;
    }

    if (event is FileMovedEvent) {
      _moveFileCreatorState(event.sourcePath, event.destinationPath);
      _onFileMoved(event.sourcePath, event.destinationPath);
      _removeV1RecentlyOpenedPath(event.sourcePath);
    }
  }

  void _moveFileCreatorState(String sourcePath, String destinationPath) {
    final creator = _fileCreatorNamesByPath.remove(normalizePowerboardsAttachmentPath(sourcePath));
    if (creator == null) {
      return;
    }
    _fileCreatorNamesByPath[normalizePowerboardsAttachmentPath(destinationPath)] = creator;
  }

  void _removeV1RecentlyOpenedPath(String path) {
    final key = _FilePathKey.keyForPath(path, false);
    if (!_v1RecentlyOpenedFiles.any((item) => item.id == key)) {
      return;
    }

    setState(() {
      _v1RecentlyOpenedFiles = [
        for (final item in _v1RecentlyOpenedFiles)
          if (item.id != key) item,
      ];
    });
  }

  void _onFileUpdated(String path) {
    final ready = storageEntries.state.asReady;
    if (ready == null) return; // ignore if loading/error

    final name = path.split('/').where((s) => s.isNotEmpty).last;
    final next = List<StorageEntry>.of(ready.value);
    final now = DateTime.now();
    final fileParent = parentPath(path);

    if (fileParent != _folderSig.value) {
      if (parentPath(fileParent) == _folderSig.value) {
        final parentName = fileParent.split('/').where((s) => s.isNotEmpty).last;
        final idx = next.indexWhere((e) => e.name == parentName);
        if (idx == -1) {
          next.add(StorageEntry(name: parentName, isFolder: true, size: null, createdAt: now, updatedAt: null));
          _setEntries(next);
        }
      }
      return;
    }

    final idx = next.indexWhere((e) => e.name == name);
    _v1FileStateRowsById.removeWhere((_, item) => _v1StateRowMatchesPath(item, path, isFolder: false));
    if (idx == -1) {
      next.add(StorageEntry(name: name, isFolder: false, size: null, createdAt: now, updatedAt: now));
      unawaited(_refreshCurrentFolder());
    } else {
      final old = next[idx];
      next[idx] = StorageEntry(name: name, isFolder: false, size: old.size, createdAt: old.createdAt, updatedAt: now);
      if (old.size == null || old.size == 0) {
        unawaited(_refreshCurrentFolder());
      }
    }

    _setEntries(next);
  }

  void _onFileDeleted(String path) {
    final ready = storageEntries.state.asReady;
    if (ready == null) return; // ignore if loading/error

    final name = path.split('/').where((s) => s.isNotEmpty).last;
    final next = List<StorageEntry>.of(ready.value);
    next.removeWhere((e) => e.name == name);
    _v1FileStateRowsById.removeWhere((_, item) => _v1StateRowMatchesPath(item, path, isFolder: false));
    final previewFile = _v1PreviewFile;
    if (previewFile != null && _v1PathForItem(previewFile) == path) {
      _v1PreviewFile = null;
      _v1FilePreviewFullscreen = false;
      _v1FilesRoomPanelOverlayOpen = false;
      _v1RestoreRoomPanelOverlayOnPreviewClose = false;
      setPreviewFilePreviewFullscreen(false);
    }
    _toggleSelected(_FilePathKey.keyForPath(path, false), false);
    _optimisticEmptyTextFiles.remove(path);

    _setEntries(next);
  }

  bool _replaceLocationForMove(String sourcePath, String destinationPath) {
    final nextFolder = _relocatePathForMove(_location.folder, sourcePath, destinationPath);
    final openedFile = _location.openedFile;
    final nextOpenedFile = openedFile == null ? null : _relocatePathForMove(openedFile, sourcePath, destinationPath);

    if (nextFolder == _location.folder && nextOpenedFile == _location.openedFile) {
      return false;
    }

    _openEntry(nextOpenedFile ?? nextFolder, nextOpenedFile == null);
    return true;
  }

  void _moveSelectedPaths(String sourcePath, String destinationPath) {
    _mutateSelected((selected) {
      return selected.map((key) {
        final isFolder = _FilePathKey.isFolderKey(key);
        final movedPath = _relocatePathForMove(_FilePathKey.pathFromKey(key), sourcePath, destinationPath);
        return _FilePathKey.keyForPath(movedPath, isFolder);
      }).toSet();
    });
  }

  void _moveOptimisticPaths(String sourcePath, String destinationPath) {
    if (_optimisticEmptyTextFiles.isEmpty) {
      return;
    }

    final movedPaths = _optimisticEmptyTextFiles.map((path) => _relocatePathForMove(path, sourcePath, destinationPath)).toSet();
    _optimisticEmptyTextFiles
      ..clear()
      ..addAll(movedPaths);
  }

  void _moveThreadDisplayNameState(String sourcePath, String destinationPath) {
    if (_threadDisplayNamesByPath.isEmpty && _threadTitleResolutionsInFlight.isEmpty) {
      return;
    }

    String relocate(String path) => _relocatePathForMove(path, sourcePath, destinationPath);

    final nextDisplayNames = <String, String>{for (final entry in _threadDisplayNamesByPath.entries) relocate(entry.key): entry.value};
    final nextInFlight = _threadTitleResolutionsInFlight.map(relocate).toSet();

    if (!_canUpdateUi) {
      _threadDisplayNamesByPath = nextDisplayNames;
      _threadTitleResolutionsInFlight
        ..clear()
        ..addAll(nextInFlight);
      return;
    }

    final displayNamesChanged = !mapEquals(_threadDisplayNamesByPath, nextDisplayNames);
    final inFlightChanged =
        _threadTitleResolutionsInFlight.length != nextInFlight.length || !_threadTitleResolutionsInFlight.containsAll(nextInFlight);

    if (!displayNamesChanged && !inFlightChanged) {
      return;
    }

    setState(() {
      _threadDisplayNamesByPath = nextDisplayNames;
    });
    _threadTitleResolutionsInFlight
      ..clear()
      ..addAll(nextInFlight);
  }

  void _onFileMoved(String sourcePath, String destinationPath) {
    _moveSelectedPaths(sourcePath, destinationPath);
    _moveOptimisticPaths(sourcePath, destinationPath);
    _moveThreadDisplayNameState(sourcePath, destinationPath);

    if (_replaceLocationForMove(sourcePath, destinationPath)) {
      return;
    }

    final currentFolder = _folderSig.value;
    if (parentPath(sourcePath) == currentFolder || parentPath(destinationPath) == currentFolder) {
      unawaited(_refreshCurrentFolder());
    }
  }

  String? _threadIndexPathForFolder(String folder) {
    final trimmed = folder.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return joinPaths(trimmed, _threadIndexFileName);
  }

  String _displayNameForPath(String path) {
    final fileName = path.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? path;
    if (isThreadPath(path)) {
      final normalizedPath = normalizeThreadStoragePath(path);
      return threadFileDisplayNameFromPath(path, threadDisplayName: _threadDisplayNamesByPath[normalizedPath]);
    }
    return _displayFileName(fileName);
  }

  String _displayNameForEntry(StorageEntry entry) {
    final path = joinPaths(_folderSig.value, entry.name);
    return entry.isFolder ? entry.name : _displayNameForPath(path);
  }

  Future<void> _refreshFileAttachmentLinks() async {
    final links = await loadPowerboardsFileAttachmentLinks(widget.client);
    if (!_canUpdateUi) {
      return;
    }

    setState(() {
      _fileAttachmentLinks = links;
    });
  }

  String? _participantDisplayNameForId(String participantId) {
    final localParticipant = widget.client.localParticipant;
    if (localParticipant != null && localParticipant.id == participantId) {
      final name = localParticipant.getAttribute("name");
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
    }

    for (final participant in widget.client.messaging.remoteParticipants) {
      if (participant.id != participantId) {
        continue;
      }

      final name = participant.getAttribute("name");
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
    }

    return null;
  }

  void _rememberFileCreator(String path, String participantId) {
    final name = _participantDisplayNameForId(participantId);
    if (name == null) {
      return;
    }

    _fileCreatorNamesByPath[normalizePowerboardsAttachmentPath(path)] = name;
  }

  String _fallbackCreatorName() {
    final name = widget.client.localParticipant?.getAttribute("name");
    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }
    return 'Unknown';
  }

  List<PowerboardsFileAttachmentLink> _fileAttachmentLinksForPath(String path) {
    final normalizedPath = normalizePowerboardsAttachmentPath(path);
    final links = _fileAttachmentLinks.where((link) => link.filePath == normalizedPath).toList()
      ..sort((left, right) {
        final rightCreatedAt = right.createdAt?.millisecondsSinceEpoch ?? 0;
        final leftCreatedAt = left.createdAt?.millisecondsSinceEpoch ?? 0;
        return rightCreatedAt.compareTo(leftCreatedAt);
      });
    return links;
  }

  List<String> _linkedThreadNamesForPath(String path) {
    final seen = <String>{};
    final names = <String>[];
    for (final link in _fileAttachmentLinksForPath(path)) {
      final name = link.threadDisplayName.trim();
      final key = name.toLowerCase();
      if (name.isEmpty || seen.contains(key)) {
        continue;
      }

      seen.add(key);
      names.add(name);
    }
    return names;
  }

  String _creatorNameForPath(String path) {
    final normalizedPath = normalizePowerboardsAttachmentPath(path);
    final creator = _fileCreatorNamesByPath[normalizedPath];
    if (creator != null && creator.trim().isNotEmpty) {
      return creator.trim();
    }

    for (final link in _fileAttachmentLinksForPath(path)) {
      final attachedBy = link.createdBy.trim();
      if (attachedBy.isNotEmpty) {
        return attachedBy;
      }
    }

    return _fallbackCreatorName();
  }

  String _creatorInitialsForName(String creator) {
    final parts = creator.trim().split(RegExp(r'[\s@._-]+')).where((part) => part.trim().isNotEmpty).toList(growable: false);
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    final compact = creator.trim().replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (compact.isEmpty) {
      return '?';
    }
    return compact.substring(0, math.min(2, compact.length)).toUpperCase();
  }

  void _openV1LinkedThread(PbFilesItemData item, String threadName) {
    final target = _fileAttachmentLinksForPath(
      _v1PathForItem(item),
    ).firstWhereOrNull((link) => link.threadDisplayName.toLowerCase() == threadName.toLowerCase());
    if (target == null) {
      return;
    }

    _openEntry(target.threadPath, false);
  }

  String _v1UpdatedLabel(StorageEntry entry) {
    return entry.updatedAt?.modified() ?? entry.createdAt?.modified() ?? '';
  }

  int _v1UpdatedSort(StorageEntry entry) {
    return (entry.updatedAt ?? entry.createdAt)?.millisecondsSinceEpoch ?? 0;
  }

  String _v1SizeLabel(StorageEntry entry) {
    if (entry.isFolder) {
      return '-';
    }

    final size = entry.size;
    if (size == null) {
      return '-';
    }

    return _formatFileSizeBytes(size);
  }

  int _v1SizeSort(StorageEntry entry) {
    if (entry.isFolder) {
      return -1;
    }

    return entry.size ?? 0;
  }

  PbFilesItemData _v1ItemForEntry(StorageEntry entry) {
    final folder = _folderSig.value;
    final fullPath = _FilePathKey.pathForEntry(folder, entry);
    final key = _FilePathKey.keyForEntry(folder, entry);
    final updatedLabel = _v1UpdatedLabel(entry);
    final updatedSort = _v1UpdatedSort(entry);
    final sizeLabel = _v1SizeLabel(entry);
    final sizeSort = _v1SizeSort(entry);
    final creator = _creatorNameForPath(fullPath);
    final creatorInitials = _creatorInitialsForName(creator);

    if (entry.isFolder) {
      return PbFilesItemData(
        id: key,
        title: entry.name,
        type: PbAttachmentFileType.folder.defaultDisplayLabel,
        sizeLabel: sizeLabel,
        sizeSort: sizeSort,
        thread: '',
        creator: creator,
        creatorInitials: creatorInitials,
        updatedLabel: updatedLabel,
        updatedSort: updatedSort,
        parentPath: folder,
        folderPath: fullPath,
        fileType: PbAttachmentFileType.folder,
        kind: PbFilesItemKind.folder,
      );
    }

    final linkedThreads = _linkedThreadNamesForPath(fullPath);
    return PbFilesItemData.fromFileName(
      id: key,
      title: _displayNameForEntry(entry),
      thread: linkedThreads.firstOrNull ?? '',
      linkedThreads: linkedThreads,
      sizeLabel: sizeLabel,
      sizeSort: sizeSort,
      creator: creator,
      creatorInitials: creatorInitials,
      updatedLabel: updatedLabel,
      updatedSort: updatedSort,
      parentPath: folder,
      fileTypeKey: powerboardsV1FileTypeKeyForPath(fullPath),
      previewState: powerboardsV1PreviewStateForPath(fullPath),
    );
  }

  PbFilesItemData _v1ItemForPath(String fullPath) {
    final linkedThreads = _linkedThreadNamesForPath(fullPath);
    final creator = _creatorNameForPath(fullPath);

    return PbFilesItemData.fromFileName(
      id: _FilePathKey.keyForPath(fullPath, false),
      title: _displayNameForPath(fullPath),
      thread: linkedThreads.firstOrNull ?? '',
      linkedThreads: linkedThreads,
      sizeLabel: '-',
      sizeSort: 0,
      creator: creator,
      creatorInitials: _creatorInitialsForName(creator),
      updatedLabel: '',
      updatedSort: 0,
      parentPath: parentPath(fullPath),
      fileTypeKey: powerboardsV1FileTypeKeyForPath(fullPath),
      previewState: powerboardsV1PreviewStateForPath(fullPath),
    );
  }

  PbFilesItemData _v1ProcessingDeleteItem(PendingStorageDeleteEntry pendingDelete) {
    final path = pendingDelete.path;
    final fallbackName = path.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? path;
    final displayName = pendingDelete.isFolder ? fallbackName : _displayNameForPath(path);
    final title = displayName.isEmpty ? 'Deleting item' : 'Deleting $displayName';

    return _v1StateRow(
      id: _FilePathKey.keyForPath(path, pendingDelete.isFolder),
      title: title,
      path: path,
      isFolder: pendingDelete.isFolder,
      updatedLabel: 'Deleting',
      updatedSort: pendingDelete.startedAt.millisecondsSinceEpoch + pendingDelete.sequence,
      kind: PbFilesItemKind.processing,
    );
  }

  PbFilesItemData _v1StateRow({
    required String id,
    required String title,
    required String path,
    required bool isFolder,
    required String updatedLabel,
    required int updatedSort,
    required PbFilesItemKind kind,
  }) {
    return PbFilesItemData.fromFileName(
      id: id,
      title: title,
      type: '',
      thread: '',
      creator: '',
      creatorInitials: '',
      updatedLabel: updatedLabel,
      updatedSort: updatedSort,
      parentPath: parentPath(path),
      folderPath: isFolder ? path : '',
      fileType: isFolder ? PbAttachmentFileType.folder : PbAttachmentFileType.generic,
      kind: kind,
    );
  }

  PbFilesItemData _v1DeleteErrorRow({required String path, required bool isFolder}) {
    final fallbackName = path.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? path;
    final displayName = isFolder ? fallbackName : _displayNameForPath(path);
    final title = displayName.isEmpty ? 'Delete failed' : 'Failed to delete $displayName';

    return _v1StateRow(
      id: _FilePathKey.keyForPath(path, isFolder),
      title: title,
      path: path,
      isFolder: isFolder,
      updatedLabel: 'Failed',
      updatedSort: DateTime.now().millisecondsSinceEpoch,
      kind: PbFilesItemKind.processingError,
    );
  }

  PbFilesItemData _v1UploadErrorRow(String path) {
    final displayName = _displayNameForPath(path);
    final title = displayName.isEmpty ? 'Upload failed' : 'Failed upload $displayName';

    return _v1StateRow(
      id: 'upload-error:${PendingStorageDeletes.normalizePath(path)}:${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      path: path,
      isFolder: false,
      updatedLabel: 'Failed',
      updatedSort: DateTime.now().millisecondsSinceEpoch,
      kind: PbFilesItemKind.processingError,
    );
  }

  bool _v1EntryCanEnableFilter(StorageEntry entry) {
    final path = _FilePathKey.pathForEntry(_folderSig.value, entry);
    if (widget.hideSystem && entry.name.startsWith('.')) {
      return false;
    }

    if (_isDeletePending(path, entry.isFolder)) {
      return false;
    }

    final key = _FilePathKey.keyForEntry(_folderSig.value, entry);
    return !_v1FileStateRowsById.containsKey(key);
  }

  bool _v1FilterEnabled(List<StorageEntry> entries) {
    return entries.any(_v1EntryCanEnableFilter);
  }

  void _clearV1FilterIfUnavailable(bool filterEnabled) {
    if (filterEnabled || _v1FilterController.text.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _v1FilterEnabled(storageEntries.state.value ?? const <StorageEntry>[]) || _v1FilterController.text.isEmpty) {
        return;
      }

      _v1FilterController.clear();
      setState(() {});
    });
  }

  List<PbFilesItemData> _v1VisibleItems(List<StorageEntry> entries) {
    final query = _v1FilterController.text.trim().toLowerCase();
    final pendingDeleteItemsForFolder = PendingStorageDeletes.entriesFor(
      _deleteScope,
    ).where((pendingDelete) => parentPath(pendingDelete.path) == _folderSig.value).map(_v1ProcessingDeleteItem).toList();
    final pendingDeleteItems = pendingDeleteItemsForFolder.where((item) => query.isEmpty || item.filterText.contains(query)).toList();
    final stateRowsForFolder = _v1FileStateRowsById.values.where((item) => item.parentPath == _folderSig.value).toList();
    final stateRows = stateRowsForFolder.where((item) => query.isEmpty || item.filterText.contains(query)).toList();
    final stateRowIds = {for (final item in stateRowsForFolder) item.id};
    final items = entries
        .where((entry) => !widget.hideSystem || !entry.name.startsWith('.'))
        .where((entry) => !_isDeletePending(_FilePathKey.pathForEntry(_folderSig.value, entry), entry.isFolder))
        .where((entry) => !stateRowIds.contains(_FilePathKey.keyForEntry(_folderSig.value, entry)))
        .map(_v1ItemForEntry)
        .where((item) => query.isEmpty || item.filterText.contains(query))
        .toList();

    items.addAll(pendingDeleteItems);
    items.addAll(stateRows);
    items.sort(_compareV1Files);
    return items;
  }

  void _setV1FileStateRow(PbFilesItemData item) {
    setState(() => _v1FileStateRowsById[item.id] = item);
  }

  void _removeV1FileStateRow(PbFilesItemData item) {
    if (!_v1FileStateRowsById.containsKey(item.id)) {
      return;
    }

    setState(() => _v1FileStateRowsById.remove(item.id));
  }

  bool _v1ItemIsSelectable(PbFilesItemData item) {
    return item.kind == PbFilesItemKind.file || item.kind == PbFilesItemKind.folder;
  }

  Iterable<PbFilesItemData> _v1SelectableItems(Iterable<PbFilesItemData> items) {
    return items.where(_v1ItemIsSelectable);
  }

  List<PbFilesItemData> get _v1RecentlyOpenedFilesForSidePane {
    return [
      for (final item in _v1RecentlyOpenedFiles)
        if (item.canPreview && !_isDeletePending(_v1PathForItem(item), false)) item,
    ].take(_v1RecentlyOpenedFilesLimit).toList(growable: false);
  }

  void _recordV1RecentlyOpenedFile(PbFilesItemData item) {
    _v1RecentlyOpenedFiles = powerboardsV1RecordRecentlyOpenedFile(_v1RecentlyOpenedFiles, item);
  }

  int _compareV1Files(PbFilesItemData left, PbFilesItemData right) {
    if (left.kind == PbFilesItemKind.folder && right.kind != PbFilesItemKind.folder) {
      return -1;
    }
    if (left.kind != PbFilesItemKind.folder && right.kind == PbFilesItemKind.folder) {
      return 1;
    }

    final result = switch (_v1SortKey) {
      PbFilesSortKey.updated => left.updatedSort.compareTo(right.updatedSort),
      PbFilesSortKey.name => left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      PbFilesSortKey.type => left.type.toLowerCase().compareTo(right.type.toLowerCase()),
      PbFilesSortKey.size => left.sizeSort.compareTo(right.sizeSort),
      PbFilesSortKey.thread => left.threadLabel.toLowerCase().compareTo(right.threadLabel.toLowerCase()),
      PbFilesSortKey.creator => left.creator.toLowerCase().compareTo(right.creator.toLowerCase()),
    };

    return _v1SortDirectionDescending ? -result : result;
  }

  void _setV1Sort(PbFilesSortKey key) {
    setState(() {
      if (_v1SortKey == key) {
        _v1SortDirectionDescending = !_v1SortDirectionDescending;
      } else {
        _v1SortKey = key;
        _v1SortDirectionDescending = key == PbFilesSortKey.updated || key == PbFilesSortKey.size;
      }
    });
  }

  String _v1PathForItem(PbFilesItemData item) {
    return _FilePathKey.pathFromKey(item.id);
  }

  bool _v1IsFolder(PbFilesItemData item) {
    return item.kind == PbFilesItemKind.folder;
  }

  bool get _v1KeyboardPreviewNavigationActive =>
      _v1FilesKeyboardBrowseArmed || _v1KeyboardPreviewFileId != null || _v1KeyboardPreviewDirection != 0;

  void _clearV1KeyboardPreviewNavigationState() {
    _v1KeyboardPreviewFileId = null;
    _v1KeyboardPreviewDirection = 0;
    _v1FilesKeyboardBrowseArmed = false;
  }

  void _clearV1KeyboardPreviewNavigation() {
    if (!_v1KeyboardPreviewNavigationActive) {
      return;
    }

    setState(_clearV1KeyboardPreviewNavigationState);
  }

  bool _isV1FilesKeyboardNavigationBlocked() {
    return FocusManager.instance.primaryFocus?.context?.widget is EditableText;
  }

  void _openV1Preview(
    PbFilesItemData item, {
    bool openOverlay = false,
    bool openFullscreen = false,
    bool restoreOverlayOnClose = false,
    bool armKeyboardBrowse = true,
    int keyboardDirection = 0,
  }) {
    if (!item.canPreview) {
      return;
    }

    if (armKeyboardBrowse) {
      _v1FilesKeyboardFocusNode.requestFocus();
    }

    setState(() {
      _v1PreviewFile = item;
      _v1FilePreviewFullscreen = openFullscreen;
      _v1RestoreRoomPanelOverlayOnPreviewClose = restoreOverlayOnClose && (openOverlay || openFullscreen);
      _v1FilesRoomPanelCollapsed = false;
      _v1FilesRoomPanelOverlayOpen = openFullscreen ? false : openOverlay;
      if (armKeyboardBrowse) {
        _v1KeyboardPreviewFileId = keyboardDirection == 0 ? null : item.id;
        _v1KeyboardPreviewDirection = keyboardDirection;
        _v1FilesKeyboardBrowseArmed = true;
      } else {
        _clearV1KeyboardPreviewNavigationState();
      }
      _recordV1RecentlyOpenedFile(item);
      _clearSelected();
    });
    _setV1FilesRoomPanelCollapsed(false);
    setPreviewFilePreviewFullscreen(openFullscreen);
  }

  void _closeV1Preview() {
    final clearOpenedFileRoute = _openedFile != null && !_usesAdaptiveMobileLayout(context) && powerboardsUsesDesktopUiPreview(context);
    final restoreRoomPanelOverlay = _v1RestoreRoomPanelOverlayOnPreviewClose && !clearOpenedFileRoute;

    setState(() {
      _v1PreviewFile = null;
      _v1FilePreviewFullscreen = false;
      _v1FilesRoomPanelOverlayOpen = restoreRoomPanelOverlay;
      _v1RestoreRoomPanelOverlayOnPreviewClose = false;
      _clearV1KeyboardPreviewNavigationState();
    });
    setPreviewFilePreviewFullscreen(false);

    if (clearOpenedFileRoute) {
      _closeFile();
    }
  }

  void _revealV1PreviewPanelForKeyboard({required bool openOverlay}) {
    if (openOverlay) {
      if (!_v1FilesRoomPanelOverlayOpen) {
        setState(() => _v1FilesRoomPanelOverlayOpen = true);
      }
      return;
    }

    _setV1FilesRoomPanelCollapsed(false);
  }

  void _openV1PreviewFromKeyboard(PbFilesItemData item, {required bool openOverlay, required bool openFullscreen, required int direction}) {
    _openV1Preview(item, openOverlay: openOverlay, openFullscreen: openFullscreen, keyboardDirection: direction);
  }

  KeyEventResult _handleV1FilesKeyEvent(
    KeyEvent event, {
    required List<PbFilesItemData> items,
    required PbFilesItemData? previewFile,
    required bool responsivePanel,
    required bool openFullscreen,
  }) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (!_v1KeyboardPreviewNavigationActive) {
        return KeyEventResult.ignored;
      }

      _clearV1KeyboardPreviewNavigation();
      return KeyEventResult.handled;
    }

    if (key != LogicalKeyboardKey.arrowDown && key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }

    if (_selectedSig.value.isNotEmpty || previewFile == null || !_v1FilesKeyboardBrowseArmed || _isV1FilesKeyboardNavigationBlocked()) {
      return KeyEventResult.ignored;
    }

    final previewableItems = items.where((item) => item.canPreview).toList(growable: false);
    final currentIndex = previewableItems.indexWhere((item) => item.id == previewFile.id);
    if (currentIndex < 0) {
      return KeyEventResult.ignored;
    }

    final direction = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
    final nextIndex = math.max(0, math.min(previewableItems.length - 1, currentIndex + direction));
    if (nextIndex == currentIndex) {
      _revealV1PreviewPanelForKeyboard(openOverlay: responsivePanel);
      return KeyEventResult.handled;
    }

    _openV1PreviewFromKeyboard(
      previewableItems[nextIndex],
      openOverlay: responsivePanel,
      openFullscreen: openFullscreen,
      direction: direction,
    );
    return KeyEventResult.handled;
  }

  void _setV1PreviewFullscreen(bool fullscreen) {
    setState(() {
      _v1FilePreviewFullscreen = fullscreen;
      if (fullscreen) {
        _v1RestoreRoomPanelOverlayOnPreviewClose = _v1RestoreRoomPanelOverlayOnPreviewClose || _v1FilesRoomPanelOverlayOpen;
        _v1FilesRoomPanelOverlayOpen = false;
      } else if (_v1PreviewFile != null || _openedFile != null) {
        _v1FilesRoomPanelOverlayOpen = true;
      }
    });
    setPreviewFilePreviewFullscreen(fullscreen);
  }

  void _closeV1FilesRoomPanelOverlay() {
    _v1FilesRoomPanelOverlayController.hide();
    setState(() {
      _v1FilesRoomPanelOverlayOpen = false;
      if (_v1PreviewFile == null && _openedFile == null) {
        _v1RestoreRoomPanelOverlayOnPreviewClose = false;
      }
    });
  }

  Widget _buildV1PreviewContent(PbFilesItemData item) {
    final path = _v1PathForItem(item);
    return fileViewer(widget.client, path) ??
        DocumentPane(
          path: path,
          room: widget.client,
          noPreviewBuilder: (context, _) => Center(
            child: PbFilePreviewStateCard(file: item.toAttachmentData(), state: PbAttachmentPreviewState.unavailable),
          ),
        );
  }

  PbFilesItemData? _v1PreviewFileFromRoute(List<PbFilesItemData> items) {
    final openedFile = _openedFile;
    if (openedFile == null) {
      return null;
    }

    final key = _FilePathKey.keyForPath(openedFile, false);
    final item = items.firstWhereOrNull((item) => item.id == key);
    if (item != null) {
      return item.canPreview ? item : null;
    }

    return _v1ItemForPath(openedFile);
  }

  void _toggleV1VisibleSelection(List<PbFilesItemData> items) {
    _clearV1KeyboardPreviewNavigation();

    final visibleIds = _v1SelectableItems(items).map((item) => item.id).toSet();
    final selected = _visibleSelected.value;
    final allSelected = visibleIds.isNotEmpty && visibleIds.every(selected.contains);

    _mutateSelected((next) {
      if (allSelected) {
        next.removeAll(visibleIds);
      } else {
        next.addAll(visibleIds);
      }
      return next;
    });
  }

  List<ChatFilePromptAction> _filePromptActionsForPath(String fullPath, {required bool isFolder}) {
    if (isFolder || widget.services?.state.isReady != true) {
      return const <ChatFilePromptAction>[];
    }

    final actions = resolveChatFilePromptActions(services: widget.services!.state.value!, filePath: fullPath);
    if (actions.isNotEmpty) {
      return actions;
    }

    final fallback = _fallbackFilePromptAction();
    return fallback == null ? const <ChatFilePromptAction>[] : [fallback];
  }

  ChatFilePromptAction? _fallbackFilePromptAction() {
    if (widget.services?.state.isReady != true) {
      return null;
    }

    for (final service in widget.services!.state.value!) {
      final descriptor = ma.serviceConversationDescriptor(service, remoteParticipants: widget.client.messaging.remoteParticipants);
      if (descriptor?.isChat != true) {
        continue;
      }

      final rawAgentName = service.agents.firstOrNull?.name;
      if (rawAgentName == null) {
        continue;
      }

      final agentName = rawAgentName.trim();
      if (agentName.isNotEmpty) {
        return defaultChatFilePromptAction(agentName: agentName);
      }
    }

    for (final participant in widget.client.messaging.remoteParticipants) {
      final descriptor = ma.participantConversationDescriptor(participant);
      if (descriptor?.isChat != true) {
        continue;
      }

      final agentName = ma.participantDisplayName(participant);
      if (agentName != null) {
        return defaultChatFilePromptAction(agentName: agentName);
      }
    }

    return null;
  }

  Future<void> _openManageAgentsForFilePrompt() async {
    final projectId = widget.projectId?.trim();
    if (projectId == null || projectId.isEmpty) {
      if (mounted) {
        ShadToaster.of(context).show(
          const ShadToast.destructive(
            title: Text("No chat agent available"),
            description: Text("Install a chat agent before asking about files."),
          ),
        );
      }
      return;
    }

    await showManageAgentsSurface(
      context: context,
      projectId: projectId,
      room: widget.client,
      onServiceChanged: () {
        widget.services?.refresh();
      },
    );
    if (!mounted) {
      return;
    }
    widget.services?.refresh();
  }

  Future<void> _startDefaultFilePrompt(String fullPath, {PbFilesItemData? recentlyOpenedItem}) async {
    final action = _filePromptActionsForPath(fullPath, isFolder: false).firstOrNull;
    if (action == null) {
      await _openManageAgentsForFilePrompt();
      return;
    }

    final callback = widget.onV1FilePromptRequested;
    if (callback != null) {
      if (recentlyOpenedItem != null && recentlyOpenedItem.canPreview) {
        setState(() {
          _recordV1RecentlyOpenedFile(recentlyOpenedItem);
        });
      }
      await callback(action, fullPath);
      return;
    }

    try {
      final threadPath = await startChatFilePromptThread(room: widget.client, action: action, filePath: fullPath);
      if (!mounted) {
        return;
      }

      _openEntry(threadPath, false);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ShadToaster.of(context).show(ShadToast.destructive(title: const Text("Unable to start chat"), description: Text("$error")));
    }
  }

  Future<void> _closeThreadIndexDocument({bool refreshUi = true}) async {
    final document = _threadIndexDocument;
    final threadIndexPath = _threadIndexPath;
    if (document != null) {
      document.removeListener(_onThreadIndexChanged);
    }
    _threadIndexDocument = null;
    _threadIndexPath = null;
    _threadDisplayNamesByPath = const <String, String>{};
    _threadTitleResolutionsInFlight.clear();

    if (threadIndexPath != null) {
      try {
        await widget.client.sync.close(threadIndexPath);
      } catch (_) {}
    }

    if (refreshUi && _canUpdateUi) {
      setState(() {});
    }
  }

  void _onThreadIndexChanged() {
    if (!_canUpdateUi) {
      return;
    }
    _refreshThreadDisplayNames();
  }

  Future<void> _rebindThreadIndexDocument() async {
    final nextThreadIndexPath = _threadIndexPathForFolder(_folderSig.value);
    if (_threadIndexPath == nextThreadIndexPath && _threadIndexDocument != null) {
      _refreshThreadDisplayNames();
      return;
    }

    await _closeThreadIndexDocument();
    if (!_canUpdateUi) {
      return;
    }
    if (nextThreadIndexPath == null) {
      return;
    }

    try {
      final exists = await widget.client.storage.exists(nextThreadIndexPath);
      if (!_canUpdateUi || !exists) {
        return;
      }

      final document = await widget.client.sync.open(nextThreadIndexPath);
      if (!_canUpdateUi || _threadIndexPathForFolder(_folderSig.value) != nextThreadIndexPath) {
        try {
          await widget.client.sync.close(nextThreadIndexPath);
        } catch (_) {}
        return;
      }

      document.addListener(_onThreadIndexChanged);
      _threadIndexDocument = document;
      _threadIndexPath = nextThreadIndexPath;
      _refreshThreadDisplayNames();
    } catch (_) {
      if (!_canUpdateUi) {
        return;
      }
      setState(() {
        _threadDisplayNamesByPath = const <String, String>{};
      });
    }
  }

  void _refreshThreadDisplayNames() {
    final document = _threadIndexDocument;
    final next = <String, String>{};
    if (document != null) {
      for (final node in document.root.getChildren().whereType<MeshElement>()) {
        if (node.tagName != 'thread') {
          continue;
        }

        final rawPath = node.getAttribute('path');
        if (rawPath is! String) {
          continue;
        }
        final path = normalizeThreadStoragePath(rawPath);
        if (path.isEmpty) {
          continue;
        }

        final rawName = node.getAttribute('name');
        if (rawName is! String) {
          continue;
        }
        final displayName = rawName.trim();
        if (displayName.isEmpty) {
          continue;
        }

        next[path] = displayName;
      }
    }

    if (!mapEquals(_threadDisplayNamesByPath, next)) {
      if (!_canUpdateUi) {
        _threadDisplayNamesByPath = next;
        return;
      }
      setState(() {
        _threadDisplayNamesByPath = next;
      });
    }
  }

  MeshElement? _threadNodeForPath(String path) {
    final document = _threadIndexDocument;
    if (document == null) {
      return null;
    }

    final normalizedPath = normalizeThreadStoragePath(path);

    return document.root.getChildren().whereType<MeshElement>().firstWhereOrNull((node) {
      final nodePath = node.getAttribute('path');
      return node.tagName == 'thread' && nodePath is String && normalizeThreadStoragePath(nodePath) == normalizedPath;
    });
  }

  void _removePath(String path, {isFolder = false}) {
    if (parentPath(path) != _folderSig.value) return;

    final ready = storageEntries.state.asReady;
    if (ready == null) return; // ignore if loading/error

    final name = path.split('/').where((s) => s.isNotEmpty).last;
    final next = List<StorageEntry>.of(ready.value);
    next.removeWhere((e) => e.name == name && e.isFolder == isFolder);
    _v1FileStateRowsById.removeWhere((_, item) => _v1StateRowMatchesPath(item, path, isFolder: isFolder));
    _toggleSelected(_FilePathKey.keyForPath(path, isFolder), false);

    _setEntries(next);
  }

  void _setEntries(List<StorageEntry> entries) {
    storageEntries.state = ResourceState.ready(entries);
    final hasThreadIndex = entries.any((entry) => !entry.isFolder && entry.name == _threadIndexFileName);
    final expectedThreadIndexPath = _threadIndexPathForFolder(_folderSig.value);
    if (hasThreadIndex && _threadIndexDocument == null && expectedThreadIndexPath != null) {
      unawaited(_rebindThreadIndexDocument());
    } else if (!hasThreadIndex && _threadIndexPath == expectedThreadIndexPath && _threadIndexDocument != null) {
      unawaited(_closeThreadIndexDocument());
    }
  }

  void _setSort(FileSort sort) {
    _sortSig.value = sort;
  }

  void _setSelected(Set<String> next) {
    _selectedSig.value = Set<String>.of(next);
  }

  void _mutateSelected(Set<String> Function(Set<String>) fn) {
    final next = fn(Set<String>.of(_selectedSig.value));
    _selectedSig.value = next;
  }

  void _toggleSelected(String key, bool selected) {
    _mutateSelected((s) {
      if (selected) {
        s.add(key);
      } else {
        s.remove(key);
      }
      return s;
    });
  }

  void _toggleAllSelected(bool selected) {
    if (selected) {
      _selectAllVisible();
    } else {
      _clearSelected();
    }
  }

  void _selectAllVisible() {
    final folder = _folderSig.value;
    final keys = _visibleSortedEntries.value
        .where((entry) => !_isDeletePending(joinPaths(folder, entry.name), entry.isFolder))
        .map((entry) => _FilePathKey.keyForEntry(folder, entry))
        .toSet();
    _setSelected(keys);
  }

  void _clearSelected() => _setSelected(<String>{});

  void _activateMobileSelectionMode() {
    _selectAllVisible();
    setState(() {
      _forceShowSelect = true;
    });
  }

  void _clearMobileSelectionMode() {
    _clearSelected();
    setState(() {
      _forceShowSelect = false;
    });
  }

  void _toggleForceShowSelect() {
    setState(() {
      _forceShowSelect = !_forceShowSelect;
    });
  }

  void _openEntry(String path, bool isFolder) {
    _clearV1KeyboardPreviewNavigation();

    final state = PathRouteMatch.of(context);
    final currentUri = state.uri;

    final updatedQueryParameters = Map<String, String>.from(currentUri.queryParameters);
    updatedQueryParameters['p'] = path.isEmpty ? '' : (isFolder ? '$path/' : path);
    updatedQueryParameters.remove(filePreviewOriginQueryParameter);

    final newUri = currentUri.replace(queryParameters: updatedQueryParameters);
    context.go(newUri.toString());
  }

  Future<void> _cycleFile(int offset) async {
    await storageEntries.untilReady();

    final files = _visibleSortedFiles.value;
    if (files.length < 2 || _openedFile == null) return;

    final currentIndex = files.indexOf(_openedFile!);
    if (currentIndex < 0) return;

    final nextIndex = (currentIndex + offset + files.length) % files.length;
    _openEntry(files[nextIndex], false);
  }

  void _closeFile() {
    final currentUri = PathRouteMatch.of(context).uri;
    final previewOrigin = currentUri.queryParameters[filePreviewOriginQueryParameter];
    if (previewOrigin != null && previewOrigin.isNotEmpty && previewOrigin != currentUri.toString()) {
      context.go(previewOrigin);
      return;
    }

    _openEntry(_folderSig.value, true);
  }

  void _previousFile() => _cycleFile(-1);
  void _nextFile() => _cycleFile(1);

  Future<List<StorageEntry>> _getChildren(String folderPath) async {
    return widget.client.storage.list(folderPath);
  }

  Future<void> _uploadFile(Stream<Uint8List> stream, String path, int totalBytes) async {
    if (totalBytes == 0 && _isEditableTextFile(path)) {
      _optimisticEmptyTextFiles.add(path);
    }

    final upload = MeshagentFileUpload(room: widget.client, path: path, dataStream: stream, size: totalBytes);
    uploadNotifications.addUpload(upload, totalBytes);

    unawaited(
      upload.done
          .then((_) async {
            if (!mounted) {
              return;
            }

            if (parentPath(path) == _folderSig.value) {
              await _refreshCurrentFolder();
            }
          })
          .catchError((Object error) {
            if (!mounted || !_usesDesktopV1FilesBrowser()) {
              return;
            }

            _setV1FileStateRow(_v1UploadErrorRow(path));
          }),
    );
  }

  Future<void> _downloadFile(String path) async {
    final url = await widget.client.storage.downloadUrl(path, download: true);
    launchUrl(Uri.parse(url));
  }

  Future<void> _shareFile(String path) async {
    try {
      await shareRemoteStorageFile(context: context, client: widget.client, path: path);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ShadToaster.of(context).show(ShadToast.destructive(title: const Text('Unable to share file'), description: Text('$error')));
    }
  }

  Future<void> _deleteFile(
    String path, {
    PendingStorageDeleteHandle? pendingDelete,
    DateTime? pendingDeleteDisplayUntil,
    bool prepareV1Feedback = true,
  }) async {
    _toggleSelected(_FilePathKey.keyForPath(path, false), false);
    final displayUntil = pendingDeleteDisplayUntil ?? DateTime.now().add(_v1DeleteProcessingStep);
    final deleteHandle = pendingDelete ?? PendingStorageDeletes.begin(scope: _deleteScope, path: path, isFolder: false);
    if (prepareV1Feedback) {
      _prepareV1PendingDeleteFeedback([_FilePathKey.keyForPath(path, false)]);
    }

    try {
      await Future.wait<void>([
        widget.client.storage.delete(path).then((_) => _onFileDeleted(path)),
        _waitForV1PendingDeleteDisplay(displayUntil),
      ]);
    } catch (_) {
      deleteHandle.complete();
      if (mounted && _usesDesktopV1FilesBrowser()) {
        _setV1FileStateRow(_v1DeleteErrorRow(path: path, isFolder: false));
      }
      rethrow;
    } finally {
      deleteHandle.complete();
    }
  }

  Future<void> _deleteFolder(
    String folderPath, {
    PendingStorageDeleteHandle? pendingDelete,
    DateTime? pendingDeleteDisplayUntil,
    bool prepareV1Feedback = true,
  }) async {
    _toggleSelected(_FilePathKey.keyForPath(folderPath, true), false);
    final displayUntil = pendingDeleteDisplayUntil ?? DateTime.now().add(_v1DeleteProcessingStep);
    final deleteHandle = pendingDelete ?? PendingStorageDeletes.begin(scope: _deleteScope, path: folderPath, isFolder: true);
    if (prepareV1Feedback) {
      _prepareV1PendingDeleteFeedback([_FilePathKey.keyForPath(folderPath, true)]);
    }

    try {
      await Future.wait<void>([
        widget.client.storage.delete(folderPath, recursive: true).then((_) => _removePath(folderPath, isFolder: true)),
        _waitForV1PendingDeleteDisplay(displayUntil),
      ]);
    } catch (_) {
      deleteHandle.complete();
      if (mounted && _usesDesktopV1FilesBrowser()) {
        _setV1FileStateRow(_v1DeleteErrorRow(path: folderPath, isFolder: true));
      }
      rethrow;
    } finally {
      deleteHandle.complete();
    }
  }

  String? _validateRenameInput(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Name cannot be empty';
    }
    if (trimmed.contains('/') || trimmed.contains('\\')) {
      return 'Enter a name, not a path';
    }
    if (trimmed == '.' || trimmed == '..') {
      return 'Enter a valid name';
    }
    return null;
  }

  bool _usesThreadDisplayNameRename(String fullPath, {required bool isFolder}) {
    return !isFolder && isThreadPath(fullPath);
  }

  String _renameFieldInitialValue(String fullPath, {required bool isFolder}) {
    if (_usesThreadDisplayNameRename(fullPath, isFolder: isFolder)) {
      final normalizedPath = normalizeThreadStoragePath(fullPath);
      return threadFileDisplayNameFromPath(fullPath, threadDisplayName: _threadDisplayNamesByPath[normalizedPath]);
    }

    return p.basename(fullPath);
  }

  String _renameConflictDisplayName(String nextName, {required bool isFolder}) {
    if (!isFolder && isThreadFileName(nextName)) {
      return threadFileDisplayNameFromPath(nextName);
    }

    return nextName;
  }

  Future<String?> _promptRenamePath(String fullPath, {required bool isFolder}) async {
    final initialValue = _renameFieldInitialValue(fullPath, isFolder: isFolder);
    final usesThreadDisplayNameRename = _usesThreadDisplayNameRename(fullPath, isFolder: isFolder);

    return await showPowerboardsAlertDialog<String>(
      context: context,
      builder: (context) {
        return ControlledForm(
          builder: (context, controller, formKey) {
            void submit() {
              if (!formKey.currentState!.saveAndValidate()) {
                return;
              }

              final formData = formKey.currentState!.value;
              final name = (formData["name"] as String? ?? "").trim();
              Navigator.of(context).pop(name);
            }

            return PowerboardsShadDialog.compact(
              crossAxisAlignment: CrossAxisAlignment.start,
              title: Text(isFolder ? "Rename folder" : (usesThreadDisplayNameRename ? "Rename thread" : "Rename file")),
              actions: [
                ShadButton.outline(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                ShadButton(onPressed: submit, child: const Text("Rename")),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    PowerboardsAdaptiveInputFormField(
                      id: "name",
                      initialValue: initialValue,
                      validator: _validateRenameInput,
                      label: const Text("Name"),
                      autofocus: true,
                      onSubmitted: (_) => submit(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _renamePath(String fullPath, {required bool isFolder}) async {
    final usesThreadDisplayNameRename = _usesThreadDisplayNameRename(fullPath, isFolder: isFolder);
    final currentName = p.basename(fullPath);
    final nextName = await _promptRenamePath(fullPath, isFolder: isFolder);
    if (!mounted) {
      return;
    }
    if (nextName == null) {
      return;
    }

    if (usesThreadDisplayNameRename) {
      final currentDisplayName = _renameFieldInitialValue(fullPath, isFolder: isFolder);
      if (nextName == currentDisplayName) {
        return;
      }

      final threadNode = _threadNodeForPath(fullPath);
      if (threadNode != null) {
        threadNode.setAttribute('name', nextName);
        final normalizedPath = normalizeThreadStoragePath(fullPath);
        setState(() {
          _threadDisplayNamesByPath = <String, String>{..._threadDisplayNamesByPath, normalizedPath: nextName};
        });
        return;
      }
    }

    final resolvedNextName = usesThreadDisplayNameRename ? threadFileNameFromDisplayName(nextName) : nextName;
    if (resolvedNextName == currentName) {
      return;
    }

    final destinationPath = joinPaths(parentPath(fullPath), resolvedNextName);
    final toaster = ShadToaster.of(context);

    try {
      if (await widget.client.storage.exists(destinationPath)) {
        if (!mounted) {
          return;
        }

        toaster.show(
          ShadToast.destructive(
            title: const Text("Rename failed"),
            description: Text(
              "${isFolder ? 'Folder' : 'File'} `${_renameConflictDisplayName(resolvedNextName, isFolder: isFolder)}` already exists in this location.",
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      await widget.client.storage.move(fullPath, destinationPath);
      if (!mounted) {
        return;
      }
      _onFileMoved(fullPath, destinationPath);
    } catch (error) {
      if (!mounted) {
        return;
      }

      toaster.show(
        ShadToast.destructive(title: const Text("Rename failed"), description: Text("$error"), duration: const Duration(seconds: 6)),
      );
    }
  }

  String _shellQuote(String value) {
    if (value.isEmpty) {
      return "''";
    }
    return "'${value.replaceAll("'", r"'\''")}'";
  }

  Future<void> _refreshCurrentFolder() async {
    final entries = await _getChildren(_folderSig.value);
    if (!mounted) {
      return;
    }

    for (final entry in entries) {
      if (entry.isFolder || entry.size == null || entry.size == 0) {
        continue;
      }
      _optimisticEmptyTextFiles.remove(joinPaths(_folderSig.value, entry.name));
    }

    _setEntries(entries);
  }

  Future<void> _compressFolder(String folderPath) async {
    final toaster = ShadToaster.of(context);
    final folderName = p.basename(folderPath);
    final parentFolder = parentPath(folderPath);

    final zipFileName = "$folderName.zip";

    toaster.show(
      ShadToast(title: const Text("Compressing folder"), description: Text("Creating $zipFileName"), duration: const Duration(seconds: 5)),
    );

    String? containerId;

    try {
      containerId = await widget.client.containers.run(
        image: "docker.io/joshkeegan/zip:latest",
        command: "/usr/bin/zip -r ${_shellQuote(zipFileName)} ${_shellQuote(folderName)}",
        mountPath: "/data",
        workingDir: "/data/$parentFolder",
        private: true,
      );

      final returnCode = await widget.client.containers.waitForExit(containerId: containerId);

      if (!mounted) {
        return;
      }

      if (returnCode == 0) {
        toaster.show(
          ShadToast(
            title: const Text("Compression complete"),
            description: Text("Created $zipFileName"),
            duration: const Duration(seconds: 5),
          ),
        );
        _refreshCurrentFolder();
      } else {
        toaster.show(
          ShadToast.destructive(
            title: const Text("Compression failed"),
            description: Text("Ups something went wrong while compressing the folder. Please try again. (Error code: $returnCode)"),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      try {
        if (containerId != null) {
          await widget.client.containers.deleteContainer(containerId: containerId);
        }
      } catch (e) {
        debugPrint("Failed to clean up compression container: $e");
      }
    }
  }

  Future<void> _onFileDrop(String name, Stream<Uint8List> stream, int? fileSize) async {
    final fileName = joinPaths(_folderSig.value, name);
    await _uploadFile(stream, fileName, fileSize ?? 0);
  }

  Future<void> _addPhotos(String path) async {
    await FileUploadHelper.pickAndUploadPhotos(path: path, onUpload: _uploadFile);
  }

  Future<void> _addFiles(String path) async {
    await FileUploadHelper.pickAndUploadFiles(path: path, onUpload: _uploadFile);
  }

  Future<void> _addFolder(String path) async {
    final result = await showPowerboardsAlertDialog<String>(
      context: context,
      builder: (context) {
        return ControlledForm(
          builder: (context, controller, formKey) {
            void submit() {
              if (!formKey.currentState!.saveAndValidate()) {
                return;
              }

              final formData = formKey.currentState!.value;
              final name = formData["name"] ?? "";

              Navigator.of(context).pop(name);
            }

            return PowerboardsShadDialog.compact(
              crossAxisAlignment: CrossAxisAlignment.start,
              title: Text("New folder"),
              actions: [
                ShadButton.outline(
                  onPressed: () {
                    Navigator.of(context).pop(null);
                  },
                  child: const Text('Cancel'),
                ),

                ShadButton(onPressed: submit, child: const Text("OK")),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    PowerboardsAdaptiveInputFormField(
                      initialValue: "",
                      validator: TextValidators.folder,
                      id: "name",
                      label: Text("Name"),
                      autofocus: true,
                      onSubmitted: (_) => submit(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result == null) {
      return;
    }

    final fileName = joinPaths(path, "$result/$placeholderFileName");
    await _uploadFile(Stream.empty(), fileName, 0);
  }

  Future<bool> _confirmAndDelete(String fullPath, bool isFolder) async {
    final name = fullPath.split('/').where((s) => s.isNotEmpty).last;
    final displayName = isFolder ? name : _displayNameForPath(fullPath);
    final bool? confirmDelete = await showPowerboardsAlertDialog<bool>(
      context: context,
      builder: (context) => PowerboardsShadDialog.compactAlert(
        title: const Text("Confirm Delete"),
        description: Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text("Are you sure you want to delete ${isFolder ? 'folder $displayName and all its contents' : displayName}?"),
        ),
        actions: [
          ShadButton.outline(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
          ShadButton.destructive(child: const Text('Delete'), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        if (isFolder) {
          await _deleteFolder(fullPath);
        } else {
          await _deleteFile(fullPath);
        }
      } catch (error) {
        if (!mounted) {
          return false;
        }

        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: Text("Unable to delete ${isFolder ? 'folder' : 'file'}"),
            description: Text("$error"),
            duration: const Duration(seconds: 6),
          ),
        );
        return false;
      }
      return true;
    }

    return false;
  }

  Future<void> _confirmAndDeleteSelected() async {
    final selected = _visibleSelected.value;
    if (selected.isEmpty) return;

    final toaster = ShadToaster.of(context);
    final isMobile = _usesAdaptiveMobileLayout(context);
    final count = selected.length;
    final names = selected.take(6).map((key) {
      final path = _FilePathKey.pathFromKey(key);
      if (_FilePathKey.isFolderKey(key)) {
        final folderName = path.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? path;
        return '$folderName/';
      }
      return _displayNameForPath(path);
    }).toList();

    final confirmDelete = await showPowerboardsAlertDialog<bool>(
      context: context,
      builder: (context) => PowerboardsShadDialog.compactAlert(
        title: const Text("Confirm Delete"),
        description: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Delete $count item${count == 1 ? '' : 's'}?"),
              const SizedBox(height: 8),
              for (final n in names) Text("• $n"),
              if (count > names.length) Text("• …and ${count - names.length} more"),
            ],
          ),
        ),
        actions: [
          ShadButton.outline(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
          ShadButton.destructive(child: const Text('Delete'), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );

    if (confirmDelete != true) return;

    int success = 0;
    final failures = <String>[];
    final toDelete = _usesDesktopV1FilesBrowser()
        ? [
            for (final item in _v1VisibleItems(storageEntries.state.value ?? const <StorageEntry>[]))
              if (selected.contains(item.id) && _v1ItemIsSelectable(item)) item.id,
          ]
        : selected.toList();
    final pendingDeletes = <String, _PendingDeleteOperation>{};
    final batchStartedAt = DateTime.now();

    for (final key in toDelete) {
      final isFolder = _FilePathKey.isFolderKey(key);
      final path = _FilePathKey.pathFromKey(key);
      if (_isDeletePending(path, isFolder)) {
        continue;
      }

      pendingDeletes[key] = _PendingDeleteOperation(
        handle: PendingStorageDeletes.begin(scope: _deleteScope, path: path, isFolder: isFolder),
        displayUntil: batchStartedAt.add(Duration(milliseconds: _v1DeleteProcessingStep.inMilliseconds * (pendingDeletes.length + 1))),
      );
    }

    _prepareV1PendingDeleteFeedback(pendingDeletes.keys);

    if (isMobile) {
      _clearMobileSelectionMode();
    } else {
      _clearSelected();
    }

    for (final key in toDelete) {
      final pendingDeleteOperation = pendingDeletes[key];
      if (pendingDeleteOperation == null) {
        continue;
      }

      final isFolder = _FilePathKey.isFolderKey(key);
      final path = _FilePathKey.pathFromKey(key);

      try {
        if (isFolder) {
          await _deleteFolder(
            path,
            pendingDelete: pendingDeleteOperation.handle,
            pendingDeleteDisplayUntil: pendingDeleteOperation.displayUntil,
            prepareV1Feedback: false,
          );
        } else {
          await _deleteFile(
            path,
            pendingDelete: pendingDeleteOperation.handle,
            pendingDeleteDisplayUntil: pendingDeleteOperation.displayUntil,
            prepareV1Feedback: false,
          );
        }
        success++;
      } catch (e) {
        failures.add(path);
      }
    }

    if (failures.isEmpty) {
      toaster.show(ShadToast(description: Text("Deleted $success item${success == 1 ? '' : 's'}"), duration: const Duration(seconds: 4)));
    } else {
      toaster.show(
        ShadToast.destructive(description: Text("Deleted $success, failed ${failures.length}"), duration: const Duration(seconds: 6)),
      );
    }
  }

  Future<void> _downloadSelected() async {
    final selected = _visibleSelected.value;
    if (selected.isEmpty) return;

    final toaster = ShadToaster.of(context);
    var downloaded = 0;
    var skippedFolders = 0;

    for (final key in selected) {
      if (_FilePathKey.isFolderKey(key)) {
        skippedFolders++;
        continue;
      }

      await _downloadFile(_FilePathKey.pathFromKey(key));
      downloaded++;
    }

    if (!mounted) {
      return;
    }

    if (downloaded > 0 && skippedFolders == 0) {
      toaster.show(
        ShadToast(description: Text("Downloading $downloaded file${downloaded == 1 ? '' : 's'}"), duration: const Duration(seconds: 4)),
      );
      return;
    }

    if (downloaded > 0) {
      toaster.show(
        ShadToast(
          description: Text(
            "Downloading $downloaded file${downloaded == 1 ? '' : 's'}. Skipped $skippedFolders folder${skippedFolders == 1 ? '' : 's'}.",
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    toaster.show(
      ShadToast(description: const Text("Folders can’t be downloaded from multi-select yet."), duration: const Duration(seconds: 4)),
    );
  }

  void _showNewTextFileDialog() {
    showPowerboardsAlertDialog<String>(
      context: context,
      builder: (context) {
        return ControlledForm(
          builder: (context, controller, formKey) {
            Future<void> submit(_) async {
              if (!formKey.currentState!.saveAndValidate()) {
                return;
              }

              final formData = formKey.currentState!.value;
              final String name = formData["name"] ?? "";
              final String trimmedName = name.trim();
              String? resolvedName = trimmedName;

              if (!trimmedName.contains('.')) {
                resolvedName = await showPowerboardsAlertDialog<String>(
                  context: context,
                  builder: (context) {
                    return PowerboardsShadDialog.compact(
                      title: const Text("Add .txt extension?"),
                      description: Text("`$trimmedName` has no extension."),
                      actions: [
                        ShadButton.outline(onPressed: () => Navigator.of(context).pop(trimmedName), child: const Text("No extension")),
                        ShadButton(onPressed: () => Navigator.of(context).pop("$trimmedName.txt"), child: const Text("Add .txt")),
                      ],
                    );
                  },
                );
              }

              if (resolvedName == null) {
                return;
              }

              if (!context.mounted) {
                return;
              }

              Navigator.of(context).pop(resolvedName);
            }

            return PowerboardsShadDialog.compact(
              crossAxisAlignment: CrossAxisAlignment.start,
              title: Text("New Text File"),
              actions: [
                ShadButton.outline(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                ShadButton(onPressed: () => submit(null), child: const Text("OK")),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 16,
                  children: [
                    PowerboardsAdaptiveInputFormField(
                      id: "name",
                      initialValue: "",
                      validator: (value) => value.trim().isEmpty ? "File name cannot be empty" : null,
                      label: Text("Name"),
                      autofocus: true,
                      onSubmitted: submit,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((fileName) {
      if (fileName != null) {
        final path = joinPaths(_folderSig.value, fileName);
        _uploadFile(Stream.value(Uint8List(0)), path, 0);
      }
    });
  }

  String _uploadTitle(List<UploadProgressItem> uploads, bool isCompleted) {
    if (uploads.isEmpty) {
      return "";
    }

    final isFolder = uploads.length == 1 && uploads.first.upload.filename == placeholderFileName;
    final failed = uploads.where((item) => item.failed).length;
    final completed = uploads.where((item) => item.completed).length;
    if (isFolder) {
      if (failed > 0) {
        return "Folder failed";
      }

      return isCompleted ? "Folder created" : "Creating folder";
    }

    final count = uploads.length;
    if (isCompleted && failed > 0) {
      if (completed == 0) {
        return "Upload failed";
      }

      return "Uploaded $completed, $failed failed";
    }

    final verb = isCompleted ? "Uploaded" : "Uploading";
    return "$verb $count file${count > 1 ? 's' : ''}";
  }

  String _uploadDisplayName(UploadProgressItem item) {
    final upload = item.upload;
    return upload.filename == placeholderFileName ? parentPath(upload.path) : upload.path.split('/').last;
  }

  Widget _v1UploadProgressPopover(BuildContext context) {
    return PbUploadProgressPopover(
      uploadsListenable: uploadNotifications.uploadsVN,
      isCompletedListenable: uploadNotifications.isCompletedVN,
      onClose: uploadNotifications.hide,
      titleBuilder: _uploadTitle,
      nameBuilder: _uploadDisplayName,
    );
  }

  Widget _popover(BuildContext context) {
    final theme = ShadTheme.of(context);
    final tt = theme.textTheme;

    return ValueListenableBuilder<List<UploadProgressItem>>(
      valueListenable: uploadNotifications.uploadsVN,
      builder: (context, uploads, _) {
        if (uploads.isEmpty) {
          return SizedBox.shrink();
        }

        return ValueListenableBuilder<bool>(
          valueListenable: uploadNotifications.isCompletedVN,
          builder: (context, isCompleted, _) {
            return SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                spacing: 12,
                children: [
                  Padding(
                    padding: const .only(top: 20, left: 16, right: 16, bottom: 12),
                    child: Text(_uploadTitle(uploads, isCompleted), style: tt.small.copyWith(fontWeight: .w700)),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: .min,
                          crossAxisAlignment: .start,
                          spacing: 12,
                          children: uploads.map((item) {
                            final upload = item.upload;
                            final totalBytes = item.totalBytes;

                            return AnimatedBuilder(
                              animation: upload,
                              builder: (context, _) {
                                final double percent = totalBytes > 0 ? (upload.bytesUploaded / totalBytes).clamp(0.0, 1.0) : 1.0;
                                final name = upload.filename == placeholderFileName ? parentPath(upload.path) : upload.path.split('/').last;

                                return Padding(
                                  padding: const .only(bottom: 8),
                                  child: Column(
                                    crossAxisAlignment: .start,
                                    children: [
                                      Text(name, style: TextStyle(fontSize: 12)),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(value: percent),
                                    ],
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const .only(top: 0, left: 16, right: 16, bottom: 20),
                    child: Row(
                      mainAxisAlignment: .end,
                      children: [ShadButton.outline(onPressed: uploadNotifications.hide, child: const Text("Close"))],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDesktopV1FilesBrowser(
    BuildContext context, {
    required List<StorageEntry> entries,
    required Set<String> selected,
    required bool isRefreshing,
  }) {
    final items = _v1VisibleItems(entries);
    final routePreviewFile = _v1PreviewFileFromRoute(items);
    final previewFile = _v1PreviewFile ?? routePreviewFile;
    final recentlyOpenedFiles = _v1RecentlyOpenedFilesForSidePane;
    final currentFolder = _folderSig.value;
    final filterEnabled = _v1FilterEnabled(entries);
    _clearV1FilterIfUnavailable(filterEnabled);

    return IconTheme(
      data: IconThemeData(color: ShadTheme.of(context).colorScheme.primary),
      child: ShadPopover(
        controller: popoverController,
        padding: EdgeInsets.zero,
        decoration: ShadDecoration.none,
        shadows: const [],
        anchor: ShadAnchor(
          childAlignment: Alignment.bottomLeft,
          overlayAlignment: Alignment.bottomLeft,
          offset: _uploadProgressPopoverOffset,
        ),
        popover: _v1UploadProgressPopover,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final usesStackedRoomPanel = constraints.maxWidth <= pbRoomPanelStackBreakpoint;
            final filePreviewFullscreen = _v1FilePreviewFullscreen || (usesStackedRoomPanel && previewFile != null);
            final responsivePanel = usesStackedRoomPanel && !filePreviewFullscreen;
            final responsiveMode = responsivePanel ? PbFilesResponsiveMode.overlay : PbFilesResponsiveMode.docked;
            final roomHasInstalledAgent = widget.services?.state.isReady == true && widget.services!.state.value!.isNotEmpty;
            final sidePaneAvailable =
                previewFile != null ||
                recentlyOpenedFiles.isNotEmpty ||
                items.isNotEmpty ||
                currentFolder.isNotEmpty ||
                roomHasInstalledAgent;
            final roomPanelCollapsed = !sidePaneAvailable || (routePreviewFile == null && _effectiveV1FilesRoomPanelCollapsed);
            final roomPanelExpanded = responsivePanel ? false : !roomPanelCollapsed;
            final dropTargetPadding = responsiveMode == PbFilesResponsiveMode.overlay
                ? const PbFilesPanelPadding(left: 20, right: 20)
                : const PbFilesPanelPadding(left: 30, right: 28);
            if (filePreviewFullscreen && !_v1FilePreviewFullscreen) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final previewStillAvailable = _v1PreviewFile != null || routePreviewFile != null;
                if (!mounted || !previewStillAvailable || _v1FilePreviewFullscreen) {
                  return;
                }

                setState(() {
                  _v1FilePreviewFullscreen = true;
                  _v1RestoreRoomPanelOverlayOnPreviewClose = _v1RestoreRoomPanelOverlayOnPreviewClose || _v1FilesRoomPanelOverlayOpen;
                  _v1FilesRoomPanelOverlayOpen = false;
                });
                setPreviewFilePreviewFullscreen(true);
              });
            }
            final mainPanel = Stack(
              children: [
                PbFilesMainPanel(
                  currentPath: currentFolder,
                  folderLabelForPath: _v1FolderLabelForPath,
                  items: items,
                  selectedIds: selected,
                  sortKey: _v1SortKey,
                  sortDirectionDescending: _v1SortDirectionDescending,
                  filterController: _v1FilterController,
                  filterEnabled: filterEnabled,
                  hasActiveFilter: _v1FilterController.text.trim().isNotEmpty,
                  roomPanelExpanded: roomPanelExpanded,
                  responsiveMode: responsiveMode,
                  showRoomPanelControls: sidePaneAvailable,
                  previewFileId: previewFile?.id,
                  keyboardPreviewFileId: _v1KeyboardPreviewFileId,
                  keyboardPreviewDirection: _v1KeyboardPreviewDirection,
                  enableDropTarget: false,
                  onBreadcrumbPressed: (path) => _openEntry(path, true),
                  onSortChanged: _setV1Sort,
                  onFilterChanged: (_) => setState(() {}),
                  onToggleSelection: (id) {
                    final item = items.firstWhereOrNull((item) => item.id == id);
                    if (item == null || !_v1ItemIsSelectable(item)) {
                      return;
                    }

                    _clearV1KeyboardPreviewNavigation();
                    _toggleSelected(id, !selected.contains(id));
                  },
                  onToggleVisibleSelection: () => _toggleV1VisibleSelection(items),
                  onClearSelection: () {
                    _clearV1KeyboardPreviewNavigation();
                    _clearSelected();
                  },
                  onDeleteSelection: _confirmAndDeleteSelected,
                  onDownloadSelection: _downloadSelected,
                  onCreateFolder: () => unawaited(_addFolder(currentFolder)),
                  onCreateTextFile: _showNewTextFileDialog,
                  onUpload: () => unawaited(_addFiles(currentFolder)),
                  onFilesDropped: (_) {},
                  onOpenRecentFiles: () {
                    if (!sidePaneAvailable) {
                      return;
                    }

                    if (responsivePanel) {
                      setState(() => _v1FilesRoomPanelOverlayOpen = true);
                      return;
                    }

                    _setV1FilesRoomPanelCollapsed(false);
                  },
                  onRoomPanelToggle: () {
                    if (!sidePaneAvailable) {
                      return;
                    }

                    if (responsivePanel) {
                      setState(() => _v1FilesRoomPanelOverlayOpen = true);
                      return;
                    }

                    _setV1FilesRoomPanelCollapsed(!roomPanelCollapsed);
                  },
                  onItemPressed: (item) {
                    if (_v1IsFolder(item)) {
                      _openEntry(_v1PathForItem(item), true);
                      return;
                    }
                    _openV1Preview(item, openOverlay: responsivePanel, openFullscreen: usesStackedRoomPanel);
                  },
                  onBrowseFolder: (item) => _openEntry(item.folderPath, true),
                  onRemoveProcessingRow: _removeV1FileStateRow,
                  onLinkedThreadPressed: _openV1LinkedThread,
                  onAskAgent: (item) => unawaited(_startDefaultFilePrompt(_v1PathForItem(item), recentlyOpenedItem: item)),
                  onDownload: (item) => unawaited(_downloadFile(_v1PathForItem(item))),
                  onRename: (item) => unawaited(_renamePath(_v1PathForItem(item), isFolder: _v1IsFolder(item))),
                  onDelete: (item) => unawaited(_confirmAndDelete(_v1PathForItem(item), _v1IsFolder(item))),
                ),
                if (isRefreshing)
                  const Positioned(
                    right: 30,
                    top: 28,
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                ValueListenableBuilder<bool>(
                  valueListenable: _v1FilesDropTargetActive,
                  builder: (context, active, child) => Positioned.fill(
                    child: PbFilesDropTargetOverlayLayer(active: active, top: 142, padding: dropTargetPadding),
                  ),
                ),
              ],
            );
            final keyboardPanel = Focus(
              focusNode: _v1FilesKeyboardFocusNode,
              autofocus: true,
              onKeyEvent: (node, event) => _handleV1FilesKeyEvent(
                event,
                items: items,
                previewFile: previewFile,
                responsivePanel: responsivePanel,
                openFullscreen: usesStackedRoomPanel || filePreviewFullscreen,
              ),
              child: Listener(onPointerDown: (_) => _clearV1KeyboardPreviewNavigation(), child: mainPanel),
            );

            PbFilesSidePane sidePaneBuilder(BuildContext context, bool resizing) {
              return PbFilesSidePane(
                files: recentlyOpenedFiles,
                previewFile: previewFile,
                fullscreen: filePreviewFullscreen,
                resizing: resizing,
                borderOnTop: responsivePanel,
                responsiveOverlay: responsivePanel,
                responsiveOverlayMobile: usesStackedRoomPanel,
                onPreviewFile: (item) => _openV1Preview(
                  item,
                  openOverlay: responsivePanel,
                  openFullscreen: usesStackedRoomPanel,
                  restoreOverlayOnClose: responsivePanel,
                  armKeyboardBrowse: false,
                ),
                previewBuilder: _buildV1PreviewContent,
                onAskAgent: (item) => unawaited(_startDefaultFilePrompt(_v1PathForItem(item), recentlyOpenedItem: item)),
                onDownload: (item) => unawaited(_downloadFile(_v1PathForItem(item))),
                onToggleFullscreen: () => _setV1PreviewFullscreen(!_v1FilePreviewFullscreen),
                onClosePreview: _closeV1Preview,
              );
            }

            if (responsivePanel) {
              if (!sidePaneAvailable && _v1FilesRoomPanelOverlayOpen) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _closeV1FilesRoomPanelOverlay();
                  }
                });
              } else if (_v1FilesRoomPanelOverlayOpen) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _v1FilesRoomPanelOverlayController.show();
                  }
                });
              }

              return OverlayPortal(
                controller: _v1FilesRoomPanelOverlayController,
                overlayChildBuilder: (context) => Positioned.fill(
                  child: sidePaneAvailable
                      ? sidePaneBuilder(context, false).asOverlayFrame(mobile: false, onClose: _closeV1FilesRoomPanelOverlay)
                      : const SizedBox.shrink(),
                ),
                child: ColoredBox(color: PbColors.surfacePanelWash, child: keyboardPanel),
              );
            }

            if (_v1FilesRoomPanelOverlayOpen || !sidePaneAvailable && _v1FilesRoomPanelOverlayController.isShowing) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  if (_v1FilesRoomPanelOverlayController.isShowing) {
                    _v1FilesRoomPanelOverlayController.hide();
                  }
                  setState(() => _v1FilesRoomPanelOverlayOpen = false);
                }
              });
            }

            return ColoredBox(
              color: PbColors.surfacePanelWash,
              child: PbRoomPanelMount(
                activeTab: PbRoomPanelTab.files,
                filePreviewOpen: previewFile != null,
                filePreviewFullscreen: filePreviewFullscreen,
                roomPanelCollapsed: roomPanelCollapsed,
                panelWidth: widget.v1RoomPanelWidth,
                onPanelWidthChanged: widget.onV1RoomPanelWidthChanged,
                threadPanel: keyboardPanel,
                roomPanelBuilder: sidePaneBuilder,
              ),
            );
          },
        ),
      ),
    );
  }

  String _v1FolderLabelForPath(String path) {
    if (path.isEmpty) {
      return 'Files';
    }

    return path.split('/').where((segment) => segment.isNotEmpty).lastOrNull ?? path;
  }

  Widget _buildActionsMenu(BuildContext? boundaryContext, String fullPath, bool isFolder, bool showTrigger) {
    final isAdaptiveMobile = _usesAdaptiveMobileLayout(context);

    Future<void> onAction(_FileAction action) async {
      switch (action) {
        case _FileAction.open:
          _openEntry(fullPath, isFolder);
          break;
        case _FileAction.delete:
          await _confirmAndDelete(fullPath, isFolder);
          break;
        case _FileAction.upload:
          await _addFiles(fullPath);
          break;
        case _FileAction.compressFolder:
          await _compressFolder(fullPath);
          break;
        case _FileAction.rename:
          await _renamePath(fullPath, isFolder: isFolder);
          break;
        case _FileAction.download:
          await _downloadFile(fullPath);
          break;
        case _FileAction.share:
          await _shareFile(fullPath);
          break;
      }
    }

    Future<void> onStartFilePrompt(ChatFilePromptAction action) async {
      final callback = widget.onV1FilePromptRequested;
      if (callback != null) {
        await callback(action, fullPath);
        return;
      }

      try {
        final threadPath = await startChatFilePromptThread(room: widget.client, action: action, filePath: fullPath);
        if (!mounted) {
          return;
        }

        _openEntry(threadPath, false);
      } catch (error) {
        if (!mounted) {
          return;
        }

        ShadToaster.of(context).show(ShadToast.destructive(title: const Text("Unable to start chat"), description: Text("$error")));
      }
    }

    List<ChatFilePromptAction> filePromptActions() {
      return _filePromptActionsForPath(fullPath, isFolder: isFolder);
    }

    List<Widget> items() {
      final promptActions = filePromptActions();
      return [
        if (!isFolder)
          ShadContextMenuItem(
            height: 40.0,
            leading: const Icon(LucideIcons.externalLink, size: 16),
            onPressed: () => onAction(_FileAction.open),
            child: const Text('Open'),
          ),
        if (!isFolder && !isAdaptiveMobile)
          ShadContextMenuItem(
            height: 40.0,
            leading: const Icon(LucideIcons.download, size: 16),
            onPressed: () => onAction(_FileAction.download),
            child: const Text('Download'),
          ),
        if (!isFolder && supportsNativeFileShare)
          ShadContextMenuItem(
            height: 40.0,
            leading: const Icon(LucideIcons.share, size: 16),
            onPressed: () => onAction(_FileAction.share),
            child: const Text('Share'),
          ),
        if (isFolder)
          ShadContextMenuItem(
            height: 40.0,
            leading: const Icon(LucideIcons.folderOpen, size: 16),
            onPressed: () => onAction(_FileAction.open),
            child: const Text('Open folder'),
          ),
        if (isFolder)
          ShadContextMenuItem(
            height: 40.0,
            leading: const Icon(LucideIcons.upload, size: 16),
            onPressed: () => onAction(_FileAction.upload),
            child: const Text('Upload here'),
          ),
        if (isFolder)
          ShadContextMenuItem(
            height: 40.0,
            leading: const Icon(LucideIcons.archive, size: 16),
            onPressed: () => onAction(_FileAction.compressFolder),
            child: const Text('Compress folder'),
          ),
        ShadContextMenuItem(
          height: 40.0,
          leading: const Icon(LucideIcons.pencil, size: 16),
          onPressed: () => onAction(_FileAction.rename),
          child: const Text('Rename'),
        ),
        ShadContextMenuItem(
          height: 40.0,
          leading: const Icon(LucideIcons.trash, size: 16),
          onPressed: () => onAction(_FileAction.delete),
          child: const Text('Delete'),
        ),
        if (promptActions.isNotEmpty) const Divider(height: 1),
        for (final action in promptActions)
          ShadContextMenuItem(
            height: 40.0,
            leading: const Icon(LucideIcons.messageSquarePlus, size: 16),
            onPressed: () => onStartFilePrompt(action),
            child: Text(action.menuLabel),
          ),
      ];
    }

    final menuItems = items();
    return _FileActionsMenuButton(
      key: ValueKey(_FilePathKey.keyForPath(fullPath, isFolder)),
      boundaryContext: boundaryContext,
      items: menuItems,
      estimatedMenuWidth: 200,
      estimatedMenuHeight: menuItems.fold<double>(8.0, (height, item) {
        return height + (item is Divider ? 17.0 : 40.0);
      }),
      onOpen: widget.services == null ? null : () => widget.services!.refresh(),
      showTrigger: showTrigger,
    );
  }

  Widget _buildToolbar(Set<String> selected) {
    final isMobile = _usesAdaptiveMobileLayout(context);
    if (!isMobile) {
      return _buildDesktopToolbar(selected);
    }

    if (widget.mobileShellOwnsHeader) {
      if (_openedFile != null) {
        return _buildAdaptiveMobileOpenedFileToolbar();
      }
      return const SizedBox.shrink();
    }

    return _buildMobileToolbar(selected);
  }

  Widget _buildAdaptiveMobileScrollAwareSecondaryRow(Widget child) {
    if (!(widget.mobileShellOwnsHeader && _usesAdaptiveMobileLayout(context))) {
      return child;
    }

    final overlayHeaderScope = PowerboardsMobileOverlayHeaderScope.maybeOf(context);
    final collapseProgress = overlayHeaderScope?.collapseProgress ?? 0;
    final hideForScroll = collapseProgress > 0.1;

    return AnimatedSwitcher(
      duration: powerboardsMobileOverlayHeaderTransitionDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        return ClipRect(
          child: FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, axisAlignment: -1.0, child: child),
          ),
        );
      },
      child: hideForScroll
          ? const SizedBox.shrink(key: ValueKey('files-mobile-secondary-row-hidden'))
          : KeyedSubtree(key: const ValueKey('files-mobile-secondary-row-visible'), child: child),
    );
  }

  Widget _buildDesktopToolbar(Set<String> selected) {
    final desktopActions = widget.desktopHeaderActions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: headerHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final leadingWidth = math.max(
                _estimateDesktopHeaderLeadingWidth(context, constraints.maxWidth),
                widget.desktopHeaderActionLeadingWidthFloor,
              );
              final localActionState = resolvePaneHeaderActionState(
                constraints,
                leadingWidth: leadingWidth,
                minimumLeadingWidth: math.max(_minimumDesktopHeaderLeadingWidth(), widget.desktopHeaderActionMinimumLeadingWidth),
                reserve: widget.desktopHeaderActionReserve,
                actions: desktopActions,
              );
              final actionState = localActionState;
              final visibleDesktopActions = visiblePaneHeaderActions(desktopActions, overflowCollapsed: actionState.overflowCollapsed);

              return Center(
                child: SizedBox(
                  height: desktopPaneHeaderContentHeight,
                  child: Row(
                    crossAxisAlignment: .center,
                    spacing: desktopPaneHeaderButtonGap,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ClipRect(child: _buildDesktopHeaderLeading()),
                        ),
                      ),
                      if (visibleDesktopActions.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: CompactHeaderActions(
                            state: actionState,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: desktopPaneHeaderButtonGap,
                              children: visibleDesktopActions,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _buildDesktopContextToolbar(selected),
      ],
    );
  }

  Widget _buildDesktopHeaderLeadingRow({required List<Widget> trailing}) {
    final sidetrayScope = DesktopSidetrayToggleScope.maybeOf(context);
    final sidetrayOpenButton = widget.showDesktopSidetrayToggle && sidetrayScope?.enabled == true && sidetrayScope?.collapsed == true
        ? DesktopSidetrayToggleButton(collapsed: true, onPressed: sidetrayScope!.onExpand)
        : null;
    final leadingActions = widget.desktopHeaderLeadingActions;
    return Row(
      spacing: desktopPaneHeaderButtonGap,
      children: [
        ?sidetrayOpenButton,
        if (leadingActions.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, spacing: desktopPaneHeaderButtonGap, children: leadingActions),
        ...trailing,
      ],
    );
  }

  Widget _buildDesktopHeaderLeading() {
    final sidetrayScope = DesktopSidetrayToggleScope.maybeOf(context);
    final showsSidetrayOpenButton = widget.showDesktopSidetrayToggle && sidetrayScope?.enabled == true && sidetrayScope?.collapsed == true;
    if (_openedFile == null) {
      if (widget.desktopHeaderLeadingActions.isEmpty && !showsSidetrayOpenButton) {
        return _buildBreadcrumb();
      }

      return _buildDesktopHeaderLeadingRow(
        trailing: [
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: _buildBreadcrumb()),
          ),
        ],
      );
    }

    final fileName = _displayNameForPath(_openedFile!);

    return _buildDesktopHeaderLeadingRow(
      trailing: [
        ..._buildFileCloseAction(),
        Expanded(
          child: Text(fileName, style: breadcrumbLinkStyle, maxLines: 1, overflow: .ellipsis),
        ),
      ],
    );
  }

  double _minimumDesktopHeaderLeadingWidth() {
    if (_openedFile != null) {
      return 124.0;
    }

    return 136.0;
  }

  Widget _buildDesktopContextToolbar(Set<String> selected) {
    final showSelectionActions = selected.isNotEmpty && _openedFile == null;

    if (showSelectionActions) {
      return _buildSelection(selected);
    }

    if (_openedFile != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final compactToolbar = constraints.maxWidth < 540;
          final gap = compactToolbar ? 6.0 : desktopPaneHeaderButtonGap;
          final children = <Widget>[
            ..._buildFileCycleActions(),
            if (_openedFileSupportsEditTabs) _buildOpenFileTabs(),
            if (_openedFileSupportsExternalSave) _buildExternalSaveButton(compact: compactToolbar),
            ..._buildRouteActions(),
          ];

          return _buildDesktopContextToolbarRow(children: children, gap: gap);
        },
      );
    }

    return _buildDesktopContextToolbarRow(children: _buildRouteActions());
  }

  Widget _buildDesktopContextToolbarRow({required List<Widget> children, double gap = desktopPaneHeaderButtonGap}) {
    return SizedBox(
      height: desktopPaneSecondaryControlHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, spacing: gap, children: children),
      ),
    );
  }

  bool get _openedFileSupportsEditTabs {
    final openedFile = _openedFile;
    if (openedFile == null) {
      return false;
    }

    return _isEditableTextFile(openedFile);
  }

  bool get _openedFileSupportsExternalSave {
    final openedFile = _openedFile;
    if (openedFile == null) {
      return false;
    }

    return _isEditableTextFile(openedFile);
  }

  bool _isEditableTextFile(String path) {
    return switch (classifyFile(path)) {
      FileKind.code || FileKind.markdown => true,
      _ => false,
    };
  }

  Widget _buildOpenFileTabs() {
    final theme = ShadTheme.of(context);
    final borderColor = theme.colorScheme.foreground.withValues(alpha: 0.16);
    final radius = theme.radius;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        border: Border.all(color: borderColor),
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOpenFileToggleButton(
            value: 'preview',
            tooltip: 'Preview',
            icon: LucideIcons.eye,
            borderRadius: BorderRadius.only(topLeft: radius.topLeft, bottomLeft: radius.bottomLeft),
          ),
          Container(width: 1, height: double.infinity, color: borderColor),
          _buildOpenFileToggleButton(
            value: 'edit',
            tooltip: 'Edit',
            icon: LucideIcons.pencil,
            borderRadius: BorderRadius.only(topRight: radius.topRight, bottomRight: radius.bottomRight),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenFileToggleButton({
    required String value,
    required String tooltip,
    required IconData icon,
    required BorderRadius borderRadius,
  }) {
    final selected = _tab == value;
    final theme = ShadTheme.of(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? theme.colorScheme.foreground : Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () => setState(() => _tab = value),
          child: SizedBox(
            width: 48,
            height: 38,
            child: Icon(icon, size: 18, color: selected ? theme.colorScheme.background : theme.colorScheme.foreground),
          ),
        ),
      ),
    );
  }

  Widget _buildExternalSaveButton({required bool compact}) {
    return AnimatedBuilder(
      animation: _codePreviewController,
      builder: (context, _) {
        final saving = _codePreviewController.saving;
        final needsSaveAttention = _codePreviewController.dirty || saving;

        return (needsSaveAttention ? ShadButton.destructive : ShadButton.outline)(
          enabled: _codePreviewController.canSave,
          onPressed: () async {
            await _codePreviewController.save();
          },
          leading: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator()) : const Icon(LucideIcons.save),
          child: compact ? null : const Text("Save"),
        );
      },
    );
  }

  Future<void> _saveAdaptiveMobileEdits() async {
    await _codePreviewController.save();

    if (!mounted) {
      return;
    }

    if (_codePreviewController.dirty || _codePreviewController.saving || _codePreviewController.saveError != null) {
      return;
    }

    await _refreshCurrentFolder();

    if (!mounted) {
      return;
    }

    setState(() {
      _tab = 'preview';
    });
  }

  PowerboardsMobileActionPillItem _buildAdaptiveMobileOpenedFilePrimaryPillItem() {
    if (!_openedFileSupportsEditTabs) {
      return const PowerboardsMobileActionPillItem(label: "Preview", selected: true);
    }

    if (_tab != 'edit') {
      return PowerboardsMobileActionPillItem(label: "Edit this file", onPressed: () => setState(() => _tab = 'edit'));
    }

    return PowerboardsMobileActionPillItem(label: "Save your edits", selected: true, onPressed: _saveAdaptiveMobileEdits);
  }

  Widget _buildAdaptiveMobileOpenedFileToolbar() {
    final theme = ShadTheme.of(context);
    final pillTextStyle = powerboardsInterTextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.0);
    final primaryPill = _buildAdaptiveMobileOpenedFilePrimaryPillItem();
    final deletePill = PowerboardsMobileActionPillItem(
      label: "Delete",
      selected: true,
      destructive: true,
      onPressed: _openedFile == null || _isDeletePending(_openedFile!, false)
          ? null
          : () async {
              final openedFile = _openedFile;
              if (openedFile == null) {
                return;
              }

              final confirmDelete = await _confirmAndDelete(openedFile, false);
              if (confirmDelete == true) {
                _openEntry(_folderSig.value, true);
              }
            },
    );

    return Padding(
      padding: const EdgeInsets.only(top: powerboardsMobileOverlaySecondaryRowLift),
      child: SizedBox(
        height: powerboardsMobileSecondaryRowHeight,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: powerboardsMobileShellHorizontalInset),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PowerboardsMobileActionPillStrip(
                      items: [primaryPill, deletePill],
                      textStyle: pillTextStyle,
                      unselectedForegroundColor: theme.colorScheme.foreground,
                      itemGap: 10,
                      pillPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileToolbar(Set<String> selected) {
    final showSelectionActions = selected.isNotEmpty && _openedFile == null;
    final showRouteActions = !showSelectionActions;
    final leading = showSelectionActions ? _buildSelection(selected) : _buildBreadcrumb();
    final selectToggle = Tooltip(
      message: "Select items",
      child: (_forceShowSelect ? ShadIconButton.new : ShadIconButton.outline)(
        icon: const Icon(LucideIcons.squareCheckBig),
        decoration: powerboardsAdaptiveIconButtonDecoration(context),
        onPressed: _toggleForceShowSelect,
      ),
    );

    if (widget.mobileShellOwnsHeader && !showSelectionActions) {
      final actionWidgets = <Widget>[if (showRouteActions) ..._buildRouteActions(), if (_openedFile == null) selectToggle];

      if (actionWidgets.isEmpty) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: EdgeInsets.only(bottom: _openedFile == null ? 8 : 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, spacing: 6, children: actionWidgets),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, _openedFile == null ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 6,
        children: [
          if (_openedFile != null) ..._buildFileCloseAction(),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: leading),
          ),
          if (showRouteActions) ..._buildRouteActions(),
          selectToggle,
        ],
      ),
    );
  }

  List<Widget> _buildFileCloseAction() {
    return [
      Tooltip(
        message: "Close file",
        child: ShadIconButton.ghost(
          icon: const Icon(LucideIcons.x),
          decoration: powerboardsAdaptiveIconButtonDecoration(context),
          onPressed: _closeFile,
        ),
      ),
    ];
  }

  List<Widget> _buildFileCycleActions() {
    final canCycleFiles = _visibleSortedFiles.value.length > 1;

    return [
      if (canCycleFiles)
        Tooltip(
          message: "Previous file",
          child: ShadIconButton.outline(
            icon: const Icon(LucideIcons.chevronLeft),
            decoration: powerboardsAdaptiveIconButtonDecoration(context),
            onPressed: _previousFile,
          ),
        ),
      if (canCycleFiles)
        Tooltip(
          message: "Next file",
          child: ShadIconButton.outline(
            icon: const Icon(LucideIcons.chevronRight),
            decoration: powerboardsAdaptiveIconButtonDecoration(context),
            onPressed: _nextFile,
          ),
        ),
    ];
  }

  List<Widget> _buildRouteActions() {
    if (_openedFile != null) {
      final isMobile = _usesAdaptiveMobileLayout(context);
      final showLegacyMobileEditActions = isMobile && !widget.mobileShellOwnsHeader;

      return [
        if (showLegacyMobileEditActions && _openedFileSupportsEditTabs) _buildOpenFileTabs(),
        if (showLegacyMobileEditActions && _openedFileSupportsExternalSave) _buildExternalSaveButton(compact: true),
        if (supportsNativeFileShare && !widget.mobileShellOwnsHeader)
          Tooltip(
            message: "Share",
            child: ShadIconButton.outline(
              icon: const Icon(LucideIcons.share),
              decoration: powerboardsAdaptiveIconButtonDecoration(context),
              onPressed: () {
                _shareFile(_openedFile!);
              },
            ),
          ),
        if (!isMobile)
          Tooltip(
            message: "Download",
            child: ShadIconButton.outline(
              icon: const Icon(LucideIcons.download),
              decoration: powerboardsAdaptiveIconButtonDecoration(context),
              onPressed: () {
                _downloadFile(_openedFile!);
              },
            ),
          ),
        Tooltip(
          message: "Delete file",
          child: ShadIconButton.outline(
            icon: const Icon(LucideIcons.trash),
            decoration: powerboardsAdaptiveIconButtonDecoration(context),
            onPressed: _isDeletePending(_openedFile!, false)
                ? null
                : () async {
                    final confirmDelete = await _confirmAndDelete(_openedFile!, false);
                    if (confirmDelete == true) {
                      _openEntry(_folderSig.value, true);
                    }
                  },
          ),
        ),
      ];
    } else {
      return [
        Tooltip(
          message: "New folder",
          child: ShadIconButton.outline(
            icon: const Icon(LucideIcons.folderPlus),
            decoration: powerboardsAdaptiveIconButtonDecoration(context),
            onPressed: () {
              _addFolder(_folderSig.value);
            },
          ),
        ),
        _buildUploadMenu(),
        if (FileUploadHelper.supportsPhotoUploadPicker)
          Tooltip(
            message: "Upload photo",
            child: ShadIconButton.outline(
              icon: const Icon(LucideIcons.imagePlus),
              decoration: powerboardsAdaptiveIconButtonDecoration(context),
              onPressed: () {
                _addPhotos(_folderSig.value);
              },
            ),
          ),
      ];
    }
  }

  Widget _buildUploadMenu() {
    return AppContextMenuButton(
      compact: true,
      boundaryContext: context,
      entries: [
        AppMenuEntry(
          title: "Upload files",
          description: "Upload files to this folder",
          icon: LucideIcons.upload,
          onPressed: () {
            _addFiles(_folderSig.value);
          },
        ),
        AppMenuEntry(
          title: "New Text File",
          description: "Create a new text file in this folder",
          icon: LucideIcons.fileText,
          onPressed: _showNewTextFileDialog,
        ),
      ],
      constraints: const BoxConstraints(minWidth: 200),
      childBuilder: (context, controller) {
        return Tooltip(
          message: "Upload file",
          child: ShadIconButton.outline(
            icon: const Icon(LucideIcons.upload),
            decoration: powerboardsAdaptiveIconButtonDecoration(context),
            onPressed: controller.toggle,
          ),
        );
      },
    );
  }

  Widget _buildSelection(Set<String> selected) {
    final isMobile = _usesAdaptiveMobileLayout(context);
    final countPadding = isMobile ? 4.0 : 6.0;
    final children = <Widget>[
      ShadButton.outline(onPressed: _clearSelected, child: Text(isMobile ? "Clear" : "Clear selection")),
      ShadButton.destructive(onPressed: () => _confirmAndDeleteSelected(), child: const Text("Delete")),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: countPadding),
        child: Text('${selected.length} selected', style: breadcrumbLinkStyle),
      ),
    ];

    if (!isMobile) {
      return _buildDesktopContextToolbarRow(children: children, gap: 8);
    }

    return Row(mainAxisSize: MainAxisSize.min, spacing: 8, children: children);
  }

  double _measureBreadcrumbLabelWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: breadcrumbLinkStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();

    return painter.width;
  }

  double _estimateDesktopHeaderLeadingWidth(BuildContext context, double maxWidth) {
    final sidetrayScope = DesktopSidetrayToggleScope.maybeOf(context);
    final sidetrayLeadingWidth = widget.showDesktopSidetrayToggle && sidetrayScope?.enabled == true && sidetrayScope?.collapsed == true
        ? desktopPaneHeaderCompactButtonWidth + desktopPaneHeaderButtonGap
        : 0.0;
    final openedFile = _openedFile;
    if (openedFile != null) {
      final fileName = _displayNameForPath(openedFile);
      final closeActionWidth = 40.0 + desktopPaneHeaderButtonGap;
      final fileNameWidth = _measureBreadcrumbLabelWidth(context, fileName) + 24.0;
      return math.min(sidetrayLeadingWidth + closeActionWidth + fileNameWidth, math.min(240.0, maxWidth * 0.3));
    }

    final segments = _folderBreadcrumbSegments();
    var width = 0.0;
    for (var i = 0; i < segments.length; i++) {
      width += _measureBreadcrumbLabelWidth(context, segments[i].label) + 40.0;
      if (i > 0) {
        width += 20.0;
      }
    }

    return math.min(sidetrayLeadingWidth + width, math.min(240.0, maxWidth * 0.3));
  }

  List<FileBreadcrumbSegment> _folderBreadcrumbSegments() {
    final segments = <FileBreadcrumbSegment>[const FileBreadcrumbSegment(label: "Files", path: "")];
    final folderSegments = _folderSig.value.split('/').where((s) => s.isNotEmpty).toList();

    var accumulated = "";
    for (final segment in folderSegments) {
      accumulated = accumulated.isEmpty ? segment : "$accumulated/$segment";
      segments.add(FileBreadcrumbSegment(label: segment, path: accumulated));
    }

    return segments;
  }

  Widget _breadcrumbSeparator() {
    return const SizedBox(
      width: 20,
      child: Center(child: Icon(LucideIcons.chevronRight, size: 16, color: Color(0xffa5a5a5))),
    );
  }

  Widget _buildBreadcrumbCrumb(FileBreadcrumbSegment segment) {
    return ShadButton.ghost(
      onPressed: () => _openEntry(segment.path, true),
      child: Text(segment.label, style: breadcrumbLinkStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildCollapsedBreadcrumbCurrent(FileBreadcrumbSegment segment) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openEntry(segment.path, true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(segment.label, style: breadcrumbLinkStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Widget _buildCollapsedBreadcrumbMenu(List<FileBreadcrumbSegment> hiddenSegments) {
    return AdaptiveShadContextMenu(
      controller: _collapsedBreadcrumbMenuController,
      boundaryContext: context,
      constraints: const BoxConstraints(minWidth: 200),
      estimatedMenuWidth: 200,
      estimatedMenuHeight: hiddenSegments.length * 40.0 + 8.0,
      items: hiddenSegments.reversed
          .map(
            (segment) => ShadContextMenuItem(
              height: 40.0,
              leading: const Icon(LucideIcons.folder, size: 16),
              onPressed: () => _openEntry(segment.path, true),
              child: Text(segment.label),
            ),
          )
          .toList(growable: false),
      child: Tooltip(
        message: "Browse collapsed path",
        child: ShadIconButton.outline(
          icon: const Icon(LucideIcons.folderTree),
          decoration: powerboardsAdaptiveIconButtonDecoration(context),
          onPressed: _collapsedBreadcrumbMenuController.toggle,
        ),
      ),
    );
  }

  Widget _buildBreadcrumbTrail(List<FileBreadcrumbSegment> segments) {
    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        children.add(_breadcrumbSeparator());
      }
      children.add(_buildBreadcrumbCrumb(segments[i]));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildCollapsedBreadcrumbTrail(List<FileBreadcrumbSegment> segments) {
    if (segments.length == 1) {
      return Row(children: [Expanded(child: _buildCollapsedBreadcrumbCurrent(segments.first))]);
    }

    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        children.add(_breadcrumbSeparator());
      }

      if (i == segments.length - 1) {
        children.add(Expanded(child: _buildCollapsedBreadcrumbCurrent(segments[i])));
        continue;
      }

      children.add(_buildBreadcrumbCrumb(segments[i]));
    }
    return Row(children: children);
  }

  Widget _buildFileNameOnly() {
    final fileName = _displayNameForPath(_openedFile!);

    return Text(fileName, style: breadcrumbLinkStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Widget _buildBreadcrumb() {
    if (_openedFile != null) {
      return _buildFileNameOnly();
    }

    final segments = _folderBreadcrumbSegments();
    if (segments.length <= 1) {
      return _buildBreadcrumbCrumb(segments.first);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const separatorWidth = 20.0;
        // Keep a little safety margin so ghost-button chrome collapses
        // before the row reaches a visible overflow.
        const crumbChromeWidth = 52.0;
        const collapseButtonWidth = 48.0;

        final segmentWidths = segments
            .map((segment) => _measureBreadcrumbLabelWidth(context, segment.label) + crumbChromeWidth)
            .toList(growable: false);

        final layout = computeFileBreadcrumbLayout(
          segments: segments,
          segmentWidths: segmentWidths,
          maxWidth: constraints.maxWidth,
          separatorWidth: separatorWidth,
          collapseButtonWidth: collapseButtonWidth,
        );

        if (layout.isCollapsed) {
          return Row(
            children: [
              _buildCollapsedBreadcrumbMenu(layout.hiddenSegments),
              _breadcrumbSeparator(),
              Expanded(child: _buildCollapsedBreadcrumbTrail(layout.visibleSegments)),
            ],
          );
        }

        return _buildBreadcrumbTrail(layout.visibleSegments);
      },
    );
  }

  Widget _buildOpenedFile(BuildContext context) {
    if (_openedFile == null) return const SizedBox.shrink();

    final path = _openedFile!;
    final fileKind = classifyFile(path);
    final showEditTabs = _isEditableTextFile(path);
    final showExternalSave = _isEditableTextFile(path);
    final openedFileEntry = storageEntries.state.asReady?.value.firstWhereOrNull(
      (entry) => !entry.isFolder && joinPaths(_folderSig.value, entry.name) == path,
    );
    final isKnownEmptyTextFile = showExternalSave && ((openedFileEntry?.size == 0) || _optimisticEmptyTextFiles.contains(path));

    Widget buildTextDocument({required bool readOnly, required bool showToolbar, CodePreviewController? controller}) {
      if (isKnownEmptyTextFile) {
        return CodePreview(
          filename: path,
          room: widget.client,
          text: "",
          readOnly: readOnly,
          controller: controller,
          showToolbar: showToolbar,
        );
      }

      return DocumentPane(
        path: path,
        room: widget.client,
        forceTextViewer: true,
        readOnlyTextViewer: readOnly,
        codePreviewController: controller,
        showCodeToolbar: showToolbar,
      );
    }

    if (!showExternalSave) {
      return _buildOpenedFileSurface(
        fileViewer(widget.client, path) ?? DocumentPane(path: path, room: widget.client),
        insetContent: _shouldInsetOpenedFileSurface(fileKind: fileKind, editing: false),
      );
    }

    final edit = _buildOpenedFileSurface(
      buildTextDocument(readOnly: false, controller: _codePreviewController, showToolbar: false),
      insetContent: _shouldInsetOpenedFileSurface(fileKind: fileKind, editing: true),
    );

    final readOnlyTextPreview = _buildOpenedFileSurface(
      buildTextDocument(readOnly: true, showToolbar: false),
      insetContent: _shouldInsetOpenedFileSurface(fileKind: fileKind, editing: false),
    );

    if (!showEditTabs) {
      return edit;
    }

    final view = fileKind == FileKind.code
        ? readOnlyTextPreview
        : _buildOpenedFileSurface(
            fileViewer(widget.client, path) ?? DocumentPane(path: path, room: widget.client),
            insetContent: _shouldInsetOpenedFileSurface(fileKind: fileKind, editing: false),
          );

    return Column(
      key: ValueKey(_openedFile),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: IndexedStack(
            index: _tab == 'preview' ? 0 : 1,
            children: [
              Container(key: ValueKey("preview$_tab"), child: view),
              edit,
            ],
          ),
        ),
      ],
    );
  }

  bool _shouldInsetOpenedFileSurface({required FileKind fileKind, required bool editing}) {
    if (editing) {
      return false;
    }

    return switch (fileKind) {
      FileKind.pdf || FileKind.office || FileKind.code || FileKind.tsv => false,
      _ => true,
    };
  }

  Widget _buildOpenedFileSurface(Widget child, {required bool insetContent}) {
    final isAdaptiveMobile = _usesAdaptiveMobileLayout(context) && widget.mobileShellOwnsHeader;
    if (isAdaptiveMobile) {
      return SizedBox.expand(
        child: ClipRect(
          child: ColoredBox(color: shadCard, child: child),
        ),
      );
    }

    final radius = ShadTheme.of(context).radius.resolve(Directionality.of(context));
    const borderWidth = 1.0;
    const previewPadding = 16.0;
    final innerRadius = BorderRadius.only(
      topLeft: Radius.circular(math.max(0, radius.topLeft.x - borderWidth)),
      topRight: Radius.circular(math.max(0, radius.topRight.x - borderWidth)),
      bottomLeft: Radius.circular(math.max(0, radius.bottomLeft.x - borderWidth)),
      bottomRight: Radius.circular(math.max(0, radius.bottomRight.x - borderWidth)),
    );

    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: shadCard,
          border: Border.all(color: shadBorder, width: borderWidth),
          borderRadius: radius,
        ),
        child: Padding(
          padding: EdgeInsets.all(borderWidth + (insetContent ? previewPadding : 0)),
          child: ClipRRect(
            borderRadius: innerRadius,
            child: ColoredBox(color: shadCard, child: child),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isAdaptiveMobile = widget.mobileShellOwnsHeader && _usesAdaptiveMobileLayout(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _openedFile == null
            ? (_forceShowSelect ? _clearMobileSelectionMode : _clearSelected)
            : _closeFile,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _previousFile,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _nextFile,
      },
      child: Focus(
        autofocus: true,
        child: FileDropArea(
          onFileDrop: _onFileDrop,
          onDraggingChanged: _setV1FilesDropTargetActive,
          overlayBuilder: !isAdaptiveMobile && powerboardsUsesDesktopUiPreview(context) ? (_, _) => const SizedBox.shrink() : null,
          child: SignalBuilder(
            builder: (context, _) {
              final selected = _visibleSelected.value;
              final hasOpenedFile = _openedFile != null;
              final useDesktopV1FilesBrowser = !isAdaptiveMobile && powerboardsUsesDesktopUiPreview(context);
              if (useDesktopV1FilesBrowser) {
                return SizedBox.expand(
                  child: ValueListenableBuilder<int>(
                    valueListenable: PendingStorageDeletes.listenableFor(_deleteScope),
                    builder: (context, _, _) => storageEntries.state.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(child: Text("Error loading files: $e")),
                      ready: (entries) => _buildDesktopV1FilesBrowser(
                        context,
                        entries: entries,
                        selected: selected,
                        isRefreshing: storageEntries.state.isRefreshing,
                      ),
                    ),
                  ),
                );
              }

              final hideEmbeddedMobileToolbar = isAdaptiveMobile && !hasOpenedFile;
              final showAdaptiveOpenedFileDivider = isAdaptiveMobile && hasOpenedFile;
              final adaptiveSecondaryRow = showAdaptiveOpenedFileDivider
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToolbar(selected),
                        const SizedBox(height: desktopPaneSecondaryRowContentGap),
                      ],
                    )
                  : hideEmbeddedMobileToolbar
                  ? const SizedBox.shrink()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToolbar(selected),
                        const SizedBox(height: desktopPaneSecondaryRowContentGap),
                      ],
                    );
              return Column(
                crossAxisAlignment: .start,
                children: [
                  _buildAdaptiveMobileScrollAwareSecondaryRow(adaptiveSecondaryRow),
                  Expanded(
                    child: IndexedStack(
                      index: _openedFile == null ? 0 : 1,
                      children: [
                        IconTheme(
                          data: IconThemeData(color: theme.colorScheme.primary),
                          child: ShadPopover(
                            controller: popoverController,
                            padding: .zero,
                            anchor: ShadAnchor(
                              childAlignment: .bottomRight,
                              overlayAlignment: .bottomRight,
                              offset: const Offset(-20.0, -20.0),
                            ),
                            popover: _popover,
                            child: SignalBuilder(
                              builder: (context, _) {
                                return storageEntries.state.when(
                                  loading: () => const Center(child: CircularProgressIndicator()),
                                  error: (e, st) => Center(child: Text("Error loading files: $e")),
                                  ready: (_) {
                                    final entries = _visibleSortedEntries.value;
                                    final sort = _sortSig.value;
                                    final folder = _folderSig.value;
                                    return FileTableView(
                                      currentPath: folder,
                                      entries: entries,
                                      selected: selected,
                                      sort: sort,
                                      isRefreshing: storageEntries.state.isRefreshing,
                                      forceShowSelect: _forceShowSelect,
                                      displayNameBuilder: _displayNameForEntry,
                                      deleteRevision: PendingStorageDeletes.listenableFor(_deleteScope),
                                      isDeletePending: _isDeletePending,
                                      onOpen: _openEntry,
                                      onToggleSelected: _toggleSelected,
                                      onToggleAllSelected: _toggleAllSelected,
                                      onSortChanged: _setSort,
                                      onActivateSelectionMode: _activateMobileSelectionMode,
                                      onClearSelectionMode: _clearMobileSelectionMode,
                                      onDownloadSelected: _downloadSelected,
                                      onDeleteSelected: _confirmAndDeleteSelected,
                                      onUploadFiles: () => _addFiles(folder),
                                      onCreateFolder: () => _addFolder(folder),
                                      onCreateTextFile: _showNewTextFileDialog,
                                      buildActionsMenu: _buildActionsMenu,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                        _buildOpenedFile(context),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class FileTableView extends StatefulWidget {
  final String currentPath;
  final List<StorageEntry> entries;
  final Set<String> selected;
  final FileSort sort;
  final bool isRefreshing;
  final bool forceShowSelect;
  final String Function(StorageEntry entry)? displayNameBuilder;
  final ValueListenable<int> deleteRevision;
  final bool Function(String fullPath, bool isFolder) isDeletePending;
  final void Function(String fullPath, bool isFolder) onOpen;
  final void Function(String key, bool selected) onToggleSelected;
  final void Function(bool selected) onToggleAllSelected;
  final void Function(FileSort) onSortChanged;
  final VoidCallback onActivateSelectionMode;
  final VoidCallback onClearSelectionMode;
  final VoidCallback onDownloadSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onUploadFiles;
  final VoidCallback onCreateFolder;
  final VoidCallback onCreateTextFile;
  final Widget Function(BuildContext? boundaryContext, String fullPath, bool isFolder, bool showTrigger) buildActionsMenu;

  const FileTableView({
    super.key,
    required this.currentPath,
    required this.entries,
    required this.selected,
    required this.sort,
    required this.isRefreshing,
    required this.forceShowSelect,
    this.displayNameBuilder,
    required this.deleteRevision,
    required this.isDeletePending,
    required this.onOpen,
    required this.onToggleSelected,
    required this.onToggleAllSelected,
    required this.onSortChanged,
    required this.onActivateSelectionMode,
    required this.onClearSelectionMode,
    required this.onDownloadSelected,
    required this.onDeleteSelected,
    required this.onUploadFiles,
    required this.onCreateFolder,
    required this.onCreateTextFile,
    required this.buildActionsMenu,
  });

  @override
  State createState() => _FileTableViewState();
}

class _FileTableViewState extends State<FileTableView> {
  static TextStyle get dataStyle => powerboardsFileListTitleStyle();
  static TextStyle get headerStyle => powerboardsFileListMetadataStyle();
  static const BorderRadius _fileCheckboxRadius = BorderRadius.all(Radius.circular(6));

  final ValueNotifier<String?> _hoveredRowKey = ValueNotifier<String?>(null);
  final GlobalKey _tableCardKey = GlobalKey();

  String _displayNameForEntry(StorageEntry entry) {
    return widget.displayNameBuilder?.call(entry) ?? entry.name;
  }

  @override
  void initState() {
    super.initState();
    dataTableShowLogs = false;
  }

  @override
  void dispose() {
    _hoveredRowKey.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FileTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      _hoveredRowKey.value = null;
    }
  }

  void _setHovered(String key) {
    if (_hoveredRowKey.value != key) _hoveredRowKey.value = key;
  }

  void _clearHoveredIf(String key) {
    if (_hoveredRowKey.value == key) _hoveredRowKey.value = null;
  }

  Widget _buildTableCard(Widget child) {
    if (_usesAdaptiveMobileLayout(context)) {
      return ColoredBox(key: _tableCardKey, color: shadCard, child: child);
    }

    final radius = ShadTheme.of(context).radius.resolve(Directionality.of(context));
    const borderWidth = 1.0;
    final innerRadius = BorderRadius.only(
      topLeft: Radius.circular(math.max(0, radius.topLeft.x - borderWidth)),
      topRight: Radius.circular(math.max(0, radius.topRight.x - borderWidth)),
      bottomLeft: Radius.circular(math.max(0, radius.bottomLeft.x - borderWidth)),
      bottomRight: Radius.circular(math.max(0, radius.bottomRight.x - borderWidth)),
    );

    return DecoratedBox(
      key: _tableCardKey,
      decoration: BoxDecoration(
        color: shadCard,
        border: Border.all(color: shadBorder, width: borderWidth),
        borderRadius: radius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(borderWidth),
        child: ClipRRect(borderRadius: innerRadius, child: child),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    Widget createMenuButton() {
      return AppContextMenuButton(
        boundaryContext: context,
        entries: [
          AppMenuEntry(
            title: "New folder",
            description: "Create a folder in this location",
            icon: LucideIcons.folderPlus,
            onPressed: widget.onCreateFolder,
          ),
          AppMenuEntry(
            title: "New Text File",
            description: "Create a new text file in this folder",
            icon: LucideIcons.fileText,
            onPressed: widget.onCreateTextFile,
          ),
        ],
        constraints: const BoxConstraints(minWidth: 220),
        childBuilder: (context, controller) {
          return ShadButton.outline(
            leading: const Icon(LucideIcons.plus),
            trailing: const Icon(LucideIcons.chevronDown),
            onPressed: controller.toggle,
            child: const Text("Create..."),
          );
        },
      );
    }

    return _buildTableCard(
      PaneEmptyState(
        title: "This folder is empty",
        titleScaleOverride: 0.72,
        verticalOffset: -28,
        action: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShadButton.outline(leading: const Icon(LucideIcons.upload), onPressed: widget.onUploadFiles, child: const Text("Upload files")),
            const SizedBox(width: 8),
            createMenuButton(),
          ],
        ),
      ),
    );
  }

  Widget _getIcon(StorageEntry entry) {
    return buildPowerboardsFileListIcon(context, entry);
  }

  Widget _getLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 5),
      child: Text(text, style: headerStyle),
    );
  }

  String? _formatEntrySize(StorageEntry entry) {
    if (entry.isFolder) {
      return null;
    }

    final size = entry.size;
    if (size == null) {
      return null;
    }

    return _formatFileSizeBytes(size);
  }

  Widget _hoverRegion(String rowKey, Widget child) {
    return MouseRegion(opaque: true, onEnter: (_) => _setHovered(rowKey), onExit: (_) => _clearHoveredIf(rowKey), child: child);
  }

  Widget _fileSelectionCheckbox({required bool value, required ShadDecoration decoration, ValueChanged<bool?>? onChanged}) {
    final checkboxForeground = ShadTheme.of(context).colorScheme.primaryForeground;

    return ShadCheckbox(
      decoration: decoration,
      value: value,
      icon: value ? Icon(LucideIcons.check, size: 14, weight: 3, color: checkboxForeground) : null,
      onChanged: onChanged,
    );
  }

  PowerboardsMobileActionPillItem _buildMobileSelectionHeaderPillItem() {
    final selectionActive = widget.forceShowSelect;
    return PowerboardsMobileActionPillItem(
      label: selectionActive ? 'Exit' : 'Select',
      selected: selectionActive,
      onPressed: selectionActive ? widget.onClearSelectionMode : widget.onActivateSelectionMode,
    );
  }

  PowerboardsMobileActionPillItem _buildMobileSortHeaderPillItem({String label = 'Sort by name'}) {
    final isNameSort = widget.sort.field == FileSortField.name;
    final descending = isNameSort && !widget.sort.ascending;
    return PowerboardsMobileActionPillItem(
      label: label,
      selected: descending,
      onPressed: () => widget.onSortChanged(FileSort(FileSortField.name, isNameSort ? !widget.sort.ascending : true)),
    );
  }

  PowerboardsMobileActionPillItem _buildMobileDeleteHeaderPillItem() {
    return PowerboardsMobileActionPillItem(label: "Delete", selected: true, destructive: true, onPressed: widget.onDeleteSelected);
  }

  Widget _buildMobileHeader(bool showSelectColumn, bool? selectAllValue) {
    final theme = ShadTheme.of(context);
    final showSelectionModeActions = widget.forceShowSelect;
    final compactToolbarWidth = MediaQuery.sizeOf(context).width < 390;
    final sortLabel = showSelectionModeActions && compactToolbarWidth ? 'Sort by…' : 'Sort by name';
    final pills = <PowerboardsMobileActionPillItem>[
      _buildMobileSelectionHeaderPillItem(),
      _buildMobileSortHeaderPillItem(label: sortLabel),
      if (showSelectionModeActions) _buildMobileDeleteHeaderPillItem(),
    ];
    final pillTextStyle = powerboardsInterTextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.0);
    final pillGap = showSelectionModeActions && compactToolbarWidth ? 8.0 : 10.0;
    final pillPadding = showSelectionModeActions && compactToolbarWidth
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 11)
        : const EdgeInsets.symmetric(horizontal: 17, vertical: 11);

    return Padding(
      padding: const EdgeInsets.only(top: powerboardsMobileOverlaySecondaryRowLift),
      child: SizedBox(
        height: powerboardsMobileSecondaryRowHeight,
        child: Center(
          child: Padding(
            padding: powerboardsMobileSecondaryRowPadding,
            child: Row(
              children: [
                if (showSelectColumn) ...[
                  SizedBox(
                    width: 36,
                    child: Center(
                      child: ShadTriCheckbox(value: selectAllValue, onChanged: (v) => widget.onToggleAllSelected(v == true)),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PowerboardsMobileActionPillStrip(
                      items: pills,
                      textStyle: pillTextStyle,
                      unselectedForegroundColor: theme.colorScheme.foreground,
                      itemGap: pillGap,
                      pillPadding: pillPadding,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isRefreshing)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollAwareMobileHeader(Widget child) {
    final overlayHeaderScope = PowerboardsMobileOverlayHeaderScope.maybeOf(context);
    final collapseProgress = overlayHeaderScope?.collapseProgress ?? 0;
    final hideForScroll = collapseProgress > 0.1;

    return AnimatedSwitcher(
      duration: powerboardsMobileOverlayHeaderTransitionDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        return ClipRect(
          child: FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, axisAlignment: -1.0, child: child),
          ),
        );
      },
      child: hideForScroll
          ? const SizedBox.shrink(key: ValueKey('file-browser-mobile-header-hidden'))
          : KeyedSubtree(key: const ValueKey('file-browser-mobile-header-visible'), child: child),
    );
  }

  Widget _buildMobileList(BuildContext context, bool showSelectColumn, bool alwaysShowMenu, bool? selectAllValue, bool showSize) {
    final colorScheme = ShadTheme.of(context).colorScheme;

    return _buildTableCard(
      Column(
        children: [
          _buildScrollAwareMobileHeader(_buildMobileHeader(showSelectColumn, selectAllValue)),
          Expanded(
            child: ListView.separated(
              itemCount: widget.entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: shadBorder),
              itemBuilder: (context, index) {
                final entry = widget.entries[index];
                final fullPath = _FilePathKey.pathForEntry(widget.currentPath, entry);
                final key = _FilePathKey.keyForEntry(widget.currentPath, entry);
                final isSelected = widget.selected.contains(key);
                final checkboxDecoration = ShadDecoration(
                  border: ShadBorder.all(color: colorScheme.border, radius: _fileCheckboxRadius),
                );
                final showRowMenu = !widget.forceShowSelect;
                final sizeLabel = showSize ? _formatEntrySize(entry) : null;
                final modifiedLabel = entry.updatedAt?.modified() ?? '';
                final metadataLabel = <String>[?sizeLabel, if (modifiedLabel.isNotEmpty) modifiedLabel].join(' • ');
                final showMetadataLabel = metadataLabel.isNotEmpty;
                final displayName = _displayNameForEntry(entry);
                final deletePending = widget.isDeletePending(fullPath, entry.isFolder);

                return Opacity(
                  opacity: deletePending ? 0.45 : 1,
                  child: Material(
                    color: isSelected ? const Color(0xFFF2F1FF) : shadCard,
                    child: InkWell(
                      onTap: deletePending ? null : () => widget.onOpen(fullPath, entry.isFolder),
                      child: Padding(
                        padding: powerboardsFileListRowPadding,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (showSelectColumn) ...[
                              SizedBox(
                                width: 36,
                                child: Center(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: deletePending ? null : () => widget.onToggleSelected(key, !isSelected),
                                    child: _fileSelectionCheckbox(decoration: checkboxDecoration, value: isSelected),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            _getIcon(entry),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(displayName, style: dataStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (showMetadataLabel) ...[
                                    const SizedBox(height: 4),
                                    Text(metadataLabel, style: headerStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (deletePending)
                              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            else
                              ValueListenableBuilder<String?>(
                                valueListenable: _hoveredRowKey,
                                builder: (_, hoveredKey, _) => widget.buildActionsMenu(
                                  _tableCardKey.currentContext,
                                  fullPath,
                                  entry.isFolder,
                                  showRowMenu && (alwaysShowMenu || isSelected || hoveredKey == key),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(valueListenable: widget.deleteRevision, builder: (context, _, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return _buildEmptyState(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final showSize = availableWidth > 500;
        final isMobile = _usesAdaptiveMobileLayout(context);
        final colorScheme = ShadTheme.of(context).colorScheme;
        final showSelectColumn = !isMobile || widget.forceShowSelect;
        final alwaysShowMenu = isMobile;
        final selectableKeys = widget.entries
            .where((entry) => !widget.isDeletePending(_FilePathKey.pathForEntry(widget.currentPath, entry), entry.isFolder))
            .map((entry) => _FilePathKey.keyForEntry(widget.currentPath, entry))
            .toSet();
        final selectedSelectableCount = widget.selected.where(selectableKeys.contains).length;
        final bool? selectAllValue = selectedSelectableCount == 0
            ? false
            : (selectedSelectableCount == selectableKeys.length ? true : null);

        if (isMobile) {
          return _buildMobileList(context, showSelectColumn, alwaysShowMenu, selectAllValue, showSize);
        }

        final sortColumnIndex = (widget.sort.field == FileSortField.name ? 0 : (showSize ? 2 : 1)) + (showSelectColumn ? 1 : 0);
        final sortAscending = widget.sort.ascending;
        final rows = widget.entries.map((entry) {
          final fullPath = _FilePathKey.pathForEntry(widget.currentPath, entry);
          final key = _FilePathKey.keyForEntry(widget.currentPath, entry);
          final isSelected = widget.selected.contains(key);
          final checkboxDecoration = ShadDecoration(
            border: ShadBorder.all(color: colorScheme.border, radius: _fileCheckboxRadius),
          );
          final sizeLabel = showSize ? (_formatEntrySize(entry) ?? "") : "";
          final displayName = _displayNameForEntry(entry);
          final deletePending = widget.isDeletePending(fullPath, entry.isFolder);

          return DataRow(
            onSelectChanged: deletePending
                ? null
                : (_) {
                    widget.onOpen(fullPath, entry.isFolder);
                  },
            color: WidgetStateProperty.resolveWith((states) {
              if (isSelected) {
                return const Color(0xFFF2F1FF);
              }
              if (states.contains(WidgetState.hovered)) {
                return const Color(0xFFF8F8FA);
              }
              return shadCard;
            }),
            cells: [
              if (showSelectColumn)
                DataCell(
                  Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: deletePending ? null : () => widget.onToggleSelected(key, !isSelected),
                      child: _fileSelectionCheckbox(decoration: checkboxDecoration, value: isSelected),
                    ),
                  ),
                ),
              DataCell(
                _hoverRegion(
                  key,
                  Opacity(
                    opacity: deletePending ? 0.45 : 1,
                    child: Row(
                      children: [
                        _getIcon(entry),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(displayName, style: dataStyle, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showSize)
                DataCell(
                  _hoverRegion(
                    key,
                    Container(
                      width: double.infinity,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(sizeLabel, style: dataStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
              DataCell(
                _hoverRegion(
                  key,
                  Container(
                    width: double.infinity,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(entry.updatedAt?.modified() ?? "", style: dataStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              DataCell(
                _hoverRegion(
                  key,
                  deletePending
                      ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                      : ValueListenableBuilder<String?>(
                          valueListenable: _hoveredRowKey,
                          builder: (_, hoveredKey, _) => Center(
                            child: widget.buildActionsMenu(
                              _tableCardKey.currentContext,
                              fullPath,
                              entry.isFolder,
                              alwaysShowMenu || isSelected || hoveredKey == key,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        }).toList();

        final sizeWidth = showSize ? (availableWidth < 760 ? 100.0 : 120.0) : 0.0;
        final modifiedWidth = constraints.maxWidth < 640 ? 140.0 : 170.0;
        final actionWidth = constraints.maxWidth < 640 ? 48.0 : 56.0;
        final selectWidth = showSelectColumn ? (constraints.maxWidth < 640 ? 48.0 : 56.0) : 0.0;
        final fixedWidthTotal = selectWidth + sizeWidth + modifiedWidth + actionWidth;

        if (constraints.maxWidth < fixedWidthTotal + 140) {
          return _buildMobileList(context, widget.forceShowSelect, true, selectAllValue, showSize);
        }

        return _buildTableCard(
          Theme(
            data: Theme.of(context).copyWith(dividerColor: shadBorder),
            child: DataTable2(
              showCheckboxColumn: false,
              columnSpacing: 0,
              horizontalMargin: 0,
              headingRowHeight: filePaneTableHeaderHeight,
              headingRowColor: const WidgetStatePropertyAll(shadCard),
              dataRowColor: const WidgetStatePropertyAll(shadCard),
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
              columns: [
                if (showSelectColumn)
                  DataColumn2(
                    fixedWidth: selectWidth,
                    label: Center(
                      child: ShadTriCheckbox(value: selectAllValue, onChanged: (v) => widget.onToggleAllSelected(v == true)),
                    ),
                  ),
                DataColumn2(
                  label: _getLabel("Name"),
                  size: ColumnSize.L,
                  onSort: (_, ascending) => widget.onSortChanged(FileSort(FileSortField.name, ascending)),
                ),
                if (showSize) DataColumn2(label: _getLabel("Size"), fixedWidth: sizeWidth),
                DataColumn2(
                  label: _getLabel("Modified"),
                  fixedWidth: modifiedWidth,
                  onSort: (_, ascending) => widget.onSortChanged(FileSort(FileSortField.modified, ascending)),
                ),
                DataColumn2(
                  label: widget.isRefreshing
                      ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                      : const SizedBox.shrink(),
                  fixedWidth: actionWidth,
                ),
              ],
              rows: rows,
            ),
          ),
        );
      },
    );
  }
}

class _FileActionsMenuButton extends StatefulWidget {
  const _FileActionsMenuButton({
    super.key,
    required this.items,
    required this.estimatedMenuWidth,
    required this.estimatedMenuHeight,
    required this.showTrigger,
    this.onOpen,
    this.boundaryContext,
  });

  final List<Widget> items;
  final double estimatedMenuWidth;
  final double estimatedMenuHeight;
  final bool showTrigger;
  final VoidCallback? onOpen;
  final BuildContext? boundaryContext;

  @override
  State<_FileActionsMenuButton> createState() => _FileActionsMenuButtonState();
}

class _FileActionsMenuButtonState extends State<_FileActionsMenuButton> {
  static const double _mobileRowMenuTriggerSize = 48;
  late final ShadContextMenuController _controller = ShadContextMenuController();
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncOpenState);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncOpenState);
    _controller.dispose();
    super.dispose();
  }

  void _syncOpenState() {
    if (_menuOpen == _controller.isOpen) {
      return;
    }

    if (!_menuOpen && _controller.isOpen) {
      widget.onOpen?.call();
    }

    setState(() {
      _menuOpen = _controller.isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showTrigger = widget.showTrigger || _menuOpen;
    return AdaptiveShadContextMenu(
      controller: _controller,
      boundaryContext: widget.boundaryContext,
      constraints: const BoxConstraints(minWidth: 200),
      estimatedMenuWidth: widget.estimatedMenuWidth,
      estimatedMenuHeight: widget.estimatedMenuHeight,
      items: widget.items,
      child: IgnorePointer(
        ignoring: !showTrigger,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: showTrigger ? 1 : 0,
          child: ShadGestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _controller.toggle,
            child: const SizedBox(
              width: _mobileRowMenuTriggerSize,
              height: _mobileRowMenuTriggerSize,
              child: Center(child: Icon(LucideIcons.ellipsis, size: 20)),
            ),
          ),
        ),
      ),
    );
  }
}

class ShadTriCheckbox extends StatelessWidget {
  const ShadTriCheckbox({super.key, required this.value, required this.onChanged});

  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool internalBool = value != false;

    final theme = ShadTheme.of(context);
    final effectiveSize = theme.checkboxTheme.size;
    final iconColor = theme.colorScheme.primaryForeground;

    final Widget? effectiveIcon = value == null ? Icon(LucideIcons.minus, size: effectiveSize, color: iconColor) : null;
    final checkboxDecoration = ShadDecoration(
      border: ShadBorder.all(color: ShadTheme.of(context).colorScheme.border, radius: _FileTableViewState._fileCheckboxRadius),
    );
    return Semantics(
      checked: value == true,
      mixed: value == null,
      child: ExcludeSemantics(
        child: ShadCheckbox(
          decoration: checkboxDecoration,
          value: internalBool,
          icon: effectiveIcon,
          onChanged: (_) => onChanged(value == false),
        ),
      ),
    );
  }
}
