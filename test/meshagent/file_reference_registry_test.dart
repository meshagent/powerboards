import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/meshagent/file_attachment_index.dart';
import 'package:powerboards/meshagent/file_reference_registry.dart';

void main() {
  PowerboardsFileReference reference({
    required String sourceRoom,
    required String sourcePath,
    required String destinationRoom,
    required String destinationPath,
    PowerboardsFileTransferOperation operation = PowerboardsFileTransferOperation.move,
    bool folder = false,
  }) {
    return PowerboardsFileReference(
      sourceRoomName: sourceRoom,
      sourcePath: sourcePath,
      destinationRoomName: destinationRoom,
      destinationPath: destinationPath,
      operation: operation,
      folder: folder,
      updatedAt: DateTime.utc(2026, 7, 21),
    );
  }

  test('same-room moves resolve historical paths to the destination', () {
    final resolution = powerboardsResolveFileReference(
      roomName: 'Product',
      path: 'drafts/brief.pdf',
      references: [
        reference(sourceRoom: 'Product', sourcePath: 'drafts/brief.pdf', destinationRoom: 'Product', destinationPath: 'approved/brief.pdf'),
      ],
    );

    expect(resolution.roomName, 'Product');
    expect(resolution.path, 'approved/brief.pdf');
  });

  test('folder moves resolve attachment descendants', () {
    final resolution = powerboardsResolveFileReference(
      roomName: 'Product',
      path: 'drafts/launch/images/hero.png',
      references: [
        reference(
          sourceRoom: 'Product',
          sourcePath: 'drafts/launch',
          destinationRoom: 'Product',
          destinationPath: 'approved/launch',
          folder: true,
        ),
      ],
    );

    expect(resolution.path, 'approved/launch/images/hero.png');
  });

  test('encoded room attachment URIs resolve through folder moves', () {
    final attachmentPath = powerboardsStorageAttachmentPathFromUrl('room:///Move%20test/blue-sky.png');
    final resolution = powerboardsResolveFileReference(
      roomName: 'Product',
      path: attachmentPath,
      references: [
        reference(
          sourceRoom: 'Product',
          sourcePath: 'Move test',
          destinationRoom: 'Product',
          destinationPath: 'samples/Move test',
          folder: true,
        ),
      ],
    );

    expect(attachmentPath, 'Move test/blue-sky.png');
    expect(resolution.path, 'samples/Move test/blue-sky.png');
  });

  test('copy records do not redirect the original attachment', () {
    final resolution = powerboardsResolveFileReference(
      roomName: 'Product',
      path: 'drafts/brief.pdf',
      references: [
        reference(
          sourceRoom: 'Product',
          sourcePath: 'drafts/brief.pdf',
          destinationRoom: 'Product',
          destinationPath: 'approved/brief.pdf',
          operation: PowerboardsFileTransferOperation.copy,
        ),
      ],
    );

    expect(resolution.path, 'drafts/brief.pdf');
  });

  test('move chains resolve to the latest location', () {
    final resolution = powerboardsResolveFileReference(
      roomName: 'Product',
      path: 'drafts/brief.pdf',
      references: [
        reference(sourceRoom: 'Product', sourcePath: 'drafts/brief.pdf', destinationRoom: 'Product', destinationPath: 'review/brief.pdf'),
        reference(sourceRoom: 'Product', sourcePath: 'review/brief.pdf', destinationRoom: 'Product', destinationPath: 'approved/brief.pdf'),
      ],
    );

    expect(resolution.path, 'approved/brief.pdf');
  });

  test('historical attachment provenance matches the current same-room path at read time', () {
    final references = [
      reference(sourceRoom: 'Product', sourcePath: 'drafts/brief.pdf', destinationRoom: 'Product', destinationPath: 'review/brief.pdf'),
      reference(sourceRoom: 'Product', sourcePath: 'review/brief.pdf', destinationRoom: 'Product', destinationPath: 'approved/brief.pdf'),
    ];

    expect(
      powerboardsFileReferenceMatchesCurrentPath(
        originalRoomName: 'Product',
        originalPath: 'drafts/brief.pdf',
        currentRoomName: 'Product',
        currentPath: 'approved/brief.pdf',
        references: references,
      ),
      isTrue,
    );
    expect(
      powerboardsFileReferenceMatchesCurrentPath(
        originalRoomName: 'Product',
        originalPath: 'drafts/brief.pdf',
        currentRoomName: 'Product',
        currentPath: 'drafts/brief.pdf',
        references: references,
      ),
      isFalse,
    );
  });

  test('cross-room moves retain the destination room identity', () {
    final resolution = powerboardsResolveFileReference(
      roomName: 'Product',
      path: 'drafts/brief.pdf',
      references: [
        reference(sourceRoom: 'Product', sourcePath: 'drafts/brief.pdf', destinationRoom: 'Research', destinationPath: 'brief.pdf'),
      ],
    );

    expect(resolution.roomName, 'Research');
    expect(resolution.path, 'brief.pdf');
  });

  test('copy destinations remain identifiable after later moves', () {
    final references = [
      reference(
        sourceRoom: 'Product',
        sourcePath: 'drafts/launch',
        destinationRoom: 'Product',
        destinationPath: 'copies/launch',
        operation: PowerboardsFileTransferOperation.copy,
        folder: true,
      ),
      reference(
        sourceRoom: 'Product',
        sourcePath: 'copies/launch',
        destinationRoom: 'Product',
        destinationPath: 'archive/launch',
        folder: true,
      ),
    ];

    expect(
      powerboardsPathWasCreatedByCopy(roomName: 'Product', path: 'archive/launch/images/copied-image.png', references: references),
      isTrue,
    );
    expect(
      powerboardsPathWasCreatedByCopy(roomName: 'Product', path: 'drafts/launch/images/original.png', references: references),
      isFalse,
    );
  });

  test('individually copied files remain identifiable after rename', () {
    final references = [
      reference(
        sourceRoom: 'Product',
        sourcePath: 'moved/moved-image.png',
        destinationRoom: 'Product',
        destinationPath: 'copies/moved-image.png',
        operation: PowerboardsFileTransferOperation.copy,
      ),
      reference(
        sourceRoom: 'Product',
        sourcePath: 'copies/moved-image.png',
        destinationRoom: 'Product',
        destinationPath: 'copies/copied-image.png',
      ),
    ];

    expect(powerboardsPathWasCreatedByCopy(roomName: 'Product', path: 'copies/copied-image.png', references: references), isTrue);
  });
}
