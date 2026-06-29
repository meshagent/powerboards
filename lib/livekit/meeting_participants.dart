import 'package:livekit_client/livekit_client.dart' as lk;

bool isActiveVideoPublication(lk.TrackPublication publication) {
  return publication.kind == lk.TrackType.VIDEO && !publication.muted && publication.track is lk.VideoTrack;
}

lk.TrackPublication? activeVideoPublicationForSource(lk.Participant participant, lk.TrackSource source) {
  for (final publication in participant.trackPublications.values) {
    if (publication.source != source) {
      continue;
    }

    if (isActiveVideoPublication(publication)) {
      return publication;
    }
  }

  return null;
}

Iterable<lk.TrackPublication> activeVideoPublications(lk.Participant participant, {lk.TrackSource? source}) sync* {
  if (source != null) {
    final publication = activeVideoPublicationForSource(participant, source);
    if (publication != null) {
      yield publication;
    }
    return;
  }

  final seenSources = <lk.TrackSource>{};
  for (final publication in participant.trackPublications.values) {
    if (!isActiveVideoPublication(publication)) {
      continue;
    }

    if (!seenSources.add(publication.source)) {
      continue;
    }

    yield publication;
  }
}

List<lk.Participant> uniqueMeetingParticipants(lk.Room room, {Iterable<String> hiddenAgentNames = const []}) {
  final participantsByIdentity = <String, lk.Participant>{};
  final hiddenAgentNameSet = hiddenAgentNames.map(_normalizeParticipantName).where((name) => name.isNotEmpty).toSet();

  for (final participant in room.remoteParticipants.values) {
    if (_isHiddenMeetingParticipant(participant, hiddenAgentNameSet)) {
      continue;
    }

    participantsByIdentity.putIfAbsent(_participantKey(participant), () => participant);
  }

  final localParticipant = room.localParticipant;
  if (localParticipant != null) {
    participantsByIdentity[_participantKey(localParticipant)] = localParticipant;
  }

  return participantsByIdentity.values.toList(growable: false);
}

String _participantKey(lk.Participant participant) {
  return participant.identity.isNotEmpty ? participant.identity : participant.sid;
}

bool _isHiddenMeetingParticipant(lk.Participant participant, Set<String> hiddenAgentNames) {
  return isHiddenMeetingParticipant(
    identity: participant.identity,
    participantName: participant.attributes["name"],
    hiddenAgentNames: hiddenAgentNames,
  );
}

bool isHiddenMeetingParticipant({required String identity, Object? participantName, Iterable<String> hiddenAgentNames = const []}) {
  final isRecorder = identity.endsWith(".agent-recorder");
  final isTranscriber = identity.endsWith(".agent-transcriber");
  if (isRecorder || isTranscriber) {
    return true;
  }

  final hiddenAgentNameSet = hiddenAgentNames.map(_normalizeParticipantName).where((name) => name.isNotEmpty).toSet();
  final normalizedParticipantName = _normalizeParticipantName(participantName);
  return normalizedParticipantName.isNotEmpty && hiddenAgentNameSet.contains(normalizedParticipantName);
}

String _normalizeParticipantName(Object? value) {
  return value is String ? value.trim().toLowerCase() : '';
}
