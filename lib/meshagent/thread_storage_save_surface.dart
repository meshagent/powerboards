import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/storage/file_browser.dart';
import 'package:powerboards/meshagent/file_list_primitives.dart';
import 'package:powerboards/powerboards_ui/v1/components/chat/pb_comment_save_copy_dialog.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_dialog_file_list.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_file_select_dialog.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:powerboards/ui/powerboards_toasts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double _saveFlowDialogBodyHorizontalInset = 24.0;
const double _saveFlowDialogBrowserHeight = 320.0;

double _desktopSaveDialogHeight(BoxConstraints constraints) {
  final maxHeight = constraints.maxHeight;
  if (!maxHeight.isFinite) {
    return 600.0;
  }

  return (maxHeight - 100.0).clamp(0.0, 600.0).toDouble();
}

BoxConstraints? _desktopSaveDialogConstraints(BuildContext context, BoxConstraints constraints) {
  if (powerboardsUsesNativeMobileDialogLayout(context)) {
    return null;
  }

  final height = _desktopSaveDialogHeight(constraints);
  return BoxConstraints(minWidth: 512.0, maxWidth: 512.0, minHeight: height, maxHeight: height);
}

String _threadStorageFileNameFromPath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return "file";
  }

  final slash = trimmed.lastIndexOf("/");
  if (slash < 0 || slash == trimmed.length - 1) {
    return trimmed;
  }

  return trimmed.substring(slash + 1);
}

String _resolvedThreadStorageSavePath({required String rawValue, required String selectedFolder, required String suggestedFileName}) {
  var fullPath = rawValue.trim().isEmpty ? suggestedFileName : rawValue.trim();

  if (!fullPath.contains("/")) {
    fullPath = selectedFolder.isEmpty ? fullPath : "$selectedFolder/$fullPath";
  }

  final suggestedDot = suggestedFileName.lastIndexOf(".");
  if (suggestedDot <= 0 || suggestedDot == suggestedFileName.length - 1) {
    return fullPath;
  }

  final lastSlash = fullPath.lastIndexOf("/");
  final fileName = lastSlash >= 0 ? fullPath.substring(lastSlash + 1) : fullPath;
  if (fileName.contains(".")) {
    return fullPath;
  }

  return "$fullPath${suggestedFileName.substring(suggestedDot)}";
}

Future<bool> _showOverwriteConfirmation(BuildContext context, {required String fullPath}) async {
  final overwrite = await showPowerboardsAlertDialog<bool>(
    context: context,
    builder: (dialogContext) => PowerboardsShadDialog.compactAlert(
      title: const Text("File already exists"),
      description: Text("A file at '$fullPath' already exists in room storage. Do you want to overwrite it?"),
      actions: [
        ShadButton.secondary(
          onPressed: () {
            Navigator.of(dialogContext).pop(false);
          },
          child: const Text("Cancel"),
        ),
        ShadButton(
          onPressed: () {
            Navigator.of(dialogContext).pop(true);
          },
          child: const Text("Overwrite"),
        ),
      ],
    ),
  );

  return overwrite == true;
}

enum PowerboardsV1SaveConflictResolution { cancel, keepBoth, replace }

@visibleForTesting
Future<PowerboardsV1SaveConflictResolution> showPowerboardsV1SaveConflictResolution(
  BuildContext context, {
  required String fullPath,
}) async {
  final resolution = await showPowerboardsAlertDialog<PowerboardsV1SaveConflictResolution>(
    context: context,
    builder: (dialogContext) => PowerboardsShadDialog.compactAlert(
      title: const Text('File already exists'),
      description: Text("A file named '${_threadStorageFileNameFromPath(fullPath)}' already exists in this folder."),
      actions: [
        ShadButton.secondary(
          onPressed: () => Navigator.of(dialogContext).pop(PowerboardsV1SaveConflictResolution.keepBoth),
          child: const Text('Keep both'),
        ),
        ShadButton(
          onPressed: () => Navigator.of(dialogContext).pop(PowerboardsV1SaveConflictResolution.replace),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
  return resolution ?? PowerboardsV1SaveConflictResolution.cancel;
}

@visibleForTesting
Future<String> powerboardsV1NextAvailableSavePath(String fullPath, {required Future<bool> Function(String path) exists}) async {
  final slash = fullPath.lastIndexOf('/');
  final directory = slash < 0 ? '' : fullPath.substring(0, slash + 1);
  final fileName = slash < 0 ? fullPath : fullPath.substring(slash + 1);
  final dot = fileName.lastIndexOf('.');
  final extension = dot <= 0 ? '' : fileName.substring(dot);
  final stem = dot <= 0 ? fileName : fileName.substring(0, dot);
  final numberedStem = RegExp(r'^(.*)-([2-9][0-9]*)$').firstMatch(stem);
  final baseStem = numberedStem?.group(1) ?? stem;
  var suffix = numberedStem == null ? 2 : int.parse(numberedStem.group(2)!) + 1;

  while (true) {
    final candidate = '$directory$baseStem-$suffix$extension';
    if (!await exists(candidate)) {
      return candidate;
    }
    suffix += 1;
  }
}

void _showThreadStorageSaveToast(BuildContext context, {required Widget title, Widget? description, bool destructive = false}) {
  final toaster = ShadToaster.maybeOf(context);
  if (toaster == null) {
    return;
  }

  final toast = powerboardsWidgetToast(title: title, description: description, destructive: destructive);
  toaster.show(toast);
}

void _dismissSaveFieldFocus() {
  FocusManager.instance.primaryFocus?.unfocus();
}

Widget _buildPowerboardsV1CommentDestinationList(BuildContext context, List<FileBrowserRowViewModel> rows) {
  final rowsById = {for (final row in rows) row.fullPath: row};
  final items = [
    for (final row in rows)
      () {
        final metadata = PbResolvedAttachmentMetadata.resolve(
          title: row.entry.name,
          explicitFileType: row.entry.isFolder ? PbAttachmentFileType.folder : null,
        );
        return PbDialogFileListItemData(
          id: row.fullPath,
          title: row.displayName,
          iconAssetName: metadata.iconAssetName,
          iconColor: row.entry.isFolder ? PbColors.surfaceRailActive : metadata.iconColor,
        );
      }(),
  ];

  return PbDialogFileList(
    items: items,
    showCheckboxes: false,
    framed: false,
    rowMargin: const EdgeInsets.symmetric(horizontal: 28),
    rowPadding: const EdgeInsets.all(11),
    listPadding: const EdgeInsets.symmetric(vertical: 8),
    clipBehavior: Clip.none,
    onItemPressed: (item) {
      final row = rowsById[item.id];
      if (row?.entry.isFolder == true) {
        row?.onPressed();
      }
    },
  );
}

Future<String?> showPowerboardsV1ThreadSaveCopySurface(BuildContext context, ThreadStorageSaveSurfaceRequest request) async {
  final isComment = request.contentType == ThreadStorageSaveContentType.comment;
  final nameController = TextEditingController(text: isComment ? '' : request.suggestedFileName);
  String selectedFolder = '';
  String? savedPath;
  bool saving = false;

  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (dialogContext) => Stack(
        children: [
          StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> saveCopy() async {
                final name = nameController.text.trim();
                if (name.isEmpty || saving) {
                  return;
                }

                var fullPath = _resolvedThreadStorageSavePath(
                  rawValue: name,
                  selectedFolder: selectedFolder,
                  suggestedFileName: request.suggestedFileName,
                );
                final exists = await request.room.storage.exists(fullPath);
                var overwrite = true;
                if (exists && dialogContext.mounted) {
                  if (request.offerKeepBothOnConflict) {
                    final resolution = await showPowerboardsV1SaveConflictResolution(dialogContext, fullPath: fullPath);
                    if (resolution == PowerboardsV1SaveConflictResolution.cancel || !dialogContext.mounted) {
                      return;
                    }
                    if (resolution == PowerboardsV1SaveConflictResolution.keepBoth) {
                      fullPath = await powerboardsV1NextAvailableSavePath(fullPath, exists: request.room.storage.exists);
                      overwrite = false;
                    }
                  } else {
                    final confirmed = await _showOverwriteConfirmation(dialogContext, fullPath: fullPath);
                    if (!confirmed || !dialogContext.mounted) {
                      return;
                    }
                  }
                } else if (request.offerKeepBothOnConflict) {
                  overwrite = false;
                }

                setDialogState(() => saving = true);

                try {
                  final content = await request.loadContent();
                  await request.room.storage.uploadStream(
                    fullPath,
                    Stream.value(content.data),
                    overwrite: overwrite,
                    size: content.data.length,
                    name: _threadStorageFileNameFromPath(fullPath),
                    mimeType: content.mimeType,
                  );
                  savedPath = fullPath;

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (context.mounted) {
                    _showThreadStorageSaveToast(context, title: const Text('Saved to room storage'), description: Text(fullPath));
                  }
                } catch (error) {
                  if (context.mounted) {
                    _showThreadStorageSaveToast(
                      context,
                      title: const Text('Unable to save file'),
                      description: Text('$error'),
                      destructive: true,
                    );
                  }
                  if (dialogContext.mounted) {
                    setDialogState(() => saving = false);
                  }
                }
              }

              return PbCommentSaveCopyDialog(
                subtitle: isComment ? 'Save comment as markdown' : 'Save attachment to Files',
                namePlaceholder: isComment ? 'Enter a name for your comment' : 'Enter a name for your file',
                nameController: nameController,
                canSave: nameController.text.trim().isNotEmpty,
                saving: saving,
                onNameChanged: (_) => setDialogState(() {}),
                onCopyAndSave: () => unawaited(saveCopy()),
                onClose: () => Navigator.of(dialogContext).pop(),
                fileBrowser: FileBrowser(
                  room: request.room,
                  selectionMode: FileBrowserSelectionMode.folders,
                  showFilesWhenSelectingFolders: true,
                  rootLabel: 'Browse',
                  onPathChanged: (path) => selectedFolder = path,
                  headerBuilder: (context, model) => PbFileSelectBreadcrumb(
                    currentPath: model.path,
                    onRootPressed: model.onRootPressed,
                    onSegmentPressed: model.onSegmentPressed,
                  ),
                  listBuilder: _buildPowerboardsV1CommentDestinationList,
                  emptyBuilder: (context) => const PbFileSelectStatus(message: 'This folder is empty'),
                  loadingBuilder: (context) => const PbFileSelectStatus(message: 'Loading files...', loading: true),
                  errorBuilder: (context, error) => const PbFileSelectStatus(message: 'Unable to load files'),
                ),
              );
            },
          ),
        ],
      ),
    );
  } finally {
    nameController.dispose();
  }
  return savedPath;
}

Future<void> showPowerboardsV1ThreadCommentSaveCopySurfaceForText(BuildContext context, {required RoomClient room, required String text}) {
  return showPowerboardsV1ThreadSaveCopySurface(
    context,
    ThreadStorageSaveSurfaceRequest(
      room: room,
      title: 'Save a copy as...',
      suggestedFileName: 'chat-comment.md',
      fileNameLabel: 'Enter a name for your comment',
      contentType: ThreadStorageSaveContentType.comment,
      loadContent: () async {
        final bytes = Uint8List.fromList(utf8.encode(text));
        return FileContent(data: bytes, name: 'chat-comment.md', mimeType: 'text/markdown');
      },
    ),
  );
}

Future<void> showPowerboardsThreadStorageSaveSurface(BuildContext context, ThreadStorageSaveSurfaceRequest request) async {
  final fileNameController = TextEditingController(text: request.suggestedFileName);
  String selectedFolder = "";
  bool saving = false;

  try {
    await showPowerboardsFlowDialog<void>(
      context: context,
      builder: (dialogContext) {
        final saveProgressColor = ShadTheme.of(dialogContext).colorScheme.primaryForeground;
        Future<void> onSavePressed(StateSetter setDialogState) async {
          final fullPath = _resolvedThreadStorageSavePath(
            rawValue: fileNameController.text,
            selectedFolder: selectedFolder,
            suggestedFileName: request.suggestedFileName,
          );
          final exists = await request.room.storage.exists(fullPath);
          if (exists && dialogContext.mounted) {
            final overwrite = await _showOverwriteConfirmation(dialogContext, fullPath: fullPath);
            if (!overwrite || !dialogContext.mounted) {
              return;
            }
          }

          setDialogState(() {
            saving = true;
          });

          try {
            final content = await request.loadContent();
            await request.room.storage.uploadStream(
              fullPath,
              Stream.value(content.data),
              overwrite: true,
              size: content.data.length,
              name: _threadStorageFileNameFromPath(fullPath),
              mimeType: content.mimeType,
            );

            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
            if (context.mounted) {
              _showThreadStorageSaveToast(context, title: const Text('Saved to room storage'), description: Text(fullPath));
            }
          } catch (error) {
            if (context.mounted) {
              _showThreadStorageSaveToast(
                context,
                title: const Text('Unable to save file'),
                description: Text('$error'),
                destructive: true,
              );
            }
          } finally {
            if (dialogContext.mounted) {
              setDialogState(() {
                saving = false;
              });
            }
          }
        }

        Widget saveButton(StateSetter setDialogState) {
          return ShadButton(
            onPressed: saving ? null : () => onSavePressed(setDialogState),
            child: saving
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(saveProgressColor)),
                      ),
                      const SizedBox(width: 6),
                      const Text('Saving...'),
                    ],
                  )
                : const Text("Save"),
          );
        }

        Widget browserWidget({
          required double headerHorizontalPadding,
          required FileBrowserRowBuilder rowBuilder,
          required bool usesNativeMobileLayout,
        }) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final browser = FileBrowser(
                onSelectionChanged: (selection) {
                  selectedFolder = selection.join("/");
                },
                room: request.room,
                multiple: false,
                selectionMode: FileBrowserSelectionMode.folders,
                showFilesWhenSelectingFolders: true,
                rootLabel: "Folders",
                headerBuilder: (context, model) =>
                    buildPowerboardsFileBrowserInsetHeader(context, model, horizontalPadding: headerHorizontalPadding),
                rowBuilder: rowBuilder,
                separatorBuilder: buildPowerboardsFileListDivider,
                emptyBuilder: buildPowerboardsFileBrowserSaveEmptyState,
              );

              if (!usesNativeMobileLayout) {
                return browser;
              }

              final expandedWidth = constraints.maxWidth + (_saveFlowDialogBodyHorizontalInset * 2);
              return OverflowBox(
                alignment: Alignment.topCenter,
                minWidth: expandedWidth,
                maxWidth: expandedWidth,
                child: SizedBox(width: expandedWidth, child: browser),
              );
            },
          );
        }

        if (powerboardsUsesNativeMobileDialogLayout(dialogContext)) {
          final usesLandscapeMobileDialogLayout = powerboardsUsesLandscapeMobileDialogLayout(dialogContext);
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) => PowerboardsShadDialog.listPicker(
              title: Text(request.title),
              description: const Text("Save to room storage"),
              mobileHideActionsWhenKeyboardVisible: false,
              actions: [
                ShadButton.secondary(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text("Cancel"),
                ),
                saveButton(setDialogState),
              ],
              child: Padding(
                padding: powerboardsUsesNativeMobileDialogLayout(dialogContext) ? EdgeInsets.zero : powerboardsDialogScrollableListPadding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: usesLandscapeMobileDialogLayout ? double.infinity : 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShadInputFormField(
                        label: Text(request.fileNameLabel),
                        placeholder: Text(request.suggestedFileName),
                        keyboardType: TextInputType.text,
                        enabled: !saving,
                        controller: fileNameController,
                        onPressedOutside: (_) => _dismissSaveFieldFocus(),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: _saveFlowDialogBrowserHeight,
                        child: browserWidget(
                          headerHorizontalPadding: _saveFlowDialogBodyHorizontalInset,
                          rowBuilder: buildPowerboardsFileBrowserNavigationRow,
                          usesNativeMobileLayout: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (dialogContext, constraints) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => PowerboardsShadDialog.task(
              scrollable: false,
              constraints: _desktopSaveDialogConstraints(dialogContext, constraints),
              title: Text(request.title),
              description: const Text('Save to room storage'),
              mobileKeyboardBehavior: PowerboardsDialogMobileKeyboardBehavior.ignore,
              actions: [
                ShadButton.outline(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                saveButton(setDialogState),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShadInputFormField(
                    label: Text(request.fileNameLabel),
                    placeholder: Text(request.suggestedFileName),
                    keyboardType: TextInputType.text,
                    enabled: !saving,
                    controller: fileNameController,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: browserWidget(
                      headerHorizontalPadding: 4,
                      rowBuilder: buildPowerboardsCompactFileBrowserNavigationRow,
                      usesNativeMobileLayout: false,
                    ),
                  ),
                  const SizedBox(height: powerboardsDialogScrollViewportVerticalInset),
                ],
              ),
            ),
          ),
        );
      },
    );
  } finally {
    fileNameController.dispose();
  }
}
