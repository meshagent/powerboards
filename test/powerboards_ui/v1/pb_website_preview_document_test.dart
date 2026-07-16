import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/components/files/pb_website_preview_document.dart';

void main() {
  test('inlines website assets and keeps local html navigation inside preview', () {
    final html = buildPbWebsitePreviewHtml(
      entryPath: 'website/index.html',
      html: '''
<!doctype html>
<html>
  <head>
    <link rel="stylesheet" href="styles.css" />
  </head>
  <body style="background-image: url('images/paper.png')">
    <img src="images/hero.png" />
    <a href="#hero">Hero</a>
    <a href="details.html#team">Details</a>
    <a href="/#pricing">Pricing</a>
    <a href="/">Home</a>
    <a href="mailto:hello@neocore.example">Email</a>
    <a href="missing.html">Missing</a>
  </body>
</html>
''',
      textContentByPath: {
        'website/index.html': '''
<!doctype html>
<html>
  <head>
    <link rel="stylesheet" href="styles.css" />
  </head>
  <body style="background-image: url('images/paper.png')">
    <img src="images/hero.png" />
    <a href="#hero">Hero</a>
    <a href="details.html#team">Details</a>
    <a href="/#pricing">Pricing</a>
    <a href="/">Home</a>
    <a href="mailto:hello@neocore.example">Email</a>
    <a href="missing.html">Missing</a>
  </body>
</html>
''',
        'website/styles.css': '''
body { background-image: url("./images/confetti.png"); }
.card { background-image: url('/images/badge.svg'); }
''',
        'website/details.html': '<html><body><h1>Details</h1></body></html>',
      },
      urlByPath: {
        'website/index.html': 'https://example.test/download/index.html',
        'website/styles.css': 'https://example.test/download/styles.css',
        'website/images/confetti.png': 'https://example.test/download/confetti.png',
        'website/images/badge.svg': 'https://example.test/download/badge.svg',
        'website/images/paper.png': 'https://example.test/download/paper.png',
        'website/images/hero.png': 'https://example.test/download/hero.png',
        'website/details.html': 'https://example.test/download/details.html',
      },
    );

    expect(html, contains('<style data-pb-website-preview="website/styles.css">'));
    expect(html, contains('<base href="https://meshagent.invalid/" />'));
    expect(html, contains("url('https://example.test/download/confetti.png')"));
    expect(html, contains("url('https://example.test/download/badge.svg')"));
    expect(html, contains("style=\"background-image: url('https://example.test/download/paper.png')\""));
    expect(html, contains('src="https://example.test/download/hero.png"'));
    expect(html, contains('href="#hero"'));
    expect(html, contains('data-pb-preview-fragment="#hero"'));
    expect(html, contains('href="#pricing"'));
    expect(html, contains('data-pb-preview-fragment="#pricing"'));
    expect(html, contains('href="#"'));
    expect(html, contains('data-pb-preview-fragment=""'));
    expect(html, contains('data-pb-preview-page="website/details.html"'));
    expect(html, contains('data-pb-preview-fragment="#team"'));
    expect(html, contains('href="mailto:hello@neocore.example"'));
    expect(html, contains('target="_blank"'));
    expect(html, contains('rel="noopener noreferrer"'));
    expect(html, isNot(contains('href="https://example.test/download/details.html"')));
    expect(html, isNot(contains('href="https://example.test/download/index.html"')));
  });

  test('uses the provided entry html as the initial preview source', () {
    final html = buildPbWebsitePreviewHtml(
      entryPath: 'website/index.html',
      html: '<html><body><main>Fresh preview</main></body></html>',
      textContentByPath: {'website/index.html': '<html><body><main>Stale preview</main></body></html>'},
      urlByPath: const {},
    );

    expect(html, contains('Fresh preview'));
    expect(html, isNot(contains('Stale preview')));
  });
}
