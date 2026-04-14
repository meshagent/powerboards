import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_icon/file_icon.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'package:meshagent/document.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/chat/file_prompt_actions.dart';
import 'package:meshagent_flutter_shadcn/file_preview/code.dart';
import 'package:meshagent_flutter_shadcn/file_preview/file_preview.dart';
import 'package:meshagent_flutter_shadcn/storage/transcript_file_name.dart';
import 'package:meshagent_flutter_shadcn/ui/ui.dart';
import 'package:meshagent_flutter_shadcn/viewers/file.dart';

import 'package:powerboards/meshagent/file_breadcrumb_layout.dart';
import 'package:powerboards/meshagent/document_pane.dart';
import 'package:powerboards/meshagent/path.dart';
import 'package:powerboards/meshagent/thread_display_name.dart';
import 'package:powerboards/meshagent/share_remote_file.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/settings/format_date.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:powerboards/ui/app_context_menu.dart';
import 'package:powerboards/ui/pane_empty_state.dart';
import 'package:powerboards/ui/pane_header_action_scope.dart';
import 'package:powerboards/ui/text_validators.dart';

import 'file_upload.dart';

const Set<String> editExtensions = {"md"};
const String placeholderFileName = ".placeholder";
const double filePaneTableHeaderHeight = 48;

bool _usesAdaptiveMobileLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return ResponsiveBreakpoints.of(context).isMobile || (size.width > size.height && size.shortestSide < 600);
}

String _displayFileName(String fileName) {
  return formatTranscriptFileNameForDisplay(fileName);
}

enum FileSortField { name, modified }

enum _FileAction { open, download, share, upload, compressFolder, rename, delete }

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

class FileManagerView extends StatefulWidget {
  final RoomClient client;
  final Resource<List<ServiceSpec>>? services;
  final bool hideSystem;
  final bool mobileShellOwnsHeader;
  final List<Widget> desktopHeaderActions;
  final double desktopHeaderActionLeadingWidthFloor;
  final double desktopHeaderActionMinimumLeadingWidth;
  final double desktopHeaderActionReserve;

  const FileManagerView({
    super.key,
    required this.client,
    this.services,
    this.hideSystem = false,
    this.mobileShellOwnsHeader = false,
    this.desktopHeaderActions = const [],
    this.desktopHeaderActionLeadingWidthFloor = 0,
    this.desktopHeaderActionMinimumLeadingWidth = 0,
    this.desktopHeaderActionReserve = desktopPaneHeaderActionReserve,
  });

  @override
  State<FileManagerView> createState() => _FileManagerViewState();
}

class _FileManagerViewState extends State<FileManagerView> {
  static TextStyle breadcrumbLinkStyle = GoogleFonts.inter(fontSize: 16, fontWeight: .w600);
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
    unawaited(_rebindThreadIndexDocument());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setLocation();
  }

  @override
  void dispose() {
    _isDisposing = true;
    roomSub.cancel();

    uploadNotifications.dispose();
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
      _location = next;
    });
  }

  void _onRoomEvent(RoomEvent event) {
    if (event is FileUpdatedEvent) {
      _onFileUpdated(event.path);
      return;
    }

    if (event is FileDeletedEvent) {
      _onFileDeleted(event.path);
      return;
    }

    if (event is FileMovedEvent) {
      _onFileMoved(event.sourcePath, event.destinationPath);
    }
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
      return threadFileDisplayNameFromPath(path, threadDisplayName: _threadDisplayNamesByPath[path]);
    }
    return _displayFileName(fileName);
  }

  String _displayNameForEntry(StorageEntry entry) {
    final path = joinPaths(_folderSig.value, entry.name);
    return entry.isFolder ? entry.name : _displayNameForPath(path);
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
    unawaited(_backfillThreadDisplayNames());
  }

  Future<void> _rebindThreadIndexDocument() async {
    final nextThreadIndexPath = _threadIndexPathForFolder(_folderSig.value);
    if (_threadIndexPath == nextThreadIndexPath && _threadIndexDocument != null) {
      _refreshThreadDisplayNames();
      unawaited(_backfillThreadDisplayNames());
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
      unawaited(_backfillThreadDisplayNames());
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
        final path = rawPath.trim();
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

  Future<void> _backfillThreadDisplayNames() async {
    if (!_canUpdateUi) {
      return;
    }

    final entries = storageEntries.state.value;
    if (entries == null) {
      return;
    }

    final currentFolder = _folderSig.value;
    for (final entry in entries) {
      if (entry.isFolder || !isThreadFileName(entry.name)) {
        continue;
      }

      final path = joinPaths(currentFolder, entry.name);
      if (!shouldReadThreadDocumentForDisplayName(path)) {
        continue;
      }

      final currentDisplayName = _threadDisplayNamesByPath[path];
      if (!shouldBackfillThreadDisplayName(currentDisplayName) || _threadTitleResolutionsInFlight.contains(path)) {
        continue;
      }

      _threadTitleResolutionsInFlight.add(path);
      unawaited(_resolveAndStoreThreadDisplayName(path: path));
    }
  }

  MeshElement? _threadNodeForPath(String path) {
    final document = _threadIndexDocument;
    if (document == null) {
      return null;
    }

    return document.root.getChildren().whereType<MeshElement>().firstWhereOrNull((node) {
      return node.tagName == 'thread' && node.getAttribute('path') == path;
    });
  }

  Future<void> _resolveAndStoreThreadDisplayName({required String path}) async {
    try {
      final document = await widget.client.sync.open(path);
      try {
        final resolvedName = deriveThreadDisplayNameFromDocument(document);
        if (!_canUpdateUi || resolvedName == null || resolvedName.trim().isEmpty) {
          return;
        }

        final latestNode = _threadNodeForPath(path);
        if (latestNode != null && shouldBackfillThreadDisplayName(latestNode.getAttribute('name') as String?)) {
          latestNode.setAttribute('name', resolvedName);
        }
        setState(() {
          _threadDisplayNamesByPath = <String, String>{..._threadDisplayNamesByPath, path: resolvedName};
        });
      } finally {
        try {
          await widget.client.sync.close(path);
        } catch (_) {}
      }
    } catch (_) {
      return;
    } finally {
      _threadTitleResolutionsInFlight.remove(path);
    }
  }

  void _removePath(String path, {isFolder = false}) {
    if (parentPath(path) != _folderSig.value) return;

    final ready = storageEntries.state.asReady;
    if (ready == null) return; // ignore if loading/error

    final name = path.split('/').where((s) => s.isNotEmpty).last;
    final next = List<StorageEntry>.of(ready.value);
    next.removeWhere((e) => e.name == name && e.isFolder == isFolder);
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
    unawaited(_backfillThreadDisplayNames());
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

  void _selectAllVisible() => _setSelected(_visibleKeys.value);
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
    final state = PathRouteMatch.of(context);
    final currentUri = state.uri;

    final updatedQueryParameters = Map<String, String>.from(currentUri.queryParameters);
    updatedQueryParameters['p'] = path.isEmpty ? '' : (isFolder ? '$path/' : path);

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

  void _closeFile() => _openEntry(_folderSig.value, true);
  void _previousFile() => _cycleFile(-1);
  void _nextFile() => _cycleFile(1);

  Future<List<StorageEntry>> _getChildren(String folderPath) async {
    return await widget.client.storage.list(folderPath);
  }

  Future<void> _uploadFile(Stream<Uint8List> stream, String path, int totalBytes) async {
    if (totalBytes == 0 && _isEditableTextFile(path)) {
      _optimisticEmptyTextFiles.add(path);
    }

    final upload = MeshagentFileUpload(room: widget.client, path: path, dataStream: stream, size: totalBytes);
    uploadNotifications.addUpload(upload, totalBytes);

    unawaited(
      upload.done.then((_) async {
        if (!mounted) {
          return;
        }

        if (parentPath(path) == _folderSig.value) {
          await _refreshCurrentFolder();
        }
      }),
    );
  }

  Future<void> _downloadFile(String path) async {
    final url = await widget.client.storage.downloadUrl(path);
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

  Future<void> _deleteFile(String path) async {
    await widget.client.storage.delete(path);
  }

  Future<void> _deleteFolder(String folderPath) async {
    final children = await _getChildren(folderPath);

    for (final child in children) {
      final childPath = joinPaths(folderPath, child.name);

      if (child.isFolder) {
        await _deleteFolder(childPath);
      } else {
        await _deleteFile(childPath);
      }
    }

    _removePath(folderPath, isFolder: true);
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

  Future<String?> _promptRenamePath(String fullPath, {required bool isFolder}) async {
    final currentName = p.basename(fullPath);
    return await showShadDialog<String>(
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
              title: Text(isFolder ? "Rename folder" : "Rename file"),
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
                    ShadInputFormField(
                      id: "name",
                      initialValue: currentName,
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
    final currentName = p.basename(fullPath);
    final nextName = await _promptRenamePath(fullPath, isFolder: isFolder);
    if (!mounted) {
      return;
    }
    if (nextName == null || nextName == currentName) {
      return;
    }

    final destinationPath = joinPaths(parentPath(fullPath), nextName);
    final toaster = ShadToaster.of(context);

    try {
      if (await widget.client.storage.exists(destinationPath)) {
        if (!mounted) {
          return;
        }

        toaster.show(
          ShadToast.destructive(
            title: const Text("Rename failed"),
            description: Text("${isFolder ? 'Folder' : 'File'} `$nextName` already exists in this location."),
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
    final result = await showShadDialog<String>(
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
                    ShadInputFormField(
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
    final bool? confirmDelete = await showShadDialog<bool>(
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
      if (isFolder) {
        await _deleteFolder(fullPath);
      } else {
        await _deleteFile(fullPath);
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

    final confirmDelete = await showShadDialog<bool>(
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
    final toDelete = selected.toList();

    if (isMobile) {
      _clearMobileSelectionMode();
    }

    for (final key in toDelete) {
      final isFolder = _FilePathKey.isFolderKey(key);
      final path = _FilePathKey.pathFromKey(key);

      try {
        if (isFolder) {
          await _deleteFolder(path);
        } else {
          await _deleteFile(path);
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
    showShadDialog<String>(
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
                resolvedName = await showShadDialog<String>(
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
                    ShadInputFormField(
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
    if (isFolder) {
      return isCompleted ? "Folder created" : "Creating folder";
    }

    final count = uploads.length;
    final verb = isCompleted ? "Uploaded" : "Uploading";
    return "$verb $count file${count > 1 ? 's' : ''}";
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

  Widget _buildActionsMenu(BuildContext? boundaryContext, String fullPath, bool isFolder, bool showTrigger) {
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
      if (isFolder || widget.services?.state.isReady != true) {
        return const <ChatFilePromptAction>[];
      }

      return resolveChatFilePromptActions(services: widget.services!.state.value!, filePath: fullPath);
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
        if (!isFolder)
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
        const SizedBox(height: desktopPaneSecondaryControlTopOffset),
        _buildDesktopContextToolbar(selected),
      ],
    );
  }

  Widget _buildDesktopHeaderLeading() {
    if (_openedFile == null) {
      return _buildBreadcrumb();
    }

    final fileName = _displayNameForPath(_openedFile!);

    return Row(
      spacing: desktopPaneHeaderButtonGap,
      children: [
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

  TextStyle _mobileOpenedFileTextActionStyle(Color color) {
    return GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: color);
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

  Widget _buildAdaptiveMobileOpenedFileIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    bool destructive = false,
  }) {
    final button = destructive
        ? ShadIconButton.destructive(
            icon: Icon(icon, size: paneHeaderIconButtonIconSize),
            onPressed: onPressed,
          )
        : ShadIconButton.outline(
            icon: Icon(icon, size: paneHeaderIconButtonIconSize),
            onPressed: onPressed,
          );

    return Tooltip(message: tooltip, child: button);
  }

  Widget _buildAdaptiveMobileOpenedFileTextAction() {
    if (!_openedFileSupportsEditTabs) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text("Preview", style: _mobileOpenedFileTextActionStyle(shadForeground)),
      );
    }

    if (_tab != 'edit') {
      return ShadButton.ghost(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        onPressed: () => setState(() => _tab = 'edit'),
        child: Text("Edit this file", style: _mobileOpenedFileTextActionStyle(shadForeground)),
      );
    }

    return AnimatedBuilder(
      animation: _codePreviewController,
      builder: (context, _) {
        return ShadButton.ghost(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          onPressed: _saveAdaptiveMobileEdits,
          child: Text("Save your edits", style: _mobileOpenedFileTextActionStyle(shadDestructive)),
        );
      },
    );
  }

  Widget _buildAdaptiveMobileOpenedFileToolbar() {
    return SizedBox(
      height: powerboardsMobileSecondaryRowHeight,
      child: Center(
        child: Padding(
          padding: powerboardsMobileSecondaryRowPadding,
          child: Row(
            children: [
              _buildAdaptiveMobileOpenedFileTextAction(),
              const Spacer(),
              if (supportsNativeFileShare) ...[
                _buildAdaptiveMobileOpenedFileIconButton(
                  tooltip: "Share",
                  icon: LucideIcons.share,
                  onPressed: () => _shareFile(_openedFile!),
                ),
                const SizedBox(width: 8),
              ],
              _buildAdaptiveMobileOpenedFileIconButton(
                tooltip: "Download",
                icon: LucideIcons.download,
                onPressed: () => _downloadFile(_openedFile!),
              ),
              const SizedBox(width: 8),
              _buildAdaptiveMobileOpenedFileIconButton(
                tooltip: "Delete file",
                icon: LucideIcons.trash,
                destructive: true,
                onPressed: () async {
                  final openedFile = _openedFile;
                  if (openedFile == null) {
                    return;
                  }

                  final confirmDelete = await _confirmAndDelete(openedFile, false);
                  if (confirmDelete == true) {
                    _openEntry(_folderSig.value, true);
                  }
                },
              ),
            ],
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
        child: ShadIconButton.ghost(icon: const Icon(LucideIcons.x), onPressed: _closeFile),
      ),
    ];
  }

  List<Widget> _buildFileCycleActions() {
    final canCycleFiles = _visibleSortedFiles.value.length > 1;

    return [
      if (canCycleFiles)
        Tooltip(
          message: "Previous file",
          child: ShadIconButton.outline(icon: const Icon(LucideIcons.chevronLeft), onPressed: _previousFile),
        ),
      if (canCycleFiles)
        Tooltip(
          message: "Next file",
          child: ShadIconButton.outline(icon: const Icon(LucideIcons.chevronRight), onPressed: _nextFile),
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
        if (supportsNativeFileShare)
          Tooltip(
            message: "Share",
            child: ShadIconButton.outline(
              icon: const Icon(LucideIcons.share),
              onPressed: () {
                _shareFile(_openedFile!);
              },
            ),
          ),
        Tooltip(
          message: "Download",
          child: ShadIconButton.outline(
            icon: const Icon(LucideIcons.download),
            onPressed: () {
              _downloadFile(_openedFile!);
            },
          ),
        ),
        Tooltip(
          message: "Delete file",
          child: ShadIconButton.outline(
            icon: const Icon(LucideIcons.trash),
            onPressed: () async {
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
            onPressed: () {
              _addFolder(_folderSig.value);
            },
          ),
        ),
        _buildUploadMenu(),
        if (!kIsWeb)
          Tooltip(
            message: "Upload photo",
            child: ShadIconButton.outline(
              icon: const Icon(LucideIcons.imagePlus),
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
          child: ShadIconButton.outline(icon: const Icon(LucideIcons.upload), onPressed: controller.toggle),
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
    final openedFile = _openedFile;
    if (openedFile != null) {
      final fileName = _displayNameForPath(openedFile);
      final closeActionWidth = 40.0 + desktopPaneHeaderButtonGap;
      final fileNameWidth = _measureBreadcrumbLabelWidth(context, fileName) + 24.0;
      return math.min(closeActionWidth + fileNameWidth, math.min(180.0, maxWidth * 0.24));
    }

    final segments = _folderBreadcrumbSegments();
    var width = 0.0;
    for (var i = 0; i < segments.length; i++) {
      width += _measureBreadcrumbLabelWidth(context, segments[i].label) + 40.0;
      if (i > 0) {
        width += 20.0;
      }
    }

    return math.min(width, math.min(180.0, maxWidth * 0.24));
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
        child: ShadIconButton.outline(icon: const Icon(LucideIcons.folderTree), onPressed: _collapsedBreadcrumbMenuController.toggle),
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
      FileKind.pdf || FileKind.office || FileKind.code => false,
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
          child: SignalBuilder(
            builder: (context, _) {
              final selected = _visibleSelected.value;
              final isAdaptiveMobile = widget.mobileShellOwnsHeader && _usesAdaptiveMobileLayout(context);
              final hasOpenedFile = _openedFile != null;
              final hideEmbeddedMobileToolbar = isAdaptiveMobile && !hasOpenedFile;
              final showAdaptiveOpenedFileDivider = isAdaptiveMobile && hasOpenedFile;
              return Column(
                crossAxisAlignment: .start,
                children: [
                  if (showAdaptiveOpenedFileDivider)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: shadBorder.withValues(alpha: 0.5))),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildToolbar(selected),
                          const SizedBox(height: desktopPaneSecondaryRowContentGap),
                        ],
                      ),
                    )
                  else ...[
                    _buildToolbar(selected),
                    if (!hideEmbeddedMobileToolbar) const SizedBox(height: desktopPaneSecondaryRowContentGap),
                  ],
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
  static TextStyle dataStyle = GoogleFonts.inter(fontSize: 14, fontWeight: .w500, color: .fromARGB(255, 0x22, 0x22, 0x22));
  static TextStyle headerStyle = GoogleFonts.inter(fontSize: 14, fontWeight: .w500, color: .fromARGB(255, 0x66, 0x66, 0x66));
  static const List<String> _sizeUnits = <String>['B', 'KB', 'MB', 'GB', 'TB'];

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

  IconData? _iconDataFor(StorageEntry entry) {
    if (entry.isFolder) return LucideIcons.folder;
    if (entry.name.endsWith('presentation')) return LucideIcons.presentation;
    if (entry.name.endsWith('document')) return LucideIcons.fileText;
    if (entry.name.endsWith('gallery')) return LucideIcons.image;

    return null;
  }

  Widget _getIcon(StorageEntry entry) {
    final iconData = _iconDataFor(entry);
    const iconSize = 34.0;
    const paddedIconSize = 24.0;

    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: iconData != null
          ? Center(
              child: Icon(
                iconData,
                size: paddedIconSize,
                color: entry.isFolder ? ShadTheme.of(context).colorScheme.secondaryForeground : null,
              ),
            )
          : FileIcon(entry.name, size: iconSize),
    );
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

    return _formatBytes(size);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < _sizeUnits.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final decimals = value >= 10 || value == value.roundToDouble() ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${_sizeUnits[unitIndex]}';
  }

  Widget _hoverRegion(String rowKey, Widget child) {
    return MouseRegion(opaque: true, onEnter: (_) => _setHovered(rowKey), onExit: (_) => _clearHoveredIf(rowKey), child: child);
  }

  Icon _sortIcon(bool ascending, {Color color = shadMutedForeground}) {
    return Icon(ascending ? LucideIcons.arrowUp : LucideIcons.arrowDown, size: 16, color: color);
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

  Widget _buildMobileHeaderActionButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    bool destructive = false,
  }) {
    final button = destructive
        ? ShadIconButton.destructive(
            icon: Icon(icon, size: paneHeaderIconButtonIconSize),
            onPressed: onPressed,
          )
        : ShadIconButton.outline(
            icon: Icon(icon, size: paneHeaderIconButtonIconSize),
            onPressed: onPressed,
          );

    return Tooltip(message: tooltip, child: button);
  }

  Widget _buildMobileSelectionHeaderButton() {
    final selectionActive = widget.forceShowSelect;
    final label = selectionActive ? 'Cancel' : 'Select';
    final textColor = selectionActive ? shadDestructive : shadForeground;

    return ShadButton.ghost(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      onPressed: selectionActive ? widget.onClearSelectionMode : widget.onActivateSelectionMode,
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }

  Widget _buildMobileSortHeaderButton() {
    final isNameSort = widget.sort.field == FileSortField.name;

    return ShadButton.ghost(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      onPressed: () => widget.onSortChanged(FileSort(FileSortField.name, isNameSort ? !widget.sort.ascending : true)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sort by name', style: headerStyle.copyWith(color: shadMutedForeground)),
          const SizedBox(width: 6),
          _sortIcon(widget.sort.ascending, color: shadMutedForeground),
        ],
      ),
    );
  }

  Widget _buildMobileSelectedActions() {
    if (!widget.forceShowSelect) {
      return const SizedBox.shrink();
    }

    final showDownloadAction = widget.selected.isNotEmpty && widget.selected.every((key) => !_FilePathKey.isFolderKey(key));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDownloadAction) ...[
          _buildMobileHeaderActionButton(tooltip: "Download selected", icon: LucideIcons.download, onPressed: widget.onDownloadSelected),
          const SizedBox(width: 8),
        ],
        _buildMobileHeaderActionButton(
          tooltip: "Delete selected",
          icon: LucideIcons.trash,
          onPressed: widget.onDeleteSelected,
          destructive: true,
        ),
      ],
    );
  }

  Widget _buildMobileHeader(bool showSelectColumn, bool? selectAllValue) {
    final selectButton = _buildMobileSelectionHeaderButton();
    final sortButton = _buildMobileSortHeaderButton();
    final selectionActions = _buildMobileSelectedActions();
    final showSelectionModeActions = widget.forceShowSelect;

    return SizedBox(
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
              selectButton,
              const Spacer(),
              if (showSelectionModeActions) selectionActions,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isRefreshing)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  if (!showSelectionModeActions) sortButton,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(BuildContext context, bool showSelectColumn, bool alwaysShowMenu, bool? selectAllValue, bool showSize) {
    final colorScheme = ShadTheme.of(context).colorScheme;

    return _buildTableCard(
      Column(
        children: [
          _buildMobileHeader(showSelectColumn, selectAllValue),
          const Divider(height: 1, color: shadBorder),
          Expanded(
            child: ListView.separated(
              itemCount: widget.entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: shadBorder),
              itemBuilder: (context, index) {
                final entry = widget.entries[index];
                final fullPath = _FilePathKey.pathForEntry(widget.currentPath, entry);
                final key = _FilePathKey.keyForEntry(widget.currentPath, entry);
                final isSelected = widget.selected.contains(key);
                final checkboxDecoration = ShadDecoration(border: ShadBorder.all(color: colorScheme.border));
                final showRowMenu = !widget.forceShowSelect;
                final sizeLabel = showSize ? _formatEntrySize(entry) : null;
                final modifiedLabel = entry.updatedAt?.modified() ?? '';
                final metadataLabel = <String>[if (sizeLabel != null) sizeLabel, if (modifiedLabel.isNotEmpty) modifiedLabel].join(' • ');
                final showMetadataLabel = metadataLabel.isNotEmpty;
                final displayName = _displayNameForEntry(entry);

                return Material(
                  color: isSelected ? const Color(0xFFF2F1FF) : shadCard,
                  child: InkWell(
                    onTap: () => widget.onOpen(fullPath, entry.isFolder),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        powerboardsMobileSecondaryRowLeadingInset,
                        14,
                        powerboardsMobileSecondaryRowTrailingInset,
                        14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (showSelectColumn) ...[
                            SizedBox(
                              width: 36,
                              child: Center(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => widget.onToggleSelected(key, !isSelected),
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
        final bool? selectAllValue = widget.selected.isEmpty ? false : (widget.selected.length == widget.entries.length ? true : null);

        if (isMobile) {
          return _buildMobileList(context, showSelectColumn, alwaysShowMenu, selectAllValue, showSize);
        }

        final sortColumnIndex = (widget.sort.field == FileSortField.name ? 0 : (showSize ? 2 : 1)) + (showSelectColumn ? 1 : 0);
        final sortAscending = widget.sort.ascending;
        final rows = widget.entries.map((entry) {
          final fullPath = _FilePathKey.pathForEntry(widget.currentPath, entry);
          final key = _FilePathKey.keyForEntry(widget.currentPath, entry);
          final isSelected = widget.selected.contains(key);
          final checkboxDecoration = ShadDecoration(border: ShadBorder.all(color: colorScheme.border));
          final sizeLabel = showSize ? (_formatEntrySize(entry) ?? "") : "";
          final displayName = _displayNameForEntry(entry);

          return DataRow(
            onSelectChanged: (_) {
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
                      onTap: () => widget.onToggleSelected(key, !isSelected),
                      child: _fileSelectionCheckbox(decoration: checkboxDecoration, value: isSelected),
                    ),
                  ),
                ),
              DataCell(
                _hoverRegion(
                  key,
                  Row(
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
                  ValueListenableBuilder<String?>(
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

class UploadProgressItem {
  const UploadProgressItem({required this.upload, required this.totalBytes});

  final MeshagentFileUpload upload;
  final int totalBytes;
}

class UploadProgressNotifications {
  UploadProgressNotifications({required this.popoverController});

  final ShadPopoverController popoverController;

  final _uploads = Signal<List<UploadProgressItem>>([]);
  final _isCompleted = Signal<bool>(false);
  final _activeUploads = <Future<void>>[];

  late final isCompletedVN = _isCompleted.toValueNotifier();
  late final uploadsVN = _uploads.toValueNotifier();

  bool _running = false;
  bool _resetUploads = true;
  Timer? _autoHideTimer;

  void addUpload(MeshagentFileUpload upload, int totalBytes) {
    _autoHideTimer?.cancel();
    _isCompleted.value = false;

    final item = UploadProgressItem(upload: upload, totalBytes: totalBytes);
    _uploads.value = _resetUploads ? [item] : [..._uploads.value, item];
    _resetUploads = false;
    _activeUploads.add(upload.done);

    _ensureRunning();
  }

  void dispose() {
    _autoHideTimer?.cancel();
    _uploads.dispose();
    _isCompleted.dispose();
  }

  void _ensureRunning() {
    if (_running) return;

    _running = true;
    _run();
  }

  Future<void> _run() async {
    if (!popoverController.isOpen) {
      popoverController.show();
    }

    try {
      while (_activeUploads.isNotEmpty) {
        await _activeUploads.removeAt(0);
      }
      _resetUploads = true;
      _isCompleted.value = true;
      _autoHideTimer?.cancel();
      _autoHideTimer = Timer(Duration(seconds: 3), hide);
    } finally {
      _running = false;
    }
  }

  void hide() {
    _autoHideTimer?.cancel();
    popoverController.hide();
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
    final checkboxDecoration = ShadDecoration(border: ShadBorder.all(color: ShadTheme.of(context).colorScheme.border));
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
