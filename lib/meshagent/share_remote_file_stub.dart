import 'package:flutter/widgets.dart';
import 'package:meshagent/room_server_client.dart';

Future<void> shareRemoteStorageFileImpl({required BuildContext context, required RoomClient client, required String path}) {
  throw UnsupportedError('Native file sharing is only available on iOS and Android.');
}
