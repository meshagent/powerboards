import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/storage/file_browser.dart';
import 'package:powerboards/meshagent/file_upload.dart';
import 'package:powerboards/meshagent/file_list_primitives.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PowerboardsMobileChatAttachButton extends StatefulWidget {
  const PowerboardsMobileChatAttachButton({
    required this.controller,
    super.key,
    this.alwaysShowAttachFiles,
    this.availableRooms,
    this.connectRoomClient,
  });

  final bool? alwaysShowAttachFiles;
  final ChatThreadController controller;
  final Future<List<Room>> Function()? availableRooms;
  final Future<RoomClient> Function(String roomName)? connectRoomClient;

  @override
  State<PowerboardsMobileChatAttachButton> createState() => _PowerboardsMobileChatAttachButtonState();
}

class _PowerboardsMobileChatAttachButtonState extends State<PowerboardsMobileChatAttachButton> {
  static const double _flowDialogBodyHorizontalInset = 24.0;

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
      builder: (dialogContext) {
        final usesLandscapeMobileDialogLayout = powerboardsUsesLandscapeMobileDialogLayout(dialogContext);

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => PowerboardsShadDialog.listPicker(
            title: const Text('Select files'),
            description: const Text('Attach files from this room'),
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
            child: Padding(
              padding: powerboardsUsesNativeMobileDialogLayout(dialogContext) ? EdgeInsets.zero : powerboardsDialogScrollableListPadding,
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: double.infinity,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: usesLandscapeMobileDialogLayout ? double.infinity : 420),
                    child: SizedBox(
                      height: 450,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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

                                      if (!identical(destinationRoom, selectedRoomClient) &&
                                          !identical(nextRoomClient, selectedRoomClient)) {
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
                          Expanded(
                            child: resolvingRoom
                                ? const Center(child: CircularProgressIndicator())
                                : resolveError
                                ? const Center(child: Text('Room failed to connect'))
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final usesNativeMobileLayout = powerboardsUsesNativeMobileDialogLayout(dialogContext);
                                      final browser = FileBrowser(
                                        key: ValueKey(selectedRoomName),
                                        onSelectionChanged: (selection) {
                                          setDialogState(() {
                                            picked = selection;
                                          });
                                        },
                                        room: selectedRoomClient,
                                        multiple: true,
                                        headerBuilder: (context, model) => buildPowerboardsFileBrowserInsetHeader(
                                          context,
                                          model,
                                          horizontalPadding: _flowDialogBodyHorizontalInset,
                                        ),
                                        rowBuilder: buildPowerboardsFileBrowserTitleOnlyRow,
                                        separatorBuilder: buildPowerboardsFileListDivider,
                                        emptyBuilder: buildPowerboardsFileBrowserEmptyState,
                                      );

                                      if (!usesNativeMobileLayout) {
                                        return browser;
                                      }

                                      final expandedWidth = constraints.maxWidth + (_flowDialogBodyHorizontalInset * 2);
                                      return OverflowBox(
                                        alignment: Alignment.topCenter,
                                        minWidth: expandedWidth,
                                        maxWidth: expandedWidth,
                                        child: SizedBox(width: expandedWidth, child: browser),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

  Future<void> _runDialogAction(BuildContext dialogContext, Future<void> Function() action) async {
    Navigator.of(dialogContext).pop();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    await action();
  }

  Future<void> _showAttachMenu() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) {
      return;
    }

    await showPowerboardsFlowDialog<void>(
      context: context,
      builder: (dialogContext) {
        final usesLandscapeMobileDialogLayout = powerboardsUsesLandscapeMobileDialogLayout(dialogContext);

        return PowerboardsShadDialog.listPicker(
          title: const Text('Add to thread'),
          description: const Text('Choose where to attach from'),
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: powerboardsUsesNativeMobileDialogLayout(dialogContext) ? EdgeInsets.zero : powerboardsDialogScrollableListPadding,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: double.infinity,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: usesLandscapeMobileDialogLayout ? double.infinity : 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (FileUploadHelper.supportsPhotoUploadPicker)
                        _AttachFlowDialogActionRow(
                          title: 'Upload a photo...',
                          icon: LucideIcons.imageUp,
                          onPressed: () => _runDialogAction(dialogContext, _onSelectPhoto),
                        ),
                      if (FileUploadHelper.supportsPhotoUploadPicker) const ShadSeparator.horizontal(margin: EdgeInsets.zero),
                      _AttachFlowDialogActionRow(
                        title: 'Upload a file...',
                        icon: LucideIcons.paperclip,
                        onPressed: () => _runDialogAction(dialogContext, _onSelectAttachment),
                      ),
                      if (widget.controller.room != null) ...[
                        const ShadSeparator.horizontal(margin: EdgeInsets.zero),
                        _AttachFlowDialogActionRow(
                          title: 'Add from room...',
                          icon: LucideIcons.download,
                          onPressed: () => _runDialogAction(dialogContext, _onBrowseFiles),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showAttachFiles = widget.alwaysShowAttachFiles != false;
    if (!showAttachFiles) {
      return const SizedBox(width: 0, height: 22);
    }

    return ShadIconButton.ghost(
      hoverBackgroundColor: ShadTheme.of(context).colorScheme.background,
      decoration: const ShadDecoration(shape: BoxShape.circle),
      onPressed: _showAttachMenu,
      iconSize: 16,
      width: 32,
      height: 32,
      icon: const Icon(LucideIcons.plus),
    );
  }
}

class _AttachFlowDialogActionRow extends StatelessWidget {
  const _AttachFlowDialogActionRow({required this.title, required this.icon, required this.onPressed});

  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final foreground = theme.colorScheme.foreground;
    final titleStyle = powerboardsInterTextStyle(color: foreground, fontWeight: FontWeight.w600);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: powerboardsMobileSecondaryRowHeight,
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Center(child: Icon(icon, size: 20, color: foreground)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
