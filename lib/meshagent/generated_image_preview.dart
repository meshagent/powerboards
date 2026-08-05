import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/chat/dataset_chat_thread.dart';
import 'package:powerboards/meshagent/v1_file_preview_source.dart';
import 'package:powerboards/meshagent/thread_storage_save_surface.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_file_preview_state_card.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_room_panel.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_svg_icon.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';

class PowerboardsV1GeneratedImageCompletionActions extends StatelessWidget {
  const PowerboardsV1GeneratedImageCompletionActions({super.key, required this.onSaveCopy, required this.onCopyPrompt});

  final VoidCallback onSaveCopy;
  final VoidCallback onCopyPrompt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _PowerboardsV1GeneratedImageAction(
            key: const ValueKey('generated-image-save-copy-action'),
            iconAssetName: 'save',
            label: 'Save a copy',
            onPressed: onSaveCopy,
          ),
          _PowerboardsV1GeneratedImageAction(
            key: const ValueKey('generated-image-copy-prompt-action'),
            iconAssetName: 'clipboard-copy',
            label: 'Copy prompt',
            onPressed: onCopyPrompt,
          ),
        ],
      ),
    );
  }
}

class _PowerboardsV1GeneratedImageAction extends StatelessWidget {
  const _PowerboardsV1GeneratedImageAction({super.key, required this.iconAssetName, required this.label, required this.onPressed});

  final String iconAssetName;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: PbColors.surfaceRailSelected,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      onPressed: onPressed,
      icon: PbSvgIcon(assetName: iconAssetName, size: 16, color: PbColors.surfaceRailSelected),
      label: Text(label),
    );
  }
}

class PowerboardsV1GeneratedImagePreview {
  const PowerboardsV1GeneratedImagePreview({
    this.generationId,
    this.uri,
    this.imageId,
    this.mimeType,
    this.status,
    this.statusDetail,
    this.width,
    this.height,
    this.sourcePrompt,
    this.prompt,
  });

  factory PowerboardsV1GeneratedImagePreview.fromDatasetThreadImage(DatasetThreadImage image) {
    return PowerboardsV1GeneratedImagePreview(
      generationId: image.generationId,
      uri: image.uri,
      imageId: image.imageId,
      mimeType: image.mimeType,
      status: image.status,
      statusDetail: image.statusDetail,
      width: image.width,
      height: image.height,
      sourcePrompt: image.sourcePrompt,
      prompt: image.prompt,
    );
  }

  final String? generationId;
  final String? uri;
  final String? imageId;
  final String? mimeType;
  final String? status;
  final String? statusDetail;
  final double? width;
  final double? height;
  final String? sourcePrompt;
  final String? prompt;

  String get artifactLabel {
    return powerboardsV1GeneratedImageArtifactLabel(sourcePrompt: sourcePrompt, computedPrompt: prompt);
  }

  String get suggestedFileName {
    return switch (mimeType?.trim().toLowerCase()) {
      'image/jpeg' || 'image/jpg' => 'generated-image.jpg',
      'image/webp' => 'generated-image.webp',
      'image/gif' => 'generated-image.gif',
      'image/svg+xml' || 'image/svg' => 'generated-image.svg',
      _ => 'generated-image.png',
    };
  }

  String get suggestedSaveCopyFileName {
    final dot = suggestedFileName.lastIndexOf('.');
    final extension = dot < 0 ? '' : suggestedFileName.substring(dot);
    return '${powerboardsV1GeneratedImageArtifactSlug(artifactLabel)}$extension';
  }

  Object get identityKey {
    final normalizedGenerationId = generationId?.trim();
    if (normalizedGenerationId != null && normalizedGenerationId.isNotEmpty) {
      return 'generation:$normalizedGenerationId';
    }
    final normalizedImageId = imageId?.trim();
    if (normalizedImageId != null && normalizedImageId.isNotEmpty) {
      return 'image:$normalizedImageId';
    }
    return 'uri:${uri?.trim() ?? ''}';
  }

  Object get contentKey => Object.hash(uri?.trim(), imageId?.trim(), mimeType?.trim(), status?.trim(), statusDetail?.trim(), width, height);

  Object get sourceKey => identityKey;

  bool get isPending {
    return switch (status?.trim().toLowerCase()) {
      'completed' || 'failed' || 'cancelled' => false,
      _ => true,
    };
  }

  PbAttachmentListItemData get file {
    return PbAttachmentListItemData(
      title: isPending ? 'Generating image…' : artifactLabel,
      subtitle: isPending ? 'Generating image' : 'Generated image',
      fileType: PbAttachmentFileType.image,
      sourceKey: identityKey,
      showAskAgentAction: false,
      showSaveCopyAsAction: true,
    );
  }

  PbAttachmentListItemData get sidepaneFile {
    return PbAttachmentListItemData(
      title: isPending ? 'Generating image…' : artifactLabel,
      subtitle: isPending ? 'Generating image…' : 'Generated image · Preview and save a copy to Files',
      fileType: PbAttachmentFileType.image,
      sourceKey: identityKey,
      isLoading: isPending,
      showAskAgentAction: false,
      showSaveCopyAsAction: true,
    );
  }

  Future<ChatThreadGeneratedImageContent?> load(RoomClient room) {
    return loadChatThreadGeneratedImageContent(room, imageId: imageId, imageUri: uri, fallbackMimeType: mimeType);
  }
}

const Set<String> _generatedImageLabelNoiseWords = <String>{
  'beautiful',
  'cinematic',
  'detailed',
  'dramatic',
  'friendly',
  'giant',
  'gigantic',
  'high-resolution',
  'photorealistic',
  'realistic',
  'stunning',
  'wide-angle',
};

String powerboardsV1GeneratedImageArtifactLabel({String? sourcePrompt, String? computedPrompt}) {
  for (final prompt in <String?>[sourcePrompt, computedPrompt]) {
    final label = _generatedImageArtifactLabelFromPrompt(prompt);
    if (label != null) {
      return label;
    }
  }
  return 'Generated image';
}

String? _generatedImageArtifactLabelFromPrompt(String? prompt) {
  var candidate = (prompt ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (candidate.isEmpty) {
    return null;
  }

  candidate = candidate.replaceFirst(
    RegExp(r'^(?:please\s+)?(?:create|generate|make|draw|render|produce|show|design)\s+(?:me\s+|us\s+)?', caseSensitive: false),
    '',
  );
  final mediumMatch = RegExp(
    r'\b(?:an?\s+|the\s+)?(?:image|photo(?:graph)?|picture|illustration|rendering|portrait|scene)\s+of\s+',
    caseSensitive: false,
  ).firstMatch(candidate);
  if (mediumMatch != null) {
    candidate = candidate.substring(mediumMatch.end);
  }
  candidate = candidate.replaceFirst(RegExp(r'^(?:an?|the)\s+', caseSensitive: false), '');

  final location = _generatedImageLocation(candidate);
  final subjectEnd = RegExp(
    r'\b(?:walks?|walking|runs?|running|sprints?|sprinting|stands?|standing|sits?|sitting|flies|flying|drives?|driving|rides?|riding|moves?|moving|strolls?|strolling|roams?|roaming|wanders?|wandering|chases?|chasing|charges?|jumps?|jumping|swims?|swimming|dances?|dancing|sleeps?|sleeping|plays?|playing|eats?|eating|looks?|looking|wears?|wearing|holds?|holding|carries|carrying|towers?|towering|poses?|posing|posed|calmly|through|across|along|around|in|on|with|at|under|over|beside|near)\b',
    caseSensitive: false,
  ).firstMatch(candidate);
  var subject = (subjectEnd == null ? candidate : candidate.substring(0, subjectEnd.start)).split(RegExp(r'[.;,:!?]')).first.trim();
  subject = subject.replaceFirst(RegExp(r'^(?:an?|the)\s+', caseSensitive: false), '');

  var subjectWords = subject
      .split(RegExp(r'\s+'))
      .map((word) => word.replaceAll(RegExp(r"^[^A-Za-z0-9]+|[^A-Za-z0-9'-]+$"), ''))
      .where((word) => word.isNotEmpty && !_generatedImageLabelNoiseWords.contains(word.toLowerCase()))
      .toList(growable: false);
  if (subjectWords.length > 3) {
    subjectWords = subjectWords.sublist(subjectWords.length - 3);
  }
  if (subjectWords.isEmpty) {
    return null;
  }

  final normalizedSubject = subjectWords.join(' ').toLowerCase();
  final subjectLabel = '${normalizedSubject[0].toUpperCase()}${normalizedSubject.substring(1)}';
  return location == null ? subjectLabel : '$subjectLabel in $location';
}

String? _generatedImageLocation(String candidate) {
  final patterns = <RegExp>[
    RegExp(r"\b(?:streets?\s+of|city\s+of)\s+([A-Z][A-Za-z0-9’'-]*(?:\s+[A-Z][A-Za-z0-9’'-]*){0,2})"),
    RegExp(r"\b(?:in|through|across|along|around)\s+(?:the\s+)?([A-Z][A-Za-z0-9’'-]*(?:\s+[A-Z][A-Za-z0-9’'-]*){0,2})"),
    RegExp(
      r"\b(?:in|through|across|along|around)\s+(?:an?\s+)?(?:busy|crowded|quiet|sunny|rainy|snowy)\s+([A-Z][A-Za-z0-9’'-]*(?:\s+[A-Z][A-Za-z0-9’'-]*)?)",
    ),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(candidate);
    if (match == null) {
      continue;
    }
    var value = match.group(1)!.replaceAll(RegExp(r"[^A-Za-z0-9’' -]+$"), '').trim();
    if (value == 'New York City') {
      value = 'New York';
    }
    final words = value.split(RegExp(r'\s+'));
    return words.length <= 2 ? value : words.take(2).join(' ');
  }

  final lowerCaseMatch = RegExp(
    r"\b(?:streets?\s+of|city\s+of)\s+(?:the\s+)?([a-z][a-z0-9'-]*(?:\s+[a-z][a-z0-9'-]*)?)",
    caseSensitive: false,
  ).firstMatch(candidate);
  if (lowerCaseMatch == null) {
    return null;
  }
  final words = lowerCaseMatch.group(1)!.split(RegExp(r'\s+'));
  if (<String>{'a', 'an', 'the'}.contains(words.first.toLowerCase())) {
    return null;
  }
  return words.map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}').join(' ');
}

String powerboardsV1GeneratedImageArtifactSlug(String label) {
  final normalized = label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'generated-image' : normalized;
}

PbFilePreviewSource powerboardsV1GeneratedImagePreviewSource({
  required RoomClient room,
  required PowerboardsV1GeneratedImagePreview preview,
  Future<void> Function()? onSave,
}) {
  final file = preview.file;
  return PbFilePreviewSource(
    sourceKey: preview.sourceKey,
    headerLeading: preview.isPending
        ? const SizedBox.square(
            dimension: 24,
            child: Padding(
              padding: EdgeInsets.all(2),
              child: CircularProgressIndicator(strokeWidth: 2, color: PbColors.textSubtle),
            ),
          )
        : null,
    hideToolbarActions: preview.isPending,
    onSave: onSave,
    child: _PowerboardsV1GeneratedImagePreviewContent(key: ValueKey(preview.sourceKey), room: room, preview: preview, file: file),
  );
}

Future<String?> showPowerboardsV1GeneratedImageSaveSurface({
  required BuildContext context,
  required RoomClient room,
  required PowerboardsV1GeneratedImagePreview preview,
}) {
  return showPowerboardsV1ThreadSaveCopySurface(
    context,
    ThreadStorageSaveSurfaceRequest(
      room: room,
      title: 'Save a copy as...',
      suggestedFileName: preview.suggestedSaveCopyFileName,
      fileNameLabel: 'Enter a name for your file',
      contentType: ThreadStorageSaveContentType.attachment,
      offerKeepBothOnConflict: true,
      loadContent: () async {
        final content = await preview.load(room);
        if (content == null) {
          throw StateError('The generated image is not available to save yet.');
        }
        return FileContent(data: content.data, name: content.suggestedFileName, mimeType: content.mimeType);
      },
    ),
  );
}

Future<void> downloadPowerboardsV1GeneratedImage({required RoomClient room, required PowerboardsV1GeneratedImagePreview preview}) async {
  final content = await preview.load(room);
  if (content == null) {
    throw StateError('The generated image is not available to download yet.');
  }
  await FilePicker.saveFile(dialogTitle: 'Download image', fileName: preview.suggestedFileName, bytes: content.data);
}

class _PowerboardsV1GeneratedImagePreviewContent extends StatefulWidget {
  const _PowerboardsV1GeneratedImagePreviewContent({super.key, required this.room, required this.preview, required this.file});

  final RoomClient room;
  final PowerboardsV1GeneratedImagePreview preview;
  final PbAttachmentListItemData file;

  @override
  State<_PowerboardsV1GeneratedImagePreviewContent> createState() => _PowerboardsV1GeneratedImagePreviewContentState();
}

class _PowerboardsV1GeneratedImagePreviewContentState extends State<_PowerboardsV1GeneratedImagePreviewContent> {
  ChatThreadGeneratedImageContent? _content;
  Object? _error;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _PowerboardsV1GeneratedImagePreviewContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room != widget.room || oldWidget.preview.contentKey != widget.preview.contentKey) {
      _load();
    }
  }

  Future<void> _load() async {
    final loadVersion = ++_loadVersion;
    try {
      final content = await widget.preview.load(widget.room);
      if (!mounted || loadVersion != _loadVersion) {
        return;
      }
      setState(() {
        if (content != null) {
          _content = content;
        }
        _error = content == null && !widget.preview.isPending ? StateError('Image unavailable') : null;
      });
    } catch (error) {
      if (!mounted || loadVersion != _loadVersion) {
        return;
      }
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    if (content != null) {
      return PowerboardsV1ImageDataPreview(
        data: content.data,
        path: content.suggestedFileName,
        fit: BoxFit.contain,
        file: widget.file,
        mimeType: content.mimeType,
      );
    }

    if (_error != null) {
      return Center(
        child: PbFilePreviewStateCard(file: widget.file, state: PbAttachmentPreviewState.unavailable),
      );
    }

    return const Center(child: CircularProgressIndicator(color: PbColors.textSubtle));
  }
}
