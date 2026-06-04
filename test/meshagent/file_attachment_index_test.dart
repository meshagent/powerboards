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
}
