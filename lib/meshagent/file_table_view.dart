import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:powerboards/meshagent/document_pane.dart';
import 'package:powerboards/meshagent/path.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_icon/file_icon.dart';

import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/ui/ui.dart';
import 'package:meshagent_flutter_shadcn/viewers/file.dart';

import 'package:powerboards/powerboards_router/powerboards_router.dart';
import 'package:powerboards/settings/format_date.dart';
import 'package:powerboards/ui/app_context_menu.dart';
import 'package:powerboards/ui/text_validators.dart';

import 'file_upload.dart';

class FileManagerView extends StatefulWidget {
  final RoomClient client;
  final bool hideSystem;

  const FileManagerView({super.key, required this.client, this.hideSystem = false});

  @override
  State<FileManagerView> createState() => _FileManagerViewState();
}

class _FileManagerViewState extends State<FileManagerView> {
  final GlobalKey<_FileTableViewState> _fileTableViewKey = GlobalKey<_FileTableViewState>();
  String _currentFolder = "";
  String? _openedFile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _initializeFromUrl();
  }

  void _initializeFromUrl() {
    final state = PathRouteMatch.of(context);
    final currentUri = state.uri;
    final path = currentUri.queryParameters['p'] ?? "";

    final segments = path.split('/');
    final lastSegment = segments.isNotEmpty ? segments.last : '';

    String currentFolder = "";
    String? openedFile;

    if (lastSegment.contains('.') && !lastSegment.startsWith('.')) {
      openedFile = path;
      final lastSlash = path.lastIndexOf('/');
      if (lastSlash > 0) {
        currentFolder = path.substring(0, lastSlash);
      }
    } else {
      currentFolder = path;
    }

    widget.client.localParticipant?.setAttribute("current_file", openedFile);

    setState(() {
      _currentFolder = currentFolder;
      _openedFile = openedFile;
    });
  }

  void _handlePathOpen(String path) {
    final state = PathRouteMatch.of(context);
    final currentUri = state.uri;

    final updatedQueryParameters = Map<String, String>.from(currentUri.queryParameters);
    updatedQueryParameters['p'] = path;

    final newUri = currentUri.replace(queryParameters: updatedQueryParameters);

    context.go(newUri.toString());
  }

  Widget _buildBreadcrumb() {
    List<Widget> crumbs = [];

    crumbs.add(
      ShadButton.ghost(
        onPressed: () => _handlePathOpen(""),
        child: Text("Files", style: _FileTableViewState.breadcrumbLinkStyle),
      ),
    );

    final segments = _currentFolder.split('/').where((s) => s.isNotEmpty).toList();
    String accumulated = "";
    for (final segment in segments) {
      accumulated = accumulated.isEmpty ? segment : "$accumulated/$segment";
      final currentPath = accumulated;
      crumbs.add(Icon(LucideIcons.chevronRight, color: Color(0xffa5a5a5)));
      crumbs.add(
        ShadButton.ghost(
          onPressed: () => _handlePathOpen("$currentPath/"),
          child: Text(segment, style: _FileTableViewState.breadcrumbLinkStyle),
        ),
      );
    }

    if (_openedFile != null) {
      final fileName = _openedFile!.split('/').last;
      crumbs.add(Icon(LucideIcons.chevronRight, color: Color(0xffa5a5a5)));
      crumbs.add(ShadButton.ghost(enabled: false, child: Text(fileName, style: _FileTableViewState.breadcrumbLinkStyle)));
    }

    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: crumbs),
      ),
    );
  }

  Future<void> _cycleFile(int offset) async {
    var entries = await _fileTableViewKey.currentState?.getChildren(_currentFolder) ?? [];
    if (widget.hideSystem) {
      entries = entries.where((e) => !e.name.startsWith('.')).toList();
    }

    final files = entries.where((e) => !e.isFolder).map((e) => _currentFolder.isEmpty ? e.name : '$_currentFolder/${e.name}').toList();
    if (files.isEmpty || _openedFile == null) return;

    final currentIndex = files.indexOf(_openedFile!);
    if (currentIndex < 0) return;

    final nextIndex = (currentIndex + offset + files.length) % files.length;
    _handlePathOpen(files[nextIndex]);
  }

  void _previousFile() => _cycleFile(-1);
  void _nextFile() => _cycleFile(1);

  Future<void> _upload(String name, Stream<Uint8List> stream, int? fileSize) async {
    final fileName = _currentFolder.isEmpty ? name : joinPaths(_currentFolder, name);
    _fileTableViewKey.currentState?.upload(stream, fileName, fileSize ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    return FileDropArea(
      onFileDrop: _upload,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 8,
              children: [
                if (_openedFile != null) ...[
                  Tooltip(
                    message: "Close file",
                    child: ShadIconButton.ghost(icon: Icon(LucideIcons.x), onPressed: () => _handlePathOpen("$_currentFolder/")),
                  ),
                  Tooltip(
                    message: "Previous file",
                    child: ShadIconButton.outline(icon: Icon(LucideIcons.chevronLeft), onPressed: _previousFile),
                  ),
                  Tooltip(
                    message: "Next file",
                    child: ShadIconButton.outline(icon: Icon(LucideIcons.chevronRight), onPressed: _nextFile),
                  ),
                ],
                _buildBreadcrumb(),
                if (_openedFile == null) ...[
                  if (_currentFolder.isNotEmpty) ...[
                    Tooltip(
                      message: "Delete folder",
                      child: ShadIconButton.outline(
                        icon: Icon(LucideIcons.trash),
                        onPressed: () async {
                          final confirmDelete = await _fileTableViewKey.currentState?._confirmAndDelete(_currentFolder, true);
                          if (confirmDelete == true) {
                            _handlePathOpen("");
                          }
                        },
                      ),
                    ),
                  ],
                  Tooltip(
                    message: "New folder",
                    child: ShadIconButton.outline(
                      icon: Icon(LucideIcons.folderPlus),
                      onPressed: () {
                        _fileTableViewKey.currentState?.addFolder(_currentFolder);
                      },
                    ),
                  ),
                  AppContextMenuButton(
                    entries: [
                      AppMenuEntry(
                        title: "Upload files",
                        description: "Upload files to this folder",
                        icon: LucideIcons.upload,
                        onPressed: () {
                          _fileTableViewKey.currentState?.addFiles(_currentFolder);
                        },
                      ),
                      AppMenuEntry(
                        title: "New Text File",
                        description: "Create a new text file in this folder",
                        icon: LucideIcons.fileText,
                        onPressed: () {
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
                              _upload(fileName, Stream.value(Uint8List(0)), 0);
                            }
                          });
                        },
                      ),
                    ],
                    childBuilder: (context, controller) {
                      return Tooltip(
                        message: "Upload file",
                        child: ShadIconButton.outline(
                          icon: Icon(LucideIcons.upload),
                          onPressed: () {
                            if (!controller.isOpen) {
                              controller.show();
                            }
                          },
                        ),
                      );
                    },
                  ),
                  if (!kIsWeb)
                    Tooltip(
                      message: "Upload photo",
                      child: ShadIconButton.outline(
                        icon: Icon(LucideIcons.imagePlus),
                        onPressed: () {
                          _fileTableViewKey.currentState?.addPhotos(_currentFolder);
                        },
                      ),
                    ),
                ],
                if (_openedFile != null) ...[
                  Tooltip(
                    message: "Delete file",
                    child: ShadIconButton.outline(
                      icon: Icon(LucideIcons.trash),
                      onPressed: () async {
                        final confirmDelete = await _fileTableViewKey.currentState?._confirmAndDelete(_openedFile!, false);
                        if (confirmDelete == true) {
                          _handlePathOpen(_currentFolder);
                        }
                      },
                    ),
                  ),
                  Tooltip(
                    message: "Download",
                    child: ShadIconButton.outline(
                      icon: Icon(LucideIcons.download),
                      onPressed: () {
                        _fileTableViewKey.currentState?.downloadFile(_openedFile!);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            child: IndexedStack(
              index: _openedFile == null ? 0 : 1,
              children: [
                FileTableView(
                  key: _fileTableViewKey,
                  client: widget.client,
                  currentPath: _currentFolder,
                  hideSystem: widget.hideSystem,
                  onOpen: _handlePathOpen,
                ),
                if (_openedFile != null) fileViewer(widget.client, _openedFile!) ?? DocumentPane(path: _openedFile!, room: widget.client),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FileTableView extends StatefulWidget {
  final RoomClient client;
  final bool hideSystem;
  final String currentPath;

  final void Function(String fullPath) onOpen;

  const FileTableView({super.key, required this.client, required this.onOpen, required this.currentPath, this.hideSystem = false});

  @override
  State<FileTableView> createState() => _FileTableViewState();
}

class _FileTableViewState extends State<FileTableView> {
  static TextStyle breadcrumbLinkStyle = GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600);
  static TextStyle dataStyle = GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Color.fromARGB(255, 0x22, 0x22, 0x22));
  static TextStyle headerStyle = GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Color.fromARGB(255, 0x66, 0x66, 0x66));

  late StreamSubscription<RoomEvent> sub;
  final Map<String, List<StorageEntry>> _cache = {};
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();

    sub = widget.client.listen(onRoomMessage);

    _refresh();
  }

  @override
  void didUpdateWidget(FileTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      _refresh();
    }
  }

  @override
  void dispose() {
    sub.cancel();

    super.dispose();
  }

  void onRoomMessage(RoomEvent event) {
    if (event is FileDeletedEvent) {
      _refreshPath(event.path);
    } else if (event is FileUpdatedEvent) {
      _refreshPath(event.path);
    }
  }

  Future<void> upload(Stream<Uint8List> stream, String fileName, int totalBytes) async {
    final toaster = ShadToaster.of(context);

    final upload = MeshagentFileUpload(room: widget.client, path: fileName, dataStream: stream);

    if (totalBytes > 0) {
      late ShadToast toast;

      toast = ShadToast(
        description: AnimatedBuilder(
          animation: upload,
          builder: (context, _) {
            final percent = (upload.bytesUploaded / totalBytes).clamp(0.0, 1.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.upload, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Uploading $fileName…')),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: percent),
              ],
            );
          },
        ),
        duration: Duration(minutes: 5), // stay until timeout or completion
      );

      toaster.show(toast);
    }

    try {
      await upload.done;
      await toaster.hide(animate: false);
    } catch (e) {
      await toaster.hide(animate: false);
      toaster.show(ShadToast.destructive(description: Text('Upload failed: $e'), duration: Duration(seconds: 5)));
    }
  }

  Future<void> addPhotos(String path) async {
    await FileUploadHelper.pickAndUploadPhotos(path: path, onUpload: upload);
  }

  Future<void> addFiles(String path) async {
    await FileUploadHelper.pickAndUploadFiles(path: path, onUpload: upload);
  }

  Future<void> addFolder(String path) async {
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
    await upload(Stream.empty(), fileName, 0);

    await _refresh();
  }

  Future<void> downloadFile(String path) async {
    final url = await widget.client.storage.downloadUrl(path);
    launchUrl(Uri.parse(url));
  }

  Future<void> _deleteFile(String path) async {
    await widget.client.storage.delete(path);
  }

  Future<void> _deleteFolder(String folderPath) async {
    final children = await getChildren(folderPath, useCache: false);

    for (final child in children) {
      final childPath = joinPaths(folderPath, child.name);
      if (child.isFolder) {
        await _deleteFolder(childPath);
      } else {
        await widget.client.storage.delete(childPath);
      }
    }

    await _refreshPath(folderPath);
  }

  Future<void> _refresh() async {
    await getChildren(widget.currentPath, useCache: false);
    setState(() => {});
  }

  Future<void> _refreshPath(String path) async {
    var folderPath = "";
    final lastSlash = path.lastIndexOf('/');
    if (lastSlash > 0) {
      folderPath = path.substring(0, lastSlash);
    }

    if (folderPath.isNotEmpty) {
      folderPath = "$folderPath/";
    }

    await getChildren(folderPath, useCache: false);
    setState(() => {});
  }

  Future<List<StorageEntry>> getChildren(String folderPath, {bool useCache = true}) async {
    if (!useCache || !_cache.containsKey(folderPath)) {
      _cache[folderPath] = await widget.client.storage.list(folderPath);
    }

    return _cache[folderPath]!;
  }

  Widget _buildActionsMenu(String fullPath, bool isFolder) {
    final colorScheme = ShadTheme.of(context).colorScheme;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, color: colorScheme.primary),
      onSelected: (value) async {
        switch (value) {
          case 'open':
            widget.onOpen(fullPath);
            break;
          case 'delete':
            await _confirmAndDelete(fullPath, isFolder);
            break;
          case 'upload':
            if (isFolder) {
              await addFiles(fullPath);
            }
            break;
          case 'download':
            await downloadFile(fullPath);
            break;
        }
      },
      itemBuilder: (context) {
        return <PopupMenuEntry<String>>[
          if (!isFolder)
            PopupMenuItem(
              value: 'open',
              child: ListTile(leading: const Icon(Icons.open_in_new), title: const Text('Open')),
            ),
          if (!isFolder)
            PopupMenuItem(
              value: 'download',
              child: ListTile(leading: const Icon(LucideIcons.download), title: const Text('Download')),
            ),
          if (isFolder)
            PopupMenuItem(
              value: 'open',
              child: ListTile(leading: const Icon(LucideIcons.folderOpen), title: const Text('Open Folder')),
            ),
          if (isFolder)
            PopupMenuItem(
              value: 'upload',
              child: ListTile(leading: const Icon(LucideIcons.upload), title: const Text('Upload here')),
            ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(leading: const Icon(LucideIcons.trash), title: const Text('Delete')),
          ),
        ];
      },
    );
  }

  Future<bool> _confirmAndDelete(String fullPath, bool isFolder) async {
    final name = fullPath.split('/').where((s) => s.isNotEmpty).last;
    final confirmDelete = await showShadDialog(
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_off, size: 80, color: Colors.grey[400]),
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
    if (entry.name.endsWith('document')) return Icons.article;
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
              child: Icon(iconData, size: paddedIconSize, color: (entry.isFolder ? Color.fromARGB(0xff, 0xe0, 0xa0, 0x30) : null)),
            )
          : FileIcon(entry.name, size: iconSize),
    );
  }

  Widget _getLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: Text(text, style: headerStyle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _cache[widget.currentPath];

    if (entries == null) {
      return const Center(child: CircularProgressIndicator());
    }

    var displayEntries = entries.toList();

    if (widget.hideSystem) {
      displayEntries = displayEntries.where((e) => !e.name.startsWith('.')).toList();
    }

    if (displayEntries.isEmpty) {
      return _buildEmptyState(context);
    }

    displayEntries.sort((a, b) {
      // folders before files
      if (a.isFolder && !b.isFolder) return -1;
      if (!a.isFolder && b.isFolder) return 1;

      int cmp;
      if (_sortColumnIndex == 0) {
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else if (_sortColumnIndex == 1) {
        final aDate = a.updatedAt;
        final bDate = b.updatedAt;

        if (aDate == null && bDate == null) {
          cmp = 0;
        } else if (aDate == null) {
          cmp = -1; // null dates come before non-null
        } else if (bDate == null) {
          cmp = 1;
        } else {
          cmp = aDate.compareTo(bDate);
        }
      } else {
        cmp = 0;
      }

      return _sortAscending ? cmp : -cmp;
    });

    final colorScheme = ShadTheme.of(context).colorScheme;

    final rows = displayEntries.map((entry) {
      final fullPath = widget.currentPath.isEmpty ? entry.name : joinPaths(widget.currentPath, entry.name);

      return DataRow(
        onSelectChanged: (_) {
          if (entry.isFolder) {
            widget.onOpen("$fullPath/");
          } else {
            widget.onOpen(fullPath);
          }
        },
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return Colors.grey.shade100;
          }
          return null;
        }),
        cells: [
          DataCell(
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
          // DataCell(Text(entry.isFolder ? "--" : _formatFileSize(111111), style: dataStyle)),
          // DataCell(Text("updated by", style: dataStyle)),
          DataCell(Text(entry.updatedAt?.modified() ?? '', style: dataStyle)),
          DataCell(_buildActionsMenu(fullPath, entry.isFolder)),
        ],
      );
    }).toList();

    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return IconTheme(
      data: IconThemeData(color: colorScheme.primary),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: DataTable2(
          showCheckboxColumn: false,
          columnSpacing: 12,
          horizontalMargin: 12,
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          columns: [
            DataColumn2(
              label: _getLabel("Name"),
              size: ColumnSize.L,
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                });
              },
            ),
            // DataColumn2(
            //   label: _getLabel("Size"),
            //   onSort: (i, asc) => _sort((e) => e.isFolder ? 0 : 111111, i, asc),
            // ),
            // DataColumn2(
            //   label: _getLabel("Updated by"),
            //   onSort: (i, asc) => _sort((e) => "updated by", i, asc),
            // ),
            DataColumn2(
              label: _getLabel("Modified"),
              fixedWidth: isMobile ? 125 : 170,
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                });
              },
            ),
            DataColumn2(label: Text("", style: headerStyle), fixedWidth: 50),
          ],
          rows: rows,
        ),
      ),
    );
  }
}
