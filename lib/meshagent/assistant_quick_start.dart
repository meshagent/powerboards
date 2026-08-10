import 'package:flutter/foundation.dart';
import 'package:meshagent/meshagent.dart';

import 'agent_config.dart';
import 'agent_containers.dart';
import 'meshagent.dart';

const String powerboardsAssistantServiceId = 'meshagent.assistant';

enum PowerboardsAssistantInstallOutcome { installed, alreadyInstalled }

typedef PowerboardsAssistantServicesLoader = Future<List<ServiceSpec>> Function();
typedef PowerboardsAssistantDirectoryLoader = Future<ServiceDirectoryPage> Function();
typedef PowerboardsAssistantTemplateSaver = Future<ServiceSpec> Function(String template, Map<String, String> values);
typedef PowerboardsAssistantAvailabilityChecker = bool Function(ServiceSpec service);

@visibleForTesting
Map<String, String> powerboardsAssistantTemplateValues({String? email}) {
  final normalizedEmail = email?.trim();
  return <String, String>{
    'provider': 'OpenAI',
    'heartbeat': 'off',
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) 'email': normalizedEmail,
  };
}

ServiceSpec? _assistantService(Iterable<ServiceSpec> services) {
  for (final service in services) {
    if (service.metadata.annotations['meshagent.service.id']?.trim() == powerboardsAssistantServiceId) {
      return service;
    }
  }
  return null;
}

Future<PowerboardsAssistantInstallOutcome> installPowerboardsAssistantQuickStart({
  required String projectId,
  required String roomName,
  String? email,
  PowerboardsAssistantServicesLoader? loadServices,
  PowerboardsAssistantDirectoryLoader? loadDirectory,
  PowerboardsAssistantTemplateSaver? saveTemplate,
  PowerboardsAssistantAvailabilityChecker? isAvailable,
  int availabilityAttempts = 40,
  Duration availabilityRetryDelay = const Duration(milliseconds: 250),
  Future<void> Function(Duration delay) wait = Future<void>.delayed,
}) async {
  final normalizedProjectId = projectId.trim();
  final normalizedRoomName = roomName.trim();
  if (normalizedProjectId.isEmpty || normalizedRoomName.isEmpty) {
    throw StateError('Assistant room context is not available.');
  }
  if (availabilityAttempts <= 0) {
    throw ArgumentError.value(availabilityAttempts, 'availabilityAttempts', 'must be positive');
  }

  final client = loadServices == null || saveTemplate == null ? getMeshagentClient() : null;
  final effectiveLoadServices =
      loadServices ?? () => client!.listRoomServices(projectId: normalizedProjectId, roomName: normalizedRoomName);
  final effectiveLoadDirectory = loadDirectory ?? loadPowerboardsServiceDirectory;
  final effectiveSaveTemplate =
      saveTemplate ??
      (template, values) => powerboardsSaveRoomServiceFromTemplate(
        client: client!,
        projectId: normalizedProjectId,
        roomName: normalizedRoomName,
        template: template,
        values: values,
      );

  var outcome = PowerboardsAssistantInstallOutcome.installed;
  var assistant = _assistantService(await effectiveLoadServices());
  if (assistant != null) {
    outcome = PowerboardsAssistantInstallOutcome.alreadyInstalled;
    if (isAvailable?.call(assistant) ?? true) {
      return outcome;
    }
  }

  if (assistant == null) {
    final directory = await effectiveLoadDirectory();
    ServiceDirectoryEntry? assistantTemplate;
    for (final entry in directory.templates) {
      if (entry.parsed.metadata.annotations['meshagent.service.id']?.trim() == powerboardsAssistantServiceId) {
        assistantTemplate = entry;
        break;
      }
    }
    if (assistantTemplate == null) {
      throw StateError('Assistant is not available in the service directory.');
    }

    try {
      await effectiveSaveTemplate(assistantTemplate.template, powerboardsAssistantTemplateValues(email: email));
    } catch (error, stackTrace) {
      assistant = _assistantService(await effectiveLoadServices());
      if (assistant == null) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      outcome = PowerboardsAssistantInstallOutcome.alreadyInstalled;
    }
  }

  for (var attempt = 0; attempt < availabilityAttempts; attempt++) {
    assistant = _assistantService(await effectiveLoadServices());
    if (assistant != null && (isAvailable?.call(assistant) ?? true)) {
      return outcome;
    }
    if (attempt + 1 < availabilityAttempts) {
      await wait(availabilityRetryDelay);
    }
  }

  throw StateError('Assistant is installed but is not available yet. Try again.');
}
