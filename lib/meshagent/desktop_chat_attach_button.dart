import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/storage/file_browser.dart';
import 'package:powerboards/meshagent/file_upload.dart';
import 'package:powerboards/meshagent/file_list_primitives.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_dialog_file_list.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_file_select_dialog.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_menu_anchor.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_menu_card.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_menu_list.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_menu_option.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:powerboards/ui/powerboards_toasts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const Duration _v1LongActionToastDelay = Duration(milliseconds: 700);

double _desktopAttachDialogHeight(BoxConstraints constraints) {
  final maxHeight = constraints.maxHeight;
  if (!maxHeight.isFinite) {
    return 600.0;
  }

  return (maxHeight - 100.0).clamp(0.0, 600.0).toDouble();
}

BoxConstraints? _desktopAttachDialogConstraints(BuildContext context, BoxConstraints constraints) {
  if (powerboardsUsesNativeMobileDialogLayout(context)) {
    return null;
  }

  final height = _desktopAttachDialogHeight(constraints);
  return BoxConstraints(minWidth: 512.0, maxWidth: 512.0, minHeight: height, maxHeight: height);
}

Widget _buildPowerboardsV1DialogFileList(BuildContext context, List<FileBrowserRowViewModel> rows) {
  final rowsById = {for (final row in rows) row.fullPath: row};
  final items = [
    for (final row in rows)
      PbDialogFileListItemData(
        id: row.fullPath,
        title: row.displayName,
        iconAssetName: PbResolvedAttachmentMetadata.resolve(
          title: row.entry.name,
          explicitFileType: row.entry.isFolder ? PbAttachmentFileType.folder : null,
        ).iconAssetName,
        iconColor: row.entry.isFolder ? PbColors.surfaceRailActive : PbResolvedAttachmentMetadata.resolve(title: row.entry.name).iconColor,
        enabled: row.canActivate,
        selectionEnabled: row.canToggleSelection,
      ),
  ];

  return PbDialogFileList(
    items: items,
    selectedIds: {for (final row in rows.where((row) => row.selected)) row.fullPath},
    showCheckboxes: true,
    framed: false,
    rowMargin: const EdgeInsets.symmetric(horizontal: 28),
    rowPadding: const EdgeInsets.all(11),
    listPadding: const EdgeInsets.symmetric(vertical: 8),
    clipBehavior: Clip.none,
    onItemPressed: (item) => rowsById[item.id]?.onPressed(),
    onToggleSelection: (id) => rowsById[id]?.onToggleSelection?.call(),
  );
}

class PowerboardsV1AttachMenuActions {
  const PowerboardsV1AttachMenuActions({required this.onUploadFile, required this.onAddFromRoom, required this.closeMenu});

  final VoidCallback onUploadFile;
  final VoidCallback? onAddFromRoom;
  final VoidCallback closeMenu;
}

typedef PowerboardsV1AttachMenuPanelBuilder = Widget Function(BuildContext context, PowerboardsV1AttachMenuActions actions);

class PowerboardsDesktopChatAttachButton extends StatefulWidget {
  const PowerboardsDesktopChatAttachButton({
    required this.controller,
    super.key,
    this.alwaysShowAttachFiles,
    this.availableRooms,
    this.connectRoomClient,
    this.agentName,
    this.showMcpConnectors = false,
    this.showMcpMenuItem = true,
    this.useV1Menu = false,
    this.v1MenuPanelBuilder,
    this.triggerBuilder,
  });

  final bool? alwaysShowAttachFiles;
  final ChatThreadController controller;
  final Future<List<Room>> Function()? availableRooms;
  final Future<RoomClient> Function(String roomName)? connectRoomClient;
  final String? agentName;
  final bool showMcpConnectors;
  final bool showMcpMenuItem;
  final bool useV1Menu;
  final PowerboardsV1AttachMenuPanelBuilder? v1MenuPanelBuilder;
  final Widget Function(BuildContext context, VoidCallback onPressed)? triggerBuilder;

  @override
  State<PowerboardsDesktopChatAttachButton> createState() => _PowerboardsDesktopChatAttachButtonState();
}

class _PowerboardsDesktopChatAttachButtonState extends State<PowerboardsDesktopChatAttachButton> {
  final ShadPopoverController popoverController = ShadPopoverController();
  bool _v1MenuOpen = false;

  bool get _canShowMcpConnectors {
    final normalizedAgentName = widget.agentName?.trim();
    return widget.showMcpConnectors && normalizedAgentName != null && normalizedAgentName.isNotEmpty;
  }

  String _importFileDisplayName(String sourcePath) {
    final segments = sourcePath.split('/').where((segment) => segment.isNotEmpty).toList();
    return segments.isEmpty ? sourcePath : segments.last;
  }

  Future<String> _resolveImportedPath({required RoomClient destinationRoom, required String requestedPath}) async {
    String candidate = requestedPath.split('/').last;
    final dotIndex = candidate.lastIndexOf('.');
    final stem = dotIndex > 0 ? candidate.substring(0, dotIndex) : candidate;
    final extension = dotIndex > 0 ? candidate.substring(dotIndex) : '';

    for (var i = 1; ; i++) {
      final candidateExists = await destinationRoom.storage.exists(candidate);
      if (!candidateExists) {
        return candidate;
      }

      final suffix = i == 1 ? ' copy' : ' copy $i';
      candidate = '$stem$suffix$extension';
    }
  }

  Future<String> _importFile({required RoomClient sourceRoom, required RoomClient destinationRoom, required String sourcePath}) async {
    final content = await sourceRoom.storage.download(sourcePath);
    final destinationPath = await _resolveImportedPath(destinationRoom: destinationRoom, requestedPath: sourcePath);

    await destinationRoom.storage.uploadStream(destinationPath, Stream.value(content.data), overwrite: true, size: content.data.length);

    return destinationPath;
  }

  Future<void> _onSelectAttachment() async {
    final picked = await FilePicker.pickFiles(dialogTitle: 'Select files', allowMultiple: true, withReadStream: true);

    if (picked == null) {
      return;
    }

    for (final file in picked.files) {
      await widget.controller.uploadFile(file.name, file.readStream!.map(Uint8List.fromList), file.size);
    }
  }

  Future<void> _onSelectPhoto() async {
    final picker = ImagePicker();

    List<XFile> picked = const [];
    try {
      picked = await picker.pickMultipleMedia();
    } catch (_) {}
    if (picked.isEmpty) {
      try {
        picked = await picker.pickMultiImage();
      } catch (_) {
        final single = await picker.pickImage(source: ImageSource.gallery);
        if (single != null) {
          picked = [single];
        }
      }
    }
    if (picked.isEmpty) {
      return;
    }

    final names = PhotoNamer.generateBatchNames(picked);

    for (var i = 0; i < picked.length; i++) {
      final file = picked[i];
      final fileName = names[i];
      final size = await file.length();
      final stream = file.openRead();

      await widget.controller.uploadFile(fileName, stream, size);
    }
  }

  Future<void> _onBrowseFiles() async {
    final destinationRoom = widget.controller.room;
    if (destinationRoom == null) {
      return;
    }

    final currentRoomName = destinationRoom.roomName?.trim() ?? '';
    String selectedRoomName = currentRoomName;
    RoomClient selectedRoomClient = destinationRoom;
    bool resolvingRoom = false;
    bool resolveError = false;
    List<String> picked = [];

    var roomOptions = [selectedRoomName];
    if (widget.availableRooms != null) {
      try {
        final loaded = await widget.availableRooms!();
        roomOptions = {selectedRoomName, ...loaded.map((room) => room.name).where((name) => name.isNotEmpty)}.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      } catch (_) {}
    }

    if (!mounted) {
      return;
    }

    final selectedFiles = widget.useV1Menu
        ? await showDialog<List<String>>(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.transparent,
            useSafeArea: false,
            builder: (dialogContext) => Stack(
              children: [
                StatefulBuilder(
                  builder: (dialogContext, setDialogState) => PbFileSelectDialog(
                    rooms: roomOptions,
                    selectedRoom: selectedRoomName,
                    canAdd: picked.isNotEmpty && !resolvingRoom,
                    onClose: () {
                      picked.clear();
                      Navigator.of(dialogContext).pop(const <String>[]);
                    },
                    onAddPressed: () => Navigator.of(dialogContext).pop(List<String>.from(picked)),
                    onRoomSelected: (value) async {
                      if (value == selectedRoomName || widget.connectRoomClient == null) {
                        return;
                      }

                      setDialogState(() {
                        resolvingRoom = true;
                        resolveError = false;
                      });

                      RoomClient? nextRoomClient;
                      if (value == currentRoomName) {
                        nextRoomClient = destinationRoom;
                      } else {
                        try {
                          nextRoomClient = await widget.connectRoomClient!(value);
                        } catch (_) {}
                      }

                      if (nextRoomClient == null) {
                        setDialogState(() {
                          resolvingRoom = false;
                          resolveError = true;
                        });
                        return;
                      }

                      if (!identical(destinationRoom, selectedRoomClient) && !identical(nextRoomClient, selectedRoomClient)) {
                        selectedRoomClient.dispose();
                      }

                      setDialogState(() {
                        selectedRoomName = value;
                        selectedRoomClient = nextRoomClient!;
                        picked = [];
                        resolvingRoom = false;
                      });
                    },
                    fileBrowser: resolvingRoom
                        ? const PbFileSelectStatus(message: 'Connecting to room...', loading: true)
                        : resolveError
                        ? const PbFileSelectStatus(message: 'Room failed to connect')
                        : FileBrowser(
                            key: ValueKey(selectedRoomName),
                            onSelectionChanged: (selection) {
                              setDialogState(() {
                                picked = selection;
                              });
                            },
                            room: selectedRoomClient,
                            multiple: true,
                            headerBuilder: (context, model) => PbFileSelectBreadcrumb(
                              currentPath: model.path,
                              onRootPressed: model.onRootPressed,
                              onSegmentPressed: model.onSegmentPressed,
                            ),
                            listBuilder: _buildPowerboardsV1DialogFileList,
                            emptyBuilder: (context) => const PbFileSelectStatus.empty(message: 'Nothing to attach here'),
                            loadingBuilder: (context) => const PbFileSelectStatus(message: 'Loading files...', loading: true),
                            errorBuilder: (context, error) => const PbFileSelectStatus(message: 'Unable to load files'),
                          ),
                  ),
                ),
              ],
            ),
          )
        : await showPowerboardsFlowDialog<List<String>>(
            context: context,
            builder: (dialogContext) => LayoutBuilder(
              builder: (dialogContext, constraints) => StatefulBuilder(
                builder: (dialogContext, setDialogState) => PowerboardsShadDialog.task(
                  scrollable: false,
                  constraints: _desktopAttachDialogConstraints(dialogContext, constraints),
                  title: const Text('Select files'),
                  description: const Text('Attach files from this room'),
                  mobileKeyboardBehavior: PowerboardsDialogMobileKeyboardBehavior.ignore,
                  actions: [
                    ShadButton.outline(
                      onPressed: () {
                        picked.clear();
                        Navigator.of(dialogContext).pop(const <String>[]);
                      },
                      child: const Text('Cancel'),
                    ),
                    (picked.isEmpty ? ShadButton.secondary : ShadButton.new)(
                      onPressed: picked.isEmpty
                          ? null
                          : () {
                              Navigator.of(dialogContext).pop(List<String>.from(picked));
                            },
                      child: const Text('Add'),
                    ),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (roomOptions.length > 1)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: SizedBox(
                              width: double.infinity,
                              child: ShadSelect<String>(
                                initialValue: selectedRoomName,
                                selectedOptionBuilder: (selectContext, value) => Text(value),
                                options: [for (final option in roomOptions) ShadOption<String>(value: option, child: Text(option))],
                                onChanged: (value) async {
                                  if (value == null || value == selectedRoomName || widget.connectRoomClient == null) {
                                    return;
                                  }

                                  setDialogState(() {
                                    resolvingRoom = true;
                                    resolveError = false;
                                  });

                                  RoomClient? nextRoomClient;
                                  if (value == currentRoomName) {
                                    nextRoomClient = destinationRoom;
                                  } else {
                                    try {
                                      nextRoomClient = await widget.connectRoomClient!(value);
                                    } catch (_) {}
                                  }

                                  if (nextRoomClient == null) {
                                    setDialogState(() {
                                      resolvingRoom = false;
                                      resolveError = true;
                                    });
                                    return;
                                  }

                                  if (!identical(destinationRoom, selectedRoomClient) && !identical(nextRoomClient, selectedRoomClient)) {
                                    selectedRoomClient.dispose();
                                  }

                                  setDialogState(() {
                                    selectedRoomName = value;
                                    selectedRoomClient = nextRoomClient!;
                                    picked = [];
                                    resolvingRoom = false;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: powerboardsDialogScrollViewportVerticalInset),
                      Expanded(
                        child: resolvingRoom
                            ? const Center(child: CircularProgressIndicator())
                            : resolveError
                            ? const Center(child: Text('Room failed to connect'))
                            : FileBrowser(
                                key: ValueKey(selectedRoomName),
                                onSelectionChanged: (selection) {
                                  setDialogState(() {
                                    picked = selection;
                                  });
                                },
                                room: selectedRoomClient,
                                multiple: true,
                                headerBuilder: (context, model) =>
                                    buildPowerboardsFileBrowserInsetHeader(context, model, horizontalPadding: 4),
                                rowBuilder: buildPowerboardsCompactFileBrowserTitleOnlyRow,
                                separatorBuilder: buildPowerboardsFileListDivider,
                                emptyBuilder: buildPowerboardsFileBrowserEmptyState,
                              ),
                      ),
                      const SizedBox(height: powerboardsDialogScrollViewportVerticalInset),
                    ],
                  ),
                ),
              ),
            ),
          );

    var importedCount = 0;
    String? lastImportedDisplayName;
    try {
      if (selectedFiles == null || selectedFiles.isEmpty) {
        return;
      }
      if (!mounted) {
        return;
      }

      final showImportProgress = widget.useV1Menu && !identical(selectedRoomClient, destinationRoom);
      final toaster = showImportProgress ? ShadToaster.maybeOf(context) : null;
      Timer? progressTimer;
      var progressShown = false;
      for (final filePath in selectedFiles) {
        if (identical(selectedRoomClient, destinationRoom)) {
          widget.controller.attachFile(filePath);
          continue;
        }

        final importDisplayName = _importFileDisplayName(filePath);
        progressTimer?.cancel();
        progressTimer = Timer(_v1LongActionToastDelay, () {
          if (!mounted) {
            return;
          }

          progressShown = true;
          toaster?.show(powerboardsToast(title: 'Importing file', description: importDisplayName, duration: const Duration(seconds: 4)));
        });
        try {
          final importedPath = await _importFile(sourceRoom: selectedRoomClient, destinationRoom: destinationRoom, sourcePath: filePath);
          widget.controller.attachFile(importedPath);
          importedCount += 1;
          lastImportedDisplayName = importDisplayName;
        } finally {
          progressTimer.cancel();
        }
      }

      if (showImportProgress && progressShown && importedCount > 0 && mounted) {
        toaster?.show(
          powerboardsToast(
            title: 'File${importedCount == 1 ? '' : 's'} attached',
            description: importedCount == 1 ? lastImportedDisplayName : '$importedCount files imported',
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (error) {
      if (mounted && widget.useV1Menu) {
        ShadToaster.maybeOf(context)?.show(
          powerboardsToast(title: 'Unable to attach file', description: '$error', destructive: true, duration: const Duration(seconds: 6)),
        );
      }
    } finally {
      if (!identical(selectedRoomClient, destinationRoom)) {
        selectedRoomClient.dispose();
      }
    }
  }

  void _setV1MenuOpen(bool open) {
    if (_v1MenuOpen == open) {
      return;
    }
    setState(() => _v1MenuOpen = open);
  }

  Widget _buildAttachButton(BuildContext context) {
    final showPhotoUpload = FileUploadHelper.supportsPhotoUploadPicker;
    final attachMenuItemCount = (showPhotoUpload ? 2 : 1) + 1;
    final showMcpMenuItem = widget.showMcpMenuItem && _canShowMcpConnectors;
    final attachMenuHeight = (attachMenuItemCount + (showMcpMenuItem ? 1 : 0)) * 40.0;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => ListenableBuilder(
        listenable: popoverController,
        builder: (context, _) => AdaptiveShadContextMenu(
          constraints: const BoxConstraints(minWidth: 175),
          estimatedMenuWidth: 175,
          estimatedMenuHeight: attachMenuHeight,
          items: [
            if (showPhotoUpload)
              ShadContextMenuItem(
                leading: const Icon(LucideIcons.imageUp),
                onPressed: _onSelectPhoto,
                child: const Text('Upload a photo...'),
              ),
            ShadContextMenuItem(
              leading: const Icon(LucideIcons.paperclip),
              onPressed: _onSelectAttachment,
              child: const Text('Upload a file...'),
            ),
            if (widget.controller.room != null)
              ShadContextMenuItem(
                leading: const Icon(LucideIcons.download),
                onPressed: _onBrowseFiles,
                child: const Text('Add from room...'),
              ),
            if (showMcpMenuItem)
              ShadContextMenuItem(
                leading: const Icon(LucideIcons.plug),
                trailing: widget.controller.isToolkitEnabled('mcp') ? const Icon(LucideIcons.check, size: 16) : null,
                onPressed: () {
                  widget.controller.toggleToolkit('mcp');
                },
                child: const Text('MCP'),
              ),
          ],
          controller: popoverController,
          child:
              widget.triggerBuilder?.call(context, popoverController.toggle) ??
              ShadIconButton.ghost(
                hoverBackgroundColor: ShadTheme.of(context).colorScheme.background,
                decoration: const ShadDecoration(shape: BoxShape.circle),
                onPressed: popoverController.toggle,
                iconSize: 16,
                width: 32,
                height: 32,
                icon: const Icon(LucideIcons.plus),
              ),
        ),
      ),
    );
  }

  Widget _buildV1AttachButton(BuildContext context) {
    final menuActions = PowerboardsV1AttachMenuActions(
      closeMenu: () => _setV1MenuOpen(false),
      onUploadFile: () {
        _setV1MenuOpen(false);
        unawaited(_onSelectAttachment());
      },
      onAddFromRoom: widget.controller.room == null
          ? null
          : () {
              _setV1MenuOpen(false);
              unawaited(_onBrowseFiles());
            },
    );

    return PbMenuAnchor(
      placement: PbMenuAnchorPlacement.bottomLeft,
      gap: 10,
      preferAboveWhenOverflow: true,
      onDismiss: () => _setV1MenuOpen(false),
      panel: _v1MenuOpen
          ? widget.v1MenuPanelBuilder?.call(context, menuActions) ??
                PbMenuCard(
                  width: 240,
                  child: PbMenuList(
                    children: <Widget>[
                      PbMenuOption(
                        title: 'Upload a file...',
                        leadingIconAssetName: 'paperclip',
                        singleLine: true,
                        onPressed: menuActions.onUploadFile,
                      ),
                      if (menuActions.onAddFromRoom != null)
                        PbMenuOption(
                          title: 'Add from room...',
                          leadingIconAssetName: 'folder-plus',
                          singleLine: true,
                          onPressed: menuActions.onAddFromRoom,
                        ),
                    ],
                  ),
                )
          : null,
      child:
          widget.triggerBuilder?.call(context, () => _setV1MenuOpen(!_v1MenuOpen)) ??
          ShadIconButton.ghost(
            hoverBackgroundColor: ShadTheme.of(context).colorScheme.background,
            decoration: const ShadDecoration(shape: BoxShape.circle),
            onPressed: () => _setV1MenuOpen(!_v1MenuOpen),
            iconSize: 16,
            width: 32,
            height: 32,
            icon: const Icon(LucideIcons.plus),
          ),
    );
  }

  @override
  void dispose() {
    popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showAttachFiles = widget.alwaysShowAttachFiles != false;

    if (!showAttachFiles && !_canShowMcpConnectors) {
      return const SizedBox(width: 0, height: 22);
    }

    if (widget.useV1Menu) {
      return _buildV1AttachButton(context);
    }

    return _buildAttachButton(context);
  }
}
