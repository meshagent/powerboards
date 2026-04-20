import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:super_clipboard/super_clipboard.dart';

typedef PowerboardsPasteFileHandler = Future<void> Function(String name, Stream<Uint8List> dataStream, int size);

const double _powerboardsMobileAttachmentPasteMaxWidth = 600;
const List<FileFormat> _powerboardsPreferredClipboardFormats = [
  Formats.mp4,
  Formats.mov,
  Formats.mkv,
  Formats.pdf,
  Formats.png,
  Formats.jpeg,
  Formats.heic,
  Formats.tiff,
  Formats.webp,
];

const Set<String> _powerboardsTextOnlyClipboardFormats = {
  'public.utf8-plain-text',
  'public.plain-text',
  'public.html',
  'public.url',
  'public.url-name',
  'text/plain',
  'text/html',
  'text/uri-list',
};

bool powerboardsUsesSystemAdaptiveTextSelectionToolbar() {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => false,
  };
}

Widget powerboardsAdaptiveInputContextMenuBuilder(BuildContext context, EditableTextState editableTextState) {
  if (powerboardsUsesSystemAdaptiveTextSelectionToolbar()) {
    return TextFieldTapRegion(
      groupId: editableTextState.widget.groupId,
      child: AdaptiveTextSelectionToolbar.editableText(editableTextState: editableTextState),
    );
  }

  return ShadInputState.defaultContextMenuBuilder(context, editableTextState);
}

EditableTextContextMenuBuilder powerboardsThreadMobileAttachmentContextMenuBuilder({
  required bool hasPasteableAttachment,
  required PowerboardsPasteFileHandler onPasteFile,
}) {
  return (context, editableTextState) => _buildPowerboardsThreadMobileAttachmentContextMenu(
    context,
    editableTextState,
    hasPasteableAttachment: hasPasteableAttachment,
    onPasteFile: onPasteFile,
  );
}

TapRegionCallback? powerboardsAdaptiveInputOnPressedOutside() {
  if (!powerboardsUsesSystemAdaptiveTextSelectionToolbar()) {
    return null;
  }

  return (_) => FocusManager.instance.primaryFocus?.unfocus();
}

Future<bool> powerboardsClipboardHasPasteableAttachment() async {
  if (!powerboardsUsesSystemAdaptiveTextSelectionToolbar()) {
    return false;
  }

  final clipboard = SystemClipboard.instance;
  if (clipboard == null) {
    return false;
  }

  final reader = await clipboard.read();
  for (final item in reader.items) {
    if (await _itemHasPasteableAttachment(item)) {
      return true;
    }
  }
  return false;
}

Widget _buildPowerboardsThreadMobileAttachmentContextMenu(
  BuildContext context,
  EditableTextState editableTextState, {
  required bool hasPasteableAttachment,
  required PowerboardsPasteFileHandler onPasteFile,
}) {
  if (!_usesMobileAttachmentPasteMenu(context) || !hasPasteableAttachment) {
    return powerboardsAdaptiveInputContextMenuBuilder(context, editableTextState);
  }

  final buttonItems = editableTextState.contextMenuButtonItems.toList(growable: true);
  final originalPasteItem = buttonItems.firstWhereOrNull((item) => item.type == ContextMenuButtonType.paste);
  final pasteFileItem = ContextMenuButtonItem(
    type: ContextMenuButtonType.paste,
    label: 'Paste file',
    onPressed: () {
      editableTextState.hideToolbar();
      unawaited(_handlePasteFile(editableTextState.context, originalPasteItem?.onPressed, onPasteFile));
    },
  );

  final pasteIndex = buttonItems.indexWhere((item) => item.type == ContextMenuButtonType.paste);
  if (pasteIndex != -1) {
    buttonItems[pasteIndex] = pasteFileItem;
  } else {
    final selectAllIndex = buttonItems.indexWhere((item) => item.type == ContextMenuButtonType.selectAll);
    if (selectAllIndex != -1) {
      buttonItems.insert(selectAllIndex, pasteFileItem);
    } else {
      buttonItems.add(pasteFileItem);
    }
  }

  return TextFieldTapRegion(
    groupId: editableTextState.widget.groupId,
    child: AdaptiveTextSelectionToolbar.buttonItems(anchors: editableTextState.contextMenuAnchors, buttonItems: buttonItems),
  );
}

bool _usesMobileAttachmentPasteMenu(BuildContext context) {
  if (!powerboardsUsesSystemAdaptiveTextSelectionToolbar()) {
    return false;
  }

  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery == null) {
    return false;
  }

  return mediaQuery.size.width < _powerboardsMobileAttachmentPasteMaxWidth;
}

Future<ClipboardReader?> _readSystemClipboardReader() async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) {
    return null;
  }

  return clipboard.read();
}

Future<DataReaderFile?> _tryGetFile(DataReader reader, FileFormat? format) {
  final completer = Completer<DataReaderFile?>();
  final progress = reader.getFile(
    format,
    (file) {
      if (!completer.isCompleted) {
        completer.complete(file);
      }
    },
    onError: (error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    },
  );

  if (progress == null) {
    return Future.value(null);
  }

  return completer.future;
}

String _clipboardFallbackFileName(FileFormat? format) {
  if (format == Formats.png) {
    return 'image.png';
  }
  if (format == Formats.jpeg) {
    return 'image.jpg';
  }
  if (format == Formats.heic) {
    return 'image.heic';
  }
  if (format == Formats.tiff) {
    return 'image.tiff';
  }
  if (format == Formats.webp) {
    return 'image.webp';
  }
  if (format == Formats.pdf) {
    return 'document.pdf';
  }
  if (format == Formats.mp4) {
    return 'video.mp4';
  }
  if (format == Formats.mov) {
    return 'video.mov';
  }
  if (format == Formats.mkv) {
    return 'video.mkv';
  }

  return 'clipboard-item';
}

bool _isLikelyAttachmentPlatformFormat(String format) {
  final normalized = format.toLowerCase();
  if (_powerboardsTextOnlyClipboardFormats.contains(normalized)) {
    return false;
  }

  if (normalized == 'public.file-url' ||
      normalized == 'public.item' ||
      normalized == 'public.content' ||
      normalized == 'public.data' ||
      normalized.startsWith('dyn.')) {
    return true;
  }

  return normalized.contains('image') ||
      normalized.contains('jpeg') ||
      normalized.contains('jpg') ||
      normalized.contains('png') ||
      normalized.contains('heic') ||
      normalized.contains('tiff') ||
      normalized.contains('gif') ||
      normalized.contains('webp') ||
      normalized.contains('pdf') ||
      normalized.contains('video') ||
      normalized.contains('movie') ||
      normalized.contains('audio') ||
      normalized.contains('zip') ||
      normalized.contains('archive') ||
      normalized.contains('word') ||
      normalized.contains('excel') ||
      normalized.contains('powerpoint') ||
      normalized.contains('spreadsheet') ||
      normalized.contains('presentation') ||
      normalized.contains('document');
}

Future<bool> _itemHasPasteableAttachment(ClipboardDataReader item) async {
  if (_powerboardsPreferredClipboardFormats.any(item.canProvide)) {
    return true;
  }

  if (item.platformFormats.any(_isLikelyAttachmentPlatformFormat)) {
    return true;
  }

  if (item.canProvide(Formats.fileUri)) {
    final fileUri = await item.readValue(Formats.fileUri);
    if (fileUri != null && fileUri.scheme == 'file' && fileUri.toFilePath().trim().isNotEmpty) {
      return true;
    }
  }

  final suggestedName = (await item.getSuggestedName())?.trim();
  if (suggestedName == null || suggestedName.isEmpty) {
    return false;
  }

  final file = await _tryGetFile(item, null);
  if (file == null) {
    return false;
  }
  file.close();
  return true;
}

Future<bool> _pasteClipboardAttachments(ClipboardReader reader, PowerboardsPasteFileHandler onPasteFile) async {
  var handled = false;

  for (final item in reader.items) {
    if (item.canProvide(Formats.fileUri)) {
      final fileUri = await item.readValue(Formats.fileUri);
      if (fileUri != null && fileUri.scheme == 'file') {
        final localPath = fileUri.toFilePath();
        if (localPath.trim().isNotEmpty) {
          final file = XFile(localPath);
          await onPasteFile(
            p.basename(localPath).trim().isNotEmpty ? p.basename(localPath).trim() : 'clipboard-item',
            file.openRead(),
            await file.length(),
          );
          handled = true;
          continue;
        }
      }
    }

    final format = _powerboardsPreferredClipboardFormats.firstWhereOrNull(item.canProvide);
    final suggestedName = (await item.getSuggestedName())?.trim();
    if (format != null || (suggestedName?.isNotEmpty ?? false)) {
      final file = await _tryGetFile(item, format);
      if (file != null) {
        final resolvedName = (file.fileName?.trim().isNotEmpty ?? false)
            ? file.fileName!.trim()
            : ((suggestedName?.isNotEmpty ?? false) ? suggestedName! : _clipboardFallbackFileName(format));
        await onPasteFile(resolvedName, file.getStream(), file.fileSize ?? 0);
        handled = true;
      }
    }
  }

  return handled;
}

Future<void> _handlePasteFile(BuildContext context, VoidCallback? fallbackPasteAction, PowerboardsPasteFileHandler onPasteFile) async {
  final reader = await _readSystemClipboardReader();
  final handled = reader != null && await _pasteClipboardAttachments(reader, onPasteFile);

  if (!handled && fallbackPasteAction != null) {
    fallbackPasteAction();
    return;
  }

  if (!handled && context.mounted) {
    ShadToaster.of(
      context,
    ).show(const ShadToast.destructive(title: Text('No file on clipboard'), description: Text('Copy a file first, then try again.')));
  }
}
