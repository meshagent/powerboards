import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/chat/chat.dart';

ThreadAttachmentAvailability powerboardsThreadAttachmentAvailabilityForStat(StorageEntry? entry) {
  return entry == null ? ThreadAttachmentAvailability.unavailable : ThreadAttachmentAvailability.available;
}

ThreadAttachmentAvailability powerboardsThreadAttachmentAvailabilityForError(Object error) {
  if (error is RoomServerException) {
    final status = error.statusCode ?? error.code;
    if (status == 403 || status == 404) {
      return ThreadAttachmentAvailability.unavailable;
    }
  }
  return ThreadAttachmentAvailability.unknown;
}
