import 'dart:convert';

import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/meshagent.dart';

/// Top-level container: { "agent_configs": [ ... ] }
class AgentConfigSet {
  final List<AgentConfigItem> agentConfigs;

  AgentConfigSet({required this.agentConfigs});

  factory AgentConfigSet.fromJson(Map<String, dynamic> json) {
    final list = json['agent_configs'] as List? ?? const [];
    return AgentConfigSet(agentConfigs: list.map((e) => AgentConfigItem.fromJson(_asMap(e))).toList());
  }

  Map<String, dynamic> toJson() => {'agent_configs': agentConfigs.map((e) => e.toJson()).toList()};

  static AgentConfigSet parse(String jsonString) => AgentConfigSet.fromJson(json.decode(jsonString) as Map<String, dynamic>);
}

String _getFilenameWithoutExtension(String filename) {
  final parts = filename.split('.');

  if (parts.length <= 1) return filename;

  return parts.sublist(0, parts.length - 1).join('.');
}

class AgentConfigItem {
  final String serviceId;
  final AgentConfig config;
  final String? status;

  AgentConfigItem({required this.serviceId, required this.config, this.status});

  factory AgentConfigItem.fromJson(Map<String, dynamic> json) {
    return AgentConfigItem(
      serviceId: (json['file'] ?? '').toString(),
      config: AgentConfig.fromJson(_asMap(json['config'])),
      status: json['status'] as String?,
    );
  }

  // name is a file without the extension
  String get name => _getFilenameWithoutExtension(serviceId);

  Map<String, dynamic> toJson() => {'file': serviceId, 'config': config.toJson(), if (status != null) 'status': status};
}

class AgentConfig {
  final String id;
  final ServiceTemplateSpec manifest;

  AgentConfig({required this.id, required this.manifest});

  factory AgentConfig.fromJson(Map<String, dynamic> json) {
    return AgentConfig(
      id: (json['agent_id'] ?? '').toString(),
      manifest: ServiceTemplateSpec.fromJson({for (final entry in (json['manifest'] as Map).entries) entry.key: entry.value}),
    );
  }

  Map<String, dynamic> toJson() => {'agent_id': id, 'manifest': manifest.toJson()};
}

/// --------------------
/// Helpers
/// --------------------

Map<String, dynamic> _asMap(Object? v) => (v is Map<String, dynamic>) ? v : <String, dynamic>{};

/// Top-level container: { "images": [ ... ] }
class ServiceDirectoryPage {
  final List<ServiceDirectoryEntry> templates;

  ServiceDirectoryPage({required this.templates});

  static Future<ServiceDirectoryPage> fromJson(Map<String, dynamic> json) async {
    final list = json['templates'] as List? ?? const [];
    final templates = await Future.wait(list.map((e) => ServiceDirectoryEntry.fromJson(_asMap(e))).toList());

    return ServiceDirectoryPage(templates: templates);
  }

  Map<String, dynamic> toJson() => {'templates': templates.map((e) => e.toJson()).toList()};

  static Future<ServiceDirectoryPage> parse(String jsonString) =>
      ServiceDirectoryPage.fromJson(json.decode(jsonString) as Map<String, dynamic>);
}

class ServiceDirectoryEntry {
  ServiceDirectoryEntry({required this.template, required this.parsed});

  static Future<ServiceDirectoryEntry> fromJson(Map<String, dynamic> json) async {
    final template = (json['template'] ?? '').toString();

    final client = getMeshagentClient();

    final parsed = await client.renderTemplate(template: template, values: {});

    return ServiceDirectoryEntry(template: template, parsed: parsed);
  }

  final String template;
  final ServiceTemplateSpec parsed;

  Map<String, dynamic> toJson() => {'template': template};
}
