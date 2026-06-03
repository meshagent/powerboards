import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meshagent/document.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_flutter/document_connection_scope.dart';
import 'package:meshagent_flutter_shadcn/file_preview/file_preview.dart';
import 'package:meshagent_flutter_shadcn/file_preview/image.dart';
import 'package:meshagent_flutter_shadcn/file_preview/video.dart';
import 'package:meshagent_flutter_shadcn/viewers/builder.dart';
import 'package:meshagent_flutter_shadcn/viewers/file.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import 'package:powerboards/meshagent/document_pane.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_file_preview_state_card.dart';
import 'package:powerboards/powerboards_ui/v1/components/layouts/pb_room_panel.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_avatar.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_typography.dart';

const Set<String> powerboardsV1EditableTextPreviewExtensions = {
  'txt',
  'text',
  'md',
  'markdown',
  'mdown',
  'mkdn',
  'rst',
  'log',
  'csv',
  'tsv',
};

const Map<String, String> powerboardsV1FileTypeKeysByExtension = {
  'thread': 'thread',
  'transcript': 'transcript',
  'widget': 'widget',
  'document': 'document',
  'presentation': 'presentation',
  'gallery': 'image',
  'form': 'document',
};

typedef PowerboardsV1PreviewTextLoader = Future<String> Function(String path);
typedef PowerboardsV1PreviewTextSaver = Future<void> Function(String path, String text);
typedef PowerboardsV1PreviewDownloadUrl = Future<String> Function(String path);
typedef PowerboardsV1UnavailablePreviewBuilder = Widget Function(BuildContext context, PbAttachmentListItemData file, String? subtitle);

@visibleForTesting
String? powerboardsV1FileTypeKeyForStoragePath(String path) {
  final extension = powerboardsV1ExtensionForPath(path);
  if (extension.isEmpty) {
    return null;
  }

  return powerboardsV1FileTypeKeysByExtension[extension];
}

String powerboardsV1ExtensionForPath(String path) {
  return p.extension(path).replaceFirst('.', '').toLowerCase();
}

bool powerboardsV1IsNativeDocumentPath(String path) {
  return const {'thread', 'widget', 'document', 'gallery', 'presentation', 'form'}.contains(powerboardsV1ExtensionForPath(path));
}

bool powerboardsV1IsEditableTextPreview({required PbAttachmentFileType fileType, required String path}) {
  if (path.startsWith('dataset://')) {
    return false;
  }

  final extension = powerboardsV1ExtensionForPath(path);
  if (powerboardsV1EditableTextPreviewExtensions.contains(extension)) {
    return true;
  }

  final kind = classifyFile(path);
  if (kind == FileKind.markdown || kind == FileKind.code || kind == FileKind.tsv) {
    return true;
  }

  return switch (fileType) {
    PbAttachmentFileType.codeGeneric ||
    PbAttachmentFileType.script ||
    PbAttachmentFileType.code ||
    PbAttachmentFileType.key ||
    PbAttachmentFileType.settings => true,
    _ => false,
  };
}

Future<String> powerboardsV1LoadPreviewText(RoomClient room, String path) async {
  final content = await room.storage.download(path);
  return utf8.decode(content.data, allowMalformed: true);
}

Future<void> powerboardsV1SavePreviewText(RoomClient room, String path, String text) async {
  final bytes = Uint8List.fromList(utf8.encode(text));
  await room.storage.uploadStream(path, Stream<Uint8List>.value(bytes), overwrite: true, size: bytes.length);
}

PbFilePreviewSource powerboardsV1PreviewSourceForAttachment({
  required RoomClient room,
  required PbAttachmentListItemData file,
  required String path,
  PowerboardsV1PreviewTextLoader? loadText,
  PowerboardsV1PreviewTextSaver? saveText,
  PowerboardsV1PreviewDownloadUrl? downloadUrl,
  PowerboardsV1UnavailablePreviewBuilder? unavailablePreviewBuilder,
}) {
  final extension = powerboardsV1ExtensionForPath(path);
  final effectiveLoadText = loadText ?? (path) => powerboardsV1LoadPreviewText(room, path);
  final effectiveSaveText = saveText ?? (path, text) => powerboardsV1SavePreviewText(room, path, text);

  if (file.fileType == PbAttachmentFileType.transcript || extension == 'transcript' || extension == 'srt' || extension == 'vtt') {
    return PbFilePreviewSource(
      childBuilder: (fullscreen) => extension == 'transcript'
          ? _V1TranscriptDocumentPreview(room: room, path: path, file: file, fullscreen: fullscreen)
          : _V1TextTranscriptPreview(
              room: room,
              path: path,
              file: file,
              title: file.title,
              fullscreen: fullscreen,
              loadText: effectiveLoadText,
            ),
    );
  }

  if (powerboardsV1IsEditableTextPreview(fileType: file.fileType, path: path)) {
    return PbFilePreviewSource(loadText: () => effectiveLoadText(path), saveText: (text) => effectiveSaveText(path, text));
  }

  return PbFilePreviewSource(
    child: powerboardsV1PreviewContentChild(
      room: room,
      file: file,
      path: path,
      downloadUrl: downloadUrl,
      unavailablePreviewBuilder: unavailablePreviewBuilder,
    ),
  );
}

Widget? powerboardsV1PreviewContentChild({
  required RoomClient room,
  required PbAttachmentListItemData file,
  required String path,
  PowerboardsV1PreviewDownloadUrl? downloadUrl,
  PowerboardsV1UnavailablePreviewBuilder? unavailablePreviewBuilder,
}) {
  if (path.startsWith('dataset://')) {
    return _v1DocumentPaneContent(room: room, file: file, path: path, unavailablePreviewBuilder: unavailablePreviewBuilder);
  }

  final extension = powerboardsV1ExtensionForPath(path);
  final kind = classifyFile(path);
  if (file.fileType == PbAttachmentFileType.thread || extension == 'thread' || kind == FileKind.thread) {
    return _V1ThreadDocumentPreview(room: room, path: path, file: file);
  }

  if (kind == FileKind.custom) {
    return fileViewer(room, path);
  }

  if (powerboardsV1IsNativeDocumentPath(path)) {
    return _v1DocumentPaneContent(room: room, file: file, path: path, unavailablePreviewBuilder: unavailablePreviewBuilder);
  }

  switch (file.fileType) {
    case PbAttachmentFileType.image:
      return _V1StorageUrlPreview(
        room: room,
        path: path,
        file: file,
        downloadUrl: downloadUrl,
        builder: (url) => ImagePreview(url: url, fit: BoxFit.contain),
      );
    case PbAttachmentFileType.video:
    case PbAttachmentFileType.mediaGeneric:
      return _V1StorageUrlPreview(
        room: room,
        path: path,
        file: file,
        downloadUrl: downloadUrl,
        builder: (url) => VideoPreview(url: url, fit: BoxFit.contain),
      );
    case PbAttachmentFileType.sound:
    case PbAttachmentFileType.music:
      return _V1StorageUrlPreview(
        room: room,
        path: path,
        file: file,
        downloadUrl: downloadUrl,
        builder: (url) => AudioPreview(url: url),
      );
    case PbAttachmentFileType.pdf:
      return PowerboardsV1PdfPreview(room: room, path: path, file: file);
    case PbAttachmentFileType.transcript:
    case PbAttachmentFileType.thread:
    case PbAttachmentFileType.presentation:
      return null;
    case PbAttachmentFileType.generic:
    case PbAttachmentFileType.folder:
    case PbAttachmentFileType.archive:
    case PbAttachmentFileType.type:
    case PbAttachmentFileType.widget:
    case PbAttachmentFileType.businessGeneric:
    case PbAttachmentFileType.spreadsheet:
    case PbAttachmentFileType.document:
    case PbAttachmentFileType.codeGeneric:
    case PbAttachmentFileType.script:
    case PbAttachmentFileType.code:
    case PbAttachmentFileType.key:
    case PbAttachmentFileType.settings:
      break;
  }

  switch (kind) {
    case FileKind.image:
      return _V1StorageUrlPreview(
        room: room,
        path: path,
        file: file,
        downloadUrl: downloadUrl,
        builder: (url) => ImagePreview(url: url, fit: BoxFit.contain),
      );
    case FileKind.video:
      return _V1StorageUrlPreview(
        room: room,
        path: path,
        file: file,
        downloadUrl: downloadUrl,
        builder: (url) => VideoPreview(url: url, fit: BoxFit.contain),
      );
    case FileKind.audio:
      return _V1StorageUrlPreview(
        room: room,
        path: path,
        file: file,
        downloadUrl: downloadUrl,
        builder: (url) => AudioPreview(url: url),
      );
    case FileKind.pdf:
      return PowerboardsV1PdfPreview(room: room, path: path, file: file);
    case FileKind.custom:
      return fileViewer(room, path);
    case FileKind.thread:
    case FileKind.markdown:
    case FileKind.code:
    case FileKind.tsv:
    case FileKind.parquet:
    case FileKind.office:
    case FileKind.lance:
    case FileKind.unknown:
      break;
  }

  return null;
}

Widget _v1DocumentPaneContent({
  required RoomClient room,
  required PbAttachmentListItemData file,
  required String path,
  PowerboardsV1UnavailablePreviewBuilder? unavailablePreviewBuilder,
}) {
  return DocumentPane(
    path: path,
    room: room,
    noPreviewBuilder: (context, subtitle) =>
        unavailablePreviewBuilder?.call(context, file, subtitle) ?? _v1UnavailablePreview(context, file, subtitle),
  );
}

Widget _v1UnavailablePreview(BuildContext context, PbAttachmentListItemData file, String? subtitle) {
  return Center(
    child: PbFilePreviewStateCard(file: file, state: PbAttachmentPreviewState.unavailable),
  );
}

class PowerboardsV1PdfPreview extends StatefulWidget {
  const PowerboardsV1PdfPreview({super.key, required this.room, required this.path, required this.file, this.pageNumber = 1});

  final RoomClient room;
  final String path;
  final PbAttachmentListItemData file;
  final int pageNumber;

  @override
  State<PowerboardsV1PdfPreview> createState() => _PowerboardsV1PdfPreviewState();
}

class _PowerboardsV1PdfPreviewState extends State<PowerboardsV1PdfPreview> {
  static const _viewerBackground = Color(0xFFA4A4A4);
  static const _pageMargin = 34.0;

  late Future<Uint8List> _pdfData = _loadPdfData();

  @override
  void didUpdateWidget(covariant PowerboardsV1PdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room != widget.room || oldWidget.path != widget.path) {
      _pdfData = _loadPdfData();
    }
  }

  Future<Uint8List> _loadPdfData() async {
    final content = await widget.room.storage.download(widget.path);
    return Uint8List.fromList(content.data);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _pdfData,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _v1UnavailablePreview(context, widget.file, null);
        }

        final data = snapshot.data;
        if (data == null) {
          return _v1PreviewLoadingStatus();
        }

        return PdfViewer.data(
          data,
          sourceName: widget.path,
          initialPageNumber: widget.pageNumber,
          params: PdfViewerParams(
            margin: _pageMargin,
            backgroundColor: _viewerBackground,
            pageDropShadow: const BoxShadow(color: Color.fromRGBO(15, 23, 42, 0.38), blurRadius: 7, offset: Offset(0, 2)),
          ),
        );
      },
    );
  }
}

class _V1ThreadDocumentPreview extends StatefulWidget {
  const _V1ThreadDocumentPreview({required this.room, required this.path, required this.file});

  final RoomClient room;
  final String path;
  final PbAttachmentListItemData file;

  @override
  State<_V1ThreadDocumentPreview> createState() => _V1ThreadDocumentPreviewState();
}

class _V1ThreadDocumentPreviewState extends State<_V1ThreadDocumentPreview> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DocumentConnectionScope(
      key: ValueKey(widget.path),
      path: widget.path,
      room: widget.room,
      builder: (context, document, error) {
        if (error != null) {
          return _v1UnavailablePreview(context, widget.file, null);
        }

        if (document == null) {
          return const Center(child: CircularProgressIndicator(color: PbColors.textSubtle));
        }

        return ChangeNotifierBuilder(
          source: document,
          builder: (context) =>
              _V1ThreadPreviewContent(file: widget.file, messages: _v1ThreadPreviewMessages(document), scrollController: _scrollController),
        );
      },
    );
  }
}

class _V1ThreadPreviewContent extends StatefulWidget {
  const _V1ThreadPreviewContent({required this.file, required this.messages, required this.scrollController});

  final PbAttachmentListItemData file;
  final List<_V1ThreadPreviewMessage> messages;
  final ScrollController scrollController;

  @override
  State<_V1ThreadPreviewContent> createState() => _V1ThreadPreviewContentState();
}

class _V1ThreadPreviewContentState extends State<_V1ThreadPreviewContent> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return ColoredBox(
        color: PbColors.surfacePanel,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: PbFilePreviewStateCard(file: widget.file, state: PbAttachmentPreviewState.unavailable, label: 'No messages yet'),
          ),
        ),
      );
    }

    return ColoredBox(
      color: PbColors.surfacePanel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth ? constraints.maxWidth : 1000.0;
          final stackMaxWidth = width > 1400 ? width * 0.8 : width;
          final sidePadding = width < 760 ? 20.0 : 30.0;
          final messageGap = width < 760 ? 12.0 : 16.0;

          return MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Scrollbar(
              controller: widget.scrollController,
              thumbVisibility: _hovered,
              interactive: true,
              child: SingleChildScrollView(
                controller: widget.scrollController,
                padding: EdgeInsets.fromLTRB(sidePadding, 6, sidePadding - 2, 8),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: stackMaxWidth),
                    child: SelectionArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var index = 0; index < widget.messages.length; index++)
                            _V1ThreadPreviewMessageRow(
                              message: widget.messages[index],
                              gap: messageGap,
                              isLast: index == widget.messages.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _V1ThreadPreviewMessageRow extends StatelessWidget {
  const _V1ThreadPreviewMessageRow({required this.message, required this.gap, required this.isLast});

  final _V1ThreadPreviewMessage message;
  final double gap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: PbColors.borderFaint)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _V1ThreadPreviewAvatar(message: message),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _V1ThreadPreviewMessageHead(message: message),
                  if (message.text.isNotEmpty) Text(message.text, style: PowerboardsTypography.p),
                  if (message.attachments.isNotEmpty) ...[
                    SizedBox(height: message.text.isEmpty ? 0 : 12),
                    _V1ThreadPreviewAttachmentWrap(attachments: message.attachments),
                  ],
                  if (message.reactions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _V1ThreadPreviewReactionWrap(reactions: message.reactions),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _V1ThreadPreviewMessageHead extends StatelessWidget {
  const _V1ThreadPreviewMessageHead({required this.message});

  final _V1ThreadPreviewMessage message;

  @override
  Widget build(BuildContext context) {
    final timestamp = _v1ThreadPreviewTimestamp(context, message.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  message.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PowerboardsTypography.smallStrong.copyWith(color: PbColors.textPrimary),
                ),
                if (message.rolePillLabel != null) _V1ThreadPreviewRolePill(message: message),
              ],
            ),
          ),
          if (timestamp != null) ...[
            const SizedBox(width: 16),
            Text(
              timestamp,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PowerboardsTypography.small.copyWith(color: PbColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _V1ThreadPreviewRolePill extends StatelessWidget {
  const _V1ThreadPreviewRolePill({required this.message});

  final _V1ThreadPreviewMessage message;

  @override
  Widget build(BuildContext context) {
    final isAgent = message.isAgentLike;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAgent ? PbColors.customBadgeBg : PbColors.surfaceAccentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: isAgent ? PbColors.customBadgeBorder : PbColors.borderStateSelected),
      ),
      child: Text(
        message.rolePillLabel!,
        style: PowerboardsTypography.badge.copyWith(color: isAgent ? PbColors.customBadgeText : PbColors.surfaceRailActive),
      ),
    );
  }
}

class _V1ThreadPreviewAvatar extends StatelessWidget {
  const _V1ThreadPreviewAvatar({required this.message});

  final _V1ThreadPreviewMessage message;

  @override
  Widget build(BuildContext context) {
    if (!message.isAgentLike) {
      return PbAvatar(initials: message.initials, size: 40, textStyle: PowerboardsTypography.customAvatarInitials);
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [PbColors.surfacePanel, PbColors.surfacePanelSoft],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: PbColors.borderSoft),
      ),
      alignment: Alignment.center,
      child: Text(message.initials, style: PowerboardsTypography.customAvatarInitials.copyWith(color: PbColors.customBrandInk)),
    );
  }
}

class _V1ThreadPreviewAttachmentWrap extends StatelessWidget {
  const _V1ThreadPreviewAttachmentWrap({required this.attachments});

  final List<_V1ThreadPreviewAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final attachment in attachments)
          Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: PbColors.surfacePanelSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: PbColors.borderSoft),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(attachment.isImage ? Icons.image_outlined : Icons.attach_file, size: 16, color: PbColors.textMuted),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    attachment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PowerboardsTypography.smallStrong.copyWith(color: PbColors.textBody),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _V1ThreadPreviewReactionWrap extends StatelessWidget {
  const _V1ThreadPreviewReactionWrap({required this.reactions});

  final List<_V1ThreadPreviewReaction> reactions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final reaction in reactions)
          Tooltip(
            message: reaction.tooltip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: PbColors.surfacePanelSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: PbColors.borderSoft),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reaction.value,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1,
                      fontFamilyFallback: ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji'],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('${reaction.count}', style: PowerboardsTypography.smallStrong.copyWith(color: PbColors.textPrimary)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _V1ThreadPreviewMessage {
  const _V1ThreadPreviewMessage({
    required this.author,
    required this.role,
    required this.text,
    required this.createdAt,
    required this.reactions,
    required this.attachments,
  });

  final String author;
  final String role;
  final String text;
  final DateTime? createdAt;
  final List<_V1ThreadPreviewReaction> reactions;
  final List<_V1ThreadPreviewAttachment> attachments;

  bool get isAgentLike {
    final normalizedRole = role.trim().toLowerCase();
    final normalizedAuthor = author.trim().toLowerCase();
    return normalizedRole == 'agent' ||
        normalizedRole == 'assistant' ||
        normalizedRole == 'ai' ||
        normalizedAuthor.contains('assistant') ||
        normalizedAuthor.contains('agent');
  }

  bool get isUserLike {
    final normalizedRole = role.trim().toLowerCase();
    return normalizedRole == 'user' || normalizedRole == 'human' || normalizedRole == 'member';
  }

  String get initials {
    if (isAgentLike && author.trim().isEmpty) {
      return 'AI';
    }
    return _v1ThreadPreviewInitials(author.trim().isEmpty ? (isAgentLike ? 'Assistant' : 'User') : author);
  }

  String? get rolePillLabel {
    if (isAgentLike) {
      return 'Agent';
    }
    if (isUserLike) {
      return 'User';
    }
    return null;
  }
}

class _V1ThreadPreviewReaction {
  const _V1ThreadPreviewReaction({required this.value, required this.count, required this.tooltip});

  final String value;
  final int count;
  final String tooltip;
}

class _V1ThreadPreviewAttachment {
  const _V1ThreadPreviewAttachment({required this.title, required this.isImage});

  final String title;
  final bool isImage;
}

List<_V1ThreadPreviewMessage> _v1ThreadPreviewMessages(MeshDocument document) {
  final elements = _v1ThreadPreviewMessageElements(document);
  final messages = <_V1ThreadPreviewMessage>[];

  for (final element in elements) {
    final message = _v1ThreadPreviewMessageFromElement(element);
    if (message != null) {
      messages.add(message);
    }
  }

  return messages;
}

List<MeshElement> _v1ThreadPreviewMessageElements(MeshDocument document) {
  final rootChildren = document.root.getChildren().whereType<MeshElement>().toList(growable: false);
  for (final child in rootChildren) {
    if (child.tagName == 'messages') {
      return child.getChildren().whereType<MeshElement>().toList(growable: false);
    }
  }

  return rootChildren.where(_v1ThreadPreviewIsRenderableMessageElement).toList(growable: false);
}

bool _v1ThreadPreviewIsRenderableMessageElement(MeshElement element) {
  return switch (element.tagName) {
    'message' || 'reasoning' || 'exec' || 'event' => true,
    _ => false,
  };
}

_V1ThreadPreviewMessage? _v1ThreadPreviewMessageFromElement(MeshElement element) {
  if (!_v1ThreadPreviewIsRenderableMessageElement(element)) {
    return null;
  }

  final text = _v1ThreadPreviewText(element);
  final attachments = _v1ThreadPreviewAttachments(element);
  final reactions = _v1ThreadPreviewReactions(element);
  if (text.isEmpty && attachments.isEmpty && reactions.isEmpty) {
    return null;
  }

  final role = _v1AttributeString(element, 'role') ?? _v1AttributeString(element, 'author_role') ?? _v1ThreadPreviewRoleForTag(element);
  final author =
      _v1AttributeString(element, 'author_name') ??
      _v1AttributeString(element, 'author') ??
      _v1AttributeString(element, 'name') ??
      _v1ThreadPreviewAuthorForRole(role);

  return _V1ThreadPreviewMessage(
    author: author,
    role: role,
    text: text,
    createdAt: _v1ThreadPreviewDateTime(element),
    reactions: reactions,
    attachments: attachments,
  );
}

String _v1ThreadPreviewText(MeshElement element) {
  final candidate = switch (element.tagName) {
    'reasoning' => _v1AttributeString(element, 'summary'),
    'exec' =>
      _v1AttributeString(element, 'command') ??
          _v1AttributeString(element, 'result') ??
          _v1AttributeString(element, 'stdout') ??
          _v1AttributeString(element, 'stderr'),
    'event' =>
      _v1AttributeString(element, 'headline') ??
          _v1AttributeString(element, 'summary') ??
          _v1AttributeString(element, 'details') ??
          _v1AttributeString(element, 'method'),
    _ => _v1AttributeString(element, 'text') ?? _v1AttributeString(element, 'summary'),
  };

  return candidate?.trim() ?? '';
}

String _v1ThreadPreviewRoleForTag(MeshElement element) {
  return switch (element.tagName) {
    'reasoning' || 'exec' => 'agent',
    'event' => 'system',
    _ => '',
  };
}

String _v1ThreadPreviewAuthorForRole(String role) {
  final normalizedRole = role.trim().toLowerCase();
  if (normalizedRole == 'agent' || normalizedRole == 'assistant' || normalizedRole == 'ai') {
    return 'Assistant';
  }
  if (normalizedRole == 'system') {
    return 'System';
  }
  return 'User';
}

DateTime? _v1ThreadPreviewDateTime(MeshElement element) {
  final value =
      _v1AttributeString(element, 'created_at') ?? _v1AttributeString(element, 'createdAt') ?? _v1AttributeString(element, 'time');
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}

List<_V1ThreadPreviewAttachment> _v1ThreadPreviewAttachments(MeshElement element) {
  final attachments = <_V1ThreadPreviewAttachment>[];
  for (final child in element.getChildren().whereType<MeshElement>()) {
    if (child.tagName != 'file' && child.tagName != 'image') {
      continue;
    }

    final title =
        _v1AttributeString(child, 'title') ??
        _v1AttributeString(child, 'name') ??
        _v1AttributeString(child, 'path') ??
        _v1AttributeString(child, 'alt') ??
        (child.tagName == 'image' ? 'Image attachment' : 'File attachment');
    attachments.add(_V1ThreadPreviewAttachment(title: p.basename(title), isImage: child.tagName == 'image'));
  }

  return attachments;
}

List<_V1ThreadPreviewReaction> _v1ThreadPreviewReactions(MeshElement element) {
  final usersByValue = <String, Set<String>>{};
  for (final child in element.getChildren().whereType<MeshElement>()) {
    if (child.tagName != 'reaction') {
      continue;
    }

    final target = _v1AttributeString(child, 'target')?.trim().toLowerCase();
    final attachmentRef = _v1AttributeString(child, 'attachment_ref')?.trim();
    if (target == 'attachment' || (attachmentRef != null && attachmentRef.isNotEmpty)) {
      continue;
    }

    final value = _v1ThreadPreviewReactionValue(_v1AttributeString(child, 'value'));
    if (value == null) {
      continue;
    }

    final userName = _v1AttributeString(child, 'user_name')?.trim();
    usersByValue.putIfAbsent(value, () => <String>{}).add(userName == null || userName.isEmpty ? 'Someone' : userName);
  }

  final entries = usersByValue.entries.toList()..sort((left, right) => left.key.compareTo(right.key));
  return [
    for (final entry in entries) _V1ThreadPreviewReaction(value: entry.key, count: entry.value.length, tooltip: entry.value.join(', ')),
  ];
}

String? _v1ThreadPreviewReactionValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  return trimmed;
}

String? _v1ThreadPreviewTimestamp(BuildContext context, DateTime? createdAt) {
  if (createdAt == null) {
    return null;
  }

  final local = createdAt.toLocal();
  final now = DateTime.now();
  final elapsed = now.difference(local);
  if (!elapsed.isNegative) {
    if (elapsed.inSeconds < 60) {
      return 'now';
    }
    if (elapsed.inMinutes < 60) {
      return '${elapsed.inMinutes}m ago';
    }
    if (elapsed.inHours < 24) {
      return '${elapsed.inHours}h ago';
    }
  }

  final localizations = MaterialLocalizations.of(context);
  if (DateUtils.isSameDay(local, now)) {
    return localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local));
  }

  return localizations.formatShortDate(local);
}

String _v1ThreadPreviewInitials(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return 'U';
  }

  final base = normalized.contains('@') ? normalized.split('@').first : normalized;
  final parts = base.split(RegExp(r'[-._ ]+')).where((part) => part.isNotEmpty).toList(growable: false);
  if (parts.length >= 2) {
    return '${_v1SingleInitial(parts[0])}${_v1SingleInitial(parts[1])}';
  }
  if (parts.length == 1) {
    final first = _v1SingleInitial(parts.first);
    return first == 'A' && normalized.toLowerCase().contains('assistant') ? 'AI' : first;
  }

  return 'U';
}

class _V1StorageUrlPreview extends StatefulWidget {
  const _V1StorageUrlPreview({required this.room, required this.path, required this.file, required this.builder, this.downloadUrl});

  final RoomClient room;
  final String path;
  final PbAttachmentListItemData file;
  final Widget Function(Uri url) builder;
  final PowerboardsV1PreviewDownloadUrl? downloadUrl;

  @override
  State<_V1StorageUrlPreview> createState() => _V1StorageUrlPreviewState();
}

class _V1StorageUrlPreviewState extends State<_V1StorageUrlPreview> {
  late Future<String> _urlFuture = _loadUrl();

  Future<String> _loadUrl() {
    return (widget.downloadUrl ?? widget.room.storage.downloadUrl)(widget.path);
  }

  @override
  void didUpdateWidget(covariant _V1StorageUrlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room != widget.room || oldWidget.path != widget.path || oldWidget.downloadUrl != widget.downloadUrl) {
      _urlFuture = _loadUrl();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _v1UnavailablePreview(context, widget.file, null);
        }

        final url = snapshot.data;
        if (url == null) {
          return const Center(child: CircularProgressIndicator(color: PbColors.textSubtle));
        }

        return widget.builder(Uri.parse(url));
      },
    );
  }
}

class _V1TranscriptDocumentPreview extends StatelessWidget {
  const _V1TranscriptDocumentPreview({required this.room, required this.path, required this.file, required this.fullscreen});

  final RoomClient room;
  final String path;
  final PbAttachmentListItemData file;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    return DocumentConnectionScope(
      room: room,
      path: path,
      builder: (context, document, error) {
        if (document == null) {
          if (error != null) {
            return _v1UnavailablePreview(context, file, null);
          }

          return _v1PreviewLoadingStatus();
        }

        return ChangeNotifierBuilder(
          source: document,
          builder: (context) {
            final segments = document.root.getElementsByTagName('segment');
            return PbTranscriptPreviewContent(
              data: _v1TranscriptDataFromSegments(context, segments),
              fullscreen: fullscreen,
              emptyStateFile: file,
            );
          },
        );
      },
    );
  }
}

class _V1TextTranscriptPreview extends StatefulWidget {
  const _V1TextTranscriptPreview({
    required this.room,
    required this.path,
    required this.file,
    required this.title,
    required this.fullscreen,
    required this.loadText,
  });

  final RoomClient room;
  final String path;
  final PbAttachmentListItemData file;
  final String title;
  final bool fullscreen;
  final PowerboardsV1PreviewTextLoader loadText;

  @override
  State<_V1TextTranscriptPreview> createState() => _V1TextTranscriptPreviewState();
}

class _V1TextTranscriptPreviewState extends State<_V1TextTranscriptPreview> {
  late Future<String> _textFuture = _loadText();

  @override
  void didUpdateWidget(covariant _V1TextTranscriptPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.room != widget.room || oldWidget.path != widget.path || oldWidget.loadText != widget.loadText) {
      _textFuture = _loadText();
    }
  }

  Future<String> _loadText() {
    return widget.loadText(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _textFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _v1UnavailablePreview(context, widget.file, null);
        }

        final text = snapshot.data;
        if (text == null) {
          return _v1PreviewLoadingStatus();
        }

        return PbTranscriptPreviewContent(
          data: _v1TranscriptDataFromText(context, text, title: widget.title),
          fullscreen: widget.fullscreen,
          emptyStateFile: widget.file,
        );
      },
    );
  }
}

Widget _v1PreviewLoadingStatus() {
  return const ColoredBox(
    color: PbColors.surfacePanel,
    child: Center(child: CircularProgressIndicator(color: PbColors.textSubtle)),
  );
}

class _V1TranscriptMeta {
  const _V1TranscriptMeta({required this.startTime, required this.endTime, required this.participants});

  final DateTime? startTime;
  final DateTime? endTime;
  final List<PbTranscriptPreviewParticipant> participants;

  Duration? get duration {
    final start = startTime;
    final end = endTime;
    if (start == null || end == null) {
      return null;
    }

    return end.difference(start);
  }
}

PbTranscriptPreviewData _v1TranscriptDataFromSegments(BuildContext context, List<MeshElement> segments) {
  final meta = _v1TranscriptMetaFromSegments(segments);
  final turns = <PbTranscriptPreviewTurn>[];

  for (final segment in segments) {
    final text = _v1AttributeString(segment, 'text')?.trim();
    if (text == null || text.isEmpty) {
      continue;
    }

    final participant = _v1TranscriptParticipantForSegment(segment);
    final segmentTime = _v1TryParseSegmentTime(segment);
    final elapsed = segmentTime != null && meta.startTime != null ? segmentTime.difference(meta.startTime!) : Duration.zero;

    turns.add(
      PbTranscriptPreviewTurn(timestamp: _v1FormatTranscriptTimecode(elapsed), speaker: participant?.label ?? 'Speaker', text: text),
    );
  }

  return PbTranscriptPreviewData(
    dateLabel: _v1FormatTranscriptHeaderDate(context, meta.startTime) ?? 'Transcript',
    detailLabel: _v1FormatTranscriptDetail(context, meta),
    participants: meta.participants,
    turns: turns,
  );
}

_V1TranscriptMeta _v1TranscriptMetaFromSegments(List<MeshElement> segments) {
  DateTime? first;
  DateTime? last;
  final participantsByLabel = <String, PbTranscriptPreviewParticipant>{};

  for (final segment in segments) {
    final parsed = _v1TryParseSegmentTime(segment);
    if (parsed != null) {
      first ??= parsed;
      last = parsed;
    }

    final participant = _v1TranscriptParticipantForSegment(segment);
    if (participant != null) {
      participantsByLabel.putIfAbsent(participant.label, () => participant);
    }
  }

  return _V1TranscriptMeta(startTime: first, endTime: last, participants: participantsByLabel.values.toList(growable: false));
}

DateTime? _v1TryParseSegmentTime(MeshElement segment) {
  final value = _v1AttributeString(segment, 'time');
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}

PbTranscriptPreviewParticipant? _v1TranscriptParticipantForSegment(MeshElement segment) {
  final label = _v1AttributeString(segment, 'participant_name')?.trim();
  if (label == null || label.isEmpty) {
    return null;
  }

  final role = _v1AttributeString(segment, 'participant_role')?.trim().toLowerCase();
  return _v1TranscriptParticipant(label: label, role: role);
}

String? _v1AttributeString(MeshElement element, String name) {
  final value = element.getAttribute(name);
  return value is String ? value : null;
}

PbTranscriptPreviewData _v1TranscriptDataFromText(BuildContext context, String text, {required String title}) {
  final cues = _v1ParseCaptionCues(text);
  final participantsByLabel = <String, PbTranscriptPreviewParticipant>{};
  final turns = <PbTranscriptPreviewTurn>[];

  Duration? lastCueStart;
  for (final cue in cues) {
    final speaker = cue.speaker ?? 'Transcript';
    participantsByLabel.putIfAbsent(speaker, () => _v1TranscriptParticipant(label: speaker));
    lastCueStart = cue.start ?? lastCueStart;
    turns.add(
      PbTranscriptPreviewTurn(timestamp: _v1FormatTranscriptTimecode(cue.start ?? Duration.zero), speaker: speaker, text: cue.text),
    );
  }

  final duration = lastCueStart == null ? null : lastCueStart + const Duration(seconds: 1);
  final detailParts = <String>['Transcript'];
  final durationLabel = _v1FormatTranscriptDuration(duration);
  if (durationLabel != null) {
    detailParts.add(durationLabel);
  }

  return PbTranscriptPreviewData(
    dateLabel: title.trim().isEmpty ? 'Transcript' : title.trim(),
    detailLabel: detailParts.join('   '),
    participants: participantsByLabel.values.toList(growable: false),
    turns: turns,
  );
}

class _V1CaptionCue {
  const _V1CaptionCue({required this.start, required this.speaker, required this.text});

  final Duration? start;
  final String? speaker;
  final String text;
}

List<_V1CaptionCue> _v1ParseCaptionCues(String text) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final blocks = normalized.split(RegExp(r'\n\s*\n'));
  final cues = <_V1CaptionCue>[];

  for (final block in blocks) {
    final lines = block
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty && line.trim() != 'WEBVTT')
        .toList(growable: false);
    final timeLineIndex = lines.indexWhere((line) => line.contains('-->'));
    if (timeLineIndex < 0 || timeLineIndex == lines.length - 1) {
      continue;
    }

    final start = _v1ParseCueTimestamp(lines[timeLineIndex].split('-->').first.trim());
    final rawCueText = lines.skip(timeLineIndex + 1).join('\n').trim();
    final cueText = rawCueText.replaceAll(RegExp(r'<[^>]+>'), '').trim();
    if (cueText.isEmpty) {
      continue;
    }

    final parsed = _v1ExtractCaptionSpeaker(cueText);
    cues.add(_V1CaptionCue(start: start, speaker: parsed.$1, text: parsed.$2));
  }

  if (cues.isNotEmpty) {
    return cues;
  }

  final fallbackText = normalized.trim();
  return fallbackText.isEmpty
      ? const <_V1CaptionCue>[]
      : <_V1CaptionCue>[_V1CaptionCue(start: Duration.zero, speaker: null, text: fallbackText)];
}

Duration? _v1ParseCueTimestamp(String value) {
  final timestamp = value.split(RegExp(r'\s+')).first.replaceAll(',', '.');
  final parts = timestamp.split(':');
  if (parts.length < 2 || parts.length > 3) {
    return null;
  }

  final hours = parts.length == 3 ? int.tryParse(parts[0]) : 0;
  final minutes = int.tryParse(parts[parts.length - 2]);
  final seconds = double.tryParse(parts.last);
  if (hours == null || minutes == null || seconds == null) {
    return null;
  }

  return Duration(hours: hours, minutes: minutes, milliseconds: (seconds * 1000).round());
}

(String?, String) _v1ExtractCaptionSpeaker(String cueText) {
  final lines = cueText.split('\n');
  if (lines.isEmpty) {
    return (null, cueText);
  }

  final match = RegExp(r'^([^:\n]{1,80}):\s*(.*)$').firstMatch(lines.first.trim());
  if (match == null) {
    return (null, cueText);
  }

  final speaker = match.group(1)?.trim();
  final firstText = match.group(2)?.trim();
  final remainingLines = <String>[if (firstText != null && firstText.isNotEmpty) firstText, ...lines.skip(1)];
  final text = remainingLines.join('\n').trim();
  return (speaker == null || speaker.isEmpty ? null : speaker, text.isEmpty ? cueText : text);
}

PbTranscriptPreviewParticipant _v1TranscriptParticipant({required String label, String? role}) {
  final normalizedRole = role?.trim().toLowerCase();
  final normalizedLabel = label.trim().toLowerCase();
  final isAgentLike =
      normalizedRole == 'agent' ||
      normalizedRole == 'assistant' ||
      normalizedLabel.contains('assistant') ||
      normalizedLabel.contains('agent');

  return PbTranscriptPreviewParticipant(label: label, initials: _v1TranscriptInitials(label), isAgentLike: isAgentLike);
}

String _v1TranscriptInitials(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return 'U';
  }

  final base = normalized.contains('@') ? normalized.split('@').first : normalized;
  final parts = base.split(RegExp(r'[-._ ]+')).where((part) => part.isNotEmpty).toList(growable: false);
  if (parts.length >= 2) {
    return '${_v1SingleInitial(parts[0])}${_v1SingleInitial(parts[1])}';
  }
  if (parts.length == 1) {
    return _v1SingleInitial(parts.first);
  }

  return 'U';
}

String _v1SingleInitial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'U';
  }

  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

String _v1FormatTranscriptTimecode(Duration elapsed) {
  final totalSeconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  String twoDigits(int value) => value.toString().padLeft(2, '0');

  return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
}

String? _v1FormatTranscriptHeaderDate(BuildContext context, DateTime? startTime) {
  if (startTime == null) {
    return null;
  }

  final local = startTime.toLocal();
  final month = MaterialLocalizations.of(context).formatMonthYear(local).split(' ').first;
  return '$month ${local.day}, ${local.year}';
}

String _v1FormatTranscriptDetail(BuildContext context, _V1TranscriptMeta meta) {
  final detailParts = <String>['Transcript'];
  final time = _v1FormatTranscriptHeaderTime(context, meta.startTime);
  final duration = _v1FormatTranscriptDuration(meta.duration);

  if (time != null && duration != null) {
    detailParts.add('$time - $duration');
  } else if (time != null) {
    detailParts.add(time);
  } else if (duration != null) {
    detailParts.add(duration);
  }

  return detailParts.join('   ');
}

String? _v1FormatTranscriptHeaderTime(BuildContext context, DateTime? startTime) {
  if (startTime == null) {
    return null;
  }

  final local = startTime.toLocal();
  final formatted = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: false);
  return formatted.replaceAll(' AM', 'a').replaceAll(' PM', 'p');
}

String? _v1FormatTranscriptDuration(Duration? duration) {
  if (duration == null) {
    return null;
  }

  final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  if (totalSeconds < 60) {
    return totalSeconds == 1 ? '1 sec' : '$totalSeconds secs';
  }

  final totalMinutes = duration.inMinutes;
  if (totalMinutes < 60) {
    return totalMinutes == 1 ? '1 min' : '$totalMinutes mins';
  }

  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) {
    return hours == 1 ? '1 hr' : '$hours hrs';
  }

  final hoursLabel = hours == 1 ? '1 hr' : '$hours hrs';
  final minutesLabel = minutes == 1 ? '1 min' : '$minutes mins';
  return '$hoursLabel $minutesLabel';
}
