import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/storage/file_browser.dart';
import 'package:powerboards/meshagent/file_upload.dart';
import 'package:powerboards/meshagent/file_list_primitives.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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

class PowerboardsDesktopChatAttachButton extends StatefulWidget {
  const PowerboardsDesktopChatAttachButton({
    required this.controller,
    super.key,
    this.alwaysShowAttachFiles,
    this.availableRooms,
    this.connectRoomClient,
    this.agentName,
    this.showMcpConnectors = false,
  });

  final bool? alwaysShowAttachFiles;
  final ChatThreadController controller;
  final Future<List<Room>> Function()? availableRooms;
  final Future<RoomClient> Function(String roomName)? connectRoomClient;
  final String? agentName;
  final bool showMcpConnectors;

  @override
  State<PowerboardsDesktopChatAttachButton> createState() => _PowerboardsDesktopChatAttachButtonState();
}

class _PowerboardsDesktopChatAttachButtonState extends State<PowerboardsDesktopChatAttachButton> {
  final ShadPopoverController popoverController = ShadPopoverController();

  bool get _canShowMcpConnectors {
    final normalizedAgentName = widget.agentName?.trim();
    return widget.showMcpConnectors && normalizedAgentName != null && normalizedAgentName.isNotEmpty;
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

    final selectedFiles = await showPowerboardsFlowDialog<List<String>>(
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
                          headerBuilder: (context, model) => buildPowerboardsFileBrowserInsetHeader(context, model, horizontalPadding: 4),
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

    try {
      if (selectedFiles == null || selectedFiles.isEmpty) {
        return;
      }

      for (final filePath in selectedFiles) {
        if (identical(selectedRoomClient, destinationRoom)) {
          widget.controller.attachFile(filePath);
          continue;
        }

        final importedPath = await _importFile(sourceRoom: selectedRoomClient, destinationRoom: destinationRoom, sourcePath: filePath);
        widget.controller.attachFile(importedPath);
      }
    } finally {
      if (!identical(selectedRoomClient, destinationRoom)) {
        selectedRoomClient.dispose();
      }
    }
  }

  Widget _buildAttachButton(BuildContext context) {
    final showPhotoUpload = FileUploadHelper.supportsPhotoUploadPicker;
    final attachMenuItemCount = (showPhotoUpload ? 2 : 1) + 1;
    final showMcpMenuItem = _canShowMcpConnectors;
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
          child: ShadIconButton.ghost(
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

    return _buildAttachButton(context);
  }
}
