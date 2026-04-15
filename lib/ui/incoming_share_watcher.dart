import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_auth/meshagent_flutter_auth.dart';
import 'package:meshagent_flutter_shadcn/storage/file_browser.dart';
import 'package:powerboards/meshagent/file_upload.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/settings/selected_room.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const _incomingShareRetryDelay = Duration(seconds: 2);

bool get supportsIncomingShare {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => false,
  };
}

class IncomingShareWatcher extends StatefulWidget {
  const IncomingShareWatcher({super.key, required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<IncomingShareWatcher> createState() => _IncomingShareWatcherState();
}

class _IncomingShareWatcherState extends State<IncomingShareWatcher> {
  final List<SharedMediaFile> _pendingShares = <SharedMediaFile>[];
  final Set<String> _queuedShareKeys = <String>{};

  StreamSubscription<List<SharedMediaFile>>? _shareSubscription;
  Timer? _retryTimer;
  bool _isProcessing = false;
  bool _didLoadInitialMedia = false;
  bool _hasWarnedAboutDestination = false;

  @override
  void initState() {
    super.initState();

    if (!supportsIncomingShare) {
      return;
    }

    _shareSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      _onSharedMediaReceived,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Failed to receive shared media: $error\n$stackTrace');
      },
    );

    unawaited(_loadInitialMedia());
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _shareSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialMedia() async {
    if (_didLoadInitialMedia) {
      return;
    }
    _didLoadInitialMedia = true;

    try {
      _onSharedMediaReceived(await ReceiveSharingIntent.instance.getInitialMedia());
    } catch (error, stackTrace) {
      debugPrint('Failed to load initial shared media: $error\n$stackTrace');
    }
  }

  void _onSharedMediaReceived(List<SharedMediaFile> media) {
    final supported = media.where(_isSupportedShare).toList(growable: false);
    final unsupportedCount = media.length - supported.length;

    if (unsupportedCount > 0) {
      _showToast(
        const Text('Unsupported shared content'),
        description: const Text('Powerboards currently supports sharing files and images only.'),
        destructive: true,
      );
    }

    if (supported.isEmpty) {
      unawaited(ReceiveSharingIntent.instance.reset());
      return;
    }

    var added = false;
    for (final item in supported) {
      final key = _shareKey(item);
      if (_queuedShareKeys.add(key)) {
        _pendingShares.add(item);
        added = true;
      }
    }

    unawaited(ReceiveSharingIntent.instance.reset());

    if (added) {
      _scheduleProcessing(immediate: true);
    }
  }

  bool _isSupportedShare(SharedMediaFile item) {
    return switch (item.type) {
      SharedMediaType.image || SharedMediaType.file || SharedMediaType.video => item.path.trim().isNotEmpty,
      SharedMediaType.text || SharedMediaType.url => false,
    };
  }

  String _shareKey(SharedMediaFile item) => '${item.type.value}:${item.path}:${item.mimeType ?? ''}';

  void _scheduleProcessing({required bool immediate}) {
    _retryTimer?.cancel();
    _retryTimer = Timer(immediate ? Duration.zero : _incomingShareRetryDelay, () {
      if (!mounted) {
        return;
      }
      unawaited(_processPendingShares());
    });
  }

  Future<void> _processPendingShares() async {
    if (_isProcessing || _pendingShares.isEmpty) {
      return;
    }

    if (MeshagentAuth.current.getAccessToken() == null || MeshagentAuth.current.getUser() == null) {
      _scheduleProcessing(immediate: false);
      return;
    }

    _isProcessing = true;
    try {
      _IncomingShareDestination? destination;
      try {
        destination = await _resolveDestination();
      } on _IncomingShareRetryNeeded {
        _scheduleProcessing(immediate: false);
        return;
      } catch (error) {
        _showToast(const Text('Unable to prepare shared files'), description: Text('$error'), destructive: true);
        return;
      }

      if (destination == null) {
        final shares = List<SharedMediaFile>.from(_pendingShares);
        for (final share in shares) {
          _queuedShareKeys.remove(_shareKey(share));
        }
        _pendingShares.removeRange(0, shares.length);
        _scheduleProcessing(immediate: false);
        return;
      }

      final shares = List<SharedMediaFile>.from(_pendingShares);
      try {
        await _uploadShares(destination, shares);
      } on _IncomingShareRetryNeeded {
        _scheduleProcessing(immediate: false);
        return;
      } catch (error) {
        _showToast(const Text('Unable to add shared files'), description: Text('$error'), destructive: true);
        return;
      }

      for (final share in shares) {
        _queuedShareKeys.remove(_shareKey(share));
      }
      _pendingShares.removeRange(0, shares.length);

      _showToast(
        Text(
          shares.length == 1
              ? 'Added shared file to ${destination.displayPath}'
              : 'Added ${shares.length} shared files to ${destination.displayPath}',
        ),
      );
    } finally {
      _isProcessing = false;
      if (_pendingShares.isNotEmpty) {
        _scheduleProcessing(immediate: false);
      }
    }
  }

  Future<_IncomingShareDestination?> _resolveDestination() async {
    final projects = await fetchProjects();
    if (projects.isEmpty) {
      return null;
    }

    if (projects.isNotEmpty) {
      if (!mounted) {
        throw const _IncomingShareRetryNeeded();
      }

      final dialogContext = widget.navigatorKey.currentContext;
      if (dialogContext == null || !dialogContext.mounted) {
        throw const _IncomingShareRetryNeeded();
      }

      final lastProjectId = localStorage.getItem('lastProjectId');
      final preferredProjectId = lastProjectId is String && projects.any((project) => project.id == lastProjectId)
          ? lastProjectId
          : projects.first.id;
      final destination = await showShadDialog<_IncomingShareDestination?>(
        context: dialogContext,
        barrierDismissible: false,
        builder: (context) => _IncomingShareDestinationDialog(
          projects: projects,
          initialProjectId: preferredProjectId,
          initialRoomName: getLastSelectedRoom(preferredProjectId) ?? '',
        ),
      );

      if (destination != null) {
        localStorage.setItem('lastProjectId', destination.projectId);
        setLastSelectedRoom(destination.projectId, destination.roomName);
        _hasWarnedAboutDestination = false;
      }
      return destination;
    }

    if (!_hasWarnedAboutDestination) {
      _hasWarnedAboutDestination = true;
      _showToast(
        const Text('No destination room available'),
        description: const Text('Open a room in Powerboards before sharing files into the app.'),
        destructive: true,
      );
    }
    return null;
  }

  Future<void> _uploadShares(_IncomingShareDestination destination, List<SharedMediaFile> shares) async {
    final client = getMeshagentClient();
    final roomConnection = await client.connectRoom(projectId: destination.projectId, roomName: destination.roomName);
    final roomClient = RoomClient(
      protocol: WebSocketClientProtocol(url: roomConnection.roomUrl, token: roomConnection.jwt),
    );

    try {
      roomClient.start();
      await roomClient.ready;

      for (final share in shares) {
        final source = LocalFileSource(share.path);
        await FileUploadHelper.uploadFileSource(
          source: source,
          path: '',
          onUpload: (stream, fileName, size) => _uploadToRoom(roomClient, destination.resolveUploadPath(fileName), stream),
        );
      }
    } on Exception catch (error) {
      if (_isRetryableIncomingShareError(error)) {
        throw const _IncomingShareRetryNeeded();
      }
      rethrow;
    } finally {
      roomClient.dispose();
    }
  }

  bool _isRetryableIncomingShareError(Exception error) {
    final message = error.toString();
    return message.contains('No access token') || message.contains('No base URL') || message.contains('No OAuth Client ID');
  }

  Future<void> _uploadToRoom(RoomClient roomClient, String fileName, Stream<Uint8List> stream) async {
    await roomClient.storage.uploadStream(fileName, stream, overwrite: true);
  }

  void _showToast(Text title, {Text? description, bool destructive = false}) {
    if (!mounted) {
      return;
    }

    final toast = destructive
        ? ShadToast.destructive(title: title, description: description)
        : ShadToast(title: title, description: description);
    final toastContext = widget.navigatorKey.currentContext ?? context;
    final toaster = ShadToaster.maybeOf(toastContext) ?? ShadToaster.maybeOf(context);
    if (toaster == null) {
      debugPrint('Toast unavailable: ${(title.data ?? '').trim()} ${description?.data ?? ''}'.trim());
      return;
    }

    toaster.show(toast);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _IncomingShareDestination {
  const _IncomingShareDestination({required this.projectId, required this.roomName, required this.folderPath});

  final String projectId;
  final String roomName;

  final String folderPath;

  String resolveUploadPath(String fileName) {
    if (folderPath.isEmpty) {
      return fileName;
    }

    return '$folderPath/$fileName';
  }

  String get displayPath {
    if (folderPath.isEmpty) {
      return roomName;
    }

    return '$roomName/$folderPath';
  }
}

class _IncomingShareRetryNeeded implements Exception {
  const _IncomingShareRetryNeeded();
}

class _IncomingShareDestinationDialog extends StatefulWidget {
  const _IncomingShareDestinationDialog({required this.projects, required this.initialProjectId, required this.initialRoomName});

  final List<Project> projects;
  final String initialProjectId;
  final String initialRoomName;

  @override
  State<_IncomingShareDestinationDialog> createState() => _IncomingShareDestinationDialogState();
}

class _IncomingShareDestinationDialogState extends State<_IncomingShareDestinationDialog> {
  late String _selectedProjectId;
  String? _selectedRoomName;
  String _selectedFolderPath = '';
  RoomClient? _folderBrowserRoom;
  List<Room> _rooms = const <Room>[];
  bool _loadingRooms = false;
  String? _roomsError;
  bool _loadingFolderBrowser = false;
  String? _folderBrowserError;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.initialProjectId;
    unawaited(_loadRoomsForProject(initialRoomName: widget.initialRoomName));
  }

  @override
  void dispose() {
    _folderBrowserRoom?.dispose();
    super.dispose();
  }

  Future<void> _loadRoomsForProject({String? initialRoomName}) async {
    final requestedProjectId = _selectedProjectId;
    final oldRoom = _folderBrowserRoom;
    _folderBrowserRoom = null;

    setState(() {
      _loadingRooms = true;
      _roomsError = null;
      _rooms = const <Room>[];
      _selectedRoomName = null;
      _loadingFolderBrowser = false;
      _folderBrowserError = null;
      _selectedFolderPath = '';
    });

    oldRoom?.dispose();

    try {
      final rooms = await listMeshagentRooms(requestedProjectId);
      if (!mounted || requestedProjectId != _selectedProjectId) {
        return;
      }

      if (rooms.isEmpty) {
        setState(() {
          _loadingRooms = false;
          _roomsError = 'No rooms available in this project.';
        });
        return;
      }

      final preferredRoom = initialRoomName ?? getLastSelectedRoom(requestedProjectId);
      final selectedRoom = rooms.firstWhereOrNull((room) => room.name == preferredRoom) ?? rooms.first;

      setState(() {
        _rooms = rooms;
        _selectedRoomName = selectedRoom.name;
        _loadingRooms = false;
      });

      await _loadFolderBrowserRoom();
    } catch (error) {
      if (!mounted || requestedProjectId != _selectedProjectId) {
        return;
      }

      setState(() {
        _loadingRooms = false;
        _roomsError = '$error';
      });
    }
  }

  Future<void> _loadFolderBrowserRoom() async {
    final selectedRoomName = _selectedRoomName;
    if (selectedRoomName == null) {
      return;
    }

    final oldRoom = _folderBrowserRoom;
    setState(() {
      _loadingFolderBrowser = true;
      _folderBrowserError = null;
      _folderBrowserRoom = null;
      _selectedFolderPath = '';
    });

    oldRoom?.dispose();

    try {
      final client = getMeshagentClient();
      final roomConnection = await client.connectRoom(projectId: _selectedProjectId, roomName: selectedRoomName);
      final roomClient = RoomClient(
        protocol: WebSocketClientProtocol(url: roomConnection.roomUrl, token: roomConnection.jwt),
      );
      await roomClient.start();
      if (!mounted || selectedRoomName != _selectedRoomName) {
        roomClient.dispose();
        return;
      }

      setState(() {
        _folderBrowserRoom = roomClient;
        _loadingFolderBrowser = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingFolderBrowser = false;
        _folderBrowserError = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: const Text('Choose upload destination'),
      description: const Text('Share files to this room'),
      scrollable: false,
      actions: [
        ShadButton.secondary(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ShadButton(
          onPressed: _loadingRooms || _loadingFolderBrowser || _selectedRoomName == null
              ? null
              : () {
                  Navigator.of(context).pop(
                    _IncomingShareDestination(projectId: _selectedProjectId, roomName: _selectedRoomName!, folderPath: _selectedFolderPath),
                  );
                },
          child: const Text('Upload'),
        ),
      ],
      child: SizedBox(
        width: 500,
        height: 450,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: ShadSelect<String>(
                  initialValue: _selectedProjectId,
                  selectedOptionBuilder: (context, value) => Text(
                    widget.projects.firstWhere((project) => project.id == value, orElse: () => widget.projects.first).name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  options: [
                    for (final project in widget.projects)
                      ShadOption<String>(
                        value: project.id,
                        child: Text(project.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null || value == _selectedProjectId) {
                      return;
                    }

                    setState(() {
                      _selectedProjectId = value;
                    });
                    unawaited(_loadRoomsForProject());
                  },
                ),
              ),
            ),
            if (_loadingRooms)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_roomsError != null)
              Expanded(
                child: Center(child: Text(_roomsError!, textAlign: TextAlign.center)),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ShadSelect<String>(
                    initialValue: _selectedRoomName!,
                    selectedOptionBuilder: (context, value) => Text(value, overflow: TextOverflow.ellipsis),
                    options: [
                      for (final room in _rooms)
                        ShadOption<String>(
                          value: room.name,
                          child: Text(room.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null || value == _selectedRoomName) {
                        return;
                      }

                      setState(() {
                        _selectedRoomName = value;
                      });
                      unawaited(_loadFolderBrowserRoom());
                    },
                  ),
                ),
              ),
              Expanded(child: ShadCard(child: _buildFolderPicker(context))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFolderPicker(BuildContext context) {
    if (_loadingFolderBrowser) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_folderBrowserError != null) {
      return Center(child: Text(_folderBrowserError!, textAlign: TextAlign.center));
    }

    final room = _folderBrowserRoom;
    if (room == null) {
      return const SizedBox.shrink();
    }

    return FileBrowser(
      room: room,
      initialPath: _selectedFolderPath,
      multiple: false,
      selectionMode: FileBrowserSelectionMode.folders,
      rootLabel: 'Folders',
      onSelectionChanged: (selection) {
        setState(() {
          _selectedFolderPath = selection.firstOrNull ?? '';
        });
      },
    );
  }
}
