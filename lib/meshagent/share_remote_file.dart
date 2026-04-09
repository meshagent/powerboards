import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:meshagent/room_server_client.dart';

import 'share_remote_file_stub.dart' if (dart.library.io) 'share_remote_file_io.dart';

bool get supportsNativeFileShare {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => false,
  };
}

Future<void> shareRemoteStorageFile({required BuildContext context, required RoomClient client, required String path}) {
  return shareRemoteStorageFileImpl(context: context, client: client, path: path);
}
