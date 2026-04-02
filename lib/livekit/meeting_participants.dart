import 'package:livekit_client/livekit_client.dart' as lk;

bool isActiveVideoPublication(lk.TrackPublication publication) {
  return publication.kind == lk.TrackType.VIDEO &&
      !publication.muted &&
      publication.track is lk.VideoTrack;
}

lk.TrackPublication? activeVideoPublicationForSource(
  lk.Participant participant,
  lk.TrackSource source,
) {
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

Iterable<lk.TrackPublication> activeVideoPublications(
  lk.Participant participant, {
  lk.TrackSource? source,
}) sync* {
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

List<lk.Participant> uniqueMeetingParticipants(lk.Room room) {
  final participantsByIdentity = <String, lk.Participant>{};

  for (final participant in room.remoteParticipants.values) {
    final isRecorder = participant.identity.endsWith(".agent-recorder");
    final isTranscriber = participant.identity.endsWith(".agent-transcriber");

    if (isRecorder || isTranscriber) {
      continue;
    }

    participantsByIdentity.putIfAbsent(
      _participantKey(participant),
      () => participant,
    );
  }

  final localParticipant = room.localParticipant;
  if (localParticipant != null) {
    participantsByIdentity[_participantKey(localParticipant)] =
        localParticipant;
  }

  return participantsByIdentity.values.toList(growable: false);
}

String _participantKey(lk.Participant participant) {
  return participant.identity.isNotEmpty
      ? participant.identity
      : participant.sid;
}
