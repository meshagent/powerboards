import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/file_preview_state.dart';
import 'package:powerboards/meshagent/file_table_view.dart';
import 'package:powerboards/meshagent/v1_file_preview_source.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_files_data.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';

void main() {
  tearDown(() {
    powerboardsV1ClearRecentlyOpenedFileSessionCache();
    powerboardsV1ClearFolderEntriesSessionCache();
    powerboardsV1ClearPdfPreviewCache();
  });

  test('file manager maps Powerboards-native paths to v1 file type keys', () {
    expect(powerboardsV1FileTypeKeyForPath('.threads/main.thread'), 'thread');
    expect(powerboardsV1FileTypeKeyForPath('transcripts/2026-06-01 12-40 PM.transcript'), 'transcript');
    expect(powerboardsV1FileTypeKeyForPath('widgets/customer-intake.widget'), 'widget');
    expect(powerboardsV1FileTypeKeyForPath('docs/product brief.document'), 'document');
    expect(powerboardsV1FileTypeKeyForPath('slides/roadmap.presentation'), 'presentation');
    expect(powerboardsV1FileTypeKeyForPath('media/moodboard.gallery'), 'image');
    expect(powerboardsV1FileTypeKeyForPath('forms/signup.form'), 'document');
    expect(powerboardsV1FileTypeKeyForPath('notes/plain.md'), isNull);
  });

  test('file manager keeps real v1 preview categories previewable', () {
    expect(powerboardsV1PreviewStateForPath('docs/notes.txt'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('docs/readme.md'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('src/main.dart'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('Project status dashboard layouts/Status Dashboard.html'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('media/photo.bmp'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('media/sample-image-preview.tiff'), PbAttachmentPreviewState.unavailable);
    expect(powerboardsV1PreviewStateForPath('media/photo.heic'), PbAttachmentPreviewState.unavailable);
    expect(powerboardsV1PreviewStateForPath('media/clip.webm'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('docs/sample.pdf'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('transcripts/live-caption.srt'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('transcripts/live-caption.vtt'), PbAttachmentPreviewState.none);
    expect(powerboardsV1PreviewStateForPath('slides/roadmap.gslides'), PbAttachmentPreviewState.unavailable);
    expect(powerboardsV1PreviewStateForPath('data/results.parquet'), PbAttachmentPreviewState.unavailable);
    expect(powerboardsV1PreviewStateForPath('archive/sample.zip'), PbAttachmentPreviewState.unsupported);
  });

  test('v1 video previews disable native player fullscreen', () {
    final preview = powerboardsV1VideoPreview(Uri.parse('https://example.com/clip.mp4'));

    expect(preview.allowNativeFullscreen, isFalse);
  });

  test('v1 pdf preview cache reuses loaded bytes for the same room and path', () async {
    final room = Object();
    var loads = 0;

    Future<Uint8List> loader() async {
      loads += 1;
      return Uint8List.fromList([loads]);
    }

    final first = await powerboardsV1LoadCachedPdfPreviewDataForTesting(room: room, path: 'docs/brief.pdf', loader: loader);
    final second = await powerboardsV1LoadCachedPdfPreviewDataForTesting(room: room, path: 'docs/brief.pdf', loader: loader);

    expect(loads, 1);
    expect(identical(first, second), isTrue);
  });

  test('v1 pdf preview cache isolates identical paths by room identity', () async {
    final firstRoom = Object();
    final secondRoom = Object();
    var loads = 0;

    Future<Uint8List> loader() async {
      loads += 1;
      return Uint8List.fromList([loads]);
    }

    final first = await powerboardsV1LoadCachedPdfPreviewDataForTesting(room: firstRoom, path: 'docs/brief.pdf', loader: loader);
    final second = await powerboardsV1LoadCachedPdfPreviewDataForTesting(room: secondRoom, path: 'docs/brief.pdf', loader: loader);

    expect(loads, 2);
    expect(first, [1]);
    expect(second, [2]);
  });

  test('v1 pdf preview cache retries after a failed load', () async {
    final room = Object();
    var attempts = 0;

    Future<Uint8List> loader() async {
      attempts += 1;
      if (attempts == 1) {
        throw StateError('boom');
      }
      return Uint8List.fromList([7]);
    }

    await expectLater(
      powerboardsV1LoadCachedPdfPreviewDataForTesting(room: room, path: 'docs/brief.pdf', loader: loader),
      throwsA(isA<StateError>()),
    );

    final loaded = await powerboardsV1LoadCachedPdfPreviewDataForTesting(room: room, path: 'docs/brief.pdf', loader: loader);

    expect(attempts, 2);
    expect(loaded, [7]);
  });

  test('v1 preview content classifies opaque storage paths from displayed filenames', () {
    final room = RoomClient(protocolFactory: () => Protocol(channel: _NoopProtocolChannel()));
    final imageFile = const PbAttachmentListItemData(
      title: 'IMG_0683.jpeg',
      subtitle: 'File',
      fileType: PbAttachmentFileType.generic,
      path: 'ig_09c631980005c30a016a0368ee98e08190898751c0c7613de7',
    );
    final pdfFile = const PbAttachmentListItemData(
      title: 'brief.pdf',
      subtitle: 'File',
      fileType: PbAttachmentFileType.generic,
      path: 'uploads/blob-brief',
    );

    expect(powerboardsV1PreviewClassificationPath(file: imageFile, path: imageFile.path!), 'IMG_0683.jpeg');
    expect(
      powerboardsV1PreviewContentChild(
        room: room,
        file: imageFile,
        path: imageFile.path!,
        downloadUrl: (_) async => 'https://api.example.test/rooms/test/download?path=IMG_0683.jpeg',
      ),
      isNotNull,
    );

    final pdfPreview = powerboardsV1PreviewContentChild(room: room, file: pdfFile, path: pdfFile.path!);

    expect(pdfPreview, isA<PowerboardsV1PdfPreview>());
    expect((pdfPreview as PowerboardsV1PdfPreview).key, const ValueKey('v1-pdf-preview:uploads/blob-brief'));
  });

  test('recently opened files move opened file to the front and de-dupe', () {
    final first = _file('first');
    final second = _file('second');
    final third = _file('third');

    final recents = powerboardsV1RecordRecentlyOpenedFile([third, second, first], second);

    expect(recents, [second, third, first]);
  });

  test('recently opened files are capped to seven previewable files', () {
    final opened = _file('opened');
    final previous = [for (var index = 0; index < 9; index++) _file('previous-$index')];

    final recents = powerboardsV1RecordRecentlyOpenedFile(previous, opened);

    expect(recents.map((file) => file.id), ['opened', 'previous-0', 'previous-1', 'previous-2', 'previous-3', 'previous-4', 'previous-5']);
  });

  test('recently opened files ignore folders', () {
    final file = _file('file');
    final folder = _file('folder', kind: PbFilesItemKind.folder);

    final recents = powerboardsV1RecordRecentlyOpenedFile([file], folder);

    expect(recents, [file]);
  });

  test('v1 file selection treats files and folders as selectable rows', () {
    expect(powerboardsV1FileItemIsSelectable(_file('file')), isTrue);
    expect(powerboardsV1FileItemIsSelectable(_file('folder', kind: PbFilesItemKind.folder)), isTrue);
    expect(powerboardsV1FileItemIsSelectable(_file('processing', kind: PbFilesItemKind.processing)), isFalse);
    expect(powerboardsV1FileItemIsSelectable(_file('error', kind: PbFilesItemKind.processingError)), isFalse);
  });

  test('folder download archive command quotes paths and excludes placeholders', () {
    final command = powerboardsDownloadArchiveCommand(
      archiveFileName: 'Team Updates download.zip',
      itemNames: ['test 1', "Dinesh's notes.md"],
    );

    expect(command, "/usr/bin/zip -r 'Team Updates download.zip' 'test 1' 'Dinesh'\\''s notes.md' -x '*/.placeholder' '.placeholder'");
  });

  test('folder download archive filename is timestamped and filesystem-safe', () {
    final fileName = powerboardsDownloadArchiveFileName(
      baseName: 'Team: Updates',
      itemCount: 2,
      createdAt: DateTime(2026, 6, 3, 14, 41, 5),
    );

    expect(fileName, 'Team- Updates-2-items-20260603-144105.zip');
  });

  test('v1 download archive staging path is hidden from file rows', () {
    expect(powerboardsV1IsDownloadArchiveStagingPath('.powerboards-downloads'), isTrue);
    expect(powerboardsV1IsDownloadArchiveStagingPath('.powerboards-downloads/site.zip'), isTrue);
    expect(powerboardsV1IsDownloadArchiveStagingPath('website/site.zip'), isFalse);
    expect(powerboardsV1IsDownloadArchiveStagingPath('manual.zip'), isFalse);
  });

  test('v1 visible selected ids retain visible file and folder rows', () {
    final realFile = _file('docs/readme.md');
    final realFolder = _file('docs/archive/', kind: PbFilesItemKind.folder);

    final selected = powerboardsV1SelectedVisibleItemIds({'docs/readme.md', 'docs/archive/', 'hidden.txt'}, [realFile, realFolder]);

    expect(selected, {'docs/readme.md', 'docs/archive/'});
  });

  test('v1 replacement rows suppress matching original file and folder rows', () {
    final failedFile = _file('docs/readme.md', kind: PbFilesItemKind.processingError);
    final failedFolder = _file('docs/archive/', kind: PbFilesItemKind.processingError);
    final untouchedFile = _file('docs/keep.md');

    final items = powerboardsV1ItemsExcludingReplacementRows(
      [_file('docs/readme.md'), _file('docs/archive/', kind: PbFilesItemKind.folder), untouchedFile],
      {failedFile.id, failedFolder.id},
    );

    expect(items, [untouchedFile]);
  });

  test('recently opened file session cache restores by project and room', () {
    final first = _file('first');
    final second = _file('second');

    powerboardsV1SaveRecentlyOpenedFilesForSession(projectId: 'project-a', roomName: 'room-a', files: [first, second]);

    expect(powerboardsV1RecentlyOpenedFilesForSession(projectId: 'project-a', roomName: 'room-a'), [first, second]);
    expect(powerboardsV1RecentlyOpenedFilesForSession(projectId: 'project-a', roomName: 'room-b'), isEmpty);
    expect(powerboardsV1RecentlyOpenedFilesForSession(projectId: 'project-b', roomName: 'room-a'), isEmpty);
  });

  test('recently opened file session cache de-dupes, caps, and clears empty lists', () {
    final folder = _file('folder', kind: PbFilesItemKind.folder);
    final files = [for (var index = 0; index < 9; index++) _file('file-$index')];

    powerboardsV1SaveRecentlyOpenedFilesForSession(
      projectId: 'project',
      roomName: 'room',
      files: [files.first, folder, ...files, files[1]],
    );

    expect(powerboardsV1RecentlyOpenedFilesForSession(projectId: 'project', roomName: 'room').map((file) => file.id), [
      'file-0',
      'file-1',
      'file-2',
      'file-3',
      'file-4',
      'file-5',
      'file-6',
    ]);

    powerboardsV1SaveRecentlyOpenedFilesForSession(projectId: 'project', roomName: 'room', files: const []);

    expect(powerboardsV1RecentlyOpenedFilesForSession(projectId: 'project', roomName: 'room'), isEmpty);
  });

  test('v1 folder entry session cache restores by project room and normalized folder', () {
    final entries = [
      StorageEntry(name: 'notes.txt', isFolder: false, size: 12, createdAt: DateTime(2026, 6, 4), updatedAt: DateTime(2026, 6, 4)),
    ];

    powerboardsV1SaveFolderEntriesForTesting(projectId: 'project-a', roomName: 'room-a', folderPath: 'docs/', entries: entries);
    entries.add(StorageEntry(name: 'late.txt', isFolder: false, size: 1, createdAt: DateTime(2026, 6, 4), updatedAt: DateTime(2026, 6, 4)));

    expect(
      powerboardsV1FolderEntriesForSession(projectId: 'project-a', roomName: 'room-a', folderPath: 'docs')!.map((entry) => entry.name),
      ['notes.txt'],
    );
    expect(powerboardsV1FolderEntriesForSession(projectId: 'project-a', roomName: 'room-b', folderPath: 'docs'), isNull);
    expect(powerboardsV1FolderEntriesForSession(projectId: 'project-b', roomName: 'room-a', folderPath: 'docs'), isNull);
    expect(powerboardsV1FolderEntriesForSession(projectId: 'project-a', roomName: 'room-a', folderPath: 'other'), isNull);
  });

  test('live v1 folder entries only render when the loaded folder still matches the route', () {
    expect(powerboardsV1LiveFolderEntriesMatchRoute(routeFolder: 'website', activeFolder: 'website', loadedFolderPath: 'website'), isTrue);
    expect(powerboardsV1LiveFolderEntriesMatchRoute(routeFolder: '', activeFolder: '', loadedFolderPath: 'website'), isFalse);
    expect(powerboardsV1LiveFolderEntriesMatchRoute(routeFolder: 'website', activeFolder: '', loadedFolderPath: 'website'), isFalse);
  });

  test('desktop v1 root Files renders while the first live folder request is pending', () {
    expect(powerboardsV1FolderEntriesForLoadingSurface<String>(routeFolder: '', cachedEntries: null), isEmpty);
    expect(powerboardsV1FolderEntriesForLoadingSurface<String>(routeFolder: '/', cachedEntries: null), isEmpty);
    expect(powerboardsV1FolderEntriesForLoadingSurface<String>(routeFolder: 'docs', cachedEntries: null), isNull);
    expect(powerboardsV1FolderEntriesForLoadingSurface(routeFolder: '', cachedEntries: const ['cached.txt']), ['cached.txt']);
  });

  test('existing-room Files can load before full participant readiness', () async {
    final ready = Completer<void>();
    final connected = Completer<void>();
    var connectionChecks = 0;
    var loads = 0;
    final result = powerboardsLoadFolderAfterRoomReady<String>(
      roomReady: ready.future,
      isConnected: () => true,
      waitUntilConnected: () {
        connectionChecks += 1;
        return connected.future;
      },
      load: () async {
        loads += 1;
        return const <String>[];
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(loads, 0);

    ready.complete();
    await Future<void>.delayed(Duration.zero);
    expect(connectionChecks, 0);
    expect(await result, isEmpty);
    expect(loads, 1);

    connected.complete();
  });

  test('fresh-room Files retries after full connectivity when the early storage request stalls', () async {
    final ready = Completer<void>();
    final connected = Completer<void>();
    final earlyLoad = Completer<List<String>>();
    var loads = 0;
    final result = powerboardsLoadFolderAfterRoomReady<String>(
      roomReady: ready.future,
      isConnected: () => false,
      waitUntilConnected: () => connected.future,
      load: () {
        loads += 1;
        if (loads == 1) {
          return earlyLoad.future;
        }
        return Future.value(const <String>[]);
      },
    );

    ready.complete();
    await Future<void>.delayed(Duration.zero);
    expect(loads, 1);

    connected.complete();
    expect(await result, isEmpty);
    expect(loads, 2);
    earlyLoad.complete(const <String>[]);
  });
}

PbFilesItemData _file(String id, {PbFilesItemKind kind = PbFilesItemKind.file}) {
  return PbFilesItemData.fromFileName(
    id: id,
    title: '$id.txt',
    thread: '',
    creator: 'Jesse Park',
    creatorInitials: 'JP',
    updatedLabel: '',
    updatedSort: 0,
    parentPath: '',
    kind: kind,
  );
}

class _NoopProtocolChannel extends ProtocolChannel {
  @override
  void dispose() {}

  @override
  Future<void> sendData(Uint8List data) async {}

  @override
  void start(void Function(Uint8List data) onDataReceived, {void Function()? onDone, void Function(Object? error)? onError}) {}
}
