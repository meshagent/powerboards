import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/agent_containers.dart';

void main() {
  test('uses canonical web server description for installed services', () {
    final service = ServiceSpec(
      metadata: ServiceMetadata(
        name: 'web server',
        description: 'Old description',
        annotations: const {'meshagent.service.id': powerboardsWebServerServiceId},
      ),
    );

    expect(powerboardsDisplayServiceDescriptionForService(service), powerboardsWebServerDescription);
  });

  test('uses canonical web server description for templates', () {
    final template = ServiceTemplateSpec(
      metadata: ServiceTemplateMetadata(
        name: 'web server',
        description: 'Old description',
        annotations: const {'meshagent.service.id': powerboardsWebServerServiceId},
      ),
    );

    expect(powerboardsDisplayServiceDescriptionForTemplate(template), powerboardsWebServerDescription);
  });

  test('keeps non-web-server descriptions unchanged apart from trimming', () {
    final service = ServiceSpec(
      metadata: ServiceMetadata(
        name: 'assistant',
        description: '  Helpful agent.  ',
        annotations: const {'meshagent.service.id': 'assistant'},
      ),
    );

    expect(powerboardsDisplayServiceDescriptionForService(service), 'Helpful agent.');
  });
}
