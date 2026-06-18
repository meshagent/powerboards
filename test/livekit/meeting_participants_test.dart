import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/livekit/meeting_participants.dart';

void main() {
  test('hides recorder and transcriber participants by legacy identity suffix', () {
    expect(isHiddenMeetingParticipant(identity: 'room.agent-recorder'), isTrue);
    expect(isHiddenMeetingParticipant(identity: 'room.agent-transcriber'), isTrue);
  });

  test('hides meeting transcriber participants by installed service agent name', () {
    expect(
      isHiddenMeetingParticipant(
        identity: 'meeting-transcriber.agent',
        participantName: 'Meeting Transcriber',
        hiddenAgentNames: const ['meeting transcriber'],
      ),
      isTrue,
    );
  });

  test('keeps unrelated agents and people visible', () {
    expect(
      isHiddenMeetingParticipant(
        identity: 'assistant.agent',
        participantName: 'Assistant',
        hiddenAgentNames: const ['Meeting Transcriber'],
      ),
      isFalse,
    );
    expect(isHiddenMeetingParticipant(identity: 'dinesh', participantName: 'Dinesh'), isFalse);
  });
}
