import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:meshagent/room_server_client.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareRemoteStorageFileImpl({required BuildContext context, required RoomClient client, required String path}) async {
  final box = context.findRenderObject() as RenderBox?;
  final sharePositionOrigin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;

  final url = await client.storage.downloadUrl(path);
  final response = await http.get(Uri.parse(url));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException('Download failed with status ${response.statusCode}', uri: Uri.parse(url));
  }

  final tempDirectory = await getTemporaryDirectory();
  final filename = p.basename(path);
  final file = File(p.join(tempDirectory.path, filename));
  await file.writeAsBytes(response.bodyBytes, flush: true);

  await Share.shareXFiles([XFile(file.path, mimeType: lookupMimeType(filename))], sharePositionOrigin: sharePositionOrigin);
}
