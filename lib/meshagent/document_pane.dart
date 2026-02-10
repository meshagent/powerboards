import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:meshagent/schema.dart';
import 'package:meshagent_flutter/document_connection_scope.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:meshagent_flutter_shadcn/forms/form.dart';
import 'package:meshagent_flutter_shadcn/viewers/builder.dart';
import 'package:meshagent_flutter_shadcn/viewers/document.dart';
import 'package:meshagent_flutter_shadcn/viewers/gallery.dart';
import 'package:meshagent_flutter_shadcn/viewers/presentation.dart';
import 'package:meshagent_flutter_shadcn/viewers/transcript.dart';
import 'package:meshagent_flutter_widgets/widgets.dart';
import 'package:path/path.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentPane extends StatefulWidget {
  const DocumentPane({super.key, required this.path, required this.room});

  final String path;
  final RoomClient room;

  @override
  State createState() => _DocumentPane();
}

class _DocumentPane extends State<DocumentPane> {
  late final Signal<String> _extSig = Signal(_ext(widget.path));
  late final _schema = Resource<MeshSchema?>(() async {
    final ext = _extSig.value;
    if (ext.isEmpty) return null;

    try {
      final s = await widget.room.storage.download(".schemas/$ext.json");
      return MeshSchema.fromJson(jsonDecode(utf8.decode(s.data)));
    } catch (e) {
      debugPrint("Failed to load schema for $ext: $e");
      return null;
    }
  }, source: _extSig);

  @override
  void dispose() {
    _schema.dispose();
    _extSig.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DocumentPane oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newExt = _ext(widget.path);
    if (newExt != _extSig.value) {
      _extSig.value = newExt;
    }
  }

  String _ext(String path) {
    final base = basename(path);
    if (base.isEmpty) return "";
    return base.split(".").last.toLowerCase();
  }

  Widget _loading() {
    return Center(child: CircularProgressIndicator());
  }

  Widget _noPreview(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "No preview available",
            style: TextStyle(color: ShadTheme.of(context).colorScheme.accentForeground, fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 15),
          Tooltip(
            message: "Download",
            child: ShadButton.outline(leading: const Icon(LucideIcons.download), onPressed: _download, child: Text("Download")),
          ),
        ],
      ),
    );
  }

  Future<void> _download() async {
    final url = await widget.room.storage.downloadUrl(widget.path);
    launchUrl(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, _) {
        final schemaState = _schema.state;

        if (!schemaState.isReady || schemaState.isRefreshing) {
          return _loading();
        }

        if (schemaState.hasError || schemaState.value == null) {
          return _noPreview(context);
        }

        final ext = _ext(widget.path);

        return DocumentConnectionScope(
          key: ValueKey(widget.path),
          room: widget.room,
          path: widget.path,
          schema: schemaState.value,
          builder: (context, document, error) => document == null
              ? error == null
                    ? _loading()
                    : _noPreview(context)
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
                                      if (element == null) {
                                        return Container();
                                      }
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
                                _ => _noPreview(context),
                              },
                            )
                          : SizedBox.shrink(),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
