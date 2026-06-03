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
}
