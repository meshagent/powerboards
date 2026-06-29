import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/meshagent.dart' as powerboards_meshagent;

void main() {
  test('hasAgentMetadata only accepts services with agent metadata entries', () {
    final webService = ServiceSpec(
      metadata: ServiceMetadata(name: 'web', annotations: const {'meshagent.service.id': 'web'}),
    );
    final agentService = ServiceSpec(
      metadata: ServiceMetadata(name: 'assistant-service', annotations: const {'meshagent.service.id': 'assistant-service'}),
      agents: [
        AgentSpec(name: 'assistant', annotations: const {'meshagent.agent.type': 'ChatBot'}),
      ],
    );

    expect(powerboards_meshagent.hasAgentMetadata(webService), isFalse);
    expect(powerboards_meshagent.hasAgentMetadata(agentService), isTrue);
  });

  test('maps voice and meeting transcriber services to the shared v1 icon assets', () {
    final voiceService = ServiceSpec(
      metadata: ServiceMetadata(name: 'voice-service', annotations: const {'meshagent.service.id': 'voice-service'}),
      agents: [
        AgentSpec(name: 'voice', annotations: const {'meshagent.agent.type': 'VoiceBot'}),
      ],
    );
    final transcriberService = ServiceSpec(
      metadata: ServiceMetadata(name: 'transcriber-service', annotations: const {'meshagent.service.id': 'transcriber-service'}),
      agents: [
        AgentSpec(name: 'transcriber', annotations: const {'meshagent.agent.type': 'MeetingTranscriber'}),
      ],
    );
    final transcriberTemplate = ServiceTemplateSpec(
      metadata: ServiceTemplateMetadata(name: 'transcriber', annotations: const {'meshagent.service.id': 'transcriber-service'}),
      agents: [
        AgentTemplateSpec(name: 'transcriber', annotations: const {'meshagent.agent.type': 'MeetingTranscriber'}),
      ],
    );

    expect(powerboards_meshagent.serviceIconAssetName(voiceService), 'audio-lines');
    expect(powerboards_meshagent.serviceIconAssetName(transcriberService), 'captions');
    expect(powerboards_meshagent.serviceTemplateIconAssetName(transcriberTemplate), 'captions');
  });
}
