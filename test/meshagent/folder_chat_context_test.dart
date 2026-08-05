import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/meshagent/folder_chat_context.dart';

void main() {
  group('folder chat context', () {
    test('round trips a nested live folder as supported text data', () {
      final dataUrl = powerboardsFolderChatContextDataUrl('/content/research/');
      final context = powerboardsFolderChatContextFromDataUrl(dataUrl);

      expect(dataUrl, startsWith('data:text/plain;base64,'));
      expect(context?.storagePath, 'content/research');
      expect(context?.displayName, 'research');
      expect(context?.workspacePath, '/data/content/research');
      expect(context?.folderLink, 'powerboards://files?path=content%2Fresearch');
    });

    test('represents the Files root instead of dropping its empty storage path', () {
      final dataUrl = powerboardsFolderChatContextDataUrl('');
      final context = powerboardsFolderChatContextFromDataUrl(dataUrl);

      expect(context?.storagePath, isEmpty);
      expect(context?.displayName, 'Files');
      expect(context?.workspacePath, '/data');
      expect(context?.folderLink, 'powerboards://files');
    });

    test('recognizes folder context after thread storage wraps or strips its data URL prefix', () {
      final dataUrl = powerboardsFolderChatContextDataUrl('content');
      final payload = dataUrl.substring('data:text/plain;base64,'.length);
      final variants = <String>[
        'room:///$dataUrl',
        '/$dataUrl',
        'room:///plain;base64,$payload',
        'plain;base64,$payload',
        payload,
        Uri.encodeFull('room:///$dataUrl').replaceFirst(',', '%2C'),
      ];

      for (final variant in variants) {
        final context = powerboardsFolderChatContextFromDataUrl(variant);
        expect(context?.storagePath, 'content', reason: variant.length > 60 ? variant.substring(0, 60) : variant);
        expect(context?.displayName, 'content');
      }
    });

    test('instructs the agent to refresh live contents and ignore dot-hidden files', () {
      final dataUrl = powerboardsFolderChatContextDataUrl(
        'content',
        visibleDirectChildren: const <PowerboardsFolderChatEntry>[
          PowerboardsFolderChatEntry(storagePath: 'content/notes.md', name: 'notes.md', isFolder: false, sizeBytes: 42),
          PowerboardsFolderChatEntry(storagePath: 'content/research', name: 'research', isFolder: true),
        ],
      );
      final encoded = dataUrl.substring('data:text/plain;base64,'.length);
      final document = jsonDecode(utf8.decode(base64Decode(encoded))) as Map<String, dynamic>;
      final instructions = (document['instructions'] as List<dynamic>).join('\n');
      final directChildren = document['visible_direct_children'] as List<dynamic>;

      expect(directChildren, hasLength(2));
      expect(directChildren.first, containsPair('storage_path', 'content/notes.md'));
      expect(directChildren.first, containsPair('type', 'file'));
      expect(directChildren.last, containsPair('type', 'folder'));
      expect(instructions, contains('authoritative snapshot'));
      expect(instructions, contains('direct children exactly as files or folders'));
      expect(instructions, contains('Do not collapse recursive descendants'));
      expect(instructions, contains('at response time'));
      expect(instructions, contains('newly created, changed, or deleted'));
      expect(instructions, contains('basename begins with a dot'));
      expect(instructions, contains('.placeholder'));
      expect(instructions, contains('powerboards://preview?path=<storage-path>'));
      expect(instructions, contains('powerboards://files?path=content'));
    });

    test('resolves a renamed folder context and preserves its direct-child snapshot', () {
      final original = powerboardsFolderChatContextDataUrl(
        'drafts/brief',
        visibleDirectChildren: const [PowerboardsFolderChatEntry(storagePath: 'drafts/brief/notes.md', name: 'notes.md', isFolder: false)],
      );
      final resolved = powerboardsResolveFolderChatContextDataUrl(
        original,
        resolvePath: (path) => path == 'drafts/brief' ? 'drafts/final-brief' : path,
      );
      final context = powerboardsFolderChatContextFromDataUrl(resolved);
      final document = jsonDecode(utf8.decode(base64Decode(resolved.substring('data:text/plain;base64,'.length)))) as Map<String, dynamic>;
      expect(context?.storagePath, 'drafts/final-brief');
      expect(context?.displayName, 'final-brief');
      expect((document['visible_direct_children'] as List).single, containsPair('storage_path', 'drafts/final-brief/notes.md'));
    });

    test('rejects unrelated and malformed data URLs', () {
      expect(powerboardsFolderChatContextFromDataUrl('content'), isNull);
      expect(powerboardsFolderChatContextFromDataUrl('data:text/plain;base64,not-base64!'), isNull);
      expect(powerboardsFolderChatContextFromDataUrl('data:text/plain;base64,${base64Encode(utf8.encode('{}'))}'), isNull);
    });

    test('leaves malformed-percent file paths to the existing file renderer', () {
      const filePaths = <String>['Screenshot% image.png', 'room:///Screenshot% image.png'];

      for (final filePath in filePaths) {
        expect(() => powerboardsFolderChatContextFromDataUrl(filePath), returnsNormally);
        expect(powerboardsFolderChatContextFromDataUrl(filePath), isNull);
      }
    });

    test('parses folder and preview product links', () {
      final root = powerboardsChatLinkTargetFromUrl('powerboards://files');
      final folder = powerboardsChatLinkTargetFromUrl('powerboards://files?path=content%2Fresearch');
      final file = powerboardsChatLinkTargetFromUrl('powerboards://preview?path=content%2Fresearch%2Fnotes.md');
      final fileWithSpaces = powerboardsChatLinkTargetFromUrl(
        'powerboards://preview?path=stuff%252FScreenshot%25202026-06-02%2520at%252010.06.10%2520AM.png',
      );
      final malformedFileWithSpaces = powerboardsChatLinkTargetFromUrl(
        'powerboards://preview?path=documents%2FScreenshot% 2026-06-02%20at%2010.06.10%20AM.png',
      );

      expect(root?.kind, PowerboardsChatLinkKind.folder);
      expect(root?.storagePath, isEmpty);
      expect(folder?.kind, PowerboardsChatLinkKind.folder);
      expect(folder?.storagePath, 'content/research');
      expect(file?.kind, PowerboardsChatLinkKind.filePreview);
      expect(file?.storagePath, 'content/research/notes.md');
      expect(fileWithSpaces?.kind, PowerboardsChatLinkKind.filePreview);
      expect(fileWithSpaces?.storagePath, 'stuff/Screenshot 2026-06-02 at 10.06.10 AM.png');
      expect(malformedFileWithSpaces?.kind, PowerboardsChatLinkKind.filePreview);
      expect(malformedFileWithSpaces?.storagePath, 'documents/Screenshot 2026-06-02 at 10.06.10 AM.png');
      expect(powerboardsChatLinkTargetFromUrl('powerboards://preview'), isNull);
      expect(powerboardsChatLinkTargetFromUrl('https://example.com'), isNull);
    });

    test('canonicalizes only malformed preview Markdown destinations', () {
      const normal = '[test.png](powerboards://preview?path=stuff%2Ftest.png)';
      const external = '[Screenshot](https://example.com/Screenshot% image.png)';
      const folder = '[stuff](powerboards://files?path=stuff with spaces)';
      const malformed = '[Screenshot](powerboards://preview?path=stuff%2FScreenshot% 2026-06-02%20at%2010.06.10%20AM.png)';
      const rawSpaces = '[Notes](powerboards://preview?path=stuff/Screenshot 2026-06-02 at 10.06.10 AM.md)';
      const narrowNoBreakSpace = '[Screenshot](powerboards://preview?path=stuff%2FScreenshot%202026-06-02%20at%2010.06.10 AM.png)';

      expect(powerboardsCanonicalizeMalformedPreviewMarkdownLinks(normal), normal);
      expect(powerboardsCanonicalizeMalformedPreviewMarkdownLinks(external), external);
      expect(powerboardsCanonicalizeMalformedPreviewMarkdownLinks(folder), folder);

      for (final markdown in <String>[malformed, rawSpaces, narrowNoBreakSpace]) {
        final canonicalized = powerboardsCanonicalizeMalformedPreviewMarkdownLinks(markdown);
        expect(canonicalized, isNot(markdown));
        expect(canonicalized, isNot(contains(RegExp(r'%(?![0-9A-Fa-f]{2})'))));
        expect(canonicalized, isNot(contains(' ')));
      }
    });

    test('folder routes remain folders and basename file links resolve inside the active folder', () {
      expect(powerboardsFolderFilesRoutePath(''), isEmpty);
      expect(powerboardsFolderFilesRoutePath('my-content'), 'my-content/');
      expect(powerboardsFolderFilesRoutePath('/my-content/research/'), 'my-content/research/');

      expect(powerboardsResolveChatFilePreviewPath('scratch.md', activeFolderStoragePath: 'my-content'), 'my-content/scratch.md');
      expect(
        powerboardsResolveChatFilePreviewPath('my-content/scratch.md', activeFolderStoragePath: 'my-content'),
        'my-content/scratch.md',
      );
      expect(powerboardsResolveChatFilePreviewPath('other/scratch.md', activeFolderStoragePath: 'my-content'), 'other/scratch.md');
    });
  });
}
