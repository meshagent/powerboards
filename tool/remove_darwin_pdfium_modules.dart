import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main() async {
  final packageConfig = _findPackageConfig(Directory.current);
  if (packageConfig == null) {
    stderr.writeln('Could not find .dart_tool/package_config.json. Run flutter pub get first.');
    exitCode = 2;
    return;
  }

  final config = jsonDecode(await packageConfig.readAsString()) as Map<String, Object?>;
  final packages = (config['packages'] as List<Object?>).cast<Map<String, Object?>>();
  final pdfiumPackage = packages.where((package) => package['name'] == 'pdfium_flutter').firstOrNull;
  if (pdfiumPackage == null) {
    stdout.writeln('pdfium_flutter is not resolved for this workspace.');
    return;
  }

  final rootUri = pdfiumPackage['rootUri'] as String?;
  if (rootUri == null) {
    stderr.writeln('pdfium_flutter package_config entry does not include rootUri.');
    exitCode = 3;
    return;
  }

  final packageRoot = _resolvePackageRoot(packageConfig.parent.parent, rootUri);
  final pubspec = File(p.join(packageRoot.path, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    stderr.writeln('Could not find pdfium_flutter pubspec at ${pubspec.path}.');
    exitCode = 4;
    return;
  }

  final original = await pubspec.readAsString();
  final modified = _commentFlutterPluginBlock(original);
  if (modified == original) {
    stdout.writeln('Darwin PDFium plugin metadata is already disabled.');
    return;
  }

  await pubspec.writeAsString(modified);
  stdout.writeln('Disabled Darwin PDFium plugin metadata in ${pubspec.path}.');
}

File? _findPackageConfig(Directory start) {
  var current = start.absolute;
  while (true) {
    final candidate = File(p.join(current.path, '.dart_tool', 'package_config.json'));
    if (candidate.existsSync()) {
      return candidate;
    }

    final parent = current.parent;
    if (parent.path == current.path) {
      return null;
    }
    current = parent;
  }
}

Directory _resolvePackageRoot(Directory workspaceRoot, String rootUri) {
  final uri = Uri.parse(rootUri);
  if (uri.scheme == 'file') {
    return Directory.fromUri(uri);
  }
  return Directory(p.normalize(p.join(workspaceRoot.path, rootUri)));
}

String _commentFlutterPluginBlock(String yaml) {
  final lines = yaml.split('\n');
  final output = <String>[];

  var commentingFlutterBlock = false;
  for (final line in lines) {
    final indent = _indentOf(line);
    final startsFlutterBlock = RegExp(r'^flutter:\s*$').hasMatch(line);

    if (startsFlutterBlock) {
      commentingFlutterBlock = true;
    } else if (commentingFlutterBlock && line.trim().isNotEmpty && indent == 0) {
      commentingFlutterBlock = false;
    }

    if (commentingFlutterBlock && line.trim().isNotEmpty && !line.trimLeft().startsWith('#')) {
      output.add('# $line');
    } else {
      output.add(line);
    }
  }

  return output.join('\n');
}

int _indentOf(String line) => line.length - line.trimLeft().length;
