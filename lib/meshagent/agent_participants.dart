import 'dart:convert';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_shadcn/chat/conversation_descriptor.dart' as ma;

const developmentAgentRoutePrefix = "remote-participant-name-";
const _legacyDevelopmentAgentRoutePrefix = "remote-participant:";

typedef AgentConversationKind = ma.ChatAgentConversationKind;
typedef ChatThreadDisplayMode = ma.ChatThreadDisplayMode;
typedef AgentConversationDescriptor = ma.ChatAgentConversationDescriptor;

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

  final participantId = routeId.substring(_legacyDevelopmentAgentRoutePrefix.length).trim();
  if (participantId.isEmpty) {
    return null;
  }

  return participantId;
}

String? participantDisplayName(RemoteParticipant participant) => ma.participantDisplayName(participant);

bool participantSupportsVoice(RemoteParticipant participant) => ma.participantSupportsVoice(participant);

bool? participantSupportsChatOverride(RemoteParticipant participant) => ma.participantSupportsChatOverride(participant);

bool participantSupportsChat(RemoteParticipant participant) => ma.participantSupportsChat(participant);

ChatThreadDisplayMode chatThreadDisplayModeFromAnnotation(Object? value) => ma.chatThreadDisplayModeFromAnnotation(value);

String? participantThreadDir(RemoteParticipant participant) => ma.participantThreadDir(participant);

String? participantThreadListPath(RemoteParticipant participant) => ma.participantThreadListPath(participant);

AgentConversationDescriptor? participantConversationDescriptor(RemoteParticipant participant) =>
    ma.participantConversationDescriptor(participant);

String? serviceThreadDir(ServiceSpec service) => ma.serviceThreadDir(service);

String? serviceThreadListPath(ServiceSpec service, {Iterable<RemoteParticipant> remoteParticipants = const []}) =>
    ma.serviceThreadListPath(service, remoteParticipants: remoteParticipants);

AgentConversationDescriptor? serviceConversationDescriptor(
  ServiceSpec service, {
  Iterable<RemoteParticipant> remoteParticipants = const [],
}) => ma.serviceConversationDescriptor(service, remoteParticipants: remoteParticipants);

bool isChatOrVoiceBotParticipant(RemoteParticipant participant) {
  if (participant.role != "agent") {
    return false;
  }

  return participantSupportsVoice(participant) || participantSupportsChat(participant);
}
