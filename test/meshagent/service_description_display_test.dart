import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/meshagent/agent_containers.dart';

void main() {
  test('preserves the full published hostname for an archived website folder', () {
    expect(powerboardsArchivedWebServerFolderName('https://test-23x.meshagent.dev/path'), 'test-23x.meshagent.dev');
  });

  test('uses canonical web server description for installed services', () {
    final service = ServiceSpec(
      metadata: ServiceMetadata(
        name: 'web server',
        description: 'Old description',
        annotations: const {'meshagent.service.id': powerboardsWebServerServiceId},
      ),
    );

    expect(powerboardsDisplayServiceDescriptionForService(service, enableV1WebServerPresentation: true), powerboardsWebServerDescription);
    expect(powerboardsDisplayServiceDescriptionForService(service), 'Old description');
  });

  test('uses canonical web server description for templates', () {
    final template = ServiceTemplateSpec(
      metadata: ServiceTemplateMetadata(
        name: 'web server',
        description: 'Old description',
        annotations: const {'meshagent.service.id': powerboardsWebServerServiceId},
      ),
    );

    expect(powerboardsDisplayServiceDescriptionForTemplate(template, enableV1WebServerPresentation: true), powerboardsWebServerDescription);
    expect(powerboardsDisplayServiceDescriptionForTemplate(template), 'Old description');
  });

  test('keeps the V1 web server icon out of legacy presentation', () {
    final service = ServiceSpec(
      metadata: ServiceMetadata(name: 'web server', annotations: const {'meshagent.service.id': powerboardsWebServerServiceId}),
    );

    expect(powerboardsServiceIconAssetName(service: service), isNull);
    expect(powerboardsServiceIconAssetName(service: service, enableV1WebServerPresentation: true), powerboardsWebServerIconAssetName);
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

  test('restores archived website files before saving the web server service', () async {
    final events = <String>[];

    final result = await powerboardsSaveServiceAfterPreparingWebServerFolder(
      isWebServer: true,
      prepareWebServerFolder: () async => events.add('restore files'),
      saveService: () async {
        events.add('start service');
        return 'saved';
      },
    );

    expect(result, 'saved');
    expect(events, ['restore files', 'start service']);
  });

  test('does not prepare a web server folder for other services', () async {
    final events = <String>[];

    await powerboardsSaveServiceAfterPreparingWebServerFolder(
      isWebServer: false,
      prepareWebServerFolder: () async => events.add('restore files'),
      saveService: () async => events.add('start service'),
    );

    expect(events, ['start service']);
  });
}
