import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/meshagent_flutter_shadcn.dart';

class ChatStartResult {
  const ChatStartResult({required this.messageId, required this.chatId, required this.threadPath, required this.title});

  final String messageId;
  final String chatId;
  final String threadPath;
  final String title;
}

abstract class DocumentRegistrar {
  ChatStartResult register({
    required String id,
    required RoomClient client,
    required String chatId,
    required String initialMessageText,
    required List<FileAttachment> initialMessageAttachments,
    required String title,
  });
}

class SettingsDocRegistrar implements DocumentRegistrar {
  @override
  ChatStartResult register({
    required String id,
    required RoomClient client,
    required String chatId,
    required String initialMessageText,
    required List<FileAttachment> initialMessageAttachments,
    required String title,
  }) {
    final threadPath = '.threads/$id.thread';

    return ChatStartResult(messageId: id, chatId: chatId, threadPath: threadPath, title: title);
  }
}
