import 'package:flutter/material.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/storage/file_browser.dart';
import 'package:powerboards/meshagent/file_list_primitives.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
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

void _showThreadStorageSaveToast(BuildContext context, {required Widget title, Widget? description, bool destructive = false}) {
  final toaster = ShadToaster.maybeOf(context);
  if (toaster == null) {
    return;
  }

  final toast = destructive
      ? ShadToast.destructive(title: title, description: description)
      : ShadToast(title: title, description: description);
  toaster.show(toast);
}

void _dismissSaveFieldFocus() {
  FocusManager.instance.primaryFocus?.unfocus();
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
                      TapRegion(
                        onTapOutside: (_) => _dismissSaveFieldFocus(),
                        child: ShadInputFormField(
                          label: Text(request.fileNameLabel),
                          placeholder: Text(request.suggestedFileName),
                          keyboardType: TextInputType.text,
                          enabled: !saving,
                          controller: fileNameController,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (_) => _dismissSaveFieldFocus(),
                        child: SizedBox(
                          height: _saveFlowDialogBrowserHeight,
                          child: browserWidget(
                            headerHorizontalPadding: _saveFlowDialogBodyHorizontalInset,
                            rowBuilder: buildPowerboardsFileBrowserNavigationRow,
                            usesNativeMobileLayout: true,
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
