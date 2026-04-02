import 'dart:convert';

import 'package:meshagent/meshagent.dart';

const developmentAgentRoutePrefix = "remote-participant-name-";
const _legacyDevelopmentAgentRoutePrefix = "remote-participant:";

enum AgentConversationKind { chat, voiceOnly, meeting }

enum ChatThreadDisplayMode { singleThread, multiThreadComposer }

class AgentConversationDescriptor {
  const AgentConversationDescriptor._({
    required this.kind,
    this.chatThreadDisplayMode = ChatThreadDisplayMode.singleThread,
    this.threadDir,
    this.threadListPath,
  });

  const AgentConversationDescriptor.chat({
    ChatThreadDisplayMode chatThreadDisplayMode =
        ChatThreadDisplayMode.singleThread,
    String? threadDir,
    String? threadListPath,
  }) : this._(
         kind: AgentConversationKind.chat,
         chatThreadDisplayMode: chatThreadDisplayMode,
         threadDir: threadDir,
         threadListPath: threadListPath,
       );

  const AgentConversationDescriptor.voiceOnly()
    : this._(kind: AgentConversationKind.voiceOnly);

  const AgentConversationDescriptor.meeting()
    : this._(kind: AgentConversationKind.meeting);

  final AgentConversationKind kind;
  final ChatThreadDisplayMode chatThreadDisplayMode;
  final String? threadDir;
  final String? threadListPath;

  bool get isChat => kind == AgentConversationKind.chat;
  bool get isVoiceOnly => kind == AgentConversationKind.voiceOnly;
  bool get isMeeting => kind == AgentConversationKind.meeting;
  bool get isMultiThreadChat =>
      isChat &&
      chatThreadDisplayMode == ChatThreadDisplayMode.multiThreadComposer;
}

String developmentAgentRouteId(String participantName) {
  final normalized = participantName.trim();
  final encoded = base64Url.encode(utf8.encode(normalized)).replaceAll('=', '');
  return "$developmentAgentRoutePrefix$encoded";
}

String? developmentAgentNameFromRoute(String routeId) {
  if (!routeId.startsWith(developmentAgentRoutePrefix)) {
    return null;
  }

  final encoded = routeId.substring(developmentAgentRoutePrefix.length).trim();
  if (encoded.isEmpty) {
    return null;
  }

  final padding = (4 - encoded.length % 4) % 4;
  final padded = encoded.padRight(encoded.length + padding, '=');
  try {
    final decoded = utf8.decode(base64Url.decode(padded)).trim();
    if (decoded.isEmpty) {
      return null;
    }
    return decoded;
  } catch (_) {
    return null;
  }
}

String? legacyDevelopmentAgentParticipantIdFromRoute(String routeId) {
  if (!routeId.startsWith(_legacyDevelopmentAgentRoutePrefix)) {
    return null;
  }

  final participantId = routeId
      .substring(_legacyDevelopmentAgentRoutePrefix.length)
      .trim();
  if (participantId.isEmpty) {
    return null;
  }

  return participantId;
}

String? participantDisplayName(RemoteParticipant participant) {
  final rawName = participant.getAttribute("name");
  if (rawName is! String) {
    return null;
  }

  final name = rawName.trim();
  if (name.isEmpty) {
    return null;
  }

  return name;
}

bool participantSupportsVoice(RemoteParticipant participant) {
  final value = participant.getAttribute("supports_voice");
  return value is bool && value;
}

bool? participantSupportsChatOverride(RemoteParticipant participant) {
  final value = participant.getAttribute("supports_chat");
  return value is bool ? value : null;
}

bool participantSupportsChat(RemoteParticipant participant) {
  final value = participantSupportsChatOverride(participant);
  if (value is bool) {
    return value;
  }

  return true;
}

String? _normalizedAnnotationString(Object? value) {
  if (value is! String) {
    return null;
  }

  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }

  return normalized;
}

ChatThreadDisplayMode chatThreadDisplayModeFromAnnotation(Object? value) {
  final normalized = _normalizedAnnotationString(value);
  if (normalized == "default-new") {
    return ChatThreadDisplayMode.multiThreadComposer;
  }

  return ChatThreadDisplayMode.singleThread;
}

String? _normalizedThreadDir(String? threadDir) {
  if (threadDir == null) {
    return null;
  }

  final trimmed = threadDir.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return trimmed.endsWith("/")
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}

String? _threadListPathFromThreadDir(String? threadDir) {
  final normalized = _normalizedThreadDir(threadDir);
  if (normalized == null) {
    return null;
  }

  return "$normalized/index.threadl";
}

String? participantThreadDir(RemoteParticipant participant) {
  final value = participant.getAttribute("meshagent.chatbot.thread-dir");
  if (value is! String) {
    return null;
  }

  return _normalizedThreadDir(value);
}

String? participantThreadListPath(RemoteParticipant participant) {
  final threadListPath = _normalizedAnnotationString(
    participant.getAttribute("meshagent.chatbot.thread-list"),
  );
  if (threadListPath != null) {
    return threadListPath;
  }

  return _threadListPathFromThreadDir(participantThreadDir(participant));
}

AgentConversationDescriptor? participantConversationDescriptor(
  RemoteParticipant participant,
) {
  final supportsVoice = participantSupportsVoice(participant);
  final supportsChatOverride = participantSupportsChatOverride(participant);
  final threadDir = participantThreadDir(participant);
  final threadListPath = participantThreadListPath(participant);
  final hasThreadAnnotations =
      _normalizedAnnotationString(
            participant.getAttribute("meshagent.chatbot.threading"),
          ) !=
          null ||
      threadDir != null ||
      threadListPath != null;

  if (supportsChatOverride == false) {
    return supportsVoice ? const AgentConversationDescriptor.voiceOnly() : null;
  }

  if (supportsVoice && supportsChatOverride != true && !hasThreadAnnotations) {
    return const AgentConversationDescriptor.voiceOnly();
  }

  if (hasThreadAnnotations || participantSupportsChat(participant)) {
    return AgentConversationDescriptor.chat(
      chatThreadDisplayMode: chatThreadDisplayModeFromAnnotation(
        participant.getAttribute("meshagent.chatbot.threading"),
      ),
      threadDir: threadDir,
      threadListPath: threadListPath,
    );
  }

  if (supportsVoice) {
    return const AgentConversationDescriptor.voiceOnly();
  }

  return null;
}

String? serviceThreadDir(ServiceSpec service) {
  return _normalizedThreadDir(
    service.agents.firstOrNull?.annotations["meshagent.chatbot.thread-dir"],
  );
}

String? serviceThreadListPath(
  ServiceSpec service, {
  Iterable<RemoteParticipant> remoteParticipants = const [],
}) {
  final annotationPath = _normalizedAnnotationString(
    service.agents.firstOrNull?.annotations["meshagent.chatbot.thread-list"],
  );
  if (annotationPath != null) {
    return annotationPath;
  }

  final threadDir = serviceThreadDir(service);
  final threadListPath = _threadListPathFromThreadDir(threadDir);
  if (threadListPath != null) {
    return threadListPath;
  }

  final agentName = service.agents.firstOrNull?.name;
  if (agentName == null || agentName.trim().isEmpty) {
    return null;
  }

  for (final participant in remoteParticipants) {
    if (participant.getAttribute("name") == agentName) {
      return participantThreadListPath(participant);
    }
  }

  return null;
}

AgentConversationDescriptor? serviceConversationDescriptor(
  ServiceSpec service, {
  Iterable<RemoteParticipant> remoteParticipants = const [],
}) {
  final type = service.agents.firstOrNull?.annotations["meshagent.agent.type"];
  if (type == "VoiceBot") {
    return const AgentConversationDescriptor.voiceOnly();
  }

  if (type == "MeetingTranscriber") {
    return const AgentConversationDescriptor.meeting();
  }

  if (type != "ChatBot") {
    return null;
  }

  return AgentConversationDescriptor.chat(
    chatThreadDisplayMode: chatThreadDisplayModeFromAnnotation(
      service.agents.firstOrNull?.annotations["meshagent.chatbot.threading"],
    ),
    threadDir: serviceThreadDir(service),
    threadListPath: serviceThreadListPath(
      service,
      remoteParticipants: remoteParticipants,
    ),
  );
}

bool isChatOrVoiceBotParticipant(RemoteParticipant participant) {
  if (participant.role != "agent") {
    return false;
  }

  return participantSupportsVoice(participant) ||
      participantSupportsChat(participant);
}
