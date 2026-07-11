import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:path/path.dart' as path;
import 'package:powerboards/meshagent/desktop_chat_attach_button.dart';
import 'package:powerboards/meshagent/folder_chat_context.dart';
import 'package:powerboards/meshagent/install_agent.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/powerboards_ui/v1/components/chat/pb_comment_box.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_menu_anchor.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_menu_card.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_menu_divider.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_menu_list.dart';
import 'package:powerboards/powerboards_ui/v1/components/menus/pb_menu_option.dart';
import 'package:powerboards/powerboards_ui/v1/components/primitives/pb_svg_icon.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_colors.dart';
import 'package:powerboards/powerboards_ui/v1/theme/pb_typography.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PowerboardsV1ThreadComposer extends StatefulWidget {
  const PowerboardsV1ThreadComposer({
    super.key,
    required this.projectId,
    required this.room,
    required this.agentName,
    required this.config,
    required this.defaultInput,
  });

  final String projectId;
  final RoomClient room;
  final String? agentName;
  final ChatThreadInputConfig config;
  final Widget defaultInput;

  @override
  State<PowerboardsV1ThreadComposer> createState() => _PowerboardsV1ThreadComposerState();
}

class _PowerboardsV1ThreadComposerState extends State<PowerboardsV1ThreadComposer> {
  late final FocusNode _focusNode = FocusNode(onKeyEvent: _onKeyEvent);
  bool _sending = false;

  String get _displayAgentName {
    final normalizedAgentName = widget.agentName?.trim();
    if (normalizedAgentName == null || normalizedAgentName.isEmpty) {
      return 'Assistant';
    }
    return normalizedAgentName[0].toUpperCase() + normalizedAgentName.substring(1);
  }

  String get _placeholderText {
    return 'Ask $_displayAgentName...';
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
      unawaited(_handleSend());
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      widget.config.onInterrupt?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<RoomClient> _connectRoomClient(String roomName) async {
    final client = getMeshagentClient();
    final connection = await client.connectRoom(projectId: widget.projectId, roomName: roomName);
    final roomClient = RoomClient(
      protocolFactory: WebSocketClientProtocol.createFactory(url: connection.roomUrl, token: connection.jwt),
    );
    await roomClient.start();
    await roomClient.ready;
    return roomClient;
  }

  Future<void> _handleSend() async {
    if (_sending || !widget.config.sendEnabled) {
      return;
    }

    final controller = widget.config.controller;
    final text = controller.text;
    final attachments = controller.attachmentUploads;
    if (text.trim().isEmpty && attachments.isEmpty) {
      return;
    }

    setState(() => _sending = true);
    final sendFuture = widget.config.onSend(text, attachments);
    controller.clear();
    _focusNode.requestFocus();
    try {
      await sendFuture;
    } on ChatSendCancelledException {
      if (controller.textFieldController.text.isEmpty && controller.attachmentUploads.isEmpty) {
        controller.textFieldController.text = text;
        for (final attachment in attachments) {
          if (attachment.status == UploadStatus.completed) {
            controller.attachFile(attachment.path, mimeType: attachment.mimeType, displayName: attachment.displayName);
          }
        }
      }
      _focusNode.requestFocus();
    } catch (error) {
      if (mounted) {
        if (controller.textFieldController.text.isEmpty && controller.attachmentUploads.isEmpty) {
          controller.textFieldController.text = text;
          for (final attachment in attachments) {
            if (attachment.status == UploadStatus.completed) {
              controller.attachFile(attachment.path, mimeType: attachment.mimeType, displayName: attachment.displayName);
            }
          }
        }
        ShadToaster.of(context).show(ShadToast.destructive(title: const Text('Unable to send message'), description: Text('$error')));
      }
      _focusNode.requestFocus();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.config.audioInputEnabled || widget.config.automaticAudioTurnDetection) {
      return widget.defaultInput;
    }

    return AnimatedBuilder(
      animation: widget.config.controller,
      builder: (context, _) {
        final attachments = widget.config.controller.attachmentUploads;
        final allAttachmentsCompleted =
            attachments.isEmpty || attachments.every((attachment) => attachment.status == UploadStatus.completed);
        final canSend =
            !_sending &&
            widget.config.sendEnabled &&
            allAttachmentsCompleted &&
            (widget.config.controller.text.trim().isNotEmpty || attachments.isNotEmpty);
        final sendPending = _sending || (!widget.config.sendEnabled && widget.config.onCancelSend != null);
        final showMcpConnectors = _showMcpConnectors();

        return PbCommentBoxShell(
          child: PbCommentBox(
            controller: widget.config.controller.textFieldController,
            focusNode: _focusNode,
            placeholder: _placeholderText,
            attachmentChips: <Widget>[for (final attachment in attachments) _buildAttachmentChip(attachment)],
            leadingControls: <Widget>[
              PowerboardsDesktopChatAttachButton(
                alwaysShowAttachFiles: true,
                controller: widget.config.controller,
                availableRooms: () => listMeshagentRooms(widget.projectId),
                connectRoomClient: _connectRoomClient,
                agentName: widget.agentName?.trim(),
                showMcpConnectors: false,
                showMcpMenuItem: false,
                useV1Menu: true,
                triggerBuilder: (context, onPressed) => PbComposerIconButton(
                  tooltip: 'Attach files',
                  onPressed: onPressed,
                  child: const PbSvgIcon(assetName: 'plus', size: 18, color: PbColors.customBrandInk),
                ),
              ),
              if (showMcpConnectors) const SizedBox(width: 10),
              if (showMcpConnectors)
                _PowerboardsV1McpControl(
                  controller: widget.config.controller,
                  room: widget.room,
                  projectId: widget.projectId,
                  agentName: widget.agentName?.trim(),
                ),
            ],
            trailingControl: sendPending ? const _PendingSendButton() : PbComposerSendButton(active: canSend, onPressed: _handleSend),
            onChanged: (value) => widget.config.onChanged?.call(value, widget.config.controller.attachmentUploads),
          ),
        );
      },
    );
  }

  bool _showMcpConnectors() {
    final normalizedAgentName = widget.agentName?.trim();
    if (normalizedAgentName == null || normalizedAgentName.isEmpty) {
      return widget.config.controller.selectedMcpConnectors.isNotEmpty;
    }
    final agent = widget.room.messaging.remoteParticipants.firstWhereOrNull(
      (participant) => participant.getAttribute('name') == normalizedAgentName,
    );
    final oauth2CallbackUrl = MeshagentConfig.current?.oauth2CallbackUrl;
    return widget.config.controller.selectedMcpConnectors.isNotEmpty ||
        (widget.config.snapshot.agentOnline && widget.config.snapshot.supportsMcp && agent != null && oauth2CallbackUrl != null);
  }

  Widget _buildAttachmentChip(FileAttachment attachment) {
    final title = _attachmentDisplayName(attachment);
    final folderContext = powerboardsFolderChatContextFromDataUrl(attachment.path);
    final metadata = PbResolvedAttachmentMetadata.resolve(
      title: title,
      explicitFileType: folderContext == null ? null : PbAttachmentFileType.folder,
    );
    return PbComposerAttachmentChip(
      title: title,
      iconAssetName: metadata.iconAssetName,
      iconColor: metadata.iconColor,
      onPressed: attachment.status == UploadStatus.completed && widget.config.onAttachmentOpen != null
          ? () => widget.config.onAttachmentOpen!(attachment)
          : null,
      onRemove: () {
        widget.config.controller.removeFileUpload(attachment);
        widget.config.onAttachmentRemoved?.call(attachment);
      },
      trailing: switch (attachment.status) {
        UploadStatus.uploading => const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: PbColors.customBlue),
        ),
        UploadStatus.failed => const PbSvgIcon(assetName: 'circle-minus-alert', size: 16, color: PbColors.customAlert),
        _ => null,
      },
    );
  }

  String _attachmentDisplayName(FileAttachment attachment) {
    final folderContext = powerboardsFolderChatContextFromDataUrl(attachment.path);
    if (folderContext != null) {
      return folderContext.displayName;
    }

    final explicit = attachment.displayName?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    if (attachment.path.startsWith('data:')) {
      return 'Inline attachment';
    }
    final basename = path.basename(attachment.path.trim());
    return basename.isEmpty ? attachment.path.trim() : basename;
  }
}

class _PowerboardsV1McpControl extends StatefulWidget {
  const _PowerboardsV1McpControl({required this.controller, required this.room, required this.projectId, required this.agentName});

  final ChatThreadController controller;
  final RoomClient room;
  final String projectId;
  final String? agentName;

  @override
  State<_PowerboardsV1McpControl> createState() => _PowerboardsV1McpControlState();
}

class _PowerboardsV1McpControlState extends State<_PowerboardsV1McpControl> {
  bool _open = false;
  bool _loading = false;
  Object? _loadError;
  String? _connectingConnectorName;
  List<Connector> _availableConnectors = const <Connector>[];
  final Map<String, bool> _connectedConnectors = <String, bool>{};

  String _connectorKey(Connector connector) {
    return jsonEncode(<String, Object?>{
      'name': connector.name,
      'server': connector.server.toJson(),
      if (connector.oauth != null) 'oauth': connector.oauth!.toJson(),
    });
  }

  Future<void> _refresh({bool force = false}) async {
    if (_loading || !mounted) {
      return;
    }
    if (!force && _availableConnectors.isNotEmpty) {
      return;
    }
    final normalizedAgentName = widget.agentName?.trim();
    if (normalizedAgentName == null || normalizedAgentName.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final connectors = mcpConnectorsFromRoomServices(
        services: (await widget.room.services.list()).services,
        agentName: normalizedAgentName,
      );
      final statuses = <String, bool>{};
      for (final connector in connectors) {
        try {
          statuses[_connectorKey(connector)] = await connector.isConnected(widget.room, normalizedAgentName);
        } catch (_) {
          statuses[_connectorKey(connector)] = false;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _availableConnectors = connectors;
        _connectedConnectors
          ..clear()
          ..addAll(statuses);
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleConnectorSelection(Connector connector) async {
    if (widget.controller.isMcpConnectorSelected(connector)) {
      widget.controller.setMcpConnectorSelected(connector, false);
      return;
    }

    final connectorKey = _connectorKey(connector);
    final isConnected = _connectedConnectors[connectorKey] == true;
    final connectorRef = Connector.buildConnectorRef(server: connector.server, oauth: connector.oauth);
    final requiresSetup = connectorRef != null || connector.oauth != null;
    if (isConnected || !requiresSetup) {
      if (!widget.controller.isToolkitEnabled('mcp')) {
        widget.controller.toggleToolkit('mcp');
      }
      widget.controller.setMcpConnectorSelected(connector, true);
      return;
    }

    final normalizedAgentName = widget.agentName?.trim();
    final oauth2CallbackUrl = MeshagentConfig.current?.oauth2CallbackUrl;
    final agent = normalizedAgentName == null
        ? null
        : widget.room.messaging.remoteParticipants.firstWhereOrNull(
            (participant) => participant.getAttribute('name') == normalizedAgentName,
          );
    if (normalizedAgentName == null || oauth2CallbackUrl == null || agent == null) {
      return;
    }

    setState(() => _connectingConnectorName = connector.name);
    try {
      await connector.authenticate(widget.room, agent, oauth2CallbackUrl);
      if (!widget.controller.isToolkitEnabled('mcp')) {
        widget.controller.toggleToolkit('mcp');
      }
      widget.controller.setMcpConnectorSelected(connector, true);
      await _refresh(force: true);
    } catch (error) {
      if (mounted) {
        ShadToaster.of(
          context,
        ).show(ShadToast.destructive(title: Text('Unable to connect ${connector.name}'), description: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _connectingConnectorName = null);
      }
    }
  }

  Future<void> _addConnector() async {
    await showShadDialog<bool?>(
      context: context,
      builder: (context) => InstallServiceDialog(
        type: ServiceType.mcp,
        projectId: widget.projectId,
        roomName: widget.room.roomName,
        onInstalled: (ctx, projectId, roomName, serviceId) {
          Navigator.of(ctx).pop(true);
        },
      ),
    );
    await _refresh(force: true);
  }

  void _setOpen(bool open) {
    if (_open == open) {
      return;
    }
    setState(() => _open = open);
    if (open) {
      unawaited(_refresh(force: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedConnectors = widget.controller.selectedMcpConnectors;
    final canAddMcpServices = widget.room.apiGrant?.admin != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PbMenuAnchor(
          placement: PbMenuAnchorPlacement.bottomLeft,
          gap: 10,
          preferAboveWhenOverflow: true,
          onDismiss: () => _setOpen(false),
          panel: _open
              ? PbMenuCard(
                  width: 280,
                  child: PbMenuList(
                    children: <Widget>[
                      if (_loading && _availableConnectors.isEmpty)
                        const _McpInfoCard(text: 'Loading connectors...')
                      else if (_loadError != null)
                        PbMenuOption(
                          title: 'Unable to load connectors',
                          leadingIconAssetName: 'rotate-ccw',
                          singleLine: true,
                          onPressed: () => _refresh(force: true),
                        )
                      else if (_availableConnectors.isEmpty)
                        const _McpInfoCard(text: 'No connectors are configured for this room')
                      else
                        for (final connector in _availableConnectors) _buildConnectorOption(connector),
                      if (canAddMcpServices) ...<Widget>[
                        const PbMenuDivider(),
                        PbMenuOption(
                          title: 'Add...',
                          leadingIconAssetName: 'plus',
                          singleLine: true,
                          onPressed: () {
                            _setOpen(false);
                            unawaited(_addConnector());
                          },
                        ),
                      ],
                    ],
                  ),
                )
              : null,
          child: PbComposerMenuButton(
            label: 'MCP',
            iconAssetName: 'plug',
            open: _open,
            tooltip: 'Choose MCP',
            onPressed: () => _setOpen(!_open),
          ),
        ),
        for (final connector in selectedConnectors) ...<Widget>[
          const SizedBox(width: 8),
          PbComposerMcpPill(label: connector.name, onRemove: () => widget.controller.setMcpConnectorSelected(connector, false)),
        ],
      ],
    );
  }

  Widget _buildConnectorOption(Connector connector) {
    final selected = widget.controller.isMcpConnectorSelected(connector);
    final isConnecting = _connectingConnectorName == connector.name;
    final isConnected = _connectedConnectors[_connectorKey(connector)] == true;
    final connectorRef = Connector.buildConnectorRef(server: connector.server, oauth: connector.oauth);
    final requiresSetup = connectorRef != null || connector.oauth != null;

    return PbMenuOption(
      title: connector.name,
      subtitle: isConnecting
          ? 'Connecting...'
          : selected
          ? 'Selected'
          : isConnected || !requiresSetup
          ? 'Connected'
          : 'Connect',
      leadingIconAssetName: 'plug',
      trailingIconAssetName: selected || isConnected ? 'circle-check-big' : null,
      onPressed: isConnecting ? null : () => unawaited(_toggleConnectorSelection(connector)),
    );
  }
}

class _PendingSendButton extends StatelessWidget {
  const _PendingSendButton();

  @override
  Widget build(BuildContext context) {
    return PbComposerActionSurface(
      tooltip: 'Sending',
      width: 42,
      minHeight: 36,
      padding: EdgeInsets.zero,
      active: true,
      primary: true,
      child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: PbColors.textInverse)),
    );
  }
}

class _McpInfoCard extends StatelessWidget {
  const _McpInfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(color: PbColors.surfaceAccentSoft, borderRadius: BorderRadius.circular(10)),
      child: Text(text, softWrap: true, style: PowerboardsTypography.textXSmall),
    );
  }
}
