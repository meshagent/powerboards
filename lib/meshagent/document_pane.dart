import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:meshagent_flutter/document_connection_scope.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/file_preview/code.dart';
import 'package:meshagent_flutter_shadcn/forms/form.dart';
import 'package:meshagent_flutter_shadcn/viewers/builder.dart';
import 'package:meshagent_flutter_shadcn/viewers/document.dart';
import 'package:meshagent_flutter_shadcn/viewers/gallery.dart';
import 'package:meshagent_flutter_shadcn/viewers/presentation.dart';
import 'package:meshagent_flutter_shadcn/viewers/transcript.dart';
import 'package:meshagent_flutter_widgets/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:powerboards/ui/app_context_menu.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

const Set<String> meshagentExtensions = {"thread", "transcript", "widget", "document", "gallery", "presentation", "form"};

enum _ViewerOverride { none, text, meshagent }

class DocumentPane extends StatefulWidget {
  const DocumentPane({super.key, required this.path, required this.room});

  final String path;
  final RoomClient room;

  @override
  State createState() => _DocumentPane();
}

class _DocumentPane extends State<DocumentPane> {
  _ViewerOverride _override = _ViewerOverride.none;
  int _reload = 0;

  @override
  void didUpdateWidget(covariant DocumentPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _override = _ViewerOverride.none;
      _reload = 0;
    }
  }

  void _setOverride(_ViewerOverride value) {
    setState(() {
      _override = value;
      _reload++;
    });
  }

  String _ext(String path) {
    final base = p.basename(path);
    if (base.isEmpty) return "";
    return base.split(".").last.toLowerCase();
  }

  Widget _loading() {
    return Center(child: CircularProgressIndicator());
  }

  Widget _codePreview() {
    return FutureBuilder<String>(
      future: widget.room.storage.downloadUrl(widget.path),
      builder: (context, snap) {
        if (snap.hasError) {
          return _noPreview(subtitle: "Failed to load download URL.");
        }
        if (!snap.hasData) return _loading();

        return CodePreview(room: widget.room, filename: widget.path, url: Uri.parse(snap.data!), readOnly: false);
      },
    );
  }

  Widget _meshagentPreview() {
    final ext = _ext(widget.path);

    return DocumentConnectionScope(
      key: ValueKey('${widget.path}:$_reload'),
      room: widget.room,
      path: widget.path,
      builder: (context, document, error) => document == null
          ? error == null
                ? _loading()
                : _noPreview(subtitle: "Failed to connect with Meshagent. Retrying document connection…")
          : ChangeNotifierBuilder(
              source: document,
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  (document.root.getChildren().isNotEmpty)
                      ? Expanded(
                          child: switch (ext) {
                            "document" => SingleChildScrollView(
                              child: DocumentViewer(client: widget.room, document: document),
                            ),
                            "thread" => ChatThread(
                              path: widget.path,
                              document: document,
                              room: widget.room,
                              toolsBuilder: (context, controller, _) => ChatThreadAttachButton(controller: controller),
                            ),
                            "gallery" => GalleryViewer(client: widget.room, document: document),
                            "presentation" => SingleChildScrollView(
                              child: PresentationViewer(client: widget.room, document: document),
                            ),
                            "transcript" => TranscriptViewer(document: document),
                            "widget" => SingleChildScrollView(
                              child: Builder(
                                builder: (context) {
                                  final element = document.root.getElementsByTagName("widgets").firstOrNull;
                                  if (element == null) return Container();
                                  return Center(
                                    child: EditMode(
                                      editing: false,
                                      child: MeshWidgetRoot(element: element, room: widget.room),
                                    ),
                                  );
                                },
                              ),
                            ),
                            "form" => SingleChildScrollView(
                              child: FormDocumentViewer(client: widget.room, document: document),
                            ),
                            _ => _noPreview(subtitle: "Connected with Meshagent, but no renderer for .$ext."),
                          },
                        )
                      : const SizedBox.shrink(),
                ],
              ),
            ),
    );
  }

  Widget _noPreview({String? subtitle}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "No preview available",
            style: TextStyle(color: ShadTheme.of(context).colorScheme.accentForeground, fontSize: 18, fontWeight: FontWeight.w500),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: ShadTheme.of(context).colorScheme.mutedForeground),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Tooltip(
                message: "Download",
                child: ShadButton.outline(leading: const Icon(LucideIcons.download), onPressed: _download, child: const Text("Download")),
              ),
              const SizedBox(width: 8),
              _openWithMenuButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _openWithMenuButton() {
    return AppContextMenuButton(
      entries: _openWithEntries(),
      childBuilder: (context, controller) {
        return Tooltip(
          message: "Open with…",
          child: ShadButton.outline(
            leading: const Icon(LucideIcons.externalLink),
            trailing: const Icon(LucideIcons.chevronDown),
            onPressed: () {
              if (!controller.isOpen) controller.show();
            },
            child: const Text("Open with…"),
          ),
        );
      },
    );
  }

  List<AppMenuEntry> _openWithEntries() {
    return [
      AppMenuEntry(
        title: "Text editor",
        description: "Open as plain text.",
        icon: LucideIcons.fileText,
        onPressed: () => _setOverride(_ViewerOverride.text),
      ),
      AppMenuEntry(
        title: "Meshagent viewer",
        description: "Open as Meshagent document.",
        icon: LucideIcons.file,
        onPressed: () => _setOverride(_ViewerOverride.meshagent),
      ),
      AppMenuEntry(
        title: "Copy link",
        description: "Copy the download URL to clipboard.",
        icon: LucideIcons.copy,
        onPressed: () => _copyDownloadUrl(),
      ),
    ];
  }

  Future<void> _copyDownloadUrl() async {
    try {
      final url = await widget.room.storage.downloadUrl(widget.path);
      await Clipboard.setData(ClipboardData(text: url));

      if (!mounted) return;
      ShadToaster.of(context).show(const ShadToast(title: Text("Download link copied to clipboard")));
    } catch (e) {
      if (!mounted) return;
      ShadToaster.of(context).show(const ShadToast(title: Text("Failed to copy download link")));
    }
  }

  Future<void> _download() async {
    final url = await widget.room.storage.downloadUrl(widget.path);
    launchUrl(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    switch (_override) {
      case _ViewerOverride.text:
        return _codePreview();
      case _ViewerOverride.meshagent:
        return _meshagentPreview();
      case _ViewerOverride.none:
        final ext = _ext(widget.path);
        if (meshagentExtensions.contains(ext)) {
          return _meshagentPreview();
        }
        return _noPreview();
    }
  }
}
