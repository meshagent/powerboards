import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';
import 'package:powerboards/meshagent/path.dart';

class FileUploadHelper {
  static Future<Uint8List> _convertImage(Uint8List bytes) async {
    if (kIsWeb) {
      throw UnsupportedError("Web doesn't support image compression well");
    }

    return FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1920 * 3,
      minHeight: 1920 * 3,
      autoCorrectionAngle: true,
      format: CompressFormat.webp,
    );
  }

  static Future<Uint8List> _readAllBytes(Stream<Uint8List> stream) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static Future<void> upload({
    required Stream<Uint8List> stream,
    required int size,
    required String name,
    required String? extension,
    required String path,
    required Future<void> Function(Stream<Uint8List> stream, String fileName, int size) onUpload,
  }) async {
    final ext = extension?.toLowerCase();
    final isHeic = ext == 'heic' || ext == 'heif';

    String uploadName = joinPaths(path, name);

    if (!isHeic || kIsWeb) {
      await onUpload(stream, uploadName, size);
      return;
    }

    var uploadBytes = await _readAllBytes(stream);

    try {
      uploadBytes = await _convertImage(uploadBytes);

      if (!uploadName.toLowerCase().endsWith('.webp')) {
        final dot = uploadName.lastIndexOf('.');
        uploadName = '${dot > -1 ? uploadName.substring(0, dot) : uploadName}.webp';
      }
    } catch (e, st) {
      debugPrint("Conversion failed: $e\n$st");
    }

    await onUpload(Stream<Uint8List>.value(uploadBytes), uploadName, uploadBytes.length);
  }

  static Future<void> pickAndUploadFiles({
    required String path,
    required Future<void> Function(Stream<Uint8List> stream, String fileName, int size) onUpload,
  }) async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: "Select files",
      allowMultiple: true,
      withReadStream: true,
      withData: kIsWeb,
    );
    if (picked == null) return;

    for (final file in picked.files) {
      final source = PlatformFileSource(file);
      final stream = source.read();
      final size = file.size;
      await upload(stream: stream, size: size, name: file.name, extension: file.extension, path: path, onUpload: onUpload);
    }
  }

  static Future<void> pickAndUploadPhotos({
    required String path,
    required Future<void> Function(Stream<Uint8List> stream, String fileName, int size) onUpload,
  }) async {
    final picker = ImagePicker();

    List<XFile> picked = const [];
    try {
      picked = await picker.pickMultipleMedia(); // images and videos
    } catch (_) {
      // Older web/mobile builds may not support pickMultipleMedia.
    }
    if (picked.isEmpty) {
      try {
        picked = await picker.pickMultiImage(); // at least images
      } catch (_) {
        // As a last resort, single image (some platforms).
        final single = await picker.pickImage(source: ImageSource.gallery);
        if (single != null) picked = [single];
      }
    }
    if (picked.isEmpty) return;

    final names = PhotoNamer.generateBatchNames(picked);

    for (var i = 0; i < picked.length; i++) {
      final xf = picked[i];
      final fileName = names[i];
      final source = XFileSource(xf);
      final stream = source.read();
      final size = await (source.length());
      await upload(stream: stream, size: size ?? 0, name: fileName, extension: source.extension, path: path, onUpload: onUpload);
    }
  }
}

abstract class FileSource {
  Stream<Uint8List> read();
  String get name;
  String? get extension;
  Future<int?> length();
}

class PlatformFileSource implements FileSource {
  final PlatformFile file;
  PlatformFileSource(this.file);

  @override
  String get name => file.name;

  @override
  String? get extension => file.extension?.toLowerCase();

  @override
  Future<int?> length() async => file.size == 0 ? null : file.size;

  @override
  Stream<Uint8List> read() {
    // Web: bytes is populated.
    if (file.bytes != null) {
      return Stream<Uint8List>.value(file.bytes!);
    }

    // Mobile when withReadStream: true
    if (file.readStream != null) {
      return file.readStream!.map((chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk));
    }

    throw UnsupportedError(
      'No readable stream available for ${file.name}. '
      'Enable withReadStream: true or ensure bytes are provided.',
    );
  }
}

class XFileSource implements FileSource {
  final XFile file;
  XFileSource(this.file);

  @override
  String get name => file.name;

  @override
  String? get extension {
    final idx = file.name.lastIndexOf('.');
    if (idx <= 0) return null;
    return file.name.substring(idx + 1).toLowerCase();
  }

  @override
  Future<int?> length() => file.length();

  @override
  Stream<Uint8List> read() {
    return file.openRead();
  }
}
