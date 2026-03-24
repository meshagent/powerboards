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
import 'package:data_table_2/data_table_2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_icon/file_icon.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/chat/file_prompt_actions.dart';
import 'package:meshagent_flutter_shadcn/file_preview/code.dart';
import 'package:meshagent_flutter_shadcn/file_preview/file_preview.dart';
import 'package:meshagent_flutter_shadcn/ui/ui.dart';
import 'package:meshagent_flutter_shadcn/viewers/file.dart';

import 'package:powerboards/meshagent/document_pane.dart';
import 'package:powerboards/meshagent/path.dart';
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

enum FileSortField { name, modified }

enum _FileAction { open, download, upload, compressFolder, delete }

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

  static String displayNameFromKey(String key) {
    final trimmed = pathFromKey(key);
    final last = trimmed.split('/').where((s) => s.isNotEmpty).lastOrNull ?? trimmed;
    return isFolderKey(key) ? '$last/' : last;
  }
}

class _BreadcrumbSegment {
  const _BreadcrumbSegment({required this.label, required this.path});

  final String label;
  final String path;
}

class FileManagerView extends StatefulWidget {
  final RoomClient client;
  final Resource<List<ServiceSpec>>? services;
  final bool hideSystem;
  final List<Widget> desktopHeaderActions;
  final double desktopHeaderActionLeadingWidthFloor;
  final double desktopHeaderActionMinimumLeadingWidth;
  final double desktopHeaderActionReserve;

  const FileManagerView({
    super.key,
    required this.client,
    this.services,
    this.hideSystem = false,
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

  _FileLocation _location = const _FileLocation(folder: "", openedFile: null);
  String? get _openedFile => _location.openedFile;

  bool _forceShowSelect = false;
  String _tab = 'preview';
  final popoverController = ShadPopoverController();
  final ShadContextMenuController _collapsedBreadcrumbMenuController = ShadContextMenuController();
  final CodePreviewController _codePreviewController = CodePreviewController();
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
          next.add(StorageEntry(name: parentName, isFolder: true, size: null, createdAt: now, updatedAt: null));
          _setEntries(next);
        }
      }
      return;
    }

    if (event is FileUpdatedEvent) {
      final idx = next.indexWhere((e) => e.name == name);
      if (idx == -1) {
        next.add(StorageEntry(name: name, isFolder: false, size: null, createdAt: now, updatedAt: now));
      } else {
        final old = next[idx];
        next[idx] = StorageEntry(name: name, isFolder: false, size: old.size, createdAt: old.createdAt, updatedAt: now);
      }
    } else if (event is FileDeletedEvent) {
      next.removeWhere((e) => e.name == name);
      _toggleSelected(_FilePathKey.keyForPath(path, false), false);
    }

    _setEntries(next);
  }

  String _ext(String path) {
    final base = p.basename(path);
    if (base.isEmpty) return "";
    return base.split(".").last.toLowerCase();
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

    final fileName = joinPaths(path, "$result/$placeholderFileName");
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
                    return ShadDialog(
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
        case _FileAction.download:
          await _downloadFile(fullPath);
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
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    if (!isMobile) {
      return _buildDesktopToolbar(selected);
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

    final fileName = _openedFile!.split('/').last;

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

    return editExtensions.contains(_ext(openedFile));
  }

  bool get _openedFileSupportsExternalSave {
    final openedFile = _openedFile;
    if (openedFile == null) {
      return false;
    }

    return isCodeFile(openedFile);
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

  Widget _buildMobileToolbar(Set<String> selected) {
    final showSelectionActions = selected.isNotEmpty && _openedFile == null;
    final showRouteActions = !showSelectionActions;

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, _openedFile == null ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 6,
        children: [
          if (_openedFile != null) ..._buildFileCloseAction(),
          Expanded(child: showSelectionActions ? _buildSelection(selected) : _buildBreadcrumb()),
          if (showRouteActions) ..._buildRouteActions(),
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
      return [
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
      final fileName = openedFile.split('/').last;
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

  List<_BreadcrumbSegment> _folderBreadcrumbSegments() {
    final segments = <_BreadcrumbSegment>[const _BreadcrumbSegment(label: "Files", path: "")];
    final folderSegments = _folderSig.value.split('/').where((s) => s.isNotEmpty).toList();

    var accumulated = "";
    for (final segment in folderSegments) {
      accumulated = accumulated.isEmpty ? segment : "$accumulated/$segment";
      segments.add(_BreadcrumbSegment(label: segment, path: accumulated));
    }

    return segments;
  }

  Widget _breadcrumbSeparator() {
    return const SizedBox(
      width: 20,
      child: Center(child: Icon(LucideIcons.chevronRight, size: 16, color: Color(0xffa5a5a5))),
    );
  }

  Widget _buildBreadcrumbCrumb(_BreadcrumbSegment segment) {
    return ShadButton.ghost(
      onPressed: () => _openEntry(segment.path, true),
      child: Text(segment.label, style: breadcrumbLinkStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildCollapsedBreadcrumbCurrent(_BreadcrumbSegment segment) {
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

  Widget _buildCollapsedBreadcrumbMenu(List<_BreadcrumbSegment> hiddenSegments) {
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
          onPressed: () {
            if (_collapsedBreadcrumbMenuController.isOpen) {
              _collapsedBreadcrumbMenuController.hide();
            } else {
              _collapsedBreadcrumbMenuController.show();
            }
          },
        ),
      ),
    );
  }

  Widget _buildFileNameOnly() {
    final fileName = _openedFile!.split('/').last;

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

        var startIndex = segments.length - 1;
        var usedWidth = segmentWidths.last;

        while (startIndex > 0) {
          final nextWidth = usedWidth + separatorWidth + segmentWidths[startIndex - 1];
          if (nextWidth > constraints.maxWidth) {
            break;
          }
          startIndex--;
          usedWidth = nextWidth;
        }

        var hiddenCount = startIndex;
        while (hiddenCount > 0 &&
            usedWidth + separatorWidth + collapseButtonWidth > constraints.maxWidth &&
            startIndex < segments.length - 1) {
          usedWidth -= separatorWidth + segmentWidths[startIndex];
          startIndex++;
          hiddenCount = startIndex;
        }

        final children = <Widget>[];
        if (hiddenCount > 0) {
          return Row(
            children: [
              _buildCollapsedBreadcrumbMenu(segments.take(hiddenCount).toList(growable: false)),
              _breadcrumbSeparator(),
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: _buildCollapsedBreadcrumbCurrent(segments.last)),
              ),
            ],
          );
        }

        for (var i = startIndex; i < segments.length; i++) {
          if (i > startIndex) {
            children.add(_breadcrumbSeparator());
          }
          children.add(_buildBreadcrumbCrumb(segments[i]));
        }

        return Row(mainAxisSize: MainAxisSize.min, children: children);
      },
    );
  }

  Widget _buildOpenedFile(BuildContext context) {
    if (_openedFile == null) return const SizedBox.shrink();

    final path = _openedFile!;
    final ext = _ext(path);
    final fileKind = classifyFile(path);
    final showEditTabs = editExtensions.contains(ext);
    final showExternalSave = isCodeFile(path);

    if (!showExternalSave) {
      return _buildOpenedFileSurface(
        fileViewer(widget.client, path) ?? DocumentPane(path: path, room: widget.client),
        insetContent: _shouldInsetOpenedFileSurface(fileKind: fileKind, editing: false),
      );
    }

    final edit = _buildOpenedFileSurface(
      DocumentPane(
        path: path,
        room: widget.client,
        forceTextViewer: true,
        codePreviewController: _codePreviewController,
        showCodeToolbar: false,
      ),
      insetContent: _shouldInsetOpenedFileSurface(fileKind: fileKind, editing: true),
    );

    if (!showEditTabs) {
      return edit;
    }

    final view = _buildOpenedFileSurface(
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
    final radius = ShadTheme.of(context).radius.resolve(Directionality.of(context));
    const borderWidth = 1.0;
    const previewPadding = 16.0;
    final innerRadius = BorderRadius.only(
      topLeft: Radius.circular(math.max(0, radius.topLeft.x - borderWidth)),
      topRight: Radius.circular(math.max(0, radius.topRight.x - borderWidth)),
      bottomLeft: Radius.circular(math.max(0, radius.bottomLeft.x - borderWidth)),
      bottomRight: Radius.circular(math.max(0, radius.bottomRight.x - borderWidth)),
    );

    return DecoratedBox(
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
                  const SizedBox(height: desktopPaneSecondaryRowContentGap),
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
                                      onOpen: _openEntry,
                                      onToggleSelected: _toggleSelected,
                                      onToggleAllSelected: _toggleAllSelected,
                                      onSortChanged: _setSort,
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
  final void Function(String fullPath, bool isFolder) onOpen;
  final void Function(String key, bool selected) onToggleSelected;
  final void Function(bool selected) onToggleAllSelected;
  final void Function(FileSort) onSortChanged;
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
    required this.onOpen,
    required this.onToggleSelected,
    required this.onToggleAllSelected,
    required this.onSortChanged,
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

  final ValueNotifier<String?> _hoveredRowKey = ValueNotifier<String?>(null);
  final GlobalKey _tableCardKey = GlobalKey();

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
            onPressed: () {
              if (!controller.isOpen) {
                controller.show();
              }
            },
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

  Widget _hoverRegion(String rowKey, Widget child) {
    return MouseRegion(opaque: true, onEnter: (_) => _setHovered(rowKey), onExit: (_) => _clearHoveredIf(rowKey), child: child);
  }

  Icon _sortIcon(bool ascending) {
    return Icon(ascending ? LucideIcons.arrowUp : LucideIcons.arrowDown, size: 16, color: shadMutedForeground);
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

  Widget _buildSortButton({required String label, required bool active, required bool ascending, required VoidCallback onPressed}) {
    return ShadButton.ghost(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: headerStyle.copyWith(color: active ? shadForeground : shadMutedForeground)),
          if (active) ...[const SizedBox(width: 6), _sortIcon(ascending)],
        ],
      ),
    );
  }

  Widget _buildMobileHeader(bool showSelectColumn, bool? selectAllValue) {
    final isNameSort = widget.sort.field == FileSortField.name;
    final isModifiedSort = widget.sort.field == FileSortField.modified;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          _buildSortButton(
            label: 'Name',
            active: isNameSort,
            ascending: widget.sort.ascending,
            onPressed: () => widget.onSortChanged(FileSort(FileSortField.name, isNameSort ? !widget.sort.ascending : true)),
          ),
          const Spacer(),
          _buildSortButton(
            label: 'Modified',
            active: isModifiedSort,
            ascending: widget.sort.ascending,
            onPressed: () => widget.onSortChanged(FileSort(FileSortField.modified, isModifiedSort ? !widget.sort.ascending : false)),
          ),
          SizedBox(
            width: 36,
            child: widget.isRefreshing
                ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(BuildContext context, bool showSelectColumn, bool alwaysShowMenu, bool? selectAllValue) {
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
                final modifiedLabel = entry.updatedAt?.modified() ?? '';
                final showModifiedLabel = modifiedLabel.isNotEmpty;

                return Material(
                  color: isSelected ? const Color(0xFFF2F1FF) : shadCard,
                  child: InkWell(
                    onTap: () => widget.onOpen(fullPath, entry.isFolder),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                                Text(entry.name, style: dataStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (showModifiedLabel) ...[
                                  const SizedBox(height: 4),
                                  Text(modifiedLabel, style: headerStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                              alwaysShowMenu || isSelected || hoveredKey == key,
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

    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final colorScheme = ShadTheme.of(context).colorScheme;
    final showSelectColumn = !isMobile || widget.forceShowSelect;
    final alwaysShowMenu = isMobile;

    final bool? selectAllValue = widget.selected.isEmpty ? false : (widget.selected.length == widget.entries.length ? true : null);

    if (isMobile) {
      return _buildMobileList(context, showSelectColumn, alwaysShowMenu, selectAllValue);
    }

    final sortColumnIndex = (widget.sort.field == FileSortField.name ? 0 : 1) + (showSelectColumn ? 1 : 0);
    final sortAscending = widget.sort.ascending;

    final rows = widget.entries.map((entry) {
      final fullPath = _FilePathKey.pathForEntry(widget.currentPath, entry);
      final key = _FilePathKey.keyForEntry(widget.currentPath, entry);
      final isSelected = widget.selected.contains(key);
      final checkboxDecoration = ShadDecoration(border: ShadBorder.all(color: colorScheme.border));

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
                    child: Text(entry.name, style: dataStyle, overflow: TextOverflow.ellipsis),
                  ),
                ],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final modifiedWidth = constraints.maxWidth < 640 ? 140.0 : 170.0;
        final actionWidth = constraints.maxWidth < 640 ? 48.0 : 56.0;
        final selectWidth = showSelectColumn ? (constraints.maxWidth < 640 ? 48.0 : 56.0) : 0.0;
        final fixedWidthTotal = selectWidth + modifiedWidth + actionWidth;

        if (constraints.maxWidth < fixedWidthTotal + 140) {
          return _buildMobileList(context, widget.forceShowSelect, true, selectAllValue);
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
            onTap: _controller.show,
            child: const SizedBox(width: 40, height: 40, child: Center(child: Icon(LucideIcons.ellipsis, size: 20))),
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
