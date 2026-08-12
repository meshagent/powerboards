import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/agent_config.dart';
import 'package:powerboards/meshagent/assistant_quick_start.dart';

ServiceSpec _assistantService() {
  return ServiceSpec(
    metadata: ServiceMetadata(name: 'assistant', annotations: const {'meshagent.service.id': powerboardsAssistantServiceId}),
  );
}

ServiceDirectoryEntry _directoryEntry({required String template, required String serviceId, required String name}) {
  return ServiceDirectoryEntry(
    template: template,
    parsed: ServiceTemplateSpec(
      metadata: ServiceTemplateMetadata(name: name, annotations: {'meshagent.service.id': serviceId}),
    ),
  );
}

void main() {
  test('Assistant directory lookup uses the exact service id instead of display name', () {
    final matching = _directoryEntry(
      template: 'assistant-template',
      serviceId: powerboardsAssistantServiceId,
      name: 'Different display name',
    );
    final directory = ServiceDirectoryPage(
      templates: [
        _directoryEntry(template: 'wrong-template', serviceId: 'meshagent.other', name: 'Assistant'),
        matching,
      ],
    );

    expect(powerboardsAssistantDirectoryEntry(directory), same(matching));
  });

  test('Assistant availability requires its named remote participant', () {
    expect(powerboardsAssistantParticipantIsAvailable(agentName: null, remoteParticipantNames: const ['assistant-agent']), isFalse);
    expect(
      powerboardsAssistantParticipantIsAvailable(agentName: 'assistant-agent', remoteParticipantNames: const ['other-agent']),
      isFalse,
    );
    expect(
      powerboardsAssistantParticipantIsAvailable(agentName: ' assistant-agent ', remoteParticipantNames: const ['assistant-agent']),
      isTrue,
    );
  });

  test('quick start preserves Assistant defaults and omits email when skipped', () async {
    var serviceLoads = 0;
    String? savedTemplate;
    Map<String, String>? savedValues;

    final outcome = await installPowerboardsAssistantQuickStart(
      projectId: 'project',
      roomName: 'room',
      availabilityRetryDelay: Duration.zero,
      loadServices: () async {
        serviceLoads += 1;
        return serviceLoads >= 3 ? [_assistantService()] : <ServiceSpec>[];
      },
      isAvailable: (_) => serviceLoads >= 4,
      loadDirectory: () async => ServiceDirectoryPage(
        templates: [
          _directoryEntry(template: 'wrong-template', serviceId: 'meshagent.other', name: 'Assistant'),
          _directoryEntry(template: 'assistant-template', serviceId: powerboardsAssistantServiceId, name: 'Not the display name'),
        ],
      ),
      saveTemplate: (template, values) async {
        savedTemplate = template;
        savedValues = values;
        return _assistantService();
      },
    );

    expect(outcome, PowerboardsAssistantInstallOutcome.installed);
    expect(serviceLoads, 4);
    expect(savedTemplate, 'assistant-template');
    expect(savedValues, {'provider': 'OpenAI', 'heartbeat': 'off'});
  });

  test('quick start sends the complete email and tolerates an already-installed race', () async {
    var serviceLoads = 0;
    Map<String, String>? savedValues;

    final outcome = await installPowerboardsAssistantQuickStart(
      projectId: 'project',
      roomName: 'room',
      email: 'helper@mail.example.test',
      loadServices: () async {
        serviceLoads += 1;
        return serviceLoads >= 2 ? [_assistantService()] : <ServiceSpec>[];
      },
      loadDirectory: () async => ServiceDirectoryPage(
        templates: [_directoryEntry(template: 'assistant-template', serviceId: powerboardsAssistantServiceId, name: 'Assistant')],
      ),
      saveTemplate: (template, values) async {
        savedValues = values;
        throw StateError('conflict');
      },
    );

    expect(outcome, PowerboardsAssistantInstallOutcome.alreadyInstalled);
    expect(savedValues, {'provider': 'OpenAI', 'heartbeat': 'off', 'email': 'helper@mail.example.test'});
  });

  test('quick start returns without opening the directory when Assistant is already installed', () async {
    var directoryLoads = 0;
    var saves = 0;

    final outcome = await installPowerboardsAssistantQuickStart(
      projectId: 'project',
      roomName: 'room',
      loadServices: () async => [_assistantService()],
      loadDirectory: () async {
        directoryLoads += 1;
        return ServiceDirectoryPage(templates: []);
      },
      saveTemplate: (template, values) async {
        saves += 1;
        return _assistantService();
      },
    );

    expect(outcome, PowerboardsAssistantInstallOutcome.alreadyInstalled);
    expect(directoryLoads, 0);
    expect(saves, 0);
  });

  test('quick start waits for an installed Assistant to become connected', () async {
    var serviceLoads = 0;
    var availabilityChecks = 0;
    var directoryLoads = 0;

    final outcome = await installPowerboardsAssistantQuickStart(
      projectId: 'project',
      roomName: 'room',
      availabilityAttempts: 4,
      availabilityRetryDelay: Duration.zero,
      loadServices: () async {
        serviceLoads += 1;
        return [_assistantService()];
      },
      loadDirectory: () async {
        directoryLoads += 1;
        return ServiceDirectoryPage(templates: []);
      },
      saveTemplate: (_, _) async => _assistantService(),
      isAvailable: (_) {
        availabilityChecks += 1;
        return availabilityChecks >= 3;
      },
    );

    expect(outcome, PowerboardsAssistantInstallOutcome.alreadyInstalled);
    expect(serviceLoads, 3);
    expect(availabilityChecks, 3);
    expect(directoryLoads, 0);
  });
}
