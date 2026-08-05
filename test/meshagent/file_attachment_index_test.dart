import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/meshagent/file_attachment_index.dart';

void main() {
  test('thread attachment paths preserve dataset document URI slashes', () {
    const threadPath = 'dataset://agents/assistant/threads/testing-screenshot-upload';

    expect(normalizePowerboardsThreadAttachmentPath(threadPath), threadPath);
  });

  test('thread attachment match key accepts older collapsed dataset URI form', () {
    const threadPath = 'dataset://agents/assistant/threads/testing-screenshot-upload';
    const legacyThreadPath = 'dataset:/agents/assistant/threads/testing-screenshot-upload';

    expect(powerboardsThreadAttachmentMatchKey(threadPath), powerboardsThreadAttachmentMatchKey(legacyThreadPath));
  });

  test('storage attachment URLs unwrap room scheme paths', () {
    expect(powerboardsStorageAttachmentPathFromUrl('room:///sample-attachments/scratch.md'), 'sample-attachments/scratch.md');
    expect(powerboardsStorageAttachmentPathFromUrl('room://sample-attachments/scratch.md'), 'sample-attachments/scratch.md');
    expect(powerboardsStorageAttachmentPathFromUrl('sample-attachments/scratch.md'), 'sample-attachments/scratch.md');
    expect(powerboardsStorageAttachmentPathFromUrl('dataset://agents/assistant/threads/thread-1'), isEmpty);
  });

  test('storage attachment URLs decode encoded folder names before move resolution', () {
    expect(powerboardsStorageAttachmentPathFromUrl('room:///Move%20test/blue-sky.png'), 'Move test/blue-sky.png');
  });

  test('attachment index links keep thread document URI paths openable', () {
    final link = PowerboardsFileAttachmentLink.fromJson(const {
      'file_path': 'screenshots/testing.png',
      'thread_path': 'dataset://agents/assistant/threads/testing-screenshot-upload',
      'thread_name': 'Testing Screenshot Upload',
    });

    expect(link.filePath, 'screenshots/testing.png');
    expect(link.threadPath, 'dataset://agents/assistant/threads/testing-screenshot-upload');
    expect(link.threadDisplayName, 'Testing Screenshot Upload');
  });

  test('attachment index links ignore legacy generated provenance fields', () {
    final link = PowerboardsFileAttachmentLink.fromJson(const {
      'file_path': 'archives/archive.zip',
      'thread_path': 'dataset://agents/assistant/threads/create-image-zip',
      'thread_name': 'Create Image Zip',
      'created_by': 'Assistant',
      'generated_by_agent_name': 'Assistant',
      'generated_provenance_source': 'thread_claim',
    });

    expect(link.createdBy, 'Assistant');
    expect(link.toJson().containsKey('generated_by_agent_name'), isFalse);
    expect(link.toJson().containsKey('generated_provenance_source'), isFalse);
  });

  test('attachment index links distinguish direct attachments from inherited copies', () {
    final legacy = PowerboardsFileAttachmentLink.fromJson(const {
      'file_path': 'archives/original.zip',
      'thread_path': 'dataset://agents/assistant/threads/archive',
    });
    final inheritedCopy = legacy.copyWith(filePath: 'copies/original.zip', inheritedFromCopy: true);
    final directAttachment = inheritedCopy.copyWith(inheritedFromCopy: false);

    expect(legacy.inheritedFromCopy, isNull);
    expect(inheritedCopy.inheritedFromCopy, isTrue);
    expect(inheritedCopy.toJson()['inherited_from_copy'], isTrue);
    expect(directAttachment.inheritedFromCopy, isFalse);
    expect(directAttachment.toJson()['inherited_from_copy'], isFalse);
  });

  test('folder transfers preserve descendant paths', () {
    expect(
      powerboardsTransferredAttachmentPath(
        path: 'assets/launch/images/hero.png',
        sourcePath: 'assets/launch',
        destinationPath: 'archive/launch',
        folder: true,
      ),
      'archive/launch/images/hero.png',
    );
  });

  test('file transfers do not rewrite unrelated descendants', () {
    expect(
      powerboardsTransferredAttachmentPath(
        path: 'assets/brief.pdf/preview.png',
        sourcePath: 'assets/brief.pdf',
        destinationPath: 'archive/brief.pdf',
        folder: false,
      ),
      'assets/brief.pdf/preview.png',
    );
  });

  test('same-room moves preserve provenance links and are idempotent', () {
    const original = PowerboardsFileAttachmentLink(
      filePath: 'drafts/brief.pdf',
      threadPath: 'dataset://agents/assistant/threads/brief',
      threadName: 'Brief',
      createdBy: 'User',
      createdAt: null,
    );

    final first = powerboardsFileAttachmentLinksAfterSameRoomTransfer(
      links: const [original],
      sourcePath: 'drafts/brief.pdf',
      destinationPath: 'approved/brief.pdf',
      folder: false,
      move: true,
    );
    final second = powerboardsFileAttachmentLinksAfterSameRoomTransfer(
      links: first,
      sourcePath: 'drafts/brief.pdf',
      destinationPath: 'approved/brief.pdf',
      folder: false,
      move: true,
    );

    expect(first, hasLength(1));
    expect(first.single.filePath, 'drafts/brief.pdf');
    expect(second, hasLength(1));
    expect(second.single.filePath, 'drafts/brief.pdf');
    expect(second.single.threadPath, original.threadPath);
  });
}
