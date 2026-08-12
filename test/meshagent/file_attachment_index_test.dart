import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/datasets_client.dart';
import 'package:meshagent/room_server_client.dart';
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

  test('thread attachment metadata follows file renames', () {
    final rewritten = powerboardsRewriteThreadAttachmentData(
      data: {
        'kind': 'message',
        'role': 'user',
        'attachments': [
          {'url': 'room:///drafts/test-text.md', 'name': 'test-text.md'},
        ],
        'message': {
          'type': 'agent_turn_start',
          'content': [
            {'type': 'text', 'text': 'Review this'},
            {'type': 'file', 'url': 'room:///drafts/test-text.md', 'name': 'test-text.md'},
          ],
        },
      },
      sourcePath: 'drafts/test-text.md',
      destinationPath: 'drafts/test-text-renamed.md',
      folder: false,
    );

    expect(rewritten, isNotNull);
    expect(rewritten!['attachments'], [
      {'url': 'room:///drafts/test-text-renamed.md', 'name': 'test-text-renamed.md'},
    ]);
    expect((rewritten['message'] as Map)['content'], [
      {'type': 'text', 'text': 'Review this'},
      {'type': 'file', 'url': 'room:///drafts/test-text-renamed.md', 'name': 'test-text-renamed.md'},
    ]);
  });

  test('thread attachment metadata follows folder moves and preserves unrelated files', () {
    final rewritten = powerboardsRewriteThreadAttachmentData(
      data: {
        'type': 'agent_turn_start',
        'content': [
          {'type': 'file', 'url': 'room:///Move%20test/blue%20sky.png', 'name': 'blue sky.png'},
          {'type': 'file', 'url': 'room:///other/notes.md', 'name': 'notes.md'},
        ],
      },
      sourcePath: 'Move test',
      destinationPath: 'samples/Move test',
      folder: true,
    );

    expect(rewritten, isNotNull);
    expect(rewritten!['content'], [
      {'type': 'file', 'url': 'room:///samples/Move%20test/blue%20sky.png', 'name': 'blue sky.png'},
      {'type': 'file', 'url': 'room:///other/notes.md', 'name': 'notes.md'},
    ]);
  });

  test('thread attachment metadata keeps plain storage URLs plain', () {
    final rewritten = powerboardsRewriteThreadAttachmentData(
      data: {
        'kind': 'message',
        'attachments': [
          {'url': 'drafts/brief.pdf', 'name': 'brief.pdf'},
        ],
      },
      sourcePath: 'drafts/brief.pdf',
      destinationPath: 'approved/final-brief.pdf',
      folder: false,
    );

    expect(rewritten, isNotNull);
    expect(rewritten!['attachments'], [
      {'url': 'approved/final-brief.pdf', 'name': 'final-brief.pdf'},
    ]);
  });

  test('thread attachment metadata ignores unrelated transfers', () {
    final rewritten = powerboardsRewriteThreadAttachmentData(
      data: {
        'kind': 'message',
        'attachments': [
          {'url': 'room:///drafts/brief.pdf', 'name': 'brief.pdf'},
        ],
      },
      sourcePath: 'other/notes.md',
      destinationPath: 'archive/notes.md',
      folder: false,
    );

    expect(rewritten, isNull);
  });

  test('thread attachment metadata can reconcile an existing move chain', () {
    final rewritten = powerboardsRewriteThreadAttachmentDataWithResolver(
      data: {
        'kind': 'message',
        'attachments': [
          {'url': 'room:///drafts/test-image.png', 'name': 'test-image.png'},
        ],
      },
      resolvePath: (path) => path == 'drafts/test-image.png' ? 'archive/final/test-image-renamed.png' : path,
    );

    expect(rewritten, isNotNull);
    expect(rewritten!['attachments'], [
      {'url': 'room:///archive/final/test-image-renamed.png', 'name': 'test-image-renamed.png'},
    ]);
  });

  test('thread attachment reconciliation queue serializes concurrent row updates', () async {
    final queue = PowerboardsThreadAttachmentReconcileQueue();
    final firstMayFinish = Completer<void>();
    final order = <String>[];

    final first = queue.run(() async {
      order.add('first started');
      await firstMayFinish.future;
      order.add('first finished');
    });
    final second = queue.run(() async {
      order.add('second started');
      order.add('second finished');
    });

    await Future<void>.delayed(Duration.zero);
    expect(order, ['first started']);

    firstMayFinish.complete();
    await Future.wait([first, second]);

    expect(order, ['first started', 'first finished', 'second started', 'second finished']);
  });

  test('missing historical thread table does not block active thread reconciliation', () async {
    final reconciledThreadPaths = <String>[];

    await reconcilePowerboardsThreadAttachmentPaths(
      threadPaths: const ['dataset://threads/retired', 'dataset://threads/active'],
      reconcileThreadPath: (threadPath) async {
        reconciledThreadPaths.add(threadPath);
        if (threadPath == 'dataset://threads/retired') {
          throw RoomServerException("Table 'retired' does not exist", code: 404);
        }
      },
    );

    expect(reconciledThreadPaths, ['dataset://threads/retired', 'dataset://threads/active']);
  });

  test('unexpected historical thread reconciliation errors still surface', () async {
    final reconciledThreadPaths = <String>[];

    await expectLater(
      reconcilePowerboardsThreadAttachmentPaths(
        threadPaths: const ['dataset://threads/failing', 'dataset://threads/unreached'],
        reconcileThreadPath: (threadPath) async {
          reconciledThreadPaths.add(threadPath);
          throw RoomServerException('Room connection closed', code: 503, retryable: true);
        },
      ),
      throwsA(isA<RoomServerException>()),
    );

    expect(reconciledThreadPaths, ['dataset://threads/failing']);
  });

  test('ordinary attachment moves leave generated image lifecycle rows unchanged', () {
    final generatedImageData = <String, dynamic>{
      'kind': 'image_generation',
      'role': 'assistant',
      'status': 'in_progress',
      'call_id': 'call-image-1',
      'arguments': {'prompt': 'Create a giraffe in New York.', 'revised_prompt': 'A giraffe walking through New York City.'},
    };
    final encodedBeforeReconciliation = jsonEncode(generatedImageData);

    final rewritten = powerboardsRewriteThreadAttachmentDataWithResolver(
      data: generatedImageData,
      resolvePath: (path) => path == 'drafts/brief.pdf' ? 'archive/brief.pdf' : path,
    );

    expect(rewritten, isNull);
    expect(jsonEncode(generatedImageData), encodedBeforeReconciliation);
  });

  test('thread attachment dataset updates encode rewritten data as JSON', () {
    final rewrittenData = <String, dynamic>{
      'kind': 'message',
      'attachments': [
        {'url': 'room:///archive/final/test-image-renamed.png', 'name': 'test-image-renamed.png'},
      ],
    };

    final values = powerboardsThreadAttachmentDatasetUpdateValues(rewrittenData);

    expect(values.keys, ['data']);
    expect(values['data'], isA<DatasetJson>());
    expect((values['data']! as DatasetJson).toJson(), rewrittenData);
    expect(encodeRecords(<DatasetRecord>[values]), [
      {
        'data': {'json': rewrittenData},
      },
    ]);
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
