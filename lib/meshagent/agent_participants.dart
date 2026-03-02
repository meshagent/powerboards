import 'dart:convert';

import 'package:meshagent/meshagent.dart';

const developmentAgentRoutePrefix = "remote-participant-name-";
const _legacyDevelopmentAgentRoutePrefix = "remote-participant:";

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

bool participantSupportsChat(RemoteParticipant participant) {
  final value = participant.getAttribute("supports_chat");
  if (value is bool) {
    return value;
  }

  return true;
}

bool isChatOrVoiceBotParticipant(RemoteParticipant participant) {
  if (participant.role != "agent") {
    return false;
  }

  return participantSupportsVoice(participant) || participantSupportsChat(participant);
}
