import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    List<StorageEntry> entries = await _fileTableViewKey.currentState?.getEntries() ?? [];

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
        crossAxisAlignment: .start,
        children: [
          Padding(
            padding: const .fromLTRB(8, 0, 8, 8),
            child: Row(
              mainAxisAlignment: .spaceBetween,
              crossAxisAlignment: .center,
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
  State createState() => _FileTableViewState();
}

class _FileTableViewState extends State<FileTableView> {
  static TextStyle breadcrumbLinkStyle = GoogleFonts.inter(fontSize: 16, fontWeight: .w600);
  static TextStyle dataStyle = GoogleFonts.inter(fontSize: 14, fontWeight: .w500, color: .fromARGB(255, 0x22, 0x22, 0x22));
  static TextStyle headerStyle = GoogleFonts.inter(fontSize: 14, fontWeight: .w500, color: .fromARGB(255, 0x66, 0x66, 0x66));

  late final storageEntries = Resource(() => getChildren(widget.currentPath));

  late StreamSubscription<RoomEvent> sub;
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  final popoverController = ShadPopoverController();
  late final uploadNotifications = UploadProgressNotifications(popoverController: popoverController);

  Future<List<StorageEntry>> getEntries() async {
    await storageEntries.untilReady();

    return storageEntries.state.value ?? [];
  }

  @override
  void initState() {
    super.initState();

    sub = widget.client.listen(onRoomMessage);
  }

  @override
  void didUpdateWidget(FileTableView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentPath != widget.currentPath) {
      storageEntries.refresh();
    }
  }

  @override
  void dispose() {
    sub.cancel();
    storageEntries.dispose();

    super.dispose();
  }

  Future<void> _refreshPath(String path) async {
    if (path.startsWith(widget.currentPath)) {
      storageEntries.refresh();
    }
  }

  void onRoomMessage(RoomEvent event) {
    if (event is FileDeletedEvent) {
      _refreshPath(event.path);
    } else if (event is FileUpdatedEvent) {
      _refreshPath(event.path);
    }
  }

  Future<List<StorageEntry>> getChildren(String folderPath) async {
    return await widget.client.storage.list(folderPath);
  }

  Future<void> upload(Stream<Uint8List> stream, String fileName, int totalBytes) async {
    final upload = MeshagentFileUpload(room: widget.client, path: fileName, dataStream: stream);

    uploadNotifications.addUpload(upload, totalBytes);
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

    storageEntries.refresh();
  }

  Future<void> downloadFile(String path) async {
    final url = await widget.client.storage.downloadUrl(path);

    launchUrl(Uri.parse(url));
  }

  Future<void> _deleteFile(String path) async {
    await widget.client.storage.delete(path);
  }

  Future<void> _deleteFolder(String folderPath) async {
    final children = await getChildren(folderPath);

    for (final child in children) {
      final childPath = joinPaths(folderPath, child.name);

      if (child.isFolder) {
        _deleteFolder(childPath);
      } else {
        _deleteFile(childPath);
      }
    }
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

    if (confirmDelete) {
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
              child: Icon(iconData, size: paddedIconSize, color: (entry.isFolder ? .fromARGB(0xff, 0xe0, 0xa0, 0x30) : null)),
            )
          : FileIcon(entry.name, size: iconSize),
    );
  }

  Widget _getLabel(String text) {
    return Padding(
      padding: const .only(right: 5),
      child: Text(text, style: headerStyle),
    );
  }

  Widget popover(BuildContext context) {
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
                      "Upload${isCompleted ? 'ed' : 'ing'}  ${uploads.length} file${uploads.length > 1 ? 's' : ''}",
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
                                final percent = (upload.bytesUploaded / totalBytes).clamp(0.0, 1.0);

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

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return IconTheme(
      data: IconThemeData(color: theme.colorScheme.primary),
      child: ShadPopover(
        controller: popoverController,
        padding: .zero,
        anchor: ShadAnchor(childAlignment: .bottomRight, overlayAlignment: .bottomRight, offset: const Offset(-20.0, -20.0)),
        popover: popover,
        child: Container(
          margin: const .fromLTRB(8, 0, 8, 8),
          decoration: BoxDecoration(
            border: .all(color: Colors.grey.shade300),
            borderRadius: .circular(8.0),
          ),
          child: SignalBuilder(
            builder: (context, _) {
              return storageEntries.state.when(
                ready: _buildTable,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text("Error loading files: $e")),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTable(List<StorageEntry> entries) {
    List<StorageEntry> displayEntries = entries;

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

    return DataTable2(
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
