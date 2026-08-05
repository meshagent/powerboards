import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/meshagent/file_move_copy.dart';

void main() {
  group('move destination validation', () {
    test('disables the current location in the source room', () {
      expect(
        powerboardsV1CanUseMoveDestination(
          sourceRoom: 'Product',
          destinationRoom: 'Product',
          initialPath: 'assets/launch',
          destinationPath: '/assets/launch/',
        ),
        isFalse,
      );
    });

    test('allows the same path in another room', () {
      expect(
        powerboardsV1CanUseMoveDestination(
          sourceRoom: 'Product',
          destinationRoom: 'Research',
          initialPath: 'assets/launch',
          destinationPath: 'assets/launch',
        ),
        isTrue,
      );
    });

    test('rejects a selected folder and its descendants', () {
      expect(
        powerboardsV1CanUseMoveDestination(
          sourceRoom: 'Product',
          destinationRoom: 'Product',
          initialPath: '',
          destinationPath: 'assets',
          sourceFolderPaths: const ['assets'],
        ),
        isFalse,
      );
      expect(
        powerboardsV1CanUseMoveDestination(
          sourceRoom: 'Product',
          destinationRoom: 'Product',
          initialPath: '',
          destinationPath: 'assets/launch/images',
          sourceFolderPaths: const ['assets'],
        ),
        isFalse,
      );
      expect(
        powerboardsV1CanUseMoveDestination(
          sourceRoom: 'Product',
          destinationRoom: 'Product',
          initialPath: '',
          destinationPath: 'research',
          sourceFolderPaths: const ['assets'],
        ),
        isTrue,
      );
    });
  });

  test('copy conflict names preserve file extensions and folder names', () {
    expect(
      powerboardsV1ConflictCopyName('brief.pdf', folder: false, copyNumber: 1),
      'Copy of brief.pdf',
    );
    expect(
      powerboardsV1ConflictCopyName('brief.pdf', folder: false, copyNumber: 2),
      'Copy 2 of brief.pdf',
    );
    expect(
      powerboardsV1ConflictCopyName('Research', folder: true, copyNumber: 1),
      'Copy of Research',
    );
  });
}
