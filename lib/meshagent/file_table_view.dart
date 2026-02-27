import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_icon/file_icon.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/ui/ui.dart';
import 'package:meshagent_flutter_shadcn/viewers/file.dart';

import 'package:powerboards/meshagent/document_pane.dart';
import 'package:powerboards/meshagent/path.dart';
import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/settings/format_date.dart';
import 'package:powerboards/ui/app_context_menu.dart';
import 'package:powerboards/ui/text_validators.dart';

import 'file_upload.dart';

enum FileSortField { name, modified }

enum _FileAction { open, download, upload, delete }

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
    final path = joinPaths(raw, ''); // normalize: remove trailing slash
    final last = path.split('/').where((s) => s.isNotEmpty).lastOrNull;
    final isFile = last != null && last.contains('.'); //todo: fix file detection by looking at storage entries instead of name

    return isFile ? _FileLocation(folder: parentPath(path), openedFile: path) : _FileLocation(folder: path, openedFile: null);
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

  static String displayNameFromKey(String key) {
    final trimmed = pathFromKey(key);
    final last = trimmed.split('/').where((s) => s.isNotEmpty).lastOrNull ?? trimmed;
    return isFolderKey(key) ? '$last/' : last;
  }
}

class FileManagerView extends StatefulWidget {
  final RoomClient client;
  final bool hideSystem;

  const FileManagerView({super.key, required this.client, this.hideSystem = false});

  @override
  State<FileManagerView> createState() => _FileManagerViewState();
}

class _FileManagerViewState extends State<FileManagerView> {
  static TextStyle breadcrumbLinkStyle = GoogleFonts.inter(fontSize: 16, fontWeight: .w600);

  _FileLocation _location = const _FileLocation(folder: "", openedFile: null);
  String? get _openedFile => _location.openedFile;

  bool _forceShowSelect = false;

  final popoverController = ShadPopoverController();
  late final uploadNotifications = UploadProgressNotifications(popoverController: popoverController);

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setLocation();
  }

  @override
  void dispose() {
    roomSub.cancel();

    uploadNotifications.dispose();
    popoverController.dispose();

    _visibleSortedFiles.dispose();
    _visibleSelected.dispose();
    _visibleKeys.dispose();
    _visibleSortedEntries.dispose();

    storageEntries.dispose();
    _sortSig.dispose();
    _selectedSig.dispose();
    _folderSig.dispose();

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
    }

    if (openedFileChanged) {
      widget.client.localParticipant?.setAttribute("current_file", next.openedFile);
    }

    setState(() => _location = next);
  }

  void _onRoomEvent(RoomEvent event) {
    final path = switch (event) {
      FileUpdatedEvent e => e.path,
      FileDeletedEvent e => e.path,
      _ => null,
    };
    if (path == null) return;

    final ready = storageEntries.state.asReady;
    if (ready == null) return; // ignore if loading/error

    final name = path.split('/').where((s) => s.isNotEmpty).last;
    final next = List<StorageEntry>.of(ready.value);
    final now = DateTime.now();
    final p = parentPath(path);

    if (p != _folderSig.value) {
      if (event is FileUpdatedEvent && parentPath(p) == _folderSig.value) {
        final parentName = p.split('/').where((s) => s.isNotEmpty).last;
        final idx = next.indexWhere((e) => e.name == parentName);
        if (idx == -1) {
          next.add(StorageEntry(name: parentName, isFolder: true, createdAt: now, updatedAt: null));
          _setEntries(next);
        }
      }
      return;
    }

    if (event is FileUpdatedEvent) {
      final idx = next.indexWhere((e) => e.name == name);
      if (idx == -1) {
        next.add(StorageEntry(name: name, isFolder: false, createdAt: now, updatedAt: now));
      } else {
        final old = next[idx];
        next[idx] = StorageEntry(name: name, isFolder: false, createdAt: old.createdAt, updatedAt: now);
      }
    } else if (event is FileDeletedEvent) {
      next.removeWhere((e) => e.name == name);
      _toggleSelected(_FilePathKey.keyForPath(path, false), false);
    }

    _setEntries(next);
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

  void _toggleForceShowSelect() {
    setState(() {
      _forceShowSelect = !_forceShowSelect;
    });
  }

  void _open(String path) {
    final state = PathRouteMatch.of(context);
    final currentUri = state.uri;

    final updatedQueryParameters = Map<String, String>.from(currentUri.queryParameters);
    updatedQueryParameters['p'] = path;

    final newUri = currentUri.replace(queryParameters: updatedQueryParameters);

    context.go(newUri.toString());
  }

  Future<void> _cycleFile(int offset) async {
    await storageEntries.untilReady();

    final files = _visibleSortedFiles.value;
    if (files.isEmpty || _openedFile == null) return;

    final currentIndex = files.indexOf(_openedFile!);
    if (currentIndex < 0) return;

    final nextIndex = (currentIndex + offset + files.length) % files.length;
    _open(files[nextIndex]);
  }

  void _closeFile() => _open(_folderSig.value);
  void _previousFile() => _cycleFile(-1);
  void _nextFile() => _cycleFile(1);

  Future<List<StorageEntry>> _getChildren(String folderPath) async {
    return await widget.client.storage.list(folderPath);
  }

  Future<void> _uploadFile(Stream<Uint8List> stream, String path, int totalBytes) async {
    final upload = MeshagentFileUpload(room: widget.client, path: path, dataStream: stream);
    uploadNotifications.addUpload(upload, totalBytes);
  }

  Future<void> _downloadFile(String path) async {
    final url = await widget.client.storage.downloadUrl(path);
    launchUrl(Uri.parse(url));
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

            return ShadDialog(
              crossAxisAlignment: CrossAxisAlignment.start,
              title: Text("New folder"),
              actions: [
                ShadButton.outline(
                  onPressed: () {
                    Navigator.of(context).pop(null);
                  },
                  child: const Text('Cancel'),
                ),

                ShadButton(
                  onTapDown: (_) {
                    return submit();
                  },
                  child: const Text("OK"),
                ),
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

    final fileName = joinPaths(path, "$result/.placeholder");
    await _uploadFile(Stream.empty(), fileName, 0);
  }

  Future<bool> _confirmAndDelete(String fullPath, bool isFolder) async {
    final name = fullPath.split('/').where((s) => s.isNotEmpty).last;
    final bool? confirmDelete = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        useSafeArea: false,
        title: const Text("Confirm Delete"),
        description: Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text("Are you sure you want to delete ${isFolder ? 'folder $name and all its contents' : name}?"),
        ),
        actions: [
          ShadButton.outline(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
          ShadButton(autofocus: true, child: const Text('Delete'), onPressed: () => Navigator.of(context).pop(true)),
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
    final count = selected.length;
    final names = selected.take(6).map(_FilePathKey.displayNameFromKey).toList();

    final confirmDelete = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        useSafeArea: false,
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
          ShadButton(autofocus: true, child: const Text('Delete'), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );

    if (confirmDelete != true) return;

    int success = 0;
    final failures = <String>[];
    final toDelete = selected.toList();

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

  void _showNewTextFileDialog() {
    showShadDialog<String>(
      context: context,
      builder: (context) {
        return ControlledForm(
          builder: (context, controller, formKey) {
            void submit(_) {
              if (!formKey.currentState!.saveAndValidate()) {
                return;
              }

              final formData = formKey.currentState!.value;
              String name = formData["name"] ?? "";

              if (!name.contains('.')) {
                name = "$name.md";
              }

              Navigator.of(context).pop(name);
            }

            return ShadDialog(
              crossAxisAlignment: CrossAxisAlignment.start,
              title: Text("New Text File"),
              actions: [ShadButton(onTapDown: submit, child: const Text("OK"))],
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
                      validator: (value) => value.isEmpty ? "File name cannot be empty" : null,
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
                    child: Text(
                      "Upload${isCompleted ? 'ed' : 'ing'} ${uploads.length} file${uploads.length > 1 ? 's' : ''}",
                      style: tt.small.copyWith(fontWeight: .w700),
                    ),
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

                                return Padding(
                                  padding: const .only(bottom: 8),
                                  child: Column(
                                    crossAxisAlignment: .start,
                                    children: [
                                      Text(upload.path.split('/').last, style: TextStyle(fontSize: 12)),
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

  PopupMenuItem<_FileAction> _menuItem(_FileAction value, IconData icon, String text) {
    return PopupMenuItem<_FileAction>(
      value: value,
      child: Row(children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(text)]),
    );
  }

  Widget _buildActionsMenu(String fullPath, bool isFolder) {
    return PopupMenuButton<_FileAction>(
      icon: const Icon(LucideIcons.ellipsis),
      onSelected: (action) async {
        switch (action) {
          case _FileAction.open:
            _open(fullPath);
            break;
          case _FileAction.delete:
            await _confirmAndDelete(fullPath, isFolder);
            break;
          case _FileAction.upload:
            await _addFiles(fullPath);
            break;
          case _FileAction.download:
            await _downloadFile(fullPath);
            break;
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<_FileAction>>[
        if (!isFolder) _menuItem(_FileAction.open, LucideIcons.externalLink, 'Open'),
        if (!isFolder) _menuItem(_FileAction.download, LucideIcons.download, 'Download'),
        if (isFolder) _menuItem(_FileAction.open, LucideIcons.folderOpen, 'Open folder'),
        if (isFolder) _menuItem(_FileAction.upload, LucideIcons.upload, 'Upload here'),
        const PopupMenuDivider(),
        _menuItem(_FileAction.delete, LucideIcons.trash, 'Delete'),
      ],
    );
  }

  Widget _buildToolbar(Set<String> selected) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final showSelectionActions = selected.isNotEmpty && _openedFile == null;
    final showRouteActions = !isMobile || !showSelectionActions;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: [
          if (_openedFile != null) ..._buildFileNavActions(),
          Expanded(child: showSelectionActions ? _buildSelection(selected) : _buildBreadcrumb()),
          if (showRouteActions) ..._buildRouteActions(),
          if (isMobile)
            Tooltip(
              message: "Select items",
              child: (_forceShowSelect ? ShadIconButton.new : ShadIconButton.outline)(
                icon: const Icon(LucideIcons.squareCheckBig),
                onPressed: _toggleForceShowSelect,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildFileNavActions() {
    return [
      Tooltip(
        message: "Close file",
        child: ShadIconButton.ghost(icon: const Icon(LucideIcons.x), onPressed: _closeFile),
      ),
      Tooltip(
        message: "Previous file",
        child: ShadIconButton.outline(icon: const Icon(LucideIcons.chevronLeft), onPressed: _previousFile),
      ),
      Tooltip(
        message: "Next file",
        child: ShadIconButton.outline(icon: const Icon(LucideIcons.chevronRight), onPressed: _nextFile),
      ),
    ];
  }

  List<Widget> _buildRouteActions() {
    if (_openedFile != null) {
      return [
        Tooltip(
          message: "Delete file",
          child: ShadIconButton.outline(
            icon: const Icon(LucideIcons.trash),
            onPressed: () async {
              final confirmDelete = await _confirmAndDelete(_openedFile!, false);
              if (confirmDelete == true) {
                _open(_folderSig.value);
              }
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
      childBuilder: (context, controller) {
        return Tooltip(
          message: "Upload file",
          child: ShadIconButton.outline(
            icon: const Icon(LucideIcons.upload),
            onPressed: () {
              if (!controller.isOpen) {
                controller.show();
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildSelection(Set<String> selected) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        spacing: 8,
        children: [
          Text('${selected.length} selected', style: breadcrumbLinkStyle),
          const SizedBox.shrink(),
          ShadButton.destructive(onPressed: () => _confirmAndDeleteSelected(), child: const Text("Delete")),
          ShadButton.outline(onPressed: _clearSelected, child: Text(isMobile ? "Clear" : "Clear selection")),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    List<Widget> crumbs = [];

    crumbs.add(
      ShadButton.ghost(
        onPressed: () => _open(""),
        child: Text("Files", style: breadcrumbLinkStyle),
      ),
    );

    final segments = _folderSig.value.split('/').where((s) => s.isNotEmpty).toList();
    String accumulated = "";
    for (final segment in segments) {
      accumulated = accumulated.isEmpty ? segment : "$accumulated/$segment";
      final currentPath = accumulated;
      crumbs.add(const Icon(LucideIcons.chevronRight, color: Color(0xffa5a5a5)));
      crumbs.add(
        ShadButton.ghost(
          onPressed: () => _open(currentPath),
          child: Text(segment, style: breadcrumbLinkStyle),
        ),
      );
    }

    if (_openedFile != null) {
      final fileName = _openedFile!.split('/').last;
      crumbs.add(const Icon(LucideIcons.chevronRight, color: Color(0xffa5a5a5)));
      crumbs.add(ShadButton.ghost(enabled: false, child: Text(fileName, style: breadcrumbLinkStyle)));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: crumbs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _openedFile == null ? _clearSelected : _closeFile,
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
              return Column(
                crossAxisAlignment: .start,
                children: [
                  _buildToolbar(selected),
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
                            child: Container(
                              margin: const .fromLTRB(8, 0, 8, 0),
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
                                        onOpen: _open,
                                        onToggleSelected: _toggleSelected,
                                        onToggleAllSelected: _toggleAllSelected,
                                        onSortChanged: _setSort,
                                        buildActionsMenu: _buildActionsMenu,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        if (_openedFile != null)
                          fileViewer(widget.client, _openedFile!) ?? DocumentPane(path: _openedFile!, room: widget.client),
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
  final void Function(String fullPath) onOpen;
  final void Function(String key, bool selected) onToggleSelected;
  final void Function(bool selected) onToggleAllSelected;
  final void Function(FileSort) onSortChanged;
  final Widget Function(String fullPath, bool isFolder) buildActionsMenu;

  const FileTableView({
    super.key,
    required this.currentPath,
    required this.entries,
    required this.selected,
    required this.sort,
    required this.isRefreshing,
    required this.forceShowSelect,
    required this.onOpen,
    required this.onToggleSelected,
    required this.onToggleAllSelected,
    required this.onSortChanged,
    required this.buildActionsMenu,
  });

  @override
  State createState() => _FileTableViewState();
}

class _FileTableViewState extends State<FileTableView> {
  static TextStyle dataStyle = GoogleFonts.inter(fontSize: 14, fontWeight: .w500, color: .fromARGB(255, 0x22, 0x22, 0x22));
  static TextStyle headerStyle = GoogleFonts.inter(fontSize: 14, fontWeight: .w500, color: .fromARGB(255, 0x66, 0x66, 0x66));

  final ValueNotifier<String?> _hoveredRowKey = ValueNotifier<String?>(null);

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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.folder, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "This folder is empty",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          const Text(
            "It looks like there are no files here",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
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
              child: Icon(iconData, size: paddedIconSize, color: (entry.isFolder ? .fromARGB(0xff, 0xe0, 0xa0, 0x30) : null)),
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

  Widget _hoverRegion(String rowKey, Widget child) {
    return MouseRegion(opaque: true, onEnter: (_) => _setHovered(rowKey), onExit: (_) => _clearHoveredIf(rowKey), child: child);
  }

  Widget _hoverShow(String rowKey, bool alwaysShow, Widget child) {
    return ValueListenableBuilder<String?>(
      valueListenable: _hoveredRowKey,
      builder: (_, hoveredKey, _) {
        final show = alwaysShow || hoveredKey == rowKey;
        return Visibility(visible: show, maintainSize: true, maintainAnimation: true, maintainState: true, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return _buildEmptyState(context);
    }

    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final colorScheme = ShadTheme.of(context).colorScheme;
    final showSelectColumn = !isMobile || widget.forceShowSelect;
    final alwaysShowCheckbox = isMobile || widget.selected.isNotEmpty;
    final alwaysShowMenu = isMobile;

    final bool? selectAllValue = widget.selected.isEmpty ? false : (widget.selected.length == widget.entries.length ? true : null);
    final sortColumnIndex = (widget.sort.field == FileSortField.name ? 0 : 1) + (showSelectColumn ? 1 : 0);
    final sortAscending = widget.sort.ascending;

    final rows = widget.entries.map((entry) {
      final fullPath = _FilePathKey.pathForEntry(widget.currentPath, entry);
      final key = _FilePathKey.keyForEntry(widget.currentPath, entry);
      final isSelected = widget.selected.contains(key);

      return DataRow(
        onSelectChanged: (_) {
          widget.onOpen(fullPath);
        },
        color: WidgetStateProperty.resolveWith((states) {
          if (isSelected) {
            return Colors.blue.shade50;
          }
          if (states.contains(WidgetState.hovered)) {
            return Colors.grey.shade100;
          }
          return null;
        }),
        cells: [
          if (showSelectColumn)
            DataCell(
              Container(
                decoration: BoxDecoration(color: Colors.white),
                child: _hoverRegion(
                  key,
                  _hoverShow(
                    key,
                    alwaysShowCheckbox,
                    Center(
                      child: Checkbox(value: isSelected, onChanged: (v) => widget.onToggleSelected(key, v ?? false)),
                    ),
                  ),
                ),
              ),
            ),
          DataCell(
            _hoverRegion(
              key,
              Row(
                children: [
                  Container(width: 3, color: isSelected ? colorScheme.primary : Colors.transparent),
                  _getIcon(entry),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(entry.name, style: dataStyle, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
          DataCell(
            _hoverRegion(
              key,
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(entry.updatedAt?.modified() ?? "", style: dataStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          DataCell(_hoverRegion(key, _hoverShow(key, alwaysShowMenu, Center(child: widget.buildActionsMenu(fullPath, entry.isFolder))))),
        ],
      );
    }).toList();

    return DataTable2(
      showCheckboxColumn: false,
      columnSpacing: 0,
      horizontalMargin: 0,
      sortColumnIndex: sortColumnIndex,
      sortAscending: sortAscending,
      columns: [
        if (showSelectColumn)
          DataColumn2(
            fixedWidth: 50,
            label: Center(
              child: Checkbox(tristate: true, value: selectAllValue, onChanged: (v) => widget.onToggleAllSelected(v == true)),
            ),
          ),
        DataColumn2(
          label: _getLabel("Name"),
          size: ColumnSize.L,
          onSort: (_, ascending) => widget.onSortChanged(FileSort(FileSortField.name, ascending)),
        ),
        DataColumn2(
          label: _getLabel("Modified"),
          fixedWidth: isMobile ? 125 : 170,
          onSort: (_, ascending) => widget.onSortChanged(FileSort(FileSortField.modified, ascending)),
        ),
        DataColumn2(
          label: widget.isRefreshing
              ? Center(child: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
              : SizedBox.shrink(),
          fixedWidth: 50,
        ),
      ],
      rows: rows,
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
