import 'dart:typed_data';

import 'package:archive/archive.dart' as archive;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/meshagent/archive_extract.dart';
import 'package:powerboards/meshagent/file_preview_state.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_archive_extract.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_file_preview_state_card.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';

void main() {
  test('unsupported archives are eligible for extract preview by supported format', () {
    for (final title in const ['bundle.zip', 'bundle.tar', 'bundle.tar.gz', 'bundle.tgz']) {
      final file = PbAttachmentListItemData.fromFileName(title: title, previewState: PbAttachmentPreviewState.unsupported);

      expect(pbCanExtractArchive(file), isTrue, reason: title);
    }
  });

  test('archive extract preview requires unsupported preview state and supported archive format', () {
    final previewableArchive = PbAttachmentListItemData.fromFileName(title: 'bundle.zip', previewState: PbAttachmentPreviewState.none);
    final unsupportedRar = PbAttachmentListItemData.fromFileName(title: 'bundle.rar', previewState: PbAttachmentPreviewState.unsupported);
    final unsupportedText = PbAttachmentListItemData.fromFileName(title: 'notes.txt', previewState: PbAttachmentPreviewState.unsupported);

    expect(pbCanExtractArchive(previewableArchive), isFalse);
    expect(pbCanExtractArchive(unsupportedRar), isFalse);
    expect(pbCanExtractArchive(unsupportedText), isFalse);
  });

  test('archive extract eligibility is not blocked by non-archive metadata', () {
    const uploadedArchive = PbAttachmentListItemData(
      title: 'uploaded-bundle.zip',
      subtitle: 'File',
      fileType: PbAttachmentFileType.generic,
      previewState: PbAttachmentPreviewState.unsupported,
    );

    expect(pbCanExtractArchive(uploadedArchive), isTrue);
  });

  test('tgz files resolve as unsupported archive previews', () {
    final metadata = PbResolvedAttachmentMetadata.resolve(title: 'bundle.tgz');

    expect(metadata.fileType, PbAttachmentFileType.archive);
    expect(metadata.displayType, 'Archive');
    expect(powerboardsV1PreviewStateForPath('bundle.tgz'), PbAttachmentPreviewState.unsupported);
  });

  test('small zip bytes inspect as a browsable archive', () {
    final inspection = inspectPowerboardsZipArchiveBytesForTesting(
      _zipCentralDirectoryBytes([
        _ZipTestEntry.folder('images/'),
        _ZipTestEntry.file('cover.jpg', 1024),
        _ZipTestEntry.file('brief.pdf', 2048),
        _ZipTestEntry.file('notes.md', 512),
        _ZipTestEntry.file('images/lobby.jpg', 4096),
      ]),
      targetFolderName: 'small-bundle',
      archiveSizeBytes: 732 * 1024,
    );

    expect(inspection.browsable, isTrue);
    expect(inspection.summaryLabel, '4 files, 1 folders, 7.5 KB expanded');
    expect(inspection.firstPreviewPath, 'cover.jpg');
    expect(inspection.entries.map((entry) => entry.path), containsAll(['images', 'cover.jpg', 'brief.pdf', 'notes.md']));
  });

  test('zip bytes over the single-file limit inspect as download-only', () {
    final inspection = inspectPowerboardsZipArchiveBytesForTesting(
      _zipCentralDirectoryBytes([_ZipTestEntry.file('movie.mov', PbArchiveExtractLimits.singleFileMaxBytes + 1)]),
      targetFolderName: 'large-file',
      archiveSizeBytes: 800 * 1024,
    );

    expect(inspection.browsable, isFalse);
    expect(inspection.overLimitReason, 'This archive exceeds the preview limits for single file size.');
    expect(inspection.entries, isEmpty);
  });

  test('small zip bytes extract into normalized files', () {
    final bytes = _realZipBytes({
      'cover.jpg': Uint8List.fromList([1, 2, 3]),
      'notes/intro.md': Uint8List.fromList([4, 5]),
    });
    final inspection = inspectPowerboardsZipArchiveBytesForTesting(
      bytes,
      targetFolderName: 'scotty_images',
      archiveSizeBytes: bytes.length,
    );

    final files = extractPowerboardsZipArchiveFilesForTesting(bytes, inspection: inspection);

    expect(inspection.browsable, isTrue);
    expect(files.map((file) => file.path), ['cover.jpg', 'notes/intro.md']);
    expect(files.first.bytes, [1, 2, 3]);
    expect(files.last.bytes, [4, 5]);
  });

  test('zip upload reports partial extraction failures without dropping successes', () async {
    final bytes = _realZipBytes({
      'cover.jpg': Uint8List.fromList([1]),
      'room.jpg': Uint8List.fromList([2]),
      'notes.txt': Uint8List.fromList([3]),
    });
    final inspection = inspectPowerboardsZipArchiveBytesForTesting(
      bytes,
      targetFolderName: 'scotty_images',
      archiveSizeBytes: bytes.length,
    );
    final files = extractPowerboardsZipArchiveFilesForTesting(bytes, inspection: inspection);
    final callbacks = <String>[];
    final uploadedPaths = <String>[];

    final result = await uploadPowerboardsZipArchiveFilesForTesting(
      targetFolderPath: 'thread/scotty_images',
      inspection: inspection,
      files: files,
      uploadStream: (path, chunks, {required overwrite, required size}) async {
        await for (final chunk in chunks) {
          expect(chunk.length, lessThanOrEqualTo(size));
        }
        if (path.endsWith('/cover.jpg')) {
          throw StateError('upload failed');
        }
        uploadedPaths.add(path);
      },
      onEntryExtracted: (entry) => callbacks.add(entry.path),
    );

    expect(uploadedPaths, ['thread/scotty_images/room.jpg', 'thread/scotty_images/notes.txt']);
    expect(callbacks, ['room.jpg', 'notes.txt']);
    expect(result.extractedEntries.map((entry) => entry.path), ['room.jpg', 'notes.txt']);
    expect(result.failedEntries.map((entry) => entry.path), ['cover.jpg']);
    expect(result.firstPreviewPath, 'room.jpg');
  });

  testWidgets('small archive inspections render the browsable extract dialog', (tester) async {
    PbArchiveInspectionResult? confirmedInspection;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              PbArchiveExtractPreviewDialog(
                file: PbAttachmentListItemData.fromFileName(title: 'small-bundle.zip', previewState: PbAttachmentPreviewState.unsupported),
                onClose: () {},
                onInspect: (file) async => PbArchiveInspectionResult.forFile(file),
                onConfirm: (inspection) => confirmedInspection = inspection,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('8 files, 2 folders, 68 MB expanded'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('images'), findsOneWidget);
    expect(find.text('cover.jpg'), findsOneWidget);
    expect(find.text('brief.pdf'), findsOneWidget);
    expect(find.text('notes.md'), findsOneWidget);
    expect(find.text('Extract files into folder'), findsOneWidget);
    expect(find.text('Extract to folder'), findsOneWidget);
    expect(find.text('Download'), findsNothing);

    await tester.tap(find.text('Extract to folder'));

    expect(confirmedInspection?.browsable, isTrue);
  });

  testWidgets('archive extract preview card is inert while extraction is in progress', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PbFilePreviewStateCard(
              file: PbAttachmentListItemData.fromFileName(title: 'small-bundle.zip', previewState: PbAttachmentPreviewState.unsupported),
              state: PbAttachmentPreviewState.unsupported,
              showExtractArchive: true,
              extractArchiveDisabled: true,
              onExtractArchive: () => taps += 1,
            ),
          ),
        ),
      ),
    );

    expect(find.text(pbArchiveExtractTriggerLabel), findsOneWidget);

    await tester.tap(find.text(pbArchiveExtractTriggerLabel));

    expect(taps, 0);
  });

  testWidgets('archive inspection errors keep download actions visible', (tester) async {
    var closed = false;
    var downloaded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              PbArchiveExtractPreviewDialog(
                file: PbAttachmentListItemData.fromFileName(
                  title: 'uploaded-bundle.zip',
                  previewState: PbAttachmentPreviewState.unsupported,
                ),
                onClose: () => closed = true,
                onInspect: (_) async => throw StateError('inspect failed'),
                onDownload: () => downloaded = true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('The archive could not be inspected. Please download to continue.'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);

    await tester.tap(find.text('Download'));
    expect(downloaded, isTrue);
    expect(closed, isFalse);
  });
}

class _ZipTestEntry {
  const _ZipTestEntry._({required this.path, required this.sizeBytes, required this.folder});

  const _ZipTestEntry.file(String path, int sizeBytes) : this._(path: path, sizeBytes: sizeBytes, folder: false);

  const _ZipTestEntry.folder(String path) : this._(path: path, sizeBytes: 0, folder: true);

  final String path;
  final int sizeBytes;
  final bool folder;
}

Uint8List _zipCentralDirectoryBytes(List<_ZipTestEntry> entries) {
  final bytes = <int>[];
  final centralDirectoryOffset = 0;

  for (final entry in entries) {
    final nameBytes = entry.path.codeUnits;
    bytes
      ..addAll(_u32(0x02014b50))
      ..addAll(_u16(20))
      ..addAll(_u16(20))
      ..addAll(_u16(0x0800))
      ..addAll(_u16(0))
      ..addAll(_u16(0))
      ..addAll(_u16(0))
      ..addAll(_u32(0))
      ..addAll(_u32(entry.sizeBytes))
      ..addAll(_u32(entry.sizeBytes))
      ..addAll(_u16(nameBytes.length))
      ..addAll(_u16(0))
      ..addAll(_u16(0))
      ..addAll(_u16(0))
      ..addAll(_u16(0))
      ..addAll(_u32(entry.folder ? 0x40000000 : 0))
      ..addAll(_u32(0))
      ..addAll(nameBytes);
  }

  final centralDirectorySize = bytes.length - centralDirectoryOffset;
  bytes
    ..addAll(_u32(0x06054b50))
    ..addAll(_u16(0))
    ..addAll(_u16(0))
    ..addAll(_u16(entries.length))
    ..addAll(_u16(entries.length))
    ..addAll(_u32(centralDirectorySize))
    ..addAll(_u32(centralDirectoryOffset))
    ..addAll(_u16(0));

  return Uint8List.fromList(bytes);
}

List<int> _u16(int value) => [value & 0xff, (value >> 8) & 0xff];

List<int> _u32(int value) => [value & 0xff, (value >> 8) & 0xff, (value >> 16) & 0xff, (value >> 24) & 0xff];

Uint8List _realZipBytes(Map<String, Uint8List> files) {
  final zipArchive = archive.Archive();
  for (final entry in files.entries) {
    zipArchive.addFile(archive.ArchiveFile.bytes(entry.key, entry.value));
  }
  return Uint8List.fromList(archive.ZipEncoder().encode(zipArchive));
}
